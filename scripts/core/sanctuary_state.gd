extends Node

signal sanctuary_state_changed(active_layers: Array)

const DATA_PATH := "res://data/levels/sanctuary_state_layers.json"

var data: Dictionary = {}
var active_layers: Array[String] = []

func _ready() -> void:
    _load_data()
    PoliticalState.politics_changed.connect(refresh)
    GameState.state_changed.connect(refresh)
    CreatureManager.creatures_changed.connect(refresh)
    refresh()

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        data = {}
        return
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _rule_matches(rule: Dictionary) -> bool:
    if rule.is_empty():
        return true
    if PoliticalState.tension < int(rule.get("tension_min", -999)):
        return false
    if PoliticalState.trust < int(rule.get("trust_min", -999)):
        return false
    if PoliticalState.trust > int(rule.get("trust_max", 999)):
        return false
    if int(PoliticalState.three_awakenings.get("body", 0)) < int(rule.get("body_min", -999)):
        return false
    if int(PoliticalState.three_awakenings.get("city", 0)) < int(rule.get("city_min", -999)):
        return false
    if GameState.supplies > int(rule.get("supplies_max", 999)):
        return false
    var any_flags: Array = rule.get("any_flag", [])
    if not any_flags.is_empty():
        var found := false
        for flag_value in any_flags:
            if PoliticalState.is_flag_set(String(flag_value)):
                found = true
                break
        if not found:
            return false
    return true

func refresh() -> void:
    var base_id := String(data.get("base_state", "stable"))
    var candidates: Array[Dictionary] = []
    for layer_value in data.get("layers", []):
        var layer: Dictionary = layer_value
        var layer_id := String(layer.get("id", ""))
        if layer_id == base_id:
            continue
        if _rule_matches(layer.get("when", {})):
            candidates.append(layer)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
    var max_major := int(data.get("composition", {}).get("max_simultaneous_major_layers", 3))
    var resolved: Array[String] = [base_id]
    for layer in candidates.slice(0, max_major):
        resolved.append(String(layer.get("id", "")))
    if resolved != active_layers:
        active_layers = resolved
        sanctuary_state_changed.emit(active_layers.duplicate())

func layer_definition(layer_id: String) -> Dictionary:
    for layer_value in data.get("layers", []):
        var layer: Dictionary = layer_value
        if String(layer.get("id", "")) == layer_id:
            return layer
    return {}

func current_visual_cues() -> Array[String]:
    var result: Array[String] = []
    for layer_id in active_layers:
        for cue in layer_definition(layer_id).get("visual", []):
            if not result.has(String(cue)):
                result.append(String(cue))
    return result

func current_audio_cues() -> Array[String]:
    var result: Array[String] = []
    for layer_id in active_layers:
        for cue in layer_definition(layer_id).get("audio", []):
            if not result.has(String(cue)):
                result.append(String(cue))
    return result

func current_population_cues() -> Array[String]:
    var result: Array[String] = []
    for layer_id in active_layers:
        for cue in layer_definition(layer_id).get("population", []):
            if not result.has(String(cue)):
                result.append(String(cue))
    return result

func gameplay_modifiers() -> Dictionary:
    var result: Dictionary = {}
    for layer_id in active_layers:
        var modifiers: Dictionary = layer_definition(layer_id).get("gameplay", {})
        for key_value in modifiers.keys():
            var key := String(key_value)
            var value = modifiers[key]
            if typeof(value) == TYPE_BOOL:
                result[key] = bool(result.get(key, false)) or bool(value)
            else:
                result[key] = int(result.get(key, 0)) + int(value)
    return result

func summary() -> String:
    var names: Array[String] = []
    for layer_id in active_layers:
        names.append(String(layer_definition(layer_id).get("name", layer_id)))
    return " · ".join(names)
