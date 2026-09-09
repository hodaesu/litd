extends "res://scripts/ui/main_v43.gd"

# v44 — lisibilité tactique du playtest mobile/web.
# - R1 est affiché côté ennemis : l'ordre visuel des héros est R4, R3, R2, R1.
# - L'ordre d'activation reste R1 -> R4 pour ne pas modifier l'initiative existante.
# - Le panneau latéral hérité « ÉTAT DE COMBAT » est supprimé du combat joueur.
# - Une attaque à choix réel de cible ouvre un sélecteur explicite et surligne
#   toutes les cibles valides. Une cible unique est choisie automatiquement.
# - Les futures attaques de zone imposées peuvent déclarer
#   target_selection="automatic" (ou fixed_group) afin de ne jamais demander
#   une sélection cible par cible.

var pending_target_skill_slot: int = -1
var pending_target_indices: Array[int] = []

func show_combat() -> void:
    super.show_combat()
    if GameState.current_screen != "combat" or not is_instance_valid(content):
        return
    _remove_legacy_combat_state_panel()
    _decorate_hero_rank_direction()
    if pending_target_skill_slot >= 0:
        _refresh_pending_target_indices()
        _highlight_pending_enemy_targets()
        _render_pending_target_picker()

# L'ancienne méthode sert aussi à déterminer l'ordre d'affichage dans le HUD.
# On la renverse pour que, de gauche à droite à l'écran, on voie R4 R3 R2 R1 :
# R1 se retrouve donc bien le plus près des ennemis.
func _heroes_by_position() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for hero_value: Variant in GameState.party:
        result.append(hero_value as Dictionary)
    result.sort_custom(func(left: Dictionary, right: Dictionary):
        return int(left.get("combat_position", 0)) > int(right.get("combat_position", 0))
    )
    return result

# Le renversement d'affichage ne doit pas renverser l'ordre d'activation.
func _select_next_combat_hero() -> void:
    combat_active_hero_id = ""
    var initiative_order: Array[Dictionary] = []
    for hero_value: Variant in GameState.party:
        initiative_order.append(hero_value as Dictionary)
    initiative_order.sort_custom(func(left: Dictionary, right: Dictionary):
        return int(left.get("combat_position", 0)) < int(right.get("combat_position", 0))
    )
    for hero: Dictionary in initiative_order:
        var hero_id := str(hero.get("id", ""))
        if int(hero.get("hp", 0)) > 0 and not combat_acted_hero_ids.has(hero_id):
            combat_active_hero_id = hero_id
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

    # On ne remplace pas le resolver : on ne fait qu'insérer une étape de choix
    # avant le comportement existant lorsqu'il existe réellement plusieurs cibles.
    if str(skill.get("effect", "")) == "attack" and not _skill_has_automatic_group_targeting(skill):
        if not COMBAT_POSITION_RULES.is_usable(hero, skill):
            super._use_combat_skill(slot)
            return
        var targetable: Array[int] = COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
        if targetable.size() == 1:
            pending_target_skill_slot = -1
            pending_target_indices.clear()
            selected_enemy = int(targetable[0])
            super._use_combat_skill(slot)
            return
        if targetable.size() > 1:
            pending_target_skill_slot = slot
            pending_target_indices = targetable.duplicate()
            combat_item_menu = false
            combat_position_menu = false
            show_screen("combat")
            return

    pending_target_skill_slot = -1
    pending_target_indices.clear()
    super._use_combat_skill(slot)

func _skill_has_automatic_group_targeting(skill: Dictionary) -> bool:
    var mode := str(skill.get("target_selection", "")).to_lower()
    return mode in ["automatic", "auto", "fixed", "fixed_group", "automatic_group", "fixed_aoe"]

func _refresh_pending_target_indices() -> void:
    pending_target_indices.clear()
    var hero := _active_combat_hero()
    if hero.is_empty():
        pending_target_skill_slot = -1
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if pending_target_skill_slot < 0 or pending_target_skill_slot >= loadout.size():
        pending_target_skill_slot = -1
        return
    var skill := HeroSkillManager.combat_skill(hero, str(loadout[pending_target_skill_slot]))
    if skill.is_empty() or str(skill.get("effect", "")) != "attack":
        pending_target_skill_slot = -1
        return
    pending_target_indices = COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
    if pending_target_indices.is_empty():
        pending_target_skill_slot = -1

func _render_pending_target_picker() -> void:
    if pending_target_skill_slot < 0 or pending_target_indices.is_empty():
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if pending_target_skill_slot >= loadout.size():
        return
    var skill := HeroSkillManager.combat_skill(hero, str(loadout[pending_target_skill_slot]))

    var panel := PanelContainer.new()
    panel.name = "ExplicitTargetPickerV44"
    panel.position = Vector2(620, 400)
    panel.size = Vector2(620, 108)
    panel.z_index = 80
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.012, 0.014, 0.020, 0.97)))
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    panel.add_child(box)
    var title := make_label("CHOISIR UNE CIBLE · %s" % str(skill.get("name", "Technique")), 13, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    box.add_child(row)
    for enemy_index: int in pending_target_indices:
        if enemy_index < 0 or enemy_index >= GameState.battle_enemies.size():
            continue
        var enemy: Dictionary = GameState.battle_enemies[enemy_index]
        var rank := int(enemy.get("combat_position", 0)) + 1
        var target_button := make_button(
            "%s\nE%d" % [str(enemy.get("name", "Ennemi")), rank],
            func(index = enemy_index): _confirm_pending_enemy_target(int(index)),
            Vector2(132, 54)
        )
        target_button.tooltip_text = "Cible valide · toucher pour confirmer"
        _apply_target_button_highlight(target_button, true)
        row.add_child(target_button)
    row.add_child(make_button("ANNULER", func(): _cancel_pending_target(), Vector2(118, 54)))

func _confirm_pending_enemy_target(enemy_index: int) -> void:
    if pending_target_skill_slot < 0 or not pending_target_indices.has(enemy_index):
        return
    var slot := pending_target_skill_slot
    selected_enemy = enemy_index
    pending_target_skill_slot = -1
    pending_target_indices.clear()
    super._use_combat_skill(slot)

func _cancel_pending_target() -> void:
    pending_target_skill_slot = -1
    pending_target_indices.clear()
    show_screen("combat")

func _highlight_pending_enemy_targets() -> void:
    # Les cartes ennemies de main_v30 sont des Button plats placés dans la rangée
    # de droite. On les repère par leur contenu texte afin de garder la couche v44
    # compatible avec les versions précédentes.
    for node_value: Variant in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null:
            continue
        var text_blob := _button_descendant_text(button)
        var matching_index := -1
        for index in range(GameState.battle_enemies.size()):
            var enemy: Dictionary = GameState.battle_enemies[index]
            if text_blob.contains(str(enemy.get("name", ""))):
                matching_index = index
                break
        if matching_index < 0:
            continue
        var is_targetable := pending_target_indices.has(matching_index)
        button.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_targetable else Color(0.48, 0.48, 0.48, 0.68)
        if is_targetable:
            _apply_target_button_highlight(button, true)

func _apply_target_button_highlight(button: Button, strong: bool) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.30, 0.22, 0.08, 0.20 if strong else 0.10)
    style.border_color = Color(1.0, 0.82, 0.34, 0.98 if strong else 0.72)
    style.set_border_width_all(3 if strong else 2)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_stylebox_override("hover", style)
    button.add_theme_stylebox_override("focus", style)

func _button_descendant_text(button: Button) -> String:
    var chunks: Array[String] = [button.text]
    for node_value: Variant in button.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label != null:
            chunks.append(label.text)
    return "\n".join(chunks)

func _remove_legacy_combat_state_panel() -> void:
    for node_value: Variant in content.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label == null:
            continue
        var normalized := label.text.to_upper().replace("É", "E").replace("È", "E").replace("Ê", "E")
        if not normalized.contains("ETAT DE COMBAT"):
            continue
        var victim: Node = label
        var cursor: Node = label.get_parent()
        while cursor != null and cursor != content:
            victim = cursor
            if cursor is PanelContainer:
                break
            cursor = cursor.get_parent()
        if victim != null and victim != content:
            victim.queue_free()
        break

func _decorate_hero_rank_direction() -> void:
    var existing := content.get_node_or_null("HeroRankDirectionV44")
    if existing != null:
        return
    var hint := make_label("HÉROS : R4  ←  R3  ←  R2  ←  R1  ·  R1 = AU CONTACT", 11, MUTED)
    hint.name = "HeroRankDirectionV44"
    hint.position = Vector2(34, 138)
    hint.size = Vector2(560, 22)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(hint)
