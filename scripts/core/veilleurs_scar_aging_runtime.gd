extends RefCounted

const RULES_PATH := "res://data/remanence_world_rules.json"

static func presentation_for_scar(scar: Dictionary) -> Dictionary:
    if scar.is_empty():
        return {}
    var rules := _load_rules()
    var scar_type := str(scar.get("type", ""))
    var age_stage := str(scar.get("age_stage", "fresh"))
    var age_runs := int(scar.get("age_runs", 0))
    var payload: Dictionary = scar.get("payload", {})
    var by_type: Dictionary = (rules.get("aging_presentations", {}) as Dictionary).get(scar_type, {})
    var presentation: Dictionary = (by_type.get(age_stage, {}) as Dictionary).duplicate(true)

    if scar_type == "persistent_corpse" and str(payload.get("owner_kind", "")) == "watcher" and bool(payload.get("great_remanence", false)) and age_runs >= 5:
        presentation = ((rules.get("special_presentations", {}) as Dictionary).get("watcher_great_remanence_grave", {}) as Dictionary).duplicate(true)

    presentation["scar_id"] = str(scar.get("id", ""))
    presentation["scar_type"] = scar_type
    presentation["age_stage"] = age_stage
    presentation["age_runs"] = age_runs
    presentation["protected"] = bool(scar.get("protected", false))
    presentation["severity"] = str(scar.get("severity", "trace"))
    if not presentation.has("visible"):
        presentation["visible"] = age_stage != "archive"
    if not presentation.has("interactive"):
        presentation["interactive"] = false
    if scar_type == "major_item_removed":
        presentation["object_id"] = str(payload.get("object_id", ""))
        presentation["object_location_anchor"] = str(payload.get("object_location_anchor", ""))
        presentation["object_location_room"] = str(payload.get("object_location_room", ""))
    return presentation

static func room_projection(scars: Array) -> Dictionary:
    var presentations: Array[Dictionary] = []
    var tags: Array[String] = []
    var visible_count := 0
    var interactive_count := 0
    for value: Variant in scars:
        if not (value is Dictionary):
            continue
        var presentation := presentation_for_scar(value)
        if presentation.is_empty():
            continue
        presentations.append(presentation)
        if bool(presentation.get("visible", false)):
            visible_count += 1
        if bool(presentation.get("interactive", false)):
            interactive_count += 1
        for tag_value: Variant in presentation.get("environment_tags", []):
            var tag := str(tag_value)
            if tag != "" and not tags.has(tag):
                tags.append(tag)
    return {
        "presentations": presentations,
        "environment_tags": tags,
        "visible_count": visible_count,
        "interactive_count": interactive_count
    }

static func relocate_persistent_object(absence_scar_id: String, new_anchor_id: String, context: Dictionary = {}) -> bool:
    if absence_scar_id == "" or new_anchor_id == "" or not RemanenceRuntime.world_scars.has(absence_scar_id):
        return false
    var scar: Dictionary = RemanenceRuntime.world_scars.get(absence_scar_id, {})
    if str(scar.get("type", "")) != "major_item_removed":
        return false
    var payload: Dictionary = (scar.get("payload", {}) as Dictionary).duplicate(true)
    var object_id := str(payload.get("object_id", ""))
    if object_id == "":
        return false
    var movements: Array = (payload.get("object_movements", []) as Array).duplicate(true)
    movements.append({
        "run_index": RemanenceRuntime.run_index,
        "from_anchor": str(payload.get("object_location_anchor", scar.get("anchor_id", ""))),
        "to_anchor": new_anchor_id,
        "room_id": str(context.get("room_id", "")),
        "carrier_id": str(context.get("carrier_id", "")),
        "reason": str(context.get("reason", "moved"))
    })
    payload["object_location_anchor"] = new_anchor_id
    payload["object_location_room"] = str(context.get("room_id", ""))
    payload["object_carrier_id"] = str(context.get("carrier_id", ""))
    payload["object_last_moved_run"] = RemanenceRuntime.run_index
    payload["object_movements"] = movements
    var updated := RemanenceRuntime.update_world_scar(absence_scar_id, {"payload": payload})
    if updated:
        RemanenceRuntime.link_archive_nodes(object_id, "anchor:%s" % new_anchor_id, "located_at", {
            "run_index": RemanenceRuntime.run_index,
            "scar_id": absence_scar_id,
            "room_id": str(context.get("room_id", "")),
            "carrier_id": str(context.get("carrier_id", ""))
        })
    return updated

static func _load_rules() -> Dictionary:
    if not FileAccess.file_exists(RULES_PATH):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
    return parsed if parsed is Dictionary else {}