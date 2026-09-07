extends Node
class_name VeilleursEncounterDirector

signal encounter_selected(runtime_encounter: Dictionary)

const CATALOG_PATH := "res://data/veilleurs/encounter_catalog_64_v1.json"
const SPECIES_PATH := "res://data/veilleurs/species_catalog_recovered_v1.json"
const SYNERGY_BINDING_PATH := "res://data/veilleurs/enemy_synergy_binding_v1.json"
const CONTRACT_PATH := "res://data/veilleurs/encounter_generation_contract_v1.json"
const NARRATIVE_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_encounter_narrative_runtime.gd")

var catalog_data: Dictionary = {}
var species_data: Dictionary = {}
var synergy_data: Dictionary = {}
var contract_data: Dictionary = {}
var encounter_records: Array[Dictionary] = []
var recent_history: Array[String] = []
var selection_count := 0
var narrative_runtime: VeilleursEncounterNarrativeRuntime

func _ready() -> void:
    narrative_runtime = NARRATIVE_RUNTIME_SCRIPT.new() as VeilleursEncounterNarrativeRuntime
    reload_content()

func reload_content() -> Dictionary:
    catalog_data = _load_dictionary(CATALOG_PATH)
    species_data = _load_dictionary(SPECIES_PATH)
    synergy_data = _load_dictionary(SYNERGY_BINDING_PATH)
    contract_data = _load_dictionary(CONTRACT_PATH)
    if narrative_runtime == null:
        narrative_runtime = NARRATIVE_RUNTIME_SCRIPT.new() as VeilleursEncounterNarrativeRuntime
    else:
        narrative_runtime.reload()
    encounter_records.clear()
    for file_value: Variant in catalog_data.get("act_files", []):
        if not (file_value is Dictionary):
            continue
        var path := str((file_value as Dictionary).get("path", ""))
        var act_file := _load_dictionary(path)
        for record_value: Variant in act_file.get("records", []):
            if record_value is Dictionary:
                encounter_records.append((record_value as Dictionary).duplicate(true))
    return validation_report()

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    if encounter_records.size() != 64:
        errors.append("encounters:%d" % encounter_records.size())
    var synergies: Array = synergy_data.get("records", [])
    if synergies.size() != 21:
        errors.append("synergies:%d" % synergies.size())
    var narrative_report: Dictionary = narrative_runtime.last_report if narrative_runtime != null else {}
    if narrative_report.is_empty() or not bool(narrative_report.get("ok", false)):
        errors.append("narrative_runtime_invalid")
    elif int(narrative_report.get("records", 0)) != 64:
        errors.append("narrative_runtime_count:%d" % int(narrative_report.get("records", 0)))
    var rules: Dictionary = catalog_data.get("rules", {})
    var max_standard := int(rules.get("max_standard_enemies", 4))
    for encounter: Dictionary in encounter_records:
        var encounter_id := str(encounter.get("id", ""))
        var actors := int(encounter.get("actors", 0))
        var species_ids: Array = encounter.get("species_ids", [])
        var names: Array = encounter.get("composition_names", [])
        if actors < 1 or actors > max_standard:
            errors.append("actor_cap:%s" % encounter_id)
        if species_ids.size() != actors or names.size() != actors:
            errors.append("composition_count:%s" % encounter_id)
        for species_id: Variant in species_ids:
            if species_entry(str(species_id)).is_empty():
                errors.append("unknown_species:%s:%s" % [encounter_id, str(species_id)])
        for synergy_id: Variant in encounter.get("synergy_ids", []):
            if synergy_by_id(str(synergy_id)).is_empty():
                errors.append("unknown_synergy:%s:%s" % [encounter_id, str(synergy_id)])
        if narrative_runtime != null:
            var detail := narrative_runtime.entry_by_id(encounter_id)
            if detail.is_empty():
                errors.append("missing_narrative_reward:%s" % encounter_id)
            elif str(detail.get("name", "")) != str(encounter.get("name", "")):
                errors.append("narrative_name_mismatch:%s" % encounter_id)
    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "encounters": encounter_records.size(),
        "synergies": synergies.size(),
        "narrative_reward_records": int(narrative_report.get("records", 0)),
        "max_standard_enemies": max_standard,
        "anti_repeat_window": 5,
        "repeat_weight": float(rules.get("repeat_weight_after_two_in_five", 0.4)),
        "runtime_binding": CATALOG_PATH,
        "narrative_runtime_binding": str(narrative_report.get("runtime_binding", ""))
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

    if context.has("depth"):
        var depth := int(context.get("depth", 1))
        var depth_candidates: Array[Dictionary] = []
        for candidate: Dictionary in candidates:
            if depth >= int(candidate.get("depth_min", 1)) and depth <= int(candidate.get("depth_max", 5)):
                depth_candidates.append(candidate)
        if not depth_candidates.is_empty():
            candidates = depth_candidates

    var previous := recent_history[-1] if not recent_history.is_empty() else ""
    if candidates.size() > 1 and not previous.is_empty():
        var without_previous: Array[Dictionary] = []
        for candidate: Dictionary in candidates:
            if str(candidate.get("name", "")) != previous:
                without_previous.append(candidate)
        if not without_previous.is_empty():
            candidates = without_previous

    var rules: Dictionary = catalog_data.get("rules", {})
    var repeat_weight := float(rules.get("repeat_weight_after_two_in_five", 0.4))
    var weights: Array[float] = []
    var total_weight := 0.0
    for candidate: Dictionary in candidates:
        var recent_count := recent_history.count(str(candidate.get("name", "")))
        var weight := repeat_weight if recent_count >= 2 else 1.0
        weights.append(weight)
        total_weight += weight
    if total_weight <= 0.0:
        return {"success": false, "reason": "no_positive_weight"}

    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value * 104729 + _act_int(act_token) * 8191 + selection_count * 131
    var roll := rng.randf() * total_weight
    var picked_index := candidates.size() - 1
    var cursor := 0.0
    for index: int in range(candidates.size()):
        cursor += weights[index]
        if roll <= cursor:
            picked_index = index
            break

    var runtime := _build_runtime_encounter(candidates[picked_index], context)
    if not bool(runtime.get("success", false)):
        return runtime
    _remember(str(runtime.get("name", "")))
    selection_count += 1
    runtime["selection_index"] = selection_count
    runtime["history_after"] = recent_history.duplicate()
    encounter_selected.emit(runtime.duplicate(true))
    return runtime

func runtime_for_named_encounter(encounter_name: String, context: Dictionary = {}) -> Dictionary:
    for encounter: Dictionary in encounter_records:
        if str(encounter.get("name", "")) == encounter_name:
            return _build_runtime_encounter(encounter, context)
    return {"success": false, "reason": "unknown_encounter", "name": encounter_name}

func active_synergies_for_spawn(spawn_entries: Array) -> Array[Dictionary]:
    var species_ids: Array[String] = []
    for value: Variant in spawn_entries:
        if value is Dictionary:
            species_ids.append(str((value as Dictionary).get("species_id", "")))
    var result: Array[Dictionary] = []
    for value: Variant in synergy_data.get("records", []):
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        var all_present := true
        for required_id: Variant in record.get("species_ids", []):
            if not species_ids.has(str(required_id)):
                all_present = false
                break
        if all_present:
            result.append(record.duplicate(true))
    return result

func synergy_by_id(synergy_id: String) -> Dictionary:
    for value: Variant in synergy_data.get("records", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == synergy_id:
            return (value as Dictionary).duplicate(true)
    return {}

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

func serialize() -> Dictionary:
    return {"schema_version": 3, "recent_history": recent_history.duplicate(), "selection_count": selection_count}

func deserialize(payload: Dictionary) -> void:
    recent_history.clear()
    for value: Variant in payload.get("recent_history", []):
        recent_history.append(str(value))
    while recent_history.size() > 5:
        recent_history.pop_front()
    selection_count = maxi(0, int(payload.get("selection_count", 0)))

func reset() -> void:
    recent_history.clear()
    selection_count = 0

func _build_runtime_encounter(source: Dictionary, context: Dictionary) -> Dictionary:
    var names: Array = source.get("composition_names", [])
    var ids: Array = source.get("species_ids", [])
    if names.size() != ids.size() or names.size() != int(source.get("actors", 0)):
        return {"success": false, "reason": "canonical_composition_mismatch", "name": source.get("name", "")}
    var spawn_entries: Array[Dictionary] = []
    for index: int in range(ids.size()):
        var species := species_entry(str(ids[index]))
        spawn_entries.append({
            "species_id": str(ids[index]),
            "name": str(names[index]),
            "family_id": str(species.get("family_id", "")),
            "memory_rank": "normal",
            "persistent_entity": false
        })
    var max_standard := int((catalog_data.get("rules", {}) as Dictionary).get("max_standard_enemies", 4))
    if spawn_entries.size() > max_standard:
        return {"success": false, "reason": "mobile_actor_cap_exceeded", "name": source.get("name", "")}

    var memorial_overlay := _memorial_overlay(context.get("memorial_candidate", {}), spawn_entries.size(), max_standard)
    if bool(memorial_overlay.get("insert", false)):
        spawn_entries.append((memorial_overlay.get("spawn", {}) as Dictionary).duplicate(true))

    var synergies: Array[Dictionary] = []
    for synergy_id: Variant in source.get("synergy_ids", []):
        var synergy := synergy_by_id(str(synergy_id))
        if not synergy.is_empty():
            synergies.append(synergy)

    var narrative_reward: Dictionary = narrative_runtime.entry_by_id(str(source.get("id", ""))) if narrative_runtime != null else {}
    if narrative_reward.is_empty():
        return {"success": false, "reason": "missing_canonical_narrative_reward", "id": source.get("id", ""), "name": source.get("name", "")}
    if str(narrative_reward.get("name", "")) != str(source.get("name", "")):
        return {"success": false, "reason": "canonical_narrative_reward_name_mismatch", "id": source.get("id", ""), "name": source.get("name", "")}
    var narrative: Dictionary = narrative_reward.get("narrative", {})
    var reward: Dictionary = narrative_reward.get("reward", {})

    return {
        "success": true,
        "canonical": true,
        "id": str(source.get("id", "")),
        "name": str(source.get("name", "")),
        "type": str(source.get("type", "Standard")),
        "act": int(source.get("act", 0)),
        "act_name": str(source.get("act_name", "")),
        "depth_min": int(source.get("depth_min", 1)),
        "depth_max": int(source.get("depth_max", 5)),
        "threat": int(source.get("threat", 0)),
        "terrain_danger": str(source.get("terrain_danger", "—")),
        "tactical_lesson": str(source.get("tactical_lesson", "")),
        "source_actor_count": int(source.get("actors", 0)),
        "source_composition": " + ".join(names),
        "spawn_entries": spawn_entries,
        "runtime_actor_count": spawn_entries.size(),
        "synergy_ids": (source.get("synergy_ids", []) as Array).duplicate(),
        "synergies": synergies,
        "synergy_feedback": _synergy_feedback(synergies),
        "memorial_overlay": memorial_overlay,
        "party_counterpick_used": false,
        "seeded_selection": true,
        "runtime_remanence": (source.get("runtime_remanence", {}) as Dictionary).duplicate(true),
        "narrative": narrative.duplicate(true),
        "reward": reward.duplicate(true),
        "capture_rule": str(reward.get("capture_rule", "")),
        "knowledge_bonus": str(reward.get("knowledge_bonus", "")),
        "generated_binding_verified": true
    }

func _memorial_overlay(candidate_value: Variant, source_actor_count: int, max_standard: int) -> Dictionary:
    if not (candidate_value is Dictionary) or (candidate_value as Dictionary).is_empty():
        return {"insert": false, "reason": "none"}
    if source_actor_count >= max_standard:
        return {"insert": false, "reason": "actor_cap_full"}
    var candidate: Dictionary = candidate_value
    var entity_id := str(candidate.get("entity_id", candidate.get("remanence_id", "")))
    var species_id := _normalize_species_id(str(candidate.get("species_id", "")))
    var rank := str(candidate.get("memory_rank", "normal")).to_lower()
    if entity_id.is_empty() or species_id.is_empty() or not rank in ["memorial", "veteran", "elite", "nemesis"]:
        return {"insert": false, "reason": "not_persistent_memorial_entity"}
    var species := species_entry(species_id)
    if species.is_empty():
        return {"insert": false, "reason": "unknown_species"}
    if rank == "nemesis" and not bool(candidate.get("shared_history", false)):
        return {"insert": false, "reason": "artificial_nemesis_forbidden"}
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

func _encounters_for_act(act_token: String) -> Array[Dictionary]:
    var act_number := _act_int(act_token)
    var result: Array[Dictionary] = []
    for encounter: Dictionary in encounter_records:
        if int(encounter.get("act", 0)) == act_number:
            result.append(encounter.duplicate(true))
    return result

func _remember(encounter_name: String) -> void:
    recent_history.append(encounter_name)
    while recent_history.size() > 5:
        recent_history.pop_front()

func _synergy_feedback(records: Array[Dictionary]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for record: Dictionary in records:
        result.append({
            "id": str(record.get("id", "")),
            "pair": " + ".join(record.get("pair_names", [])),
            "function": str(record.get("function", "")),
            "counterplay": str(record.get("counterplay", "")),
            "visible": bool(record.get("visible_to_player", true)),
            "breakable": bool(record.get("breakable", true)),
            "knowledge_rule": str(record.get("knowledge_rule", ""))
        })
    return result

func _normalize_species_id(value: String) -> String:
    var normalized := value.strip_edges().to_lower()
    if normalized.begins_with("enemy."):
        normalized = normalized.substr(6)
    return normalized

func _act_int(value: String) -> int:
    var text := value.strip_edges()
    if text.is_valid_int():
        return int(text)
    if text.begins_with("V"):
        return 5
    if text.begins_with("IV"):
        return 4
    if text.begins_with("III"):
        return 3
    if text.begins_with("II"):
        return 2
    if text.begins_with("I"):
        return 1
    return 0

func _load_dictionary(path: String) -> Dictionary:
    if path.is_empty() or not FileAccess.file_exists(path):
        push_error("VeilleursEncounterDirector missing data: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
