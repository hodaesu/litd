extends Node

var failures: Array[String] = []

func run() -> void:
    LayeredMusicRuntime.reset_runtime()
    await get_tree().process_frame

    _check(not LayeredMusicRuntime.data.is_empty(), "Layered music data must load")
    _check(LayeredMusicRuntime.supports_cue("combat_normal"), "Combat normal must support vertical orchestration")
    _check(LayeredMusicRuntime.supports_cue("combat_boss"), "Boss music must support vertical orchestration")
    _check(LayeredMusicRuntime.layer_player_count() == 10, "Two synchronized banks of five stems are required")

    LayeredMusicRuntime.sync_cue("combat_normal", 0.55)
    await get_tree().process_frame
    var first: Dictionary = LayeredMusicRuntime.snapshot()
    _check(str(first.get("cue", "")) == "combat_normal", "Layered runtime must start combat_normal")
    _check((first.get("active_layers", []) as Array) == ["pulse", "percussion"], "Controlled normal combat must use pulse + percussion")
    _check(int(first.get("running_layers", 0)) == 5, "All stems must run even when some are muted")
    _check(float(first.get("phase_spread_seconds", 1.0)) <= 0.08, "Stem playback positions must remain synchronized")
    var generation: int = int(first.get("cue_generation", -1))

    LayeredMusicRuntime.set_intensity(0.64)
    await get_tree().process_frame
    var medium: Dictionary = LayeredMusicRuntime.snapshot()
    _check(int(medium.get("cue_generation", -2)) == generation, "Changing intensity must not restart the piece")
    _check((medium.get("active_layers", []) as Array) == ["pulse", "percussion", "strings"], "Strings must enter without changing cue")

    LayeredMusicRuntime.set_intensity(0.56)
    await get_tree().process_frame
    var hysteresis: Dictionary = LayeredMusicRuntime.snapshot()
    _check((hysteresis.get("active_layers", []) as Array).has("strings"), "Strings must remain through the exit hysteresis band")
    LayeredMusicRuntime.set_intensity(0.49)
    await get_tree().process_frame
    _check(not (LayeredMusicRuntime.snapshot().get("active_layers", []) as Array).has("strings"), "Strings must leave below their exit threshold")

    LayeredMusicRuntime.set_intensity(0.95)
    await get_tree().process_frame
    var crisis: Dictionary = LayeredMusicRuntime.snapshot()
    _check((crisis.get("active_layers", []) as Array) == ["pulse", "percussion", "strings", "choir", "crisis"], "Crisis must expose all five orchestration layers")
    _check(int(crisis.get("cue_generation", -2)) == generation, "Full crisis orchestration must still be the same piece")

    NarrativeAudioDirector.begin_dialogue("layered_music_smoke")
    await get_tree().process_frame
    _check(bool(LayeredMusicRuntime.snapshot().get("narrative_override", false)), "Dialogue must take priority over stems")
    NarrativeAudioDirector.end_dialogue("layered_music_smoke")
    await get_tree().process_frame

    var before_boss_generation: int = int(LayeredMusicRuntime.snapshot().get("cue_generation", 0))
    LayeredMusicRuntime.sync_cue("combat_boss", 0.84)
    await get_tree().process_frame
    var boss: Dictionary = LayeredMusicRuntime.snapshot()
    _check(str(boss.get("cue", "")) == "combat_boss", "Boss must switch to its own layered cue")
    _check(int(boss.get("cue_generation", 0)) == before_boss_generation + 1, "Changing piece must increment cue generation exactly once")
    _check((boss.get("active_layers", []) as Array) == ["pulse", "percussion", "strings", "choir"], "Boss phase one must already carry four layers")

    LayeredMusicRuntime.sync_cue("sanctuary_day", 0.2)
    await get_tree().process_frame
    _check(str(LayeredMusicRuntime.snapshot().get("cue", "x")) == "", "Authored non-layered cues must leave stem runtime")

    LayeredMusicRuntime.reset_runtime()
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("LAYERED_MUSIC_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("LAYERED_MUSIC_SMOKE: " + failure)
    print("LAYERED_MUSIC_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
