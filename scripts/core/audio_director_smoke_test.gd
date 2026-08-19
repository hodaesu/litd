extends Node

var failures: Array[String] = []

func run() -> void:
    _check(not AudioDirector.data.is_empty(), "AudioDirector must load audio_director.json")
    _check(AudioDirector.required_buses().size() == 8, "AudioDirector must expose eight production buses")
    for bus_name: String in AudioDirector.required_buses():
        _check(AudioServer.get_bus_index(bus_name) >= 0, "Missing runtime audio bus: " + bus_name)

    AudioDirector.reset_runtime()
    AudioDirector.set_exploration_zone("c03_abandoned_relay")
    var exploration: Dictionary = AudioDirector.snapshot()
    _check(str(exploration.get("mode", "")) == "exploration", "Exploration context must be active")
    _check(str(exploration.get("music_cue", "")) == "exploration_ruins", "Relay/ruins must select exploration_ruins")
    _check((exploration.get("active_sfx_cues", []) as Array).has("wind_ashlands"), "Ashlands exploration must retain wind ambience")

    AudioDirector.enter_combat_context("smoke_normal", "normal")
    var combat: Dictionary = AudioDirector.snapshot()
    _check(str(combat.get("mode", "")) == "combat", "Normal encounter must switch to combat mode")
    _check(str(combat.get("music_cue", "")) == "combat_normal", "Normal encounter must request combat_normal")
    var combat_mix: Dictionary = combat.get("bus_levels_db", {})
    _check(float(combat_mix.get("Combat", -80.0)) >= -1.0, "Combat bus must be foregrounded in combat")
    _check(float(combat_mix.get("Ambience", 0.0)) <= -8.0, "Ambience must yield during combat")

    AudioDirector.enter_combat_context("c01_boss_ash_witness", "boss")
    var boss: Dictionary = AudioDirector.snapshot()
    _check(str(boss.get("mode", "")) == "boss", "Boss encounter must switch to boss mode")
    _check(str(boss.get("music_cue", "")) == "combat_boss", "Boss encounter must request combat_boss")
    _check(int(boss.get("boss_phase", 0)) == 1, "Boss context must begin in phase one")
    _check((boss.get("active_sfx_cues", []) as Array).has("boss_presence"), "Boss presence cue must be active")

    AudioDirector.notify_boss_phase(2)
    var phase_two: Dictionary = AudioDirector.snapshot()
    _check(int(phase_two.get("boss_phase", 0)) == 2, "Boss phase transition must be tracked")
    _check((phase_two.get("active_sfx_cues", []) as Array).has("boss_phase_change"), "Boss phase transition cue must be retained")

    var hero: Dictionary = _first_living_hero()
    _check(not hero.is_empty(), "Smoke test needs a living hero")
    var original_fear: int = int(hero.get("fear", 0)) if not hero.is_empty() else 0
    if not hero.is_empty():
        hero["fear"] = 82
        AudioDirector.refresh_from_game_state()
        var terrified: Dictionary = AudioDirector.snapshot()
        _check(str(terrified.get("fear_profile", "")) == "terrified", "Fear 82 must select terrified profile")
        _check((terrified.get("active_sfx_cues", []) as Array).has("fear_heartbeat"), "Terrified profile must expose heartbeat")
        var terrified_mix: Dictionary = terrified.get("bus_levels_db", {})
        _check(float(terrified_mix.get("Psychology", -80.0)) > -10.0, "Psychology bus must become audible when terrified")
        _check(float(terrified_mix.get("Music", 0.0)) <= -5.0, "Fear must duck boss music rather than overpower gameplay")

        hero["fear"] = 100
        AudioDirector.refresh_from_game_state()
        var panic: Dictionary = AudioDirector.snapshot()
        _check(str(panic.get("fear_profile", "")) == "panic", "Fear 100 must select panic profile")
        _check((panic.get("active_sfx_cues", []) as Array).has("panic_sting"), "Panic profile must expose panic sting")
        hero["fear"] = original_fear

    AudioDirector.finish_combat_context(false)
    var defeat: Dictionary = AudioDirector.snapshot()
    _check(str(defeat.get("mode", "")) == "exploration", "Combat finish must leave combat mode")
    _check(str(defeat.get("music_cue", "")) == "defeat_retreat", "Defeat must request defeat_retreat")
    _check(int(defeat.get("history_size", 0)) >= 5, "AudioDirector must retain bounded event history")

    AudioDirector.reset_runtime()
    _finish()

func _first_living_hero() -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value if hero_value is Dictionary else {}
        if not hero.is_empty() and int(hero.get("hp", 1)) > 0:
            return hero
    return {}

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("AUDIO_DIRECTOR_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("AUDIO_DIRECTOR_SMOKE: " + failure)
    print("AUDIO_DIRECTOR_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
