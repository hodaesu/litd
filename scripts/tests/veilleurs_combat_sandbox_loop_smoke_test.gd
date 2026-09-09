extends Node

func _ready() -> void:
    var runtime := VeilleursCombatSandboxRuntime.new()
    var setup := runtime.setup()
    assert(bool(setup.get("ok", false)))
    assert(runtime.heroes.size() == 4)
    assert(str(runtime.heroes[0].get("name")) == "Mathilde")
    assert(str(runtime.heroes[1].get("name")) == "Marec")
    assert(str(runtime.heroes[2].get("name")) == "Anouk")
    assert(str(runtime.heroes[3].get("name")) == "Aurélien")
    assert(runtime.enemies.size() == 2)

    # Mathilde targets a leg: action -> anatomical lesion -> inspectable consequence.
    var first := runtime.perform_action("duelist_precise_strike", 0, "right_leg")
    assert(bool(first.get("ok", false)))
    assert(str(first.get("kind")) == "attack")
    if bool(first.get("hit", false)):
        var inspection := runtime.inspect_actor("enemy", 0)
        assert(bool(inspection.get("ok", false)))
        var zones: Array = inspection.get("anatomy", [])
        assert(bool(zones[5].get("known")))
        assert(str(zones[5].get("state")) == "injured")
        assert(int(inspection.get("inspection_cost_ap")) == 0)

    # Repeating the same target zone gives the AI a readable hypothesis.
    var second := runtime.perform_action("duelist_precise_strike", 0, "right_leg")
    assert(bool(second.get("ok", false)))
    var reaction: Dictionary = second.get("ai_reaction", {})
    assert(bool(reaction.get("observed", false)))
    assert(str(reaction.get("decision", "")) in ["guard_zone", "none", "exploit_wounded_actor"])

    # Turn rotation preserves 2 AP baseline and reaches all four current heroes.
    runtime.end_active_turn()
    assert(str(runtime.active_hero().get("name")) == "Marec")
    assert(int(runtime.active_hero().get("ap")) == 2)

    var marec := runtime.perform_action("breaker_guard_break", 1, "torso")
    assert(bool(marec.get("ok", false)))
    runtime.end_active_turn()
    assert(str(runtime.active_hero().get("name")) == "Anouk")

    var anouk := runtime.perform_action("mystic_read_pattern", 1, "torso")
    assert(bool(anouk.get("ok", false)))
    runtime.end_active_turn()
    assert(str(runtime.active_hero().get("name")) == "Aurélien")

    var aurelien := runtime.perform_action("surgeon_targeted_cut", 1, "left_arm")
    assert(bool(aurelien.get("ok", false)))
    runtime.end_active_turn()
    assert(runtime.round == 2)
    assert(str(runtime.active_hero().get("name")) == "Mathilde")

    print("VEILLEURS_COMBAT_SANDBOX_LOOP_SMOKE_OK")
    get_tree().quit(0)
