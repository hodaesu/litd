extends Node

const VS001 := preload("res://scripts/core/veilleurs_vs001_runtime.gd")
const SESSION := preload("res://scripts/core/veilleurs_vs001_session_runtime.gd")

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

    _run_session_smoke()

    if failures.is_empty():
        print("VEILLEURS_VS001_SMOKE_OK careful=%.3f force=%.3f" % [careful_percent, force_percent])
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_VS001_SMOKE: " + failure)
    print("VEILLEURS_VS001_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)

func _run_session_smoke() -> void:
    var session := SESSION.new()
    var started: Dictionary = session.start()
    _check(bool(started.get("active", false)), "VS001 session must start active")
    _check(session.current_room() == "s1_vestibule", "VS001 session must start in S1")
    _check(session.available_neighbors() == ["s2_rope_gallery"], "S1 must only expose S2")
    _check(not session.can_enter_room("s8_lower_archive"), "S8 must be inaccessible at start")

    _check(bool(session.enter_room("s2_rope_gallery").get("success", false)), "S1 to S2 must be traversable")
    _check(bool(session.set_tripwire_state("detected").get("success", false)), "S2 tripwire must be detectable")
    _check(bool(session.set_tripwire_state("disarmed").get("success", false)), "S2 tripwire must be disarmable")

    _check(bool(session.enter_room("s3_sleepers").get("success", false)), "S2 to S3 must be traversable")
    _check(bool(session.resolve_combat(5, true).get("success", false)), "S3 combat pressure must resolve")
    _check(bool(session.enter_room("s5_fractured_crypt").get("success", false)), "S3 to S5 must be traversable")
    _check(bool(session.enter_room("s6_survivor").get("success", false)), "S5 to optional S6 must be traversable")

    var recruitment_actions: Array[String] = [
        "observe",
        "nayra_lower_guard",
        "aisha_diagnose",
        "aisha_treat",
        "idris_deescalate",
        "offer_food",
        "subdue"
    ]
    for action_id: String in recruitment_actions:
        _check(bool(session.recruitment_action(action_id).get("success", false)), "S6 action must resolve: %s" % action_id)
    var recruited: Dictionary = session.resolve_recruitment("nayra", 0)
    _check(bool(recruited.get("success", false)), "Careful S6 sequence with neutral roll must recruit")
    _check(str(recruited.get("outcome", "")) == "recruited", "S6 outcome must persist as recruited")

    _check(bool(session.enter_room("s5_fractured_crypt").get("success", false)), "S6 retreat to S5 must remain possible")
    _check(bool(session.enter_room("s7_voice_chamber").get("success", false)), "S5 to S7 must be traversable")
    var s7_loot: Dictionary = session.acquire_room_loot("s7")
    _check(bool(s7_loot.get("success", false)), "S7 authored loot must be acquirable")
    _check(int(s7_loot.get("or_delta", 0)) == 38, "S7 must award 38 or in the authored seed")

    var studied: Dictionary = session.resolve_device("study", true)
    _check(bool(studied.get("success", false)), "Studying S7 successfully must complete the local objective")
    _check(bool(studied.get("state", {}).get("objective_complete", false)), "S7 study must mark the objective complete")
    _check(session.can_enter_room("s8_lower_archive"), "Successful S7 study must unlock S8")
    _check(bool(session.enter_room("s8_lower_archive").get("success", false)), "Unlocked S8 must be traversable")

    var saved: Dictionary = session.serialize()
    _check(bool(saved.get("s8_discovered", false)), "S8 discovery must serialize")
    _check(str(saved.get("s6_outcome", "")) == "recruited", "S6 recruitment must serialize")
    var restored := SESSION.new()
    _check(restored.deserialize(saved), "VS001 session state must deserialize")
    _check(restored.current_room() == "s8_lower_archive", "Restored session must keep current room")
    _check(str(restored.snapshot().get("scars", {}).get("voices.s7.device", "")) == "studied", "S7 device scar must persist")

    var extraction: Dictionary = restored.extract("objective_complete")
    _check(bool(extraction.get("success", false)), "Restored VS001 session must extract")
    _check(bool(extraction.get("objective_complete", false)), "Extraction must preserve completed objective")
    _check(str(extraction.get("s6_outcome", "")) == "recruited", "Extraction must report S6 recruited outcome")
    _check(bool(extraction.get("s8_discovered", false)), "Extraction must report S8 discovery")
