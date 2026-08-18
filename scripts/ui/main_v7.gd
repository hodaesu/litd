extends "res://scripts/ui/main_v6.gd"

# Combat v7 : ciblage anatomique volontaire + trauma indépendant par partie.
# Les spécialisations des héros modifient précision et trauma selon les tags du membre.

func show_combat() -> void:
    _ensure_anatomy_state()
    super.show_combat()
    _decorate_anatomy_targeting()

func _ensure_anatomy_state() -> void:
    for enemy_value in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("max_hp", enemy.get("hp", 0))) > 0:
            AnatomyRuntime.ensure_state(enemy)

func _decorate_anatomy_targeting() -> void:
    if GameState.battle_enemies.is_empty():
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var enemy: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(enemy.get("hp", 0)) <= 0:
        return
    AnatomyRuntime.ensure_state(enemy)
    var part := AnatomyRuntime.selected_part(enemy)
    if part.is_empty():
        return
    var hero := _active_round_hero()
    var chance := AnatomyRuntime.part_hit_chance(hero, part) if not hero.is_empty() else 0
    var trauma_map: Dictionary = enemy.get("anatomy_part_trauma", {})
    var part_id := str(part.get("id", ""))
    var threshold := AnatomyRuntime.part_threshold(enemy, part)
    var trauma := int(trauma_map.get(part_id, 0))

    var previous := make_button("◀ PARTIE", func(): _cycle_anatomy_part(-1), Vector2(105, 42))
    previous.position = Vector2(760, 205)
    content.add_child(previous)
    var next := make_button("PARTIE ▶", func(): _cycle_anatomy_part(1), Vector2(105, 42))
    next.position = Vector2(1125, 205)
    content.add_child(next)

    var label := make_label(
        "CIBLE ANATOMIQUE · %s · Trauma %d/%d · précision %d %%" % [
            str(part.get("name", part_id)), trauma, threshold, chance
        ],
        12, GOLD
    )
    label.position = Vector2(870, 205)
    label.size = Vector2(250, 42)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(label)

func _cycle_anatomy_part(direction: int) -> void:
    if GameState.battle_enemies.is_empty():
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var enemy: Dictionary = GameState.battle_enemies[selected_enemy]
    var selected := AnatomyRuntime.cycle_part(enemy, direction)
    if selected != "":
        var part := AnatomyRuntime.part_definition(enemy, selected)
        GameState.add_log("Cible anatomique : %s." % str(part.get("name", selected)))
    show_screen("combat")

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    var target := _selected_target_for(hero, action)
    if target.is_empty():
        return
    AnatomyRuntime.ensure_state(target)
    var selected_part := str(target.get("selected_anatomy_part", ""))
    var hp_before := int(target.get("hp", 0))
    super._hero_attack_action(hero, action)
    var inflicted := maxi(0, hp_before - int(target.get("hp", 0)))
    if inflicted <= 0:
        return
    var result := AnatomyRuntime.register_targeted_hit(hero, target, action, inflicted, selected_part)
    _report_anatomy_result(target, result)

func _technique_damage(hero: Dictionary, target: Dictionary, power: float) -> int:
    AnatomyRuntime.ensure_state(target)
    var selected_part := str(target.get("selected_anatomy_part", ""))
    var damage := super._technique_damage(hero, target, power)
    if damage <= 0:
        return damage
    var technique_id := str(_technique_for(hero).get("id", ""))
    var result := AnatomyRuntime.register_targeted_hit(hero, target, "technique", damage, selected_part, technique_id)
    _report_anatomy_result(target, result)
    return damage

func _report_anatomy_result(target: Dictionary, result: Dictionary) -> void:
    if result.is_empty():
        return
    var part_name := str(result.get("part_name", "partie"))
    var trauma := int(result.get("trauma", 0))
    var threshold := int(result.get("threshold", 0))
    if not bool(result.get("precision_success", true)):
        GameState.add_log("Ciblage anatomique imparfait : %s n'est touché qu'en périphérie (%d/%d Trauma)." % [part_name, trauma, threshold])
    elif not bool(result.get("severed", false)):
        GameState.add_log("Trauma ciblé — %s : %d/%d." % [part_name, trauma, threshold])
    if bool(result.get("severed", false)):
        dismemberment_target_context = target
        _report_dismemberment(result)
        dismemberment_target_context = {}
