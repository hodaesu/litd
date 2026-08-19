extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    await _frames(2)
    _check(not GameState.party.is_empty(), "Psychology smoke requires a party")
    if GameState.party.is_empty():
        _finish()
        return

    var hero: Dictionary = GameState.party[0]
    var psychology := PsychologyRuntime.ensure_hero(hero)
    _check(psychology.has("madness_exposure"), "Legacy madness must migrate to hidden exposure")
    _check(psychology.has("hope_history"), "Hope must be represented by event history")
    _check(PsychologyRuntime.fear_band_label(hero) != "", "Fear must resolve to a visible band")

    var legacy_hope := int(hero.get("hope", 0))
    hero["fear"] = 50
    var meal := PsychologyRuntime.apply_named_event("sanctuary_shared_meal", {"screen": "smoke"}, [hero])
    _check(bool(meal.get("applied", false)), "Shared meal psychology event must apply")
    _check(int(hero.get("fear", 0)) == 45, "Shared meal must reduce fear by 5")
    _check(int(hero.get("hope", 0)) == legacy_hope, "Hope must not increase as a numeric resource")
    _check(not PsychologyRuntime.state_for(hero).get("hope_history", []).is_empty(), "Hope manifestation must be recorded")

    hero["fear"] = 99
    hero["fear"] = 100
    PsychologyRuntime.record_external_fear(hero, 99, "terrifying_enemy", {"screen": "combat"})
    _check(int(PsychologyRuntime.state_for(hero).get("panic_count", 0)) >= 1, "Reaching 100 fear must record panic")

    hero["fear"] = 0
    var wrong_zone := PsychologyRuntime.apply_named_event(
        "ashlands_village_internal_barricades",
        {"zone_id": "zone_01_faubourg_cendreux"},
        [hero]
    )
    _check(not bool(wrong_zone.get("applied", false)), "Zone-filtered events must ignore other zones")
    var correct_zone := PsychologyRuntime.apply_named_event(
        "ashlands_village_internal_barricades",
        {"zone_id": "zone_02_village_ravage"},
        [hero]
    )
    _check(bool(correct_zone.get("applied", false)), "Zone-filtered events must apply in their canonical zone")
    _check(int(hero.get("fear", 0)) == 6, "Village barricades must add six fear")

    _finish()

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("PSYCHOLOGY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PSYCHOLOGY_SMOKE: " + failure)
    print("PSYCHOLOGY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
