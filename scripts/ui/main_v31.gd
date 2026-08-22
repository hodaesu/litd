extends "res://scripts/ui/main_v30.gd"

# v31 : le rang devient une contrainte tactique réelle des compétences.
# Rang 1 = avant ; rang 4 = arrière. Une compétence inutilisable depuis le rang
# courant reste visible mais son bouton est désactivé et indique les rangs requis.

const COMBAT_POSITION_RULES := preload("res://scripts/core/combat_position_rules.gd")

func show_hero_skills() -> void:
    super.show_hero_skills()
    var hero := _selected_skill_hero()
    if hero.is_empty():
        return
    var hint := make_label("R1 = AVANT · R4 = ARRIÈRE · les rangs autorisés sont visibles au survol", 12, MUTED)
    hint.position = Vector2(760, 48)
    hint.size = Vector2(475, 26)
    content.add_child(hint)
    _decorate_loadout_tooltips(hero, false)

func show_combat() -> void:
    super.show_combat()
    var hero := _active_combat_hero()
    if hero.is_empty() or GameState.current_screen != "combat":
        return

    var position_hint := make_label(
        "RANG %d · R1 AVANT ← → R4 ARRIÈRE" % (int(hero.get("combat_position", 0)) + 1),
        13,
        GOLD
    )
    position_hint.position = Vector2(760, 14)
    position_hint.size = Vector2(460, 28)
    content.add_child(position_hint)
    _decorate_loadout_tooltips(hero, true)

func _decorate_loadout_tooltips(hero: Dictionary, enforce_usability: bool) -> void:
    var loadout := HeroSkillManager.combat_loadout(hero)
    var all_buttons := content.find_children("*", "Button", true, false)
    for slot in range(mini(HeroSkillManager.COMBAT_LOADOUT_SIZE, loadout.size())):
        var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
        if skill.is_empty():
            continue
        var allowed: Array[int] = COMBAT_POSITION_RULES.allowed_positions(hero, skill)
        var short_label := COMBAT_POSITION_RULES.short_position_label(allowed)
        var prefix := "%d · " % (slot + 1)
        for node_value in all_buttons:
            var button := node_value as Button
            if button == null or not button.text.begins_with(prefix):
                continue
            button.tooltip_text = "%s\nRangs autorisés : %s" % [
                str(skill.get("description", "")),
                COMBAT_POSITION_RULES.position_label(allowed)
            ]
            if enforce_usability:
                button.text = "%d · %s\n%s" % [slot + 1, str(skill.get("name", "Technique")), short_label]
                button.disabled = not COMBAT_POSITION_RULES.is_usable(hero, skill)
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
    if not COMBAT_POSITION_RULES.is_usable(hero, skill):
        var allowed: Array[int] = COMBAT_POSITION_RULES.allowed_positions(hero, skill)
        GameState.add_log(
            "%s ne peut pas utiliser %s depuis le rang %d. Rangs autorisés : %s." % [
                str(hero.get("name", "Héros")),
                str(skill.get("name", "Technique")),
                int(hero.get("combat_position", 0)) + 1,
                COMBAT_POSITION_RULES.position_label(allowed)
            ]
        )
        show_screen("combat")
        return
    super._use_combat_skill(slot)
