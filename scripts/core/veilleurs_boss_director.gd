extends Node
class_name VeilleursBossDirector

signal boss_started(state: Dictionary)
signal phase_changed(state: Dictionary, phase_definition: Dictionary)
signal boss_finished(state: Dictionary)

const BOSS_PHASES_PATH := "res://data/veilleurs/boss_phase_catalog_v1.json"

var phase_data: Dictionary = {}
var active_state: Dictionary = {}
var completed_bosses: Dictionary = {}

func _ready() -> void:
    reload_content()

func reload_content() -> Dictionary:
    phase_data = _load_dictionary(BOSS_PHASES_PATH)
    return validation_report()

func validation_report() -> Dictionary:
    var grouped := _grouped_phases()
    var expected := {
        "ishar_gardien_du_passage": 3,
        "orateur_sans_voix": 3,
        "mere_des_veines": 3,
        "porte_cendres_blanc": 3,
        "le_copiste": 4
    }
    var errors: Array[String] = []
    if grouped.size() != 5:
        errors.append("boss_count:%d" % grouped.size())
    for boss_id: String in expected.keys():
        var phases: Array = grouped.get(boss_id, [])
        if phases.size() != int(expected[boss_id]):
            errors.append("phase_count:%s:%d" % [boss_id, phases.size()])
        for phase_value: Variant in phases:
            if not (phase_value is Dictionary):
                errors.append("invalid_phase:%s" % boss_id)
                continue
            var phase: Dictionary = phase_value
            for required: String in ["title", "doctrine", "trigger", "mechanics", "counterplay", "transition"]:
                if str(phase.get(required, "")).is_empty():
                    errors.append("missing_%s:%s:%s" % [required, boss_id, str(phase.get("phase", 0))])
    return {"ok": errors.is_empty(), "errors": errors, "bosses": grouped.size(), "boss_phases": 16}

func boss_ids() -> Array[String]:
    var result: Array[String] = []
    for key: Variant in _grouped_phases().keys():
        result.append(str(key))
    result.sort()
    return result

func phase_count(boss_id: String) -> int:
    return (_grouped_phases().get(_boss_id(boss_id), []) as Array).size()

func phase_definition(boss_id: String, phase_number: int) -> Dictionary:
    for phase_value: Variant in _grouped_phases().get(_boss_id(boss_id), []):
        if phase_value is Dictionary and int((phase_value as Dictionary).get("phase", 0)) == phase_number:
            return (phase_value as Dictionary).duplicate(true)
    return {}

func start_boss(boss_id: String, entity_id: String = "", body_snapshot: Dictionary = {}) -> Dictionary:
    var normalized := _boss_id(boss_id)
    var phases: Array = _grouped_phases().get(normalized, [])
    if phases.is_empty():
        return {"success": false, "reason": "unknown_boss", "boss_id": normalized}
    var first: Dictionary = phases[0]
    active_state = {
        "success": true,
        "boss_id": normalized,
        "boss_name": str(first.get("boss", boss_id)),
        "entity_id": entity_id,
        "current_phase": 1,
        "max_phase": phases.size(),
        "observed_phases": [1],
        "body_snapshot": body_snapshot.duplicate(true),
        "phase_history": [{"phase": 1, "event": "started"}],
        "completed": false,
        "victory": false,
        "recruitable": false
    }
    boss_started.emit(active_state.duplicate(true))
    phase_changed.emit(active_state.duplicate(true), first.duplicate(true))
    return active_state.duplicate(true)

func is_active() -> bool:
    return not active_state.is_empty() and not bool(active_state.get("completed", false))

func current_phase_definition() -> Dictionary:
    if active_state.is_empty():
        return {}
    return phase_definition(str(active_state.get("boss_id", "")), int(active_state.get("current_phase", 0)))

func current_transition_contract() -> String:
    return str(current_phase_definition().get("transition", ""))

func apply_body_snapshot(body_snapshot: Dictionary) -> Dictionary:
    if active_state.is_empty():
        return {}
    if not body_snapshot.is_empty():
        active_state["body_snapshot"] = _merge_persistent_body(active_state.get("body_snapshot", {}), body_snapshot)
    return (active_state.get("body_snapshot", {}) as Dictionary).duplicate(true)

func advance_phase(transition_satisfied: bool, latest_body_snapshot: Dictionary = {}) -> Dictionary:
    if not is_active():
        return {"success": false, "reason": "no_active_boss"}
    if not transition_satisfied:
        return {
            "success": false,
            "reason": "canonical_transition_not_satisfied",
            "phase": int(active_state.get("current_phase", 0)),
            "transition": current_transition_contract()
        }
    apply_body_snapshot(latest_body_snapshot)
    var current := int(active_state.get("current_phase", 1))
    var maximum := int(active_state.get("max_phase", 1))
    if current >= maximum:
        return {"success": false, "reason": "final_phase_requires_finish", "phase": current}
    var next_phase := current + 1
    active_state["current_phase"] = next_phase
    var observed: Array = active_state.get("observed_phases", [])
    if not next_phase in observed:
        observed.append(next_phase)
    active_state["observed_phases"] = observed
    var history: Array = active_state.get("phase_history", [])
    history.append({"phase": next_phase, "event": "entered", "body_snapshot": (active_state.get("body_snapshot", {}) as Dictionary).duplicate(true)})
    active_state["phase_history"] = history
    var definition := current_phase_definition()
    phase_changed.emit(active_state.duplicate(true), definition.duplicate(true))
    return {"success": true, "state": active_state.duplicate(true), "phase_definition": definition}

func finish_boss(victory: bool, latest_body_snapshot: Dictionary = {}) -> Dictionary:
    if not is_active():
        return {"success": false, "reason": "no_active_boss"}
    apply_body_snapshot(latest_body_snapshot)
    active_state["completed"] = true
    active_state["victory"] = victory
    var history: Array = active_state.get("phase_history", [])
    history.append({"phase": int(active_state.get("current_phase", 0)), "event": "victory" if victory else "ended_without_victory"})
    active_state["phase_history"] = history
    completed_bosses[str(active_state.get("boss_id", ""))] = active_state.duplicate(true)
    var result := active_state.duplicate(true)
    boss_finished.emit(result.duplicate(true))
    return {"success": true, "state": result}

func observed_phases(boss_id: String) -> Array:
    var normalized := _boss_id(boss_id)
    if str(active_state.get("boss_id", "")) == normalized:
        return (active_state.get("observed_phases", []) as Array).duplicate()
    var completed: Dictionary = completed_bosses.get(normalized, {})
    return (completed.get("observed_phases", []) as Array).duplicate()

func can_recruit_boss(_boss_id_value: String) -> bool:
    return false

func serialize() -> Dictionary:
    return {
        "schema_version": 1,
        "active_state": active_state.duplicate(true),
        "completed_bosses": completed_bosses.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    active_state = payload.get("active_state", {}).duplicate(true)
    completed_bosses = payload.get("completed_bosses", {}).duplicate(true)
    if not active_state.is_empty():
        active_state["recruitable"] = false

func reset() -> void:
    active_state.clear()
    completed_bosses.clear()

func _grouped_phases() -> Dictionary:
    var grouped: Dictionary = {}
    for value: Variant in phase_data.get("records", []):
        if not (value is Dictionary):
            continue
        var phase: Dictionary = value
        var boss_id := _boss_id(str(phase.get("boss", "")))
        if not grouped.has(boss_id):
            grouped[boss_id] = []
        (grouped[boss_id] as Array).append(phase.duplicate(true))
    for boss_id: Variant in grouped.keys():
        (grouped[boss_id] as Array).sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("phase", 0)) < int(b.get("phase", 0)))
    return grouped

func _merge_persistent_body(previous_value: Variant, incoming: Dictionary) -> Dictionary:
    var previous: Dictionary = previous_value if previous_value is Dictionary else {}
    var merged := previous.duplicate(true)
    for key: Variant in incoming.keys():
        var incoming_value: Variant = incoming[key]
        if incoming_value is Dictionary and merged.get(key, {}) is Dictionary:
            var nested: Dictionary = (merged.get(key, {}) as Dictionary).duplicate(true)
            for nested_key: Variant in (incoming_value as Dictionary).keys():
                nested[nested_key] = (incoming_value as Dictionary)[nested_key]
            merged[key] = nested
        elif incoming_value is Array:
            var existing: Array = merged.get(key, []) if merged.get(key, []) is Array else []
            for item: Variant in incoming_value:
                if not existing.has(item):
                    existing.append(item)
            merged[key] = existing
        else:
            merged[key] = incoming_value
    return merged

func _boss_id(value: String) -> String:
    var normalized := value.to_lower().strip_edges().replace("boss.", "")
    normalized = normalized.replace("ishar, gardien du passage", "ishar_gardien_du_passage")
    normalized = normalized.replace("orateur sans voix", "orateur_sans_voix")
    normalized = normalized.replace("mère des veines", "mere_des_veines")
    normalized = normalized.replace("porte-cendres blanc", "porte_cendres_blanc")
    normalized = normalized.replace("le copiste", "le_copiste")
    return normalized

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("VeilleursBossDirector missing data: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
