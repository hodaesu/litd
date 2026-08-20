class_name CinematicDirectionRuntime
extends RefCounted

const PHYSICAL_PATH := "res://data/physical_bible.json"
const NONVERBAL_PATH := "res://data/nonverbal_language_contract.json"
const PROXEMICS_PATH := "res://data/relationship_proxemics.json"
const GRAMMAR_PATH := "res://data/cinematic_grammar.json"
const BLOCKING_PATH := "res://data/demo_cinematic_blocking.json"

var _physical: Dictionary = {}
var _nonverbal: Dictionary = {}
var _proxemics: Dictionary = {}
var _grammar: Dictionary = {}
var _blocking: Dictionary = {}


func load_contracts() -> bool:
    _physical = _read_json(PHYSICAL_PATH)
    _nonverbal = _read_json(NONVERBAL_PATH)
    _proxemics = _read_json(PROXEMICS_PATH)
    _grammar = _read_json(GRAMMAR_PATH)
    _blocking = _read_json(BLOCKING_PATH)
    return is_ready()


func is_ready() -> bool:
    return not _physical.is_empty() \
        and not _nonverbal.is_empty() \
        and not _proxemics.is_empty() \
        and not _grammar.is_empty() \
        and not _blocking.is_empty()


func physical_profile(character_id: String) -> Dictionary:
    var characters: Dictionary = _physical.get("characters", {})
    var raw: Variant = characters.get(character_id, {})
    if typeof(raw) != TYPE_DICTIONARY:
        return {}
    return (raw as Dictionary).duplicate(true)


func nonverbal_channels() -> Array:
    var raw: Variant = _nonverbal.get("channels", [])
    if typeof(raw) != TYPE_ARRAY:
        return []
    return (raw as Array).duplicate(true)


func proxemic_pair(pair_id: String) -> Dictionary:
    var pairs: Dictionary = _proxemics.get("pair_defaults", {})
    var raw: Variant = pairs.get(pair_id, {})
    if typeof(raw) != TYPE_DICTIONARY:
        return {}
    return (raw as Dictionary).duplicate(true)


func scene_contract(scene_id: String) -> Dictionary:
    var raw_scenes: Variant = _blocking.get("scenes", [])
    if typeof(raw_scenes) != TYPE_ARRAY:
        return {}
    for raw: Variant in raw_scenes:
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var scene: Dictionary = raw as Dictionary
        if String(scene.get("id", "")) == scene_id:
            return scene.duplicate(true)
    return {}


func scene_ids() -> Array[String]:
    var result: Array[String] = []
    var raw_scenes: Variant = _blocking.get("scenes", [])
    if typeof(raw_scenes) != TYPE_ARRAY:
        return result
    for raw: Variant in raw_scenes:
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var scene: Dictionary = raw as Dictionary
        var scene_id := String(scene.get("id", ""))
        if not scene_id.is_empty():
            result.append(scene_id)
    return result


func dialogue_scene(line_id: String) -> Dictionary:
    var raw_scenes: Variant = _blocking.get("scenes", [])
    if typeof(raw_scenes) != TYPE_ARRAY:
        return {}
    for raw: Variant in raw_scenes:
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var scene: Dictionary = raw as Dictionary
        var raw_ids: Variant = scene.get("dialogue_ids", [])
        if typeof(raw_ids) != TYPE_ARRAY:
            continue
        for raw_line: Variant in raw_ids:
            if String(raw_line) == line_id:
                return scene.duplicate(true)
    return {}


func camera_move_is_authored(move_id: String) -> bool:
    var moves: Dictionary = _grammar.get("camera_moves", {})
    return moves.has(move_id) and move_id != "orbit"


func validate_scene_handoff(scene_id: String) -> bool:
    var scene := scene_contract(scene_id)
    if scene.is_empty() or String(scene.get("handoff", "")).is_empty():
        return false
    var raw_beats: Variant = scene.get("beats", [])
    if typeof(raw_beats) != TYPE_ARRAY or (raw_beats as Array).size() < 2:
        return false
    for raw: Variant in raw_beats:
        if typeof(raw) != TYPE_DICTIONARY:
            return false
        var beat: Dictionary = raw as Dictionary
        if String(beat.get("camera", "")).is_empty() or String(beat.get("reason", "")).is_empty():
            return false
        if String(beat.get("camera", "")).to_lower().contains("orbit"):
            return false
    return true


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed as Dictionary
