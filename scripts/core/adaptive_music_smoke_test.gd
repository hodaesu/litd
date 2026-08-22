extends Node

const TRAINING_PATH := "res://data/adaptive_music_training.json"

var failures: Array[String] = []

func run() -> void:
    var payload: Dictionary = _load_dictionary(TRAINING_PATH)
    _check(not payload.is_empty(), "Adaptive music training data must load")
    var scenarios_variant: Variant = payload.get("scenarios", [])
    var scenarios: Array = scenarios_variant if scenarios_variant is Array else []
    _check(scenarios.size() >= 12, "Adaptive music training must cover at least twelve situations")

    for value: Variant in scenarios:
        var scenario: Dictionary = value if value is Dictionary else {}
        if scenario.is_empty():
            continue
        var context_value: Variant = scenario.get("context", {})
        var expect_value: Variant = scenario.get("expect", {})
        var context: Dictionary = context_value if context_value is Dictionary else {}
        var expect: Dictionary = expect_value if expect_value is Dictionary else {}
        AdaptiveMusicDirector.current_intensity = 0.55
        var decision: Dictionary = AdaptiveMusicDirector._decide(context)
        var scenario_id: String = str(scenario.get("id", "unnamed"))
        _check(str(decision.get("cue", "")) == str(expect.get("cue", "")), "%s cue: %s" % [scenario_id, str(decision.get("cue", ""))])
        _check(bool(decision.get("switch_music", false)) == bool(expect.get("switch_music", false)), "%s switch_music mismatch" % scenario_id)
        var intensity: float = float(decision.get("intensity", -1.0))
        _check(intensity >= float(expect.get("intensity_min", 0.0)) - 0.0001, "%s intensity too low: %.3f" % [scenario_id, intensity])
        _check(intensity <= float(expect.get("intensity_max", 1.0)) + 0.0001, "%s intensity too high: %.3f" % [scenario_id, intensity])

        var expected_layers: Array[String] = _string_array(expect.get("layers", []))
        var actual_layers: Array[String] = LayeredMusicRuntime.preview_layer_ids(str(decision.get("cue", "")), intensity, [])
        _check(actual_layers == expected_layers, "%s layers: %s expected %s" % [scenario_id, str(actual_layers), str(expected_layers)])

    var narrative_variant: Variant = payload.get("narrative_contract", {})
    var narrative: Dictionary = narrative_variant if narrative_variant is Dictionary else {}
    var beats_variant: Variant = NarrativeAudioDirector.data.get("beats", {})
    var beats: Dictionary = beats_variant if beats_variant is Dictionary else {}
    _check(str((beats.get("revelation", {}) as Dictionary).get("music", "")) == str(narrative.get("revelation", "")), "Revelation must retain its musical cue")
    _check(str((beats.get("loss", {}) as Dictionary).get("music", "")) == str(narrative.get("loss", "")), "Loss must retain its musical cue")
    _check(str((beats.get("reunion", {}) as Dictionary).get("music", "")) == str(narrative.get("reunion", "")), "Reunion must retain its musical cue")
    _check(str((AudioDirector.data.get("combat_resolution_music", {}) as Dictionary).get("victory", "")) == str(narrative.get("victory", "")), "Victory must retain a costly-resolution cue")
    _check(str((AudioDirector.data.get("combat_resolution_music", {}) as Dictionary).get("defeat", "")) == str(narrative.get("defeat", "")), "Defeat must retain a retreat cue")
    _check(bool(narrative.get("layered_stems_must_yield", false)), "Narrative contract must require layered stems to yield")

    _finish()

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    var values: Array = value if value is Array else []
    for item: Variant in values:
        result.append(str(item))
    return result

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("ADAPTIVE_MUSIC_TRAINING_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("ADAPTIVE_MUSIC_TRAINING: " + failure)
    print("ADAPTIVE_MUSIC_TRAINING_FAILED: %d" % failures.size())
    get_tree().quit(1)
