extends Node

signal scene_queued(scene_id: String)
signal scene_presented(scene_id: String, payload: Dictionary)
signal scene_line_selected(payload: Dictionary)
signal scene_silence_selected(scene_id: String, reaction: String)
signal narrative_state_changed

const DATA_PATH := "res://data/narrative/systemic_cross_sanctuary_scenes.json"
const RECENT_PRESENTATION_LIMIT := 8

var data: Dictionary = {}
var scenes: Dictionary = {}
var pending_scene_ids: Array[String] = []
var seen_scene_ids: Array[String] = []
var recent_presentations: Array[Dictionary] = []
var _presenting: bool = false

func _ready() -> void:
    _load_data()
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not SystemicCrossRuntime.cross_event_applied.is_connected(_on_cross_event_applied):
        SystemicCrossRuntime.cross_event_applied.connect(_on_cross_event_applied)
    if not SystemicCrossRuntime.cascade_applied.is_connected(_on_cascade_applied):
        SystemicCrossRuntime.cascade_applied.connect(_on_cascade_applied)
    call_deferred("_sync_applied_scenes")

func _load_data() -> void:
    data = _load_json_dictionary(DATA_PATH)
    var value: Variant = data.get("scenes", {})
    scenes = value.duplicate(true) if value is Dictionary else {}

func _load_json_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("SystemicCrossNarrativeRuntime: missing data file " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func reset_new_game() -> void:
    pending_scene_ids = []
    seen_scene_ids = []
    recent_presentations = []
    _presenting = false
    narrative_state_changed.emit()

func _on_new_game_reset() -> void:
    reset_new_game()

func _on_screen_requested(screen_name: String) -> void:
    if screen_name != "sanctuary":
        return
    if not bool(data.get("rules", {}).get("one_scene_per_sanctuary_entry", true)):
        return
    call_deferred("present_next_pending_scene")

func _on_cross_event_applied(event_id: String, _payload: Dictionary) -> void:
    queue_scene(event_id)

func _on_cascade_applied(cascade_id: String, _payload: Dictionary) -> void:
    queue_scene(cascade_id)

func queue_scene(scene_id: String) -> bool:
    if not scenes.has(scene_id):
        return false
    if seen_scene_ids.has(scene_id) or pending_scene_ids.has(scene_id):
        return false
    pending_scene_ids.append(scene_id)
    scene_queued.emit(scene_id)
    narrative_state_changed.emit()
    return true

func _sync_applied_scenes() -> void:
    for event_id: String in SystemicCrossRuntime.applied_event_ids():
        queue_scene(event_id)
    for cascade_id: String in SystemicCrossRuntime.applied_cascade_ids():
        queue_scene(cascade_id)

func pending_scene_count() -> int:
    return pending_scene_ids.size()

func has_pending_scene() -> bool:
    return not pending_scene_ids.is_empty()

func next_scene_title() -> String:
    if pending_scene_ids.is_empty():
        return ""
    return str(scenes.get(pending_scene_ids[0], {}).get("title", pending_scene_ids[0]))

func scene_seen(scene_id: String) -> bool:
    return seen_scene_ids.has(scene_id)

func present_next_pending_scene() -> Dictionary:
    if _presenting or GameState.current_screen != "sanctuary":
        return {}
    _sync_applied_scenes()
    if pending_scene_ids.is_empty():
        return {}
    _presenting = true
    var scene_id: String = str(pending_scene_ids.pop_front())
    if seen_scene_ids.has(scene_id):
        _presenting = false
        return present_next_pending_scene()
    var payload: Dictionary = resolved_scene(scene_id)
    if payload.is_empty():
        _presenting = false
        return {}
    seen_scene_ids.append(scene_id)
    _record_presentation(payload)
    _log_scene(payload)
    scene_presented.emit(scene_id, payload.duplicate(true))
    narrative_state_changed.emit()
    _presenting = false
    return payload

func resolved_scene(scene_id: String) -> Dictionary:
    var source_value: Variant = scenes.get(scene_id, {})
    if not (source_value is Dictionary):
        return {}
    var source: Dictionary = source_value
    if source.is_empty():
        return {}
    var context: Dictionary = _context_for(scene_id)
    var payload: Dictionary = source.duplicate(true)
    payload["scene_id"] = scene_id
    for key: String in ["title", "task", "opening", "closing", "location"]:
        payload[key] = _replace_tokens(str(payload.get(key, "")), context)
    payload["dialogue"] = _resolve_dialogue(source.get("dialogue", []), context)
    payload["silent_reaction"] = _resolve_silent_reaction(source.get("silent_reactions", []), context)
    return payload

func _resolve_dialogue(values: Variant, context: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var lines: Array = values if values is Array else []
    var limit: int = maxi(0, int(data.get("rules", {}).get("max_spoken_hero_lines", 2)))
    for value: Variant in lines:
        if result.size() >= limit:
            break
        var line: Dictionary = value if value is Dictionary else {}
        var speaker_id: String = str(line.get("speaker_id", ""))
        if speaker_id == "":
            continue
        var hero: Dictionary = _alive_hero(speaker_id)
        if hero.is_empty():
            continue
        var text: String = _replace_tokens(str(line.get("text", "")), context)
        if text == "":
            continue
        result.append({
            "speaker_id": speaker_id,
            "speaker": str(hero.get("name", _display_hero_id(speaker_id))),
            "text": text
        })
    return result

func _resolve_silent_reaction(values: Variant, context: Dictionary) -> Dictionary:
    var reactions: Array = values if values is Array else []
    for value: Variant in reactions:
        var reaction: Dictionary = value if value is Dictionary else {}
        var hero_id: String = str(reaction.get("hero_id", ""))
        var hero: Dictionary = _alive_hero(hero_id)
        if hero.is_empty():
            continue
        var text: String = _replace_tokens(str(reaction.get("text", "")), context)
        if text == "":
            continue
        return {
            "hero_id": hero_id,
            "speaker": str(hero.get("name", _display_hero_id(hero_id))),
            "text": text
        }
    return {}

func _context_for(scene_id: String) -> Dictionary:
    if SystemicCrossRuntime.applied_events.has(scene_id):
        var state_value: Variant = SystemicCrossRuntime.applied_events.get(scene_id, {})
        var state: Dictionary = state_value if state_value is Dictionary else {}
        var context_value: Variant = state.get("context", {})
        return context_value.duplicate(true) if context_value is Dictionary else {}
    if SystemicCrossRuntime.applied_cascades.has(scene_id):
        var cascade_value: Variant = SystemicCrossRuntime.applied_cascades.get(scene_id, {})
        return cascade_value.duplicate(true) if cascade_value is Dictionary else {}
    return {}

func _replace_tokens(text: String, context: Dictionary) -> String:
    var dead_name: String = str(context.get("name", context.get("dead_name", "le nom inscrit")))
    var cause: String = str(context.get("cause", context.get("material_cause", "cause matérielle consignée")))
    return text.replace("{dead_name}", dead_name).replace("{cause}", cause)

func _alive_hero(registry_id: String) -> Dictionary:
    var normalized: String = _normalize_hero_id(registry_id)
    for hero_value: Variant in GameState.alive_heroes():
        var hero: Dictionary = hero_value if hero_value is Dictionary else {}
        if _normalize_hero_id(str(hero.get("id", ""))) == normalized:
            return hero
    return {}

func _normalize_hero_id(value: String) -> String:
    var normalized: String = value.strip_edges().to_lower()
    if normalized.begins_with("hero."):
        normalized = normalized.trim_prefix("hero.")
    return normalized

func _display_hero_id(value: String) -> String:
    return _normalize_hero_id(value).capitalize()

func _record_presentation(payload: Dictionary) -> void:
    recent_presentations.append({
        "scene_id": str(payload.get("scene_id", "")),
        "title": str(payload.get("title", "")),
        "chapter_id": CampaignState.current_chapter_id,
        "location": str(payload.get("location", ""))
    })
    while recent_presentations.size() > RECENT_PRESENTATION_LIMIT:
        recent_presentations.pop_front()

func _log_scene(payload: Dictionary) -> void:
    var title: String = str(payload.get("title", "Conséquence"))
    var opening: String = str(payload.get("opening", ""))
    var task: String = str(payload.get("task", ""))
    var closing: String = str(payload.get("closing", ""))
    GameState.add_log("SCÈNE AU SANCTUAIRE — %s" % title)
    if opening != "":
        GameState.add_log(opening)
    if task != "":
        GameState.add_log("Pendant ce temps : %s" % task)
    for line_value: Variant in payload.get("dialogue", []):
        var line: Dictionary = line_value if line_value is Dictionary else {}
        if line.is_empty():
            continue
        scene_line_selected.emit(line.duplicate(true))
        GameState.add_log("%s — %s" % [str(line.get("speaker", "Héros")), str(line.get("text", ""))])
    var silence_value: Variant = payload.get("silent_reaction", {})
    var silence: Dictionary = silence_value if silence_value is Dictionary else {}
    if not silence.is_empty():
        var reaction: String = str(silence.get("text", ""))
        scene_silence_selected.emit(str(payload.get("scene_id", "")), reaction)
        GameState.add_log(reaction)
    if closing != "":
        GameState.add_log(closing)

func recent_scene_summaries(limit: int = 4) -> Array[String]:
    var result: Array[String] = []
    for index: int in range(recent_presentations.size() - 1, -1, -1):
        if result.size() >= limit:
            break
        var item: Dictionary = recent_presentations[index]
        result.append("%s · %s" % [str(item.get("title", "")), str(item.get("location", ""))])
    return result

func serialize() -> Dictionary:
    return {
        "pending_scene_ids": pending_scene_ids.duplicate(),
        "seen_scene_ids": seen_scene_ids.duplicate(),
        "recent_presentations": recent_presentations.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    pending_scene_ids = []
    for value: Variant in payload.get("pending_scene_ids", []):
        var scene_id: String = str(value)
        if scenes.has(scene_id) and not pending_scene_ids.has(scene_id):
            pending_scene_ids.append(scene_id)
    seen_scene_ids = []
    for value: Variant in payload.get("seen_scene_ids", []):
        var scene_id: String = str(value)
        if scenes.has(scene_id) and not seen_scene_ids.has(scene_id):
            seen_scene_ids.append(scene_id)
    recent_presentations = []
    for value: Variant in payload.get("recent_presentations", []):
        if value is Dictionary:
            recent_presentations.append((value as Dictionary).duplicate(true))
    while recent_presentations.size() > RECENT_PRESENTATION_LIMIT:
        recent_presentations.pop_front()
    for scene_id: String in seen_scene_ids:
        pending_scene_ids.erase(scene_id)
    _sync_applied_scenes()
    narrative_state_changed.emit()
