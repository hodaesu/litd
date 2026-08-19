extends Node

var failures: Array[String] = []
var missing_count: int = 0

func run() -> void:
    VoiceRuntime.reload_manifest()
    DialogueDirector.reset_run()
    if not VoiceRuntime.voice_missing.is_connected(_on_voice_missing):
        VoiceRuntime.voice_missing.connect(_on_voice_missing)

    var snapshot: Dictionary = VoiceRuntime.snapshot()
    _check(int(snapshot.get("asset_count", -1)) == 0, "Prototype branch must not pretend approved voice assets exist")
    _check(not VoiceRuntime.voice_available("fw_aur_direct_01"), "Unrendered dialogue must remain text-only")
    _check(VoiceRuntime.asset_for_line("fw_aur_direct_01").is_empty(), "Missing voice line must return an empty asset")

    var selected: Dictionary = DialogueDirector.request_line(
        "choice_wait",
        {"speaker_id": "aurelien", "force_fourth_wall": true}
    )
    await get_tree().process_frame
    _check(str(selected.get("mode", "")) == "dialogue", "DialogueDirector must still select authored text without voice audio")
    _check(str(selected.get("speaker_id", "")) == "aurelien", "Requested living hero must remain the speaker")
    _check(missing_count == 1, "VoiceRuntime must report the absent approved WAV exactly once")
    _check(not bool(VoiceRuntime.snapshot().get("playing", true)), "Missing voice audio must never create a fake playback state")

    _finish()

func _on_voice_missing(_line_id: String) -> void:
    missing_count += 1

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VOICE_RUNTIME_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VOICE_RUNTIME_SMOKE: " + failure)
    print("VOICE_RUNTIME_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
