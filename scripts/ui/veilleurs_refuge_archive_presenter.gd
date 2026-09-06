extends RefCounted
class_name VeilleursRefugeArchivePresenter

const UI_CONTRACT_PATH := "res://data/veilleurs/archives_refuge_ui_contract_v1.json"
const INPUT_CONTRACT_PATH := "res://data/veilleurs/vs001_ui_input_contract.json"
const KNOWLEDGE_LABELS := {
    "UNKNOWN": "Inconnu",
    "SUSPECTED": "Soupçonné",
    "OBSERVED": "Observé",
    "CONFIRMED": "Confirmé",
    "UNDERSTOOD": "Compris"
}

var ui_contract: Dictionary = {}
var input_contract: Dictionary = {}
var content_runtime: VeilleursContentRuntime = null

func _init() -> void:
    ui_contract = _load_dictionary(UI_CONTRACT_PATH)
    input_contract = _load_dictionary(INPUT_CONTRACT_PATH)

func bind(runtime: VeilleursContentRuntime) -> void:
    content_runtime = runtime

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    var principles: Dictionary = ui_contract.get("principles", {})
    if int(principles.get("touch_target_min_points", 0)) < 48:
        errors.append("touch_target_below_48")
    if bool(principles.get("long_press_required", true)):
        errors.append("long_press_required")
    if bool(principles.get("hover_required", true)):
        errors.append("hover_required")
    if bool((ui_contract.get("recruitment_interaction", {}) as Dictionary).get("show_capture_percentage", true)):
        errors.append("capture_percentage_visible")
    var controller: Dictionary = (ui_contract.get("profiles", {}) as Dictionary).get("controller", {})
    if bool(controller.get("pointer_dependency", true)):
        errors.append("controller_pointer_dependency")
    return {"ok": errors.is_empty(), "errors": errors, "touch_target_min_points": int(principles.get("touch_target_min_points", 48))}

func layout_profile(viewport_width: float, input_mode: String = "touch") -> Dictionary:
    var profile_name := "phone"
    if input_mode == "controller":
        profile_name = "controller"
    elif input_mode == "mouse_keyboard":
        profile_name = "desktop"
    elif viewport_width >= 1100.0:
        profile_name = "desktop"
    elif viewport_width >= 700.0:
        profile_name = "tablet"
    var profiles: Dictionary = ui_contract.get("profiles", {})
    var profile: Dictionary = (profiles.get(profile_name, {}) as Dictionary).duplicate(true)
    profile["name"] = profile_name
    profile["touch_target_min_points"] = int((ui_contract.get("principles", {}) as Dictionary).get("touch_target_min_points", 48))
    profile["safe_area_required"] = bool((ui_contract.get("principles", {}) as Dictionary).get("safe_area_required_on_mobile", true)) and profile_name in ["phone", "tablet"]
    return profile

func refuge_view() -> Dictionary:
    if content_runtime == null:
        return {"bound": false, "cards": [], "capacity": 0, "used": 0, "remaining": 0}
    var snapshot := content_runtime.refuge_snapshot()
    var cards: Array[Dictionary] = []
    for value: Variant in snapshot.get("roster", []):
        if value is Dictionary:
            cards.append(_recruit_card(value))
    return {
        "bound": true,
        "act": snapshot.get("act", "I"),
        "capacity": snapshot.get("capacity", 0),
        "used": snapshot.get("used", 0),
        "remaining": snapshot.get("remaining", 0),
        "cards": cards,
        "party_max": 4,
        "party_min_watchers": 1,
        "relationship_axes": ["CONFIANCE", "RESPECT", "PEUR", "RESSENTIMENT"]
    }

func rally_view(candidate: Dictionary) -> Dictionary:
    var enemy_snapshot: Dictionary = candidate.get("enemy_snapshot", {})
    var body_state: Dictionary = enemy_snapshot.get("body_state", {})
    return {
        "rally_id": candidate.get("rally_id", ""),
        "species_id": candidate.get("species_id", ""),
        "species_name": candidate.get("species_name", ""),
        "condition_text": candidate.get("condition_text", ""),
        "condition_mode": candidate.get("condition_mode", ""),
        "capture_is_recruitment": false,
        "show_capture_percentage": false,
        "observable_state": {
            "blessures": (enemy_snapshot.get("persistent_injuries", []) as Array).duplicate(true),
            "corps": body_state.duplicate(true),
            "posture": (candidate.get("context", {}) as Dictionary).get("posture", "inconnue"),
            "relation": (candidate.get("context", {}) as Dictionary).get("relation", "inconnue"),
            "volonte": (candidate.get("context", {}) as Dictionary).get("volonte", "inconnue")
        },
        "confirmation_required": true,
        "boss_recruitment_available": false
    }

func archive_entity_view(entity_id: String) -> Dictionary:
    if content_runtime == null:
        return {"bound": false, "entity_id": entity_id}
    var entry := content_runtime.archive_entry(entity_id)
    if entry.is_empty():
        return {
            "bound": true,
            "entity_id": entity_id,
            "knowledge_state": "UNKNOWN",
            "knowledge_label": "Inconnu",
            "sections": _empty_sections(),
            "unknown_is_explicit": true
        }
    var state := str(entry.get("knowledge_state", "UNKNOWN"))
    return {
        "bound": true,
        "entity_id": entity_id,
        "knowledge_state": state,
        "knowledge_label": str(KNOWLEDGE_LABELS.get(state, state.capitalize())),
        "sections": {
            "identite_connaissance": {"knowledge_state": state, "events": (entry.get("events", []) as Array).duplicate(true)},
            "corps": (entry.get("corps", []) as Array).duplicate(true),
            "combat": (entry.get("combat", []) as Array).duplicate(true),
            "histoire": (entry.get("histoire", []) as Array).duplicate(true),
            "traces": (entry.get("traces", []) as Array).duplicate(true)
        },
        "unknown_is_explicit": true
    }

func boss_archive_view(boss_id: String, entity_id: String = "") -> Dictionary:
    if content_runtime == null:
        return {"bound": false, "boss_id": boss_id}
    var archive_id := entity_id if not entity_id.is_empty() else "boss:%s" % boss_id
    var base := archive_entity_view(archive_id)
    base["boss_id"] = boss_id
    base["observed_phases"] = content_runtime.known_boss_phases(boss_id)
    base["unseen_phase_reveal_forbidden"] = true
    return base

func primary_sections() -> Array[String]:
    return ["identite_connaissance", "corps", "combat", "histoire", "traces"]

func _recruit_card(value: Variant) -> Dictionary:
    var recruit: Dictionary = value if value is Dictionary else {}
    var injuries: Array = recruit.get("persistent_injuries", [])
    var relationships: Dictionary = recruit.get("relationships", {})
    var relation_parts: Array[String] = []
    for axis: String in ["CONFIANCE", "RESPECT", "PEUR", "RESSENTIMENT"]:
        relation_parts.append("%s %d" % [axis.capitalize(), int(relationships.get(axis, 0))])
    return {
        "identity": recruit.get("name", "Auxiliaire"),
        "species": recruit.get("species_id", ""),
        "memory_rank": recruit.get("memory_rank", "normal"),
        "injury_summary": "%d blessure(s) persistante(s)" % injuries.size(),
        "relationship_summary": " · ".join(relation_parts),
        "availability": recruit.get("availability", "available"),
        "identity_seed": recruit.get("identity_seed", 0)
    }

func _empty_sections() -> Dictionary:
    return {
        "identite_connaissance": {"knowledge_state": "UNKNOWN", "events": []},
        "corps": [],
        "combat": [],
        "histoire": [],
        "traces": []
    }

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
