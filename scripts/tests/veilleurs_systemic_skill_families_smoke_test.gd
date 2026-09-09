extends Node

func _ready() -> void:
    var runtime := VeilleursCombatSandboxRuntime.new()
    assert(bool(runtime.setup().get("ok", false)))

    # Mathilde: protective reaction is a real combat state.
    var protect := runtime.perform_action("MATH-GAR-01", 1, "torso")
    assert(bool(protect.get("ok", false)))
    assert(str(runtime.heroes[1].get("protected_by")) == "mathilde")
    assert(str(runtime.heroes[0].get("reaction")) == "protect")
    runtime.end_active_turn()

    # Marec: posture changes incoming resolution and costly force damages his function.
    var guard := runtime.perform_action("MARC-GAR-01", 1, "torso")
    assert(bool(guard.get("ok", false)))
    assert(str(runtime.heroes[1].get("posture")) == "guard")
    runtime.end_active_turn()

    # Anouk: Trame control accumulates bodily overload and exposes symptoms.
    var control := runtime.perform_action("ANOU-TRA-13", 0, "torso")
    assert(bool(control.get("ok", false)))
    assert(str(runtime.enemies[0].get("control_state")) == "deviated")
    assert(int(runtime.heroes[2].get("trame_overload")) == 2)
    assert(str(runtime.heroes[2].get("trame_symptom")) == "fine_tremor")
    runtime.end_active_turn()

    # Aurélien: coordination is an explicit, temporary tactical effect.
    var coordinate := runtime.perform_action("AURE-COO-01", 0, "torso")
    assert(bool(coordinate.get("ok", false)))
    assert(int(runtime.heroes[0].get("coordination_bonus")) == 10)
    runtime.end_active_turn()

    # New round: Mathilde can prepare a parry as a 0-AP reaction.
    var parry := runtime.perform_action("MATH-LAM-10", 0, "torso")
    assert(bool(parry.get("ok", false)))
    assert(str(runtime.heroes[0].get("reaction")) == "parry")
    runtime.end_active_turn()

    # Marec enters costly-force posture then hits: right-arm function pays the cost.
    var force_posture := runtime.perform_action("MARC-FOR-28", 1, "torso")
    assert(bool(force_posture.get("ok", false)))
    var hit := runtime.perform_action("MARC-FOR-01", 1, "torso")
    assert(bool(hit.get("ok", false)))
    if bool(hit.get("hit", false)):
        var marec_arm: Dictionary = (runtime.heroes[1].get("anatomy", {}) as Dictionary).get("right_arm", {})
        assert(str(marec_arm.get("function")) == "impaired")
        assert(str(runtime.heroes[1].get("pain_state")) in ["strong", "severe"])
    runtime.end_active_turn()

    # Anouk can recover overload by giving up AP rather than spending abstract mana.
    var before := int(runtime.heroes[2].get("trame_overload"))
    var recover := runtime.perform_action("ANOU-RET-01", 2, "torso")
    assert(bool(recover.get("ok", false)))
    assert(int(runtime.heroes[2].get("trame_overload")) < before)
    runtime.end_active_turn()

    # Aurélien splints a real impaired anatomical zone rather than adding generic HP.
    var mathilde_anatomy: Dictionary = runtime.heroes[0].get("anatomy", {})
    var leg: Dictionary = mathilde_anatomy.get("right_leg", {})
    leg["state"] = "injured"
    leg["function"] = "impaired"
    leg["injuries"] = [{"severity":2,"impact":"blunt","source":"test"}]
    mathilde_anatomy["right_leg"] = leg
    runtime.heroes[0]["anatomy"] = mathilde_anatomy
    var splint := runtime.perform_action("AURE-CHI-13", 0, "right_leg")
    assert(bool(splint.get("ok", false)))
    var treated: Dictionary = (runtime.heroes[0].get("anatomy", {}) as Dictionary).get("right_leg", {})
    assert(str(treated.get("function")) == "stabilized")
    assert(str(treated.get("treatment")) == "splint")

    print("VEILLEURS_SYSTEMIC_SKILL_FAMILIES_SMOKE_OK")
    get_tree().quit(0)
