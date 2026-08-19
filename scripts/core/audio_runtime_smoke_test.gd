extends Node

var failures: Array[String] = []

func run() -> void:
    _check(not PrototypeAudioBank.data.is_empty(), "PrototypeAudioBank must load its data")
    var coverage: Dictionary = PrototypeAudioBank.coverage()
    _check(int(coverage.get("assets", 0)) >= 17, "Prototype bank must expose at least 17 local assets")
    _check(int(coverage.get("sfx", 0)) >= 11, "Prototype bank must expose SFX")
    _check(int(coverage.get("music", 0)) >= 6, "Prototype bank must expose music beds")
    _check(int(coverage.get("loops", 0)) >= 5, "Prototype bank must expose looping ambience/music")
    _check(int(coverage.get("external_verified_sources", 0)) >= 1, "Prototype bank must preserve verified external source metadata")

    var source_entries: Array[Dictionary] = PrototypeAudioBank.external_verified_sources()
    _check(not source_entries.is_empty() and str(source_entries[0].get("license", "")) == "CC0", "Verified footsteps source must remain CC0")

    var footstep_stream: AudioStream = PrototypeAudioBank.stream_for_cue("footstep_ash", "sfx")
    _check(footstep_stream is AudioStreamWAV, "Footstep cue must create a real AudioStreamWAV")
    if footstep_stream is AudioStreamWAV:
        var wav := footstep_stream as AudioStreamWAV
        _check(wav.data.size() > 1000, "Generated footstep must contain PCM audio")
        _check(wav.mix_rate == 16000, "Prototype PCM rate must remain mobile-friendly")

    SfxRuntime.reset_runtime()
    var ui_playback: Dictionary = SfxRuntime.play_cue("ui_confirm", {"reason": "smoke"})
    _check(bool(ui_playback.get("played", false)), "2D UI SFX must play")
    _check(str(ui_playback.get("spatial", "")) == "2d", "UI confirm must stay non-positional")

    var step_playback: Dictionary = SfxRuntime.play_cue("footstep_stone", {"position_3d": Vector3(2.0, 0.0, -3.0), "reason": "smoke"})
    _check(bool(step_playback.get("played", false)), "3D footstep SFX must play")
    _check(bool(step_playback.get("positioned", false)), "Footstep must use a positioned emitter when a world position is supplied")
    _check(str(step_playback.get("bus", "")) == "Foley", "Footstep must route to Foley")

    AudioDirector.reset_runtime()
    _check(AudioDirector.music_player_count() == 2, "Music runtime must keep two players for crossfades")
    _check(AudioDirector.music_crossfade_seconds() > 0.0, "Music crossfade duration must be configured")

    AudioDirector.set_exploration_zone("zone_01_faubourg_cendreux")
    var exploration: Dictionary = AudioDirector.snapshot()
    _check(str(exploration.get("music_cue", "")) == "exploration_ashlands", "Ashlands exploration cue must be selected")
    _check(str(exploration.get("music_source", "")) == "prototype_generated", "Exploration must have real local prototype audio")
    var loop_variant: Variant = exploration.get("loop_sfx_cues", [])
    var loops: Array = loop_variant if loop_variant is Array else []
    _check(loops.has("wind_ashlands"), "Ashlands wind must run as a persistent ambience loop")

    var combat_payload: Dictionary = AudioDirector.request_music("combat_normal", {"reason": "smoke_crossfade"})
    _check(bool(combat_payload.get("has_runtime_audio", false)), "Combat music cue must resolve to audible local audio")
    _check(str(combat_payload.get("audio_source", "")) == "prototype_generated", "Combat fallback must identify its prototype source")
    _check(AudioDirector.is_music_transitioning(), "Switching exploration to combat must start a crossfade")

    AudioDirector.enter_combat_context("smoke_boss", "boss")
    var boss: Dictionary = AudioDirector.snapshot()
    _check(str(boss.get("music_cue", "")) == "combat_boss", "Boss must select combat_boss")
    _check(str(boss.get("music_source", "")) == "prototype_generated", "Boss must have audible local prototype music")
    AudioDirector.notify_boss_phase(2)
    var last_sfx: Dictionary = SfxRuntime.last_playback()
    _check(str(last_sfx.get("cue_id", "")) == "boss_phase_change", "Boss phase must play its phase-change SFX")

    var fear_payload: Dictionary = AudioDirector.request_sfx("fear_heartbeat", {"reason": "smoke_fear"})
    _check(bool(fear_payload.get("has_runtime_audio", false)), "Fear heartbeat must be audible")
    _check(str(fear_payload.get("audio_source", "")) == "prototype_generated", "Fear heartbeat must identify prototype source")

    AudioDirector.reset_runtime()
    await get_tree().process_frame
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("AUDIO_RUNTIME_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("AUDIO_RUNTIME_SMOKE: " + failure)
    print("AUDIO_RUNTIME_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
