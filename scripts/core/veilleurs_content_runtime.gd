extends Node
class_name VeilleursContentRuntime

signal content_loaded(report: Dictionary)
signal rally_candidate_created(candidate: Dictionary)
signal rally_resolved(result: Dictionary)
signal refuge_changed(snapshot: Dictionary)
signal archive_changed(entity_id: String, entry: Dictionary)
signal boss_knowledge_changed(boss_id: String, phases: Array)

const FOUNDATION_PATH := "res://data/veilleurs/content_foundation_v2.json"
const SPECIES_PATH := "res://data/veilleurs/species_catalog_recovered_v1.json"
const ENCOUNTERS_PATH := "res://data/veilleurs/encounter_index_v1.json"
const SYNERGIES_PATH := "res://data/veilleurs/enemy_synergy_catalog_v1.json"
const BOSS_PHASES_PATH := "res://data/veilleurs/boss_phase_catalog_v1.json"
const REFUGE_PATH := "res://data/veilleurs/recruitment_refuge_contract_v1.json"
const SYSTEM_RULES_PATH := "res://data/veilleurs/canonical_prepc_2026_09_03/system_rules_v1.json"
const ARCHIVE_PATH := "res://data/veilleurs/remanence_archive_runtime_contract_v1.json"
const SOURCE_MANIFEST_PATH := "res://data/veilleurs/canonical_prepc_2026_09_03/canonical_source_manifest_v1.json"

const ACT_ORDER := ["I", "II", "III", "IV", "V"]
const KNOWLEDGE_STATES := ["UNKNOWN", "SUSPECTED", "OBSERVED", "CONFIRMED", "UNDERSTOOD"]
const RELATIONSHIP_AXES := ["CONFIANCE", "RESPECT", "PEUR", "RESSENTIMENT"]

var catalogs: Dictionary = {}
var loaded := false
var current_act := "I"
var refuge_roster: Array[Dictionary] = []
var pending_rallies: Dictionary = {}
var archive_entries: Dictionary = {}
var boss_phase_knowledge: Dictionary = {}
var event_log: Array[Dictionary] = []

func _ready() -> void:
    reload_content()

func reload_content() -> Dictionary:
    catalogs = {
        "foundation": _load_dictionary(FOUNDATION_PATH),
        "species": _load_dictionary(SPECIES_PATH),
        "encounters": _load_dictionary(ENCOUNTERS_PATH),
        "synergies": _load_dictionary(SYNERGIES_PATH),
        "boss_phases": _load_dictionary(BOSS_PHASES_PATH),
        "refuge": _load_dictionary(REFUGE_PATH),
        "system_rules": _load_dictionary(SYSTEM_RULES_PATH),
        "archive": _load_dictionary(ARCHIVE_PATH),
        "source_manifest": _load_dictionary(SOURCE_MANIFEST_PATH)
    }
    var report := validation_report()
    loaded = bool(report.get("ok", false))
    content_loaded.emit(report.duplicate(true))
    return report

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    for key: String in ["foundation", "species", "encounters", "synergies", "boss_phases", "refuge", "system_rules", "archive", "source_manifest"]:
        if not catalogs.has(key) or (catalogs.get(key, {}) as Dictionary).is_empty():
            errors.append("missing:%s" % key)

    var species_count := _ordinary_species().size()
    var encounters := all_encounters()
    var synergies: Array = (catalogs.get("synergies", {}) as Dictionary).get("records", [])
    var boss_phases: Array = (catalogs.get("boss_phases", {}) as Dictionary).get("records", [])
    if species_count != 24:
        errors.append("ordinary_species:%d" % species_count)
    if encounters.size() != 64:
        errors.append("encounters:%d" % encounters.size())
    if synergies.size() != 21:
        errors.append("synergies:%d" % synergies.size())
    if boss_phases.size() != 16:
        errors.append("boss_phases:%d" % boss_phases.size())
    for encounter_value: Variant in encounters:
        if encounter_value is Dictionary and int((encounter_value as Dictionary).get("actors", 0)) > 4:
            errors.append("encounter_actor_cap:%s" % str((encounter_value as Dictionary).get("name", "unknown")))
    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "ordinary_species": species_count,
        "encounters": encounters.size(),
        "synergies": synergies.size(),
        "boss_phases": boss_phases.size(),
        "bosses": _boss_phase_counts().size(),
        "source_sha256": str((catalogs.get("source_manifest", {}) as Dictionary).get("zip_sha256", ""))
    }

func all_encounters() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var acts: Dictionary = (catalogs.get("encounters", {}) as Dictionary).get("acts", {})
    for act_label: Variant in acts.keys():
        for record_value: Variant in acts.get(act_label, []):
            if record_value is Dictionary:
                var record: Dictionary = (record_value as Dictionary).duplicate(true)
                record["act_label"] = str(act_label)
                result.append(record)
    return result

func encounters_for_act(act_token: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for encounter: Dictionary in all_encounters():
        if _act_token(str(encounter.get("act_label", ""))) == _act_token(act_token):
            result.append(encounter.duplicate(true))
    return result

func encounter_by_name(encounter_name: String) -> Dictionary:
    for encounter: Dictionary in all_encounters():
        if str(encounter.get("name", "")) == encounter_name:
            return encounter.duplicate(true)
    return {}

func synergies_for_species(species_name: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var records: Array = (catalogs.get("synergies", {}) as Dictionary).get("records", [])
    for value: Variant in records:
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        var pair: Array = str(record.get("pair", "")).split(" + ")
        if species_name in pair:
            result.append(record.duplicate(true))
    return result

func species_entry(species_id: String) -> Dictionary:
    var normalized := _normalize_species_id(species_id)
    for entry: Dictionary in _ordinary_species():
        if str(entry.get("id", "")) == normalized:
            return entry.duplicate(true)
    return {}

func set_current_act(act_token: String) -> bool:
    var normalized := _act_token(act_token)
    if not normalized in ACT_ORDER:
        return false
    current_act = normalized
    refuge_changed.emit(refuge_snapshot())
    return true

func capacity_for_act(act_token: String = "") -> int:
    var token := current_act if act_token.is_empty() else _act_token(act_token)
    var refuge: Dictionary = catalogs.get("refuge", {})
    var capacity: Dictionary = refuge.get("refuge", {}).get("capacity_by_act", {})
    return int(capacity.get(token, 0))

func refuge_slots_remaining(act_token: String = "") -> int:
    return maxi(0, capacity_for_act(act_token) - refuge_roster.size())

func refuge_snapshot() -> Dictionary:
    return {
        "act": current_act,
        "capacity": capacity_for_act(),
        "used": refuge_roster.size(),
        "remaining": refuge_slots_remaining(),
        "roster": refuge_roster.duplicate(true),
        "pending_rallies": pending_rallies.duplicate(true)
    }

func create_rally_candidate(enemy: Dictionary, act_token: String = "", context: Dictionary = {}) -> Dictionary:
    if is_boss(enemy):
        return {"ok": false, "reason": "boss_non_recruitable"}
    var species_id := _normalize_species_id(str(enemy.get("species_id", enemy.get("creature_id", enemy.get("id", "")))))
    var species := species_entry(species_id)
    if species.is_empty():
        return {"ok": false, "reason": "unknown_ordinary_species", "species_id": species_id}
    var act := current_act if act_token.is_empty() else _act_token(act_token)
    if not act in ACT_ORDER:
        return {"ok": false, "reason": "invalid_act"}
    var source_identity := str(enemy.get("remanence_id", enemy.get("instance_id", "")))
    var seed_material := "%s|%s|%s|%s" % [species_id, str(enemy.get("name", species.get("name", species_id))), source_identity, str(event_log.size())]
    var rally_id := "%s:%d" % [species_id, abs(hash(seed_material))]
    var candidate := {
        "ok": true,
        "rally_id": rally_id,
        "capture_is_recruitment": false,
        "species_id": species_id,
        "species_name": str(species.get("name", species_id)),
        "act": act,
        "source_entity_id": source_identity,
        "identity_seed": int(enemy.get("identity_seed", abs(hash(seed_material)))),
        "condition_text": _rally_condition_text(species_id, act),
        "condition_mode": "story_resolution_required" if act == "I" else "encounter_condition_signal_required",
        "enemy_snapshot": _persistent_enemy_snapshot(enemy),
        "context": context.duplicate(true),
        "status": "captured_or_neutralized_pending_rally"
    }
    pending_rallies[rally_id] = candidate.duplicate(true)
    _append_event("capture_or_neutralization", {"rally_id": rally_id, "species_id": species_id, "act": act})
    rally_candidate_created.emit(candidate.duplicate(true))
    refuge_changed.emit(refuge_snapshot())
    return candidate

func resolve_rally_candidate(rally_id: String, player_accepts: bool, resolution: Dictionary = {}) -> Dictionary:
    if not pending_rallies.has(rally_id):
        return {"ok": false, "reason": "unknown_rally_candidate"}
    var candidate: Dictionary = pending_rallies[rally_id]
    if not player_accepts:
        pending_rallies.erase(rally_id)
        _append_event("rally_declined", {"rally_id": rally_id, "species_id": candidate.get("species_id", "")})
        var declined := {"ok": true, "recruited": false, "reason": "player_declined", "rally_id": rally_id}
        rally_resolved.emit(declined.duplicate(true))
        refuge_changed.emit(refuge_snapshot())
        return declined

    var act := str(candidate.get("act", current_act))
    var condition_satisfied := bool(resolution.get("story_eligible", false)) if act == "I" else bool(resolution.get("condition_satisfied", false))
    if not condition_satisfied:
        return {
            "ok": false,
            "recruited": false,
            "reason": "canonical_rally_condition_not_resolved",
            "condition_mode": candidate.get("condition_mode", ""),
            "condition_text": candidate.get("condition_text", "")
        }
    if refuge_slots_remaining(act) <= 0:
        return {"ok": false, "recruited": false, "reason": "refuge_full", "capacity": capacity_for_act(act)}

    var enemy_snapshot: Dictionary = candidate.get("enemy_snapshot", {})
    var recruit := {
        "entity_id": str(candidate.get("source_entity_id", "")),
        "identity_seed": int(candidate.get("identity_seed", 0)),
        "species_id": str(candidate.get("species_id", "")),
        "name": str(candidate.get("species_name", candidate.get("species_id", "Auxiliaire"))),
        "memory_rank": str(enemy_snapshot.get("memory_rank", "normal")),
        "persistent_injuries": (enemy_snapshot.get("persistent_injuries", []) as Array).duplicate(true),
        "capture_wounds": (enemy_snapshot.get("capture_wounds", {}) as Dictionary).duplicate(true),
        "body_state": (enemy_snapshot.get("body_state", {}) as Dictionary).duplicate(true),
        "traits": (enemy_snapshot.get("traits", []) as Array).duplicate(true),
        "relationships": {"CONFIANCE": 0, "RESPECT": 0, "PEUR": 0, "RESSENTIMENT": 0},
        "history": [{"event": "rallied", "act": act, "condition": str(candidate.get("condition_text", ""))}],
        "availability": str(enemy_snapshot.get("availability", "available")),
        "refuge_event_flags": [],
        "rallied": true,
        "capture_is_recruitment": false
    }
    refuge_roster.append(recruit)
    pending_rallies.erase(rally_id)
    if not str(recruit.get("entity_id", "")).is_empty() and RemanenceRuntime.entities.has(str(recruit.get("entity_id", ""))):
        RemanenceRuntime.set_entity_status(str(recruit.get("entity_id", "")), "recruited")
        RemanenceRuntime.record_event(str(recruit.get("entity_id", "")), "recruited", {
            "summary": "%s rejoint le Refuge des Veilleurs." % str(recruit.get("name", "Un auxiliaire")),
            "species_id": recruit.get("species_id", "")
        })
    record_archive_hook(_archive_id_for_recruit(recruit), "recruitment_resolved", {"recruit": recruit.duplicate(true)})
    _append_event("rally_committed", {"rally_id": rally_id, "species_id": recruit.get("species_id", ""), "act": act})
    var result := {"ok": true, "recruited": true, "recruit": recruit.duplicate(true), "rally_id": rally_id}
    rally_resolved.emit(result.duplicate(true))
    refuge_changed.emit(refuge_snapshot())
    return result

func release_recruit(identity_seed: int) -> bool:
    for index: int in range(refuge_roster.size()):
        if int(refuge_roster[index].get("identity_seed", -1)) == identity_seed:
            var recruit := refuge_roster[index].duplicate(true)
            refuge_roster.remove_at(index)
            _append_event("recruit_released", {"identity_seed": identity_seed, "species_id": recruit.get("species_id", "")})
            refuge_changed.emit(refuge_snapshot())
            return true
    return false

func record_archive_hook(entity_id: String, hook: String, payload: Dictionary = {}) -> Dictionary:
    var archive_id := entity_id if not entity_id.is_empty() else "anonymous:%d" % abs(hash(JSON.stringify(payload)))
    var entry: Dictionary = archive_entries.get(archive_id, {
        "entity_id": archive_id,
        "knowledge_state": "UNKNOWN",
        "corps": [],
        "combat": [],
        "histoire": [],
        "traces": [],
        "events": []
    })
    match hook:
        "knowledge_suspected":
            entry["knowledge_state"] = _max_knowledge_state(str(entry.get("knowledge_state", "UNKNOWN")), "SUSPECTED")
        "knowledge_observed":
            entry["knowledge_state"] = _max_knowledge_state(str(entry.get("knowledge_state", "UNKNOWN")), "OBSERVED")
        "knowledge_confirmed":
            entry["knowledge_state"] = _max_knowledge_state(str(entry.get("knowledge_state", "UNKNOWN")), "CONFIRMED")
        "knowledge_understood":
            entry["knowledge_state"] = _max_knowledge_state(str(entry.get("knowledge_state", "UNKNOWN")), "UNDERSTOOD")
        "persistent_injury_added":
            (entry["corps"] as Array).append(payload.duplicate(true))
        "world_scar_created", "important_object_state_changed":
            (entry["traces"] as Array).append(payload.duplicate(true))
        "relationship_threshold_crossed", "recruitment_resolved", "entity_promoted", "knowledge_contradicted":
            (entry["histoire"] as Array).append({"hook": hook, "payload": payload.duplicate(true)})
        _:
            (entry["combat"] as Array).append({"hook": hook, "payload": payload.duplicate(true)})
    (entry["events"] as Array).append({"hook": hook, "payload": payload.duplicate(true)})
    archive_entries[archive_id] = entry
    _append_event("archive_hook", {"entity_id": archive_id, "hook": hook})
    archive_changed.emit(archive_id, entry.duplicate(true))
    return entry.duplicate(true)

func archive_entry(entity_id: String) -> Dictionary:
    return (archive_entries.get(entity_id, {}) as Dictionary).duplicate(true)

func record_boss_phase_observed(boss_id: String, phase: int) -> bool:
    var max_phase := _boss_max_phase(boss_id)
    if max_phase <= 0 or phase < 1 or phase > max_phase:
        return false
    var known: Array = boss_phase_knowledge.get(boss_id, [])
    if not phase in known:
        known.append(phase)
        known.sort()
        boss_phase_knowledge[boss_id] = known
        _append_event("boss_phase_observed", {"boss_id": boss_id, "phase": phase})
        boss_knowledge_changed.emit(boss_id, known.duplicate())
    return true

func known_boss_phases(boss_id: String) -> Array:
    return (boss_phase_knowledge.get(boss_id, []) as Array).duplicate()

func boss_phase_is_known(boss_id: String, phase: int) -> bool:
    return phase in known_boss_phases(boss_id)

func is_boss(enemy: Dictionary) -> bool:
    if bool(enemy.get("boss", false)):
        return true
    var raw_id := str(enemy.get("id", ""))
    if raw_id.begins_with("boss."):
        return true
    var species_id := _normalize_species_id(str(enemy.get("species_id", enemy.get("creature_id", raw_id))))
    for boss_id: String in _boss_phase_counts().keys():
        if species_id == boss_id:
            return true
    return false

func serialize() -> Dictionary:
    return {
        "schema_version": 1,
        "current_act": current_act,
        "refuge_roster": refuge_roster.duplicate(true),
        "pending_rallies": pending_rallies.duplicate(true),
        "archive_entries": archive_entries.duplicate(true),
        "boss_phase_knowledge": boss_phase_knowledge.duplicate(true),
        "event_log": event_log.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    if payload.is_empty():
        reset()
        return
    current_act = _act_token(str(payload.get("current_act", "I")))
    if not current_act in ACT_ORDER:
        current_act = "I"
    refuge_roster.clear()
    for value: Variant in payload.get("refuge_roster", []):
        if value is Dictionary:
            refuge_roster.append((value as Dictionary).duplicate(true))
    pending_rallies = payload.get("pending_rallies", {}).duplicate(true)
    archive_entries = payload.get("archive_entries", {}).duplicate(true)
    boss_phase_knowledge = payload.get("boss_phase_knowledge", {}).duplicate(true)
    event_log.clear()
    for value: Variant in payload.get("event_log", []):
        if value is Dictionary:
            event_log.append((value as Dictionary).duplicate(true))
    refuge_changed.emit(refuge_snapshot())

func reset() -> void:
    current_act = "I"
    refuge_roster.clear()
    pending_rallies.clear()
    archive_entries.clear()
    boss_phase_knowledge.clear()
    event_log.clear()
    refuge_changed.emit(refuge_snapshot())

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("VeilleursContentRuntime missing canonical data: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if parsed is Dictionary:
        return (parsed as Dictionary).duplicate(true)
    push_error("VeilleursContentRuntime invalid canonical JSON: %s" % path)
    return {}

func _ordinary_species() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var families: Array = (catalogs.get("species", {}) as Dictionary).get("families", [])
    for family_value: Variant in families:
        if not (family_value is Dictionary):
            continue
        for species_value: Variant in (family_value as Dictionary).get("species", []):
            if species_value is Dictionary:
                var species: Dictionary = (species_value as Dictionary).duplicate(true)
                species["family_id"] = str((family_value as Dictionary).get("id", ""))
                species["act"] = int((family_value as Dictionary).get("act", 0))
                result.append(species)
    return result

func _boss_phase_counts() -> Dictionary:
    var result: Dictionary = {}
    var records: Array = (catalogs.get("boss_phases", {}) as Dictionary).get("records", [])
    for value: Variant in records:
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        var boss_id := _boss_runtime_id(str(record.get("boss", "")))
        result[boss_id] = maxi(int(result.get(boss_id, 0)), int(record.get("phase", 0)))
    return result

func _boss_max_phase(boss_id: String) -> int:
    return int(_boss_phase_counts().get(_boss_runtime_id(boss_id), 0))

func _boss_runtime_id(value: String) -> String:
    var normalized := value.to_lower().strip_edges()
    normalized = normalized.replace("boss.", "")
    normalized = normalized.replace("ishar, gardien du passage", "ishar_gardien_du_passage")
    normalized = normalized.replace("orateur sans voix", "orateur_sans_voix")
    normalized = normalized.replace("mère des veines", "mere_des_veines")
    normalized = normalized.replace("porte-cendres blanc", "porte_cendres_blanc")
    normalized = normalized.replace("le copiste", "le_copiste")
    return normalized

func _rally_condition_text(species_id: String, act: String) -> String:
    if act == "I":
        return "Auxiliaire possible; ne remplace jamais un Veilleur. Aucune condition numérique ne doit être inventée."
    var system_rules: Dictionary = catalogs.get("system_rules", {})
    var ralliement: Dictionary = system_rules.get("ralliement", {})
    var conditions: Dictionary = ralliement.get("current_conditions", {})
    return str(conditions.get("enemy.%s" % species_id, ""))

func _persistent_enemy_snapshot(enemy: Dictionary) -> Dictionary:
    return {
        "memory_rank": str(enemy.get("memory_rank", "normal")),
        "persistent_injuries": (enemy.get("persistent_injuries", []) as Array).duplicate(true),
        "capture_wounds": (enemy.get("capture_wounds", {}) as Dictionary).duplicate(true),
        "body_state": {
            "dismembered_parts": (enemy.get("dismembered_parts", []) as Array).duplicate(true),
            "anatomy_injuries": (enemy.get("anatomy_injuries", {}) as Dictionary).duplicate(true),
            "anatomy_part_states": (enemy.get("anatomy_part_states", {}) as Dictionary).duplicate(true),
            "anatomy_part_trauma": (enemy.get("anatomy_part_trauma", {}) as Dictionary).duplicate(true)
        },
        "traits": (enemy.get("traits", []) as Array).duplicate(true),
        "availability": str(enemy.get("availability", "available"))
    }

func _archive_id_for_recruit(recruit: Dictionary) -> String:
    var entity_id := str(recruit.get("entity_id", ""))
    if not entity_id.is_empty():
        return entity_id
    return "recruit:%s:%d" % [str(recruit.get("species_id", "unknown")), int(recruit.get("identity_seed", 0))]

func _normalize_species_id(value: String) -> String:
    var normalized := value.strip_edges().to_lower()
    if normalized.begins_with("enemy."):
        normalized = normalized.substr(6)
    return normalized

func _act_token(value: String) -> String:
    var text := value.strip_edges()
    for token: String in ACT_ORDER:
        if text == token or text.begins_with(token + " ") or text.begins_with(token + " —"):
            return token
    return text

func _max_knowledge_state(current: String, requested: String) -> String:
    var current_index := KNOWLEDGE_STATES.find(current)
    var requested_index := KNOWLEDGE_STATES.find(requested)
    if current_index < 0:
        current_index = 0
    if requested_index < 0:
        requested_index = 0
    return str(KNOWLEDGE_STATES[maxi(current_index, requested_index)])

func _append_event(event_type: String, payload: Dictionary) -> void:
    event_log.append({"event": event_type, "payload": payload.duplicate(true)})
    if event_log.size() > 128:
        event_log.pop_front()
