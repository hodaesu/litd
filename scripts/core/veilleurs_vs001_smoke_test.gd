extends Node

const VS001 := preload("res://scripts/core/veilleurs_vs001_runtime.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    var balance: Dictionary = VS001.load_balance()
    _check(not balance.is_empty(), "VS001 balance data must load")
    _check(str(balance.get("seed", "")) == "WATCHERS_VERTICAL_001", "VS001 seed must remain locked")

    var careful_actions: Array[String] = [
        "observe",
        "nayra_lower_guard",
        "aisha_diagnose",
        "aisha_treat",
        "idris_deescalate",
        "offer_food",
        "subdue"
    ]
    var force_actions: Array[String] = ["subdue"]
    var careful: Dictionary = VS001.capture_preview(careful_actions, "nayra")
    var force: Dictionary = VS001.capture_preview(force_actions, "nayra")
    var careful_percent := float(careful.get("success_percent", 0.0))
    var force_percent := float(force.get("success_percent", 0.0))
    _check(careful_percent >= 70.0 and careful_percent <= 90.0, "Careful S6 recruitment must stay inside the provisional target band")
    _check(force_percent >= 20.0 and force_percent <= 45.0, "Immediate-force S6 recruitment must stay inside the provisional target band")
    _check(careful_percent > force_percent, "Careful S6 recruitment must remain more reliable than immediate force")

    var light := 82
    light = VS001.apply_light(light, "normal_move")
    _check(light == 80, "Normal movement must consume 2 light")
    light = VS001.apply_light(light, "deep_search")
    _check(light == 76, "Deep search must consume 4 light")
    light = VS001.apply_light(light, "", 5)
    _check(light == 71, "Five meaningful combat rounds must consume 5 light")

    var noise := VS001.apply_noise(0, "violent_combat", false)
    _check(noise == 25, "Violent combat must create 25 noise")
    noise = VS001.apply_noise(noise, "normal_move", true)
    _check(noise == 22, "A calm normal move must add movement noise then decay by 5")
    _check(VS001.event_chance(52, 25) == 17, "Stable-light noisy event chance baseline must stay deterministic")

    var standard: Dictionary = VS001.ghoul_profile("hungry_standard")
    var scout: Dictionary = VS001.ghoul_profile("hungry_scout")
    var voracious: Dictionary = VS001.ghoul_profile("voracious_evolved")
    var standard_stats: Dictionary = standard.get("stats", {})
    var scout_stats: Dictionary = scout.get("stats", {})
    var voracious_stats: Dictionary = voracious.get("stats", {})
    _check(int(scout_stats.get("hp", 0)) < int(standard_stats.get("hp", 0)), "Scout ghoul must remain lighter than standard ghoul")
    _check(int(scout_stats.get("initiative", 0)) > int(standard_stats.get("initiative", 0)), "Scout ghoul must remain faster than standard ghoul")
    _check(int(voracious_stats.get("hp", 0)) > int(standard_stats.get("hp", 0)), "Voracious ghoul must remain tougher than standard ghoul")
    _check(float(voracious.get("flee_threshold", 1.0)) < float(standard.get("flee_threshold", 0.0)), "Voracious ghoul must remain harder to rout")

    _check(VS001.base_seed_gold() == 67, "VS001 authored base seed must contain 67 or")

    if failures.is_empty():
        print("VEILLEURS_VS001_SMOKE_OK careful=%.3f force=%.3f" % [careful_percent, force_percent])
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_VS001_SMOKE: " + failure)
    print("VEILLEURS_VS001_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
