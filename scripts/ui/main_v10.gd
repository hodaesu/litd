extends "res://scripts/ui/main_v9.gd"

# Combat v10 : capture influencée par l'état anatomique de la cible.

func hero_action(action: String) -> void:
    if action != "capture":
        super.hero_action(action)
        return
    if GameState.battle_enemies.is_empty():
        super.hero_action(action)
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var enemy: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(enemy.get("hp", 0)) <= 0:
        super.hero_action(action)
        return

    AnatomyRuntime.ensure_state(enemy)
    var snapshot := enemy.duplicate(true)
    var original_hp := int(enemy.get("hp", 0))
    var max_hp := maxi(1, int(enemy.get("max_hp", original_hp)))
    var bonus := CaptureWoundRuntime.capture_bonus(enemy)
    if bonus > 0:
        var hp_ratio := float(original_hp) / float(max_hp)
        var adjusted_ratio := maxf(0.0, hp_ratio - float(bonus) / 70.0)
        enemy["hp"] = maxi(1, int(round(float(max_hp) * adjusted_ratio)))
        GameState.add_log("Lien facilité par les blessures : bonus anatomique jusqu'à +%d %% de capture." % bonus)

    super.hero_action(action)

    if bool(enemy.get("captured", false)):
        var creature := CaptureWoundRuntime.apply_to_latest_capture(snapshot)
        if not creature.is_empty():
            GameState.add_log("ÉTAT À LA CAPTURE — confiance %d · %s." % [
                int(creature.get("bond", 50)), CaptureWoundRuntime.care_status(creature)
            ])
    else:
        enemy["hp"] = original_hp

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
