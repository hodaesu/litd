extends "res://scripts/ui/main_v42.gd"

# v43 — robustesse finale des contrôles du playtest.
# Corrige le contrat de typage du ciblage explicatif et garantit des cibles
# tactiles >= 96×48 pour les sous-menus créés dynamiquement.

const PLAYTEST_MIN_TOUCH := Vector2(96.0, 48.0)

func _make_combat_skill_buttons_explanatory() -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    var all_buttons := content.find_children("*", "Button", true, false)
    for slot in range(mini(HeroSkillManager.COMBAT_LOADOUT_SIZE, loadout.size())):
        var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
        if skill.is_empty():
            continue
        var prefix := "%d · " % (slot + 1)
        for node_value: Variant in all_buttons:
            var button := node_value as Button
            if button == null or not button.text.begins_with(prefix):
                continue
            # Un bouton de compétence reste touchable : la validation métier
            # explique ensuite pourquoi le rang ou la cible interdit l'action.
            button.disabled = false
            if not COMBAT_POSITION_RULES.is_usable(hero, skill):
                if not button.tooltip_text.contains("Touchez pour voir pourquoi"):
                    button.tooltip_text += "\nTouchez pour voir pourquoi cette technique est impossible depuis le rang actuel."
            elif str(skill.get("effect", "")) == "attack":
                var targetable: Array[int] = COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
                if targetable.is_empty() and not button.tooltip_text.contains("aucune cible"):
                    button.tooltip_text += "\nTouchez pour voir pourquoi aucune cible n'est actuellement atteignable."
            break

func show_guild_chest() -> void:
    super.show_guild_chest()
    var formation := content.get_node_or_null("FormationEntryV42") as Button
    if formation != null:
        _normalize_touch_button(formation)

func _render_combat_position_menu(hero: Dictionary) -> void:
    super._render_combat_position_menu(hero)
    var panel := content.get_node_or_null("CombatPositionMenuV42") as Control
    if panel != null:
        panel.size.y = maxf(panel.size.y, 104.0)
        _normalize_touch_buttons_under(panel)

func _render_combat_item_menu() -> void:
    super._render_combat_item_menu()
    var panel := content.get_node_or_null("CombatItemMenuV42") as Control
    if panel != null:
        panel.size.y = maxf(panel.size.y, 132.0)
        _normalize_touch_buttons_under(panel)

func _normalize_touch_buttons_under(node: Node) -> void:
    for node_value: Variant in node.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null:
            _normalize_touch_button(button)

func _normalize_touch_button(button: Button) -> void:
    button.custom_minimum_size = Vector2(
        maxf(button.custom_minimum_size.x, PLAYTEST_MIN_TOUCH.x),
        maxf(button.custom_minimum_size.y, PLAYTEST_MIN_TOUCH.y)
    )
    button.focus_mode = Control.FOCUS_ALL
