extends "res://scripts/ui/main_v9.gd"

# Combat v10 : capture influencée par l'état anatomique de la cible.

func _hero_capture_action(hero: Dictionary) -> void:
    var living_targets := GameState.alive_enemies()
    if living_targets.is_empty():
        finish_victory()
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var capture_target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(capture_target.get("hp", 0)) <= 0:
        capture_target = living_targets[0]

    AnatomyRuntime.ensure_state(capture_target)
    var snapshot := capture_target.duplicate(true)
    var original_hp := int(capture_target.get("hp", 0))
    var max_hp := maxi(1, int(capture_target.get("max_hp", original_hp)))
    var bonus := CaptureWoundRuntime.capture_bonus(capture_target)
    if bonus > 0:
        var hp_ratio := float(original_hp) / float(max_hp)
        var adjusted_ratio := maxf(0.0, hp_ratio - float(bonus) / 70.0)
        capture_target["hp"] = maxi(1, int(round(float(max_hp) * adjusted_ratio)))
        GameState.add_log("Lien facilité par les blessures : bonus anatomique jusqu'à +%d %% de capture." % bonus)

    var capture_result := CreatureManager.attempt_capture(capture_target)
    var success := bool(capture_result.get("success", false))
    if not success:
        capture_target["hp"] = original_hp
    GameState.add_log(str(capture_result.get("message", "Le sceau échoue.")))

    if success:
        var creature := CaptureWoundRuntime.apply_to_latest_capture(snapshot)
        if not creature.is_empty():
            GameState.add_log("ÉTAT À LA CAPTURE — confiance %d · %s." % [
                int(creature.get("bond", 50)), CaptureWoundRuntime.care_status(creature)
            ])
        if GameState.alive_enemies().is_empty():
            finish_victory()
            return

    if bool(capture_result.get("consumed", false)):
        _complete_hero_action(hero)
    else:
        battle_locked = false
        show_screen("combat")

func _finish_party_round() -> void:
    var restore_id := ""
    var creature := CreatureManager.active_creature()
    if not creature.is_empty() and not CaptureWoundRuntime.can_fight(creature):
        restore_id = CreatureManager.active_instance_id
        CreatureManager.active_instance_id = ""
        GameState.add_log("%s reste en convalescence et ne peut pas combattre (%s)." % [
            str(creature.get("name", "Le compagnon")), CaptureWoundRuntime.care_status(creature)
        ])
    super._finish_party_round()
    if restore_id != "":
        CreatureManager.active_instance_id = restore_id
