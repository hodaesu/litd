extends Node
class_name VeilleursEncounterDirector

signal encounter_selected(runtime_encounter: Dictionary)

const ENCOUNTERS_PATH := "res://data/veilleurs/encounter_index_v1.json"
const SPECIES_PATH := "res://data/veilleurs/species_catalog_recovered_v1.json"
const SYNERGIES_PATH := "res://data/veilleurs/enemy_synergy_catalog_v1.json"
const CONTRACT_PATH := "res://data/veilleurs/encounter_generation_contract_v1.json"
const HISTORY_WINDOW := 5
const REPEAT_THRESHOLD := 2
const REPEAT_WEIGHT := 0.4
const MAX_STANDARD_ENEMIES := 4

var encounter_data: Dictionary = {}
var species_data: Dictionary = {}
var synergy_data: Dictionary = {}
var contract_data: Dictionary = {}
var recent_history: Array[String] = []
var selection_count := 0

func _ready() -> void:
    reload_content()

func reload_content() -> Dictionary:
    encounter_data = _load_dictionary(ENCOUNTERS_PATH)
    species_data = _load_dictionary(SPECIES_PATH)
    synergy_data = _load_dictionary(SYNERGIES_PATH)
    contract_data = _load_dictionary(CONTRACT_PATH)
    return validation_report()

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    var all: Array[Dictionary] = _all_encounters()
    var synergies: Array = synergy_data.get("records", [])
    if all.size() != 64:
        errors.append("encounters:%d" % all.size())
    if synergies.size() != 21:
        errors.append("synergies:%d" % synergies.size())
    for encounter: Dictionary in all:
        if int(encounter.get("actors", 0)) < 1 or int(encounter.get("actors", 0)) > MAX_STANDARD_ENEMIES:
            errors.append("actor_cap:%s" % str(encounter.get("name", "unknown")))
        var spawn_entries := _spawn_entries(str(encounter.get("composition", "")))
        if spawn_entries.size() != int(encounter.get("actors", 0)):
            errors.append("composition_count:%s" % str(encounter.get("name", "unknown")))
        for spawn: Dictionary in spawn_entries:
            if str(spawn.get("species_id", "")).is_empty():
                errors.append("unknown_species:%s" % str(spawn.get("name", "")))
    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "encounters": all.size(),
        "synergies": synergies.size(),
        "max_standard_enemies": MAX_STANDARD_ENEMIES,
        "anti_repeat_window": HISTORY_WINDOW,
        "repeat_weight": REPEAT_WEIGHT
    }

func select_encounter(seed_value: int, act_token: String, context: Dictionary = {}) -> Dictionary:
    var candidates := _encounters_for_act(act_token)
    if candidates.is_empty():
        return {"success": false, "reason": "no_encounter_for_act"}

    var desired_type := str(context.get("type", ""))
    if not desired_type.is_empty():
        var typed: Array[Dictionary] = []
        for candidate: Dictionary in candidates:
            if str(candidate.get("type", "")) == desired_type:
                typed.append(candidate)
        if not typed.is_empty():
            candidates = typed

    var previous := recent_history[-1] if not recent_history.is_empty() else ""
    if candidates.size() > 1 and not previous.is_empty():
        var without_previous: Array[Dictionary] = []
        for candidate: Dictionary in candidates:
            if str(candidate.get("name", "")) != previous:
                without_previous.append(candidate)
        if not without_previous.is_empty():
            candidates = without_previous

    var weights: Array[float] = []
    var total_weight := 0.0
    for candidate: Dictionary in candidates:
        var name := str(candidate.get("name", ""))
        var recent_count := recent_history.count(name)
        var weight := REPEAT_WEIGHT if recent_count >= REPEAT_THRESHOLD else 1.0
        weights.append(weight)
        total_weight += weight
    if total_weight <= 0.0:
        return {"success": false, "reason": "no_positive_weight"}

    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value * 104729 + int(_act_token(act_token).hash()) * 31 + selection_count * 8191
    var roll := rng.randf() * total_weight
    var picked_index := candidates.size() - 1
    var cursor := 0.0
    for index: int in range(candidates.size()):
        cursor += weights[index]
        if roll <= cursor:
            picked_index = index
            break

    var picked: Dictionary = candidates[picked_index].duplicate(true)
    var runtime := _build_runtime_encounter(picked, context)
    if not bool(runtime.get("success", false)):
        return runtime
    _remember(str(picked.get("name", "")))
    selection_count += 1
    runtime["selection_index"] = selection_count
    runtime["history_after"] = recent_history.duplicate()
    encounter_selected.emit(runtime.duplicate(true))
    return runtime

func runtime_for_named_encounter(encounter_name: String, context: Dictionary = {}) -> Dictionary:
    for encounter: Dictionary in _all_encounters():
        if str(encounter.get("name", "")) == encounter_name:
            return _build_runtime_encounter(encounter, context)
    return {"success": false, "reason": "unknown_encounter", "name": encounter_name}

func active_synergies_for_spawn(spawn_entries: Array) -> Array[Dictionary]:
    var names: Array[String] = []
    for value: Variant in spawn_entries:
        if value is Dictionary:
            names.append(str((value as Dictionary).get("name", "")))
    var result: Array[Dictionary] = []
    for value: Variant in synergy_data.get("records", []):
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        var pair := str(record.get("pair", "")).split(" + ")
        var all_present := true
        for required_name: String in pair:
            if not names.has(required_name):
                all_present = false
                break
        if all_present:
            result.append(record.duplicate(true))
    return result

func serialize() -> Dictionary:
    return {
        "schema_version": 1,
        "recent_history": recent_history.duplicate(),
        "selection_count": selection_count
    }

func deserialize(payload: Dictionary) -> void:
    recent_history.clear()
    for value: Variant in payload.get("recent_history", []):
        recent_history.append(str(value))
    while recent_history.size() > HISTORY_WINDOW:
        recent_history.pop_front()
    selection_count = maxi(0, int(payload.get("selection_count", 0)))

func reset() -> void:
    recent_history.clear()
    selection_count = 0

func _build_runtime_encounter(source: Dictionary, context: Dictionary) -> Dictionary:
    var spawn_entries := _spawn_entries(str(source.get("composition", "")))
    if spawn_entries.size() != int(source.get("actors", 0)):
        return {"success": false, "reason": "canonical_composition_mismatch", "name": source.get("name", "")}
    if spawn_entries.size() > MAX_STANDARD_ENEMIES:
        return {"success": false, "reason": "mobile_actor_cap_exceeded", "name": source.get("name", "")}

    var memorial_overlay := _memorial_overlay(context.get("memorial_candidate", {}), spawn_entries.size())
    if bool(memorial_overlay.get("insert", false)):
        spawn_entries.append(memorial_overlay.get("spawn", {}).duplicate(true))
    var synergies := active_synergies_for_spawn(spawn_entries)
    return {
        "success": true,
        "canonical": true,
        "name": str(source.get("name", "")),
        "type": str(source.get("type", "Standard")),
        "act": _act_token(str(source.get("act_label", context.get("act", "")))),
        "source_composition": str(source.get("composition", "")),
        "source_actor_count": int(source.get("actors", 0)),
        "spawn_entries": spawn_entries,
        "runtime_actor_count": spawn_entries.size(),
        "synergies": synergies,
        "synergy_feedback": _synergy_feedback(synergies),
        "memorial_overlay": memorial_overlay,
        "party_counterpick_used": false,
        "seeded_selection": true
    }

func _memorial_overlay(candidate_value: Variant, source_actor_count: int) -> Dictionary:
    if not (candidate_value is Dictionary) or (candidate_value as Dictionary).is_empty():
        return {"insert": false, "reason": "none"}
    if source_actor_count >= MAX_STANDARD_ENEMIES:
        return {"insert": false, "reason": "actor_cap_full"}
    var candidate: Dictionary = candidate_value
    var entity_id := str(candidate.get("entity_id", candidate.get("remanence_id", "")))
    var species_id := _normalize_species_id(str(candidate.get("species_id", "")))
    var rank := str(candidate.get("memory_rank", "normal")).to_lower()
    if entity_id.is_empty() or species_id.is_empty() or not rank in ["memorial", "veteran", "elite", "nemesis"]:
        return {"insert": false, "reason": "not_persistent_memorial_entity"}
    if species_entry(species_id).is_empty():
        return {"insert": false, "reason": "unknown_species"}
    if rank == "nemesis" and not bool(candidate.get("shared_history", false)):
        return {"insert": false, "reason": "artificial_nemesis_forbidden"}
    var species := species_entry(species_id)
    return {
        "insert": true,
        "reason": "persistent_entity_insertion",
        "spawn": {
            "species_id": species_id,
            "name": str(candidate.get("name", species.get("name", species_id))),
            "family_id": str(species.get("family_id", "")),
            "memory_rank": rank,
            "entity_id": entity_id,
            "persistent_entity": true
        }
    }

func species_entry(species_id: String) -> Dictionary:
    var normalized := _normalize_species_id(species_id)
    for family_value: Variant in species_data.get("families", []):
        if not (family_value is Dictionary):
            continue
        var family: Dictionary = family_value
        for species_value: Variant in family.get("species", []):
            if not (species_value is Dictionary):
                continue
            var species: Dictionary = species_value
            if str(species.get("id", "")) == normalized:
                var result := species.duplicate(true)
                result["family_id"] = str(family.get("id", ""))
                result["act"] = int(family.get("act", 0))
                return result
    return {}

func _spawn_entries(composition: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if composition.is_empty():
        return result
    for name_value: String in composition.split(" + "):
        var found := _species_by_name(name_value)
        result.append({
            "species_id": str(found.get("id", "")),
            "name": name_value,
            "family_id": str(found.get("family_id", "")),
            "memory_rank": "normal",
            "persistent_entity": false
        })
    return result

func _species_by_name(species_name: String) -> Dictionary:
    for family_value: Variant in species_data.get("families", []):
        if not (family_value is Dictionary):
            continue
        var family: Dictionary = family_value
        for species_value: Variant in family.get("species", []):
            if species_value is Dictionary and str((species_value as Dictionary).get("name", "")) == species_name:
                var result := (species_value as Dictionary).duplicate(true)
                result["family_id"] = str(family.get("id", ""))
                result["act"] = int(family.get("act", 0))
                return result
    return {}

func _all_encounters() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var acts: Dictionary = encounter_data.get("acts", {})
    for label: Variant in acts.keys():
        for value: Variant in acts.get(label, []):
            if value is Dictionary:
                var record := (value as Dictionary).duplicate(true)
                record["act_label"] = str(label)
                result.append(record)
    return result

func _encounters_for_act(act_token: String) -> Array[Dictionary]:
    var token := _act_token(act_token)
    var result: Array[Dictionary] = []
    for encounter: Dictionary in _all_encounters():
        if _act_token(str(encounter.get("act_label", ""))) == token:
            result.append(encounter.duplicate(true))
    return result

func _remember(encounter_name: String) -> void:
    recent_history.append(encounter_name)
    while recent_history.size() > HISTORY_WINDOW:
        recent_history.pop_front()

func _synergy_feedback(records: Array[Dictionary]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for record: Dictionary in records:
        result.append({
            "pair": str(record.get("pair", "")),
            "function": str(record.get("function", "")),
            "counterplay": str(record.get("counterplay", "")),
            "visible": true,
            "breakable": true
        })
    return result

func _normalize_species_id(value: String) -> String:
    var normalized := value.strip_edges().to_lower()
    if normalized.begins_with("enemy."):
        normalized = normalized.substr(6)
    return normalized

func _act_token(value: String) -> String:
    var text := value.strip_edges()
    for token: String in ["I", "II", "III", "IV", "V"]:
        if text == token or text.begins_with(token + " ") or text.begins_with(token + " —"):
            return token
    return text

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("VeilleursEncounterDirector missing data: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
