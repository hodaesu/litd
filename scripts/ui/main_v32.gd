extends "res://scripts/ui/main_v31.gd"

# v32 : les ennemis occupent eux aussi quatre rangs E1–E4.
# Les attaques ont une portée de cible, la ligne avant protège les rangs profonds,
# et certaines techniques repoussent ou attirent leur cible après avoir touché.

const COMBAT_TARGETING_RULES := preload("res://scripts/core/combat_targeting_rules.gd")

func show_combat() -> void:
    _ensure_enemy_tactical_positions()
    _sort_enemies_by_rank_preserve_target()
    super.show_combat()
    if GameState.current_screen != "combat":
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        return
    _render_enemy_rank_markers()
    _render_targeting_hint(hero)
    _decorate_targeting_tooltips(hero)

func _ensure_enemy_tactical_positions() -> void:
    COMBAT_TARGETING_RULES.ensure_enemy_positions(GameState.battle_enemies)

func _sort_enemies_by_rank_preserve_target() -> void:
    if GameState.battle_enemies.is_empty():
        selected_enemy = 0
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var selected_uid := str((GameState.battle_enemies[selected_enemy] as Dictionary).get("combat_uid", ""))
    GameState.battle_enemies.sort_custom(func(left_value: Variant, right_value: Variant):
        var left: Dictionary = left_value
        var right: Dictionary = right_value
        return int(left.get("combat_position", 0)) < int(right.get("combat_position", 0))
    )
    if selected_uid != "":
        for index in range(GameState.battle_enemies.size()):
            var enemy: Dictionary = GameState.battle_enemies[index]
            if str(enemy.get("combat_uid", "")) == selected_uid:
                selected_enemy = index
                return
    selected_enemy = _first_living_enemy_index()

func _first_living_enemy_index() -> int:
    for index in range(GameState.battle_enemies.size()):
        if int((GameState.battle_enemies[index] as Dictionary).get("hp", 0)) > 0:
            return index
    return 0

func _render_enemy_rank_markers() -> void:
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        var rank := int(enemy.get("combat_position", 0)) + 1
        var marker := make_label("E%d" % rank, 13, GOLD if index == selected_enemy else MUTED)
        marker.position = Vector2(654 + float(index) * 140.0, 150)
        marker.size = Vector2(58, 24)
        content.add_child(marker)

func _render_targeting_hint(hero: Dictionary) -> void:
    if GameState.battle_enemies.is_empty():
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    var target_rank := int(target.get("combat_position", 0)) + 1
    var hint := make_label(
        "CIBLE : %s · E%d · la ligne E1/E2 protège E3/E4 contre la mêlée" % [str(target.get("name", "Ennemi")), target_rank],
        12,
        GOLD
    )
    hint.position = Vector2(642, 478)
    hint.size = Vector2(600, 28)
    content.add_child(hint)

func _decorate_targeting_tooltips(hero: Dictionary) -> void:
    var loadout := HeroSkillManager.combat_loadout(hero)
    var all_buttons := content.find_children("*", "Button", true, false)
    for slot in range(mini(HeroSkillManager.COMBAT_LOADOUT_SIZE, loadout.size())):
        var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
        if skill.is_empty() or str(skill.get("effect", "")) != "attack":
            continue
        var prefix := "%d · " % (slot + 1)
        var range_label := COMBAT_TARGETING_RULES.target_range_label(hero, skill)
        var movement := COMBAT_TARGETING_RULES.movement_label(hero, skill)
        var targetable := COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
        for node_value in all_buttons:
            var button := node_value as Button
            if button == null or not button.text.begins_with(prefix):
                continue
            button.tooltip_text += "\nPortée ennemie : %s%s" % [range_label, " · %s" % movement if movement != "" else ""]
            if not COMBAT_TARGETING_RULES.ignores_frontline(hero, skill):
                button.tooltip_text += "\nE1/E2 font écran devant E3/E4."
            button.disabled = button.disabled or targetable.is_empty()
            break

func _use_combat_skill(slot: int) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        finish_defeat()
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if slot < 0 or slot >= loadout.size():
        return
    var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
    if skill.is_empty():
        return
    if str(skill.get("effect", "")) == "attack":
        var target := _selected_living_enemy()
        if target.is_empty():
            var targetable := COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
            if targetable.is_empty():
                GameState.add_log("Aucune cible n'est à portée de %s." % str(skill.get("name", "Technique")))
                show_screen("combat")
                return
            selected_enemy = int(targetable[0])
            target = GameState.battle_enemies[selected_enemy]
        if not COMBAT_TARGETING_RULES.can_target(hero, skill, target, GameState.battle_enemies):
            GameState.add_log(
                "%s ne peut pas atteindre %s en E%d avec %s. Portée : %s." % [
                    str(hero.get("name", "Héros")),
                    str(target.get("name", "Ennemi")),
                    int(target.get("combat_position", 0)) + 1,
                    str(skill.get("name", "Technique")),
                    COMBAT_TARGETING_RULES.target_range_label(hero, skill)
                ]
            )
            show_screen("combat")
            return
    super._use_combat_skill(slot)

func _selected_living_enemy() -> Dictionary:
    if GameState.battle_enemies.is_empty():
        return {}
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp", 0)) <= 0:
        return {}
    return target

func _resolve_skill_attack(hero: Dictionary, skill: Dictionary) -> void:
    var target := _selected_living_enemy()
    var target_uid := str(target.get("combat_uid", "")) if not target.is_empty() else ""
    super._resolve_skill_attack(hero, skill)
    if target_uid == "":
        return
    var resolved_target := _enemy_by_combat_uid(target_uid)
    if resolved_target.is_empty() or int(resolved_target.get("hp", 0)) <= 0:
        return
    var delta := COMBAT_TARGETING_RULES.forced_movement_delta(hero, skill)
    if delta == 0:
        return
    var move_result := COMBAT_TARGETING_RULES.move_enemy(GameState.battle_enemies, resolved_target, delta)
    if not bool(move_result.get("moved", false)):
        return
    var verb := "repousse" if delta > 0 else "attire"
    GameState.add_log(
        "%s %s %s de E%d vers E%d." % [
            str(skill.get("name", "La technique")),
            verb,
            str(resolved_target.get("name", "la cible")),
            int(move_result.get("from", 0)) + 1,
            int(move_result.get("to", 0)) + 1
        ]
    )

func _enemy_by_combat_uid(uid: String) -> Dictionary:
    for enemy_value in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if str(enemy.get("combat_uid", "")) == uid:
            return enemy
    return {}
