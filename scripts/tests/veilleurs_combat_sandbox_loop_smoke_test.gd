extends Node

func _fail(message: String) -> void:
    push_error(message)
    get_tree().quit(1)

func _check(condition: bool, message: String) -> bool:
    if not condition:
        _fail(message)
        return false
    return true

func _ready() -> void:
    var runtime := VeilleursCombatSandboxRuntime.new()
    var setup := runtime.setup()
    if not _check(bool(setup.get("ok", false)), "sandbox setup failed"): return
    if not _check(runtime.heroes.size() == 4, "quartet size invalid"): return
    if not _check(str(runtime.heroes[0].get("name")) == "Mathilde", "Mathilde missing"): return
    if not _check(str(runtime.heroes[1].get("name")) == "Marec", "Marec missing"): return
    if not _check(str(runtime.heroes[2].get("name")) == "Anouk", "Anouk missing"): return
    if not _check(str(runtime.heroes[3].get("name")) == "Aurélien", "Aurélien missing"): return
    if not _check(runtime.enemies.size() == 2, "encounter size invalid"): return

    var first := runtime.perform_action("MATH-LAM-01", 0, "right_leg")
    if not _check(bool(first.get("ok", false)), "Mathilde Trait net failed: %s" % str(first)): return
    if not _check(str(first.get("kind")) == "attack", "Mathilde action is not attack"): return
    if bool(first.get("hit", false)):
        var inspection := runtime.inspect_actor("enemy", 0)
        if not _check(bool(inspection.get("ok", false)), "enemy inspection failed"): return
        var zones: Array = inspection.get("anatomy", [])
        if not _check(bool(zones[5].get("known")), "right leg should be known after hit"): return
        if not _check(str(zones[5].get("state")) == "injured", "right leg should be injured after hit"): return
        if not _check(int(inspection.get("inspection_cost_ap")) == 0, "inspection must cost 0 AP"): return

    var parry := runtime.perform_action("MATH-LAM-10", 0)
    if not _check(bool(parry.get("ok", false)), "Mathilde parry preparation failed: %s" % str(parry)): return
    runtime.end_active_turn()
    if not _check(str(runtime.active_hero().get("name")) == "Marec", "turn did not reach Marec"): return

    var marec := runtime.perform_action("MARC-FOR-01", 1, "torso")
    if not _check(bool(marec.get("ok", false)), "Marec attack failed: %s" % str(marec)): return
    runtime.end_active_turn()
    if not _check(str(runtime.active_hero().get("name")) == "Anouk", "turn did not reach Anouk"): return

    var anouk := runtime.perform_action("ANOU-TRA-13", 1, "torso")
    if not _check(bool(anouk.get("ok", false)), "Anouk control failed: %s" % str(anouk)): return
    runtime.end_active_turn()
    if not _check(str(runtime.active_hero().get("name")) == "Aurélien", "turn did not reach Aurélien"): return

    var aurelien := runtime.perform_action("AURE-COO-01", 1, "torso")
    if not _check(bool(aurelien.get("ok", false)), "Aurélien coordination failed: %s" % str(aurelien)): return
    runtime.end_active_turn()
    if not _check(runtime.round == 2, "round should advance to 2"): return
    if not _check(str(runtime.active_hero().get("name")) == "Mathilde", "round should return to Mathilde"): return

    print("VEILLEURS_COMBAT_SANDBOX_LOOP_SMOKE_OK")
    get_tree().quit(0)
