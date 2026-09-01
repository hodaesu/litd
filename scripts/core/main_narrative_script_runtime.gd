extends Node

signal scene_started(scene: Dictionary)
signal beat_ready(beat: Dictionary)
signal choice_requested(choice: Dictionary)
signal scene_finished(scene_id: String)

const MANIFEST_PATH := "res://data/narrative/main_script/manifest.json"

var manifest: Dictionary = {}
var scripts_by_chapter: Dictionary = {}
var active_scene: Dictionary = {}
var active_beat_index: int = -1

func _ready() -> void:
    reload_scripts()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("MainNarrativeScriptRuntime: missing " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func reload_scripts() -> void:
    manifest = _load_json(MANIFEST_PATH)
    scripts_by_chapter.clear()
    for value: Variant in manifest.get("chapters", []):
        var entry: Dictionary = value if value is Dictionary else {}
        var chapter_id := str(entry.get("id", ""))
        var path := str(entry.get("file", ""))
        if chapter_id == "" or path == "":
            continue
        var script := _load_json(path)
        if not script.is_empty():
            scripts_by_chapter[chapter_id] = script

func chapter_script(chapter_id: String = "") -> Dictionary:
    var target := chapter_id if chapter_id != "" else CampaignState.current_chapter_id
    var value: Variant = scripts_by_chapter.get(target, {})
    return value.duplicate(true) if value is Dictionary else {}

func chapter_scenes(chapter_id: String = "") -> Array:
    var script := chapter_script(chapter_id)
    var values: Variant = script.get("scenes", [])
    return values.duplicate(true) if values is Array else []

func scene(scene_id: String, chapter_id: String = "") -> Dictionary:
    for value: Variant in chapter_scenes(chapter_id):
        var candidate: Dictionary = value if value is Dictionary else {}
        if str(candidate.get("id", "")) == scene_id:
            return candidate.duplicate(true)
    return {}

func scenes_for_trigger(trigger_id: String, chapter_id: String = "") -> Array:
    var result: Array = []
    for value: Variant in chapter_scenes(chapter_id):
        var candidate: Dictionary = value if value is Dictionary else {}
        if str(candidate.get("trigger", "")) == trigger_id:
            result.append(candidate.duplicate(true))
    return result

func start_scene(scene_id: String, chapter_id: String = "") -> Dictionary:
    if EndgameState.active_cycle > 0:
        return {"mode":"blocked", "reason":"cycle_initial_only", "scene_id":scene_id}
    var target := scene(scene_id, chapter_id)
    if target.is_empty():
        return {"mode":"missing", "scene_id":scene_id}
    active_scene = target
    active_beat_index = 0
    scene_started.emit(active_scene.duplicate(true))
    return _emit_current_beat()

func start_first_for_trigger(trigger_id: String, chapter_id: String = "") -> Dictionary:
    var matches := scenes_for_trigger(trigger_id, chapter_id)
    if matches.is_empty():
        return {"mode":"missing", "trigger":trigger_id}
    return start_scene(str(matches[0].get("id", "")), chapter_id)

func current_beat() -> Dictionary:
    if active_scene.is_empty() or active_beat_index < 0:
        return {}
    var beats: Array = active_scene.get("beats", [])
    if active_beat_index >= beats.size():
        return {}
    var value: Variant = beats[active_beat_index]
    return value.duplicate(true) if value is Dictionary else {}

func advance() -> Dictionary:
    var beat := current_beat()
    if beat.is_empty():
        return _finish_active_scene()
    if str(beat.get("kind", "")) == "choice":
        var prepared := beat.duplicate(true)
        prepared["options"] = available_options(beat)
        choice_requested.emit(prepared.duplicate(true))
        return {"mode":"choice_required", "choice":prepared}
    active_beat_index += 1
    if current_beat().is_empty():
        return _finish_active_scene()
    return _emit_current_beat()

func choose(option_id: String) -> Dictionary:
    var beat := current_beat()
    if str(beat.get("kind", "")) != "choice":
        return {"mode":"invalid", "reason":"current_beat_is_not_choice"}
    for option_value: Variant in available_options(beat):
        var option: Dictionary = option_value if option_value is Dictionary else {}
        if str(option.get("id", "")) != option_id:
            continue
        _apply_sets(option.get("sets", []))
        active_beat_index += 1
        return {
            "mode":"choice_resolved",
            "option":option.duplicate(true),
            "response":option.get("response", []).duplicate(true),
            "next":_emit_current_beat() if not current_beat().is_empty() else _finish_active_scene()
        }
    return {"mode":"invalid", "reason":"option_unavailable", "option_id":option_id}

func available_options(choice_beat: Dictionary) -> Array:
    var result: Array = []
    for option_value: Variant in choice_beat.get("options", []):
        var option: Dictionary = option_value if option_value is Dictionary else {}
        if _availability_matches(str(option.get("availability", ""))):
            result.append(option.duplicate(true))
    return result

func _availability_matches(rule: String) -> bool:
    if rule == "":
        return true
    if rule.begins_with("ending_available:"):
        var ending_id := rule.trim_prefix("ending_available:")
        for value: Variant in CampaignState.available_endings():
            var ending: Dictionary = value if value is Dictionary else {}
            if str(ending.get("id", "")) == ending_id:
                return true
        return false
    if rule.begins_with("failure_state:"):
        var failure_id := rule.trim_prefix("failure_state:")
        return bool(CampaignState.chapter_flags.get("failure_state_" + failure_id, false))
    return bool(CampaignState.chapter_flags.get(rule, false))

func _apply_sets(values: Variant) -> void:
    if not values is Array:
        return
    for raw: Variant in values:
        var flag := str(raw)
        if flag == "":
            continue
        CampaignState.set_chapter_flag(flag, true)

func _emit_current_beat() -> Dictionary:
    var beat := current_beat()
    if beat.is_empty():
        return _finish_active_scene()
    var payload := beat.duplicate(true)
    payload["mode"] = "beat"
    payload["scene_id"] = str(active_scene.get("id", ""))
    payload["beat_index"] = active_beat_index
    if str(payload.get("kind", "")) == "choice":
        payload["options"] = available_options(payload)
        choice_requested.emit(payload.duplicate(true))
    else:
        beat_ready.emit(payload.duplicate(true))
    return payload

func _finish_active_scene() -> Dictionary:
    if active_scene.is_empty():
        return {"mode":"idle"}
    var scene_id := str(active_scene.get("id", ""))
    var exit_state: Array = active_scene.get("exit_state", []).duplicate(true)
    CampaignState.set_chapter_flag("scene_complete_" + scene_id, true)
    active_scene = {}
    active_beat_index = -1
    scene_finished.emit(scene_id)
    return {"mode":"scene_finished", "scene_id":scene_id, "exit_state":exit_state}

func serialize() -> Dictionary:
    return {
        "active_scene_id":str(active_scene.get("id", "")),
        "active_chapter_id":str(active_scene.get("chapter_id", "")),
        "active_beat_index":active_beat_index
    }

func deserialize(payload: Dictionary) -> void:
    var scene_id := str(payload.get("active_scene_id", ""))
    var chapter_id := str(payload.get("active_chapter_id", ""))
    if scene_id == "":
        active_scene = {}
        active_beat_index = -1
        return
    active_scene = scene(scene_id, chapter_id)
    active_beat_index = clampi(int(payload.get("active_beat_index", 0)), 0, maxi(0, active_scene.get("beats", []).size() - 1))
