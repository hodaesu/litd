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
    _check(psychology.has("resolve_charges"), "Hope must expose a non-stacking resolve charge state")
    _check(PsychologyRuntime.fear_band_label(hero) != "", "Fear must resolve to a visible band")

    var legacy_hope := int(hero.get("hope", 0))
    hero["fear"] = 50
    var meal := PsychologyRuntime.apply_named_event("sanctuary_shared_meal", {"screen": "smoke"}, [hero])
    _check(bool(meal.get("applied", false)), "Shared meal psychology event must apply")
    _check(int(hero.get("fear", 0)) == 45, "Shared meal must reduce fear by 5")
    _check(int(hero.get("hope", 0)) == legacy_hope, "Hope must not increase as a numeric resource")
    _check(not PsychologyRuntime.state_for(hero).get("hope_history", []).is_empty(), "Hope manifestation must be recorded")
    _check(int(PsychologyRuntime.state_for(hero).get("resolve_charges", 0)) == 1, "Hope manifestation must prepare one resolve charge")

    hero["fear"] = 60
    var afraid_modifiers := PsychologyRuntime.combat_modifiers(hero)
    _check(int(afraid_modifiers.get("precision", 0)) == -5, "Afraid band must penalize precision")
    _check(int(afraid_modifiers.get("damage_percent", 0)) == -5, "Afraid band must penalize damage")
    _check(int(afraid_modifiers.get("healing_power", 0)) == -5, "Afraid band must penalize healing")

    hero["fear"] = 100
    var resolved := PsychologyRuntime.resolve_panic_action(hero, 1)
    _check(str(resolved.get("kind", "")) == "resolve", "Prepared Hope must convert Panic into resolve")
    _check(not bool(resolved.get("consume_action", true)), "Hope resolve must preserve the hero action")
    _check(int(hero.get("fear", 0)) == 70, "Hope resolve must pull fear down to 70")
    _check(int(PsychologyRuntime.state_for(hero).get("resolve_charges", 0)) == 0, "Hope resolve charge must be consumed")

    var state := PsychologyRuntime.state_for(hero)
    var traumas: Array = state.get("traumas", [])
    if not traumas.has("panic_memory"):
        traumas.append("panic_memory")
    state["traumas"] = traumas
    hero["psychology"] = state
    hero["fear"] = 100
    var panic := PsychologyRuntime.resolve_panic_action(hero, 2)
    _check(str(panic.get("kind", "")) == "retreat", "Panic Memory must favor retreat during a crisis")
    _check(bool(panic.get("consume_action", false)), "Unresolved Panic must consume the action")
    _check(int(hero.get("fear", 0)) == 85, "Unresolved Panic must fall back to the crisis threshold")

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

    _test_social_targeting_and_pressure()
    _test_companion_intervention()
    _finish()

func _test_social_targeting_and_pressure() -> void:
    if GameState.party.size() < 2:
        return
    var calm: Dictionary = GameState.party[0]
    var terrified: Dictionary = GameState.party[1]
    calm["hp"] = int(calm.get("max_hp", 1))
    calm["fear"] = 10
    terrified["hp"] = int(terrified.get("max_hp", 1))
    terrified["fear"] = 88
    PsychologyRuntime.ensure_hero(calm)
    PsychologyRuntime.ensure_hero(terrified)

    var predator := {"name": "Prédateur test", "fear": 8, "damage": [1, 2]}
    var chosen := PsychologyCombatDirector.select_enemy_target(predator, [calm, terrified], 3)
    _check(str(chosen.get("id", "")) == str(terrified.get("id", "")), "Fear-aware enemies must prioritize the terrified hero")

    var before := int(terrified.get("fear", 0))
    var pressure := PsychologyCombatDirector.apply_enemy_pressure(predator, terrified, 3)
    _check(not pressure.is_empty(), "A fear predator must apply extra psychological pressure to a terrified target")
    _check(int(terrified.get("fear", 0)) > before, "Psychological pressure must increase Fear")
    _check(str(pressure.get("line", "")) != "", "Psychological pressure must expose a contextual combat line")

    terrified["fear"] = 80
    var witness := {
        "name": "Témoin des Cendres",
        "fear": 8,
        "boss": true,
        "chapter_boss_id": "c01_boss_ash_witness",
        "damage": [1, 2]
    }
    var boss_pressure := PsychologyCombatDirector.apply_enemy_pressure(witness, terrified, 4)
    _check(int(boss_pressure.get("extra_fear", 0)) >= 5, "The Ash Witness must apply stronger boss pressure")
    _check(str(boss_pressure.get("line", "")).contains("Témoin"), "The Ash Witness must use its contextual psychology line")

func _test_companion_intervention() -> void:
    if GameState.party.is_empty():
        return
    PsychologyCombatDirector.reset_runtime()
    var target: Dictionary = GameState.party[0]
    target["hp"] = maxi(1, int(target.get("max_hp", 1)))
    target["fear"] = 80
    CreatureManager.captured_creatures = [{
        "instance_id": "smoke-oni",
        "species_id": "oni",
        "name": "Oni test",
        "level": 1,
        "xp": 0,
        "skill_points": 0,
        "unlocked_skills": [],
        "specialization": ""
    }]
    CreatureManager.active_instance_id = "smoke-oni"
    var before := int(target.get("fear", 0))
    var intervention := PsychologyCombatDirector.companion_intervention(5)
    _check(not intervention.is_empty(), "A protective companion must react to a terrified hero")
    _check(int(target.get("fear", 0)) < before, "Companion intervention must reduce Fear")
    _check(bool(target.get("guarding", false)), "Protective Oni intervention must guard the terrified hero")
    var repeated := PsychologyCombatDirector.companion_intervention(5)
    _check(repeated.is_empty(), "A companion must intervene at most once in the same round")

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
