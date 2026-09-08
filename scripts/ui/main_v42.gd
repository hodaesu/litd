extends "res://scripts/ui/main_v41.gd"

# v42 — fiabilisation des interactions du playtest.
# Objectif : aucun contrôle essentiel ne doit être inaccessible ou silencieux sur
# mobile/web. La formation est modifiable gratuitement hors combat et le
# repositionnement en combat consomme l'action du héros actif.

const PLAYTEST_COMBAT_INVENTORY_RULES := preload("res://scripts/core/combat_inventory_rules.gd")

var formation_selected_hero_id: String = ""

func show_screen(name: String) -> void:
    if name == "formation":
        GameState.current_screen = name
        clear_content()
        _show_formation_editor()
        _install_header_controls()
        call_deferred("_postprocess_playtest_controls")
        return
    super.show_screen(name)
    call_deferred("_postprocess_playtest_controls")

func _postprocess_mobile_screen() -> void:
    super._postprocess_mobile_screen()
    call_deferred("_postprocess_playtest_controls")

# -----------------------------------------------------------------------------
# INVENTAIRE / ÉQUIPE — accès explicite à la formation.
# -----------------------------------------------------------------------------

func show_guild_chest() -> void:
    super.show_guild_chest()
    var formation := make_button("FORMATION", func(): GameState.request_screen("formation"), Vector2(210, 44))
    formation.name = "FormationEntryV42"
    formation.position = Vector2(800, 10)
    formation.tooltip_text = "Organiser les rangs R1 à R4. Hors combat : gratuit. En combat : le déplacement du héros actif coûte son action."
    content.add_child(formation)

func _show_formation_editor() -> void:
    _ensure_combat_positions()
    _canonical_backdrop(
        "FORMATION DU GROUPE",
        "R1 = avant · R4 = arrière. Touchez un héros puis son rang de destination."
    )

    var in_combat := _combat_is_in_progress()
    var active := _active_combat_hero() if in_combat else {}

    var mode := make_label(
        ("COMBAT · %s agit : changer de rang consommera son action." % str(active.get("name", "Le héros actif")))
        if in_combat
        else "PRÉPARATION · les permutations sont gratuites et sauvegardées immédiatement.",
        15,
        CANON_GOLD if in_combat else CANON_TEXT
    )
    mode.position = Vector2(52, 122)
    mode.size = Vector2(1160, 34)
    content.add_child(mode)

    var row := HBoxContainer.new()
    row.position = Vector2(52, 172)
    row.size = Vector2(1160, 190)
    row.add_theme_constant_override("separation", 12)
    content.add_child(row)

    for rank in range(4):
        var occupant := _hero_at_combat_position(rank)
        var occupant_id := str(occupant.get("id", ""))
        var occupant_name := str(occupant.get("name", "EMPLACEMENT LIBRE"))
        var selected := occupant_id != "" and occupant_id == formation_selected_hero_id
        var current_active := in_combat and occupant_id == str(active.get("id", ""))
        var usable_count := _usable_skill_count_at_rank(occupant, rank) if not occupant.is_empty() else 0
        var loadout_count := HeroSkillManager.combat_loadout(occupant).size() if not occupant.is_empty() else 0
        var text := "%sR%d%s\n%s\n%d/%d compétences utilisables" % [
            "◆ " if selected else "",
            rank + 1,
            " · ACTIF" if current_active else "",
            occupant_name,
            usable_count,
            loadout_count
        ]
        var button := make_button(text, func(target_rank = rank): _formation_rank_pressed(int(target_rank)), Vector2(278, 150))
        button.alignment = HORIZONTAL_ALIGNMENT_CENTER
        button.tooltip_text = "R%d — %s" % [rank + 1, "première ligne" if rank == 0 else ("arrière" if rank == 3 else "ligne intermédiaire")]
        if in_combat and rank == int(active.get("combat_position", -1)):
            button.disabled = true
            button.tooltip_text += " · position actuelle"
        row.add_child(button)

    var instruction_text := ""
    if in_combat:
        instruction_text = "Choisissez directement le nouveau rang de %s. Si le rang est occupé, les deux héros permutent. Le tour de %s se termine après validation." % [
            str(active.get("name", "ce héros")),
            str(active.get("name", "ce héros"))
        ]
    elif formation_selected_hero_id == "":
        instruction_text = "1. Touchez le héros à déplacer.  2. Touchez son rang de destination. Un rang occupé provoque une permutation."
    else:
        var selected_hero := _hero_by_id_for_formation(formation_selected_hero_id)
        instruction_text = "%s sélectionné · choisissez maintenant R1, R2, R3 ou R4." % str(selected_hero.get("name", "Héros"))

    var instruction := make_label(instruction_text, 16, CANON_TEXT)
    instruction.position = Vector2(52, 392)
    instruction.size = Vector2(1160, 70)
    content.add_child(instruction)

    var compatibility := make_label(_formation_compatibility_summary(), 13, CANON_MUTED)
    compatibility.position = Vector2(52, 468)
    compatibility.size = Vector2(1160, 82)
    content.add_child(compatibility)

    var back_target := "combat" if in_combat else "inventory_equipment"
    var back := make_button("RETOUR", func(target = back_target): GameState.request_screen(str(target)), Vector2(220, 50))
    back.position = Vector2(52, 572)
    content.add_child(back)

    if not in_combat and formation_selected_hero_id != "":
        var cancel := make_button("ANNULER LA SÉLECTION", func(): formation_selected_hero_id = ""; show_screen("formation"), Vector2(260, 50))
        cancel.position = Vector2(292, 572)
        content.add_child(cancel)

func _formation_rank_pressed(rank: int) -> void:
    rank = clampi(rank, 0, 3)
    if _combat_is_in_progress():
        _change_combat_position_to(rank)
        return

    var occupant := _hero_at_combat_position(rank)
    if formation_selected_hero_id == "":
        if occupant.is_empty():
            _show_inline_control_feedback("Cet emplacement est libre. Sélectionnez d'abord un héros.")
            return
        formation_selected_hero_id = str(occupant.get("id", ""))
        show_screen("formation")
        return

    var selected := _hero_by_id_for_formation(formation_selected_hero_id)
    if selected.is_empty():
        formation_selected_hero_id = ""
        show_screen("formation")
        return

    var current := int(selected.get("combat_position", 0))
    if current == rank:
        formation_selected_hero_id = ""
        show_screen("formation")
        return

    if not occupant.is_empty() and str(occupant.get("id", "")) != str(selected.get("id", "")):
        occupant["combat_position"] = current
    selected["combat_position"] = rank
    GameState.add_log("Formation : %s passe en R%d." % [str(selected.get("name", "Héros")), rank + 1])
    formation_selected_hero_id = ""
    SaveManager.save_game()
    show_screen("formation")

func _hero_at_combat_position(rank: int) -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("combat_position", -1)) == rank:
            return hero
    return {}

func _hero_by_id_for_formation(hero_id: String) -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _usable_skill_count_at_rank(hero: Dictionary, rank: int) -> int:
    if hero.is_empty():
        return 0
    var count := 0
    for skill_id: String in HeroSkillManager.combat_loadout(hero):
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty():
            continue
        var allowed: Array[int] = COMBAT_POSITION_RULES.allowed_positions(hero, skill)
        if allowed.has(rank):
            count += 1
    return count

func _formation_compatibility_summary() -> String:
    var lines: Array[String] = []
    for hero in _heroes_by_position():
        var rank := int(hero.get("combat_position", 0))
        lines.append("R%d · %s : %d compétence(s) de combat utilisable(s) depuis ce rang" % [
            rank + 1,
            str(hero.get("name", "Héros")),
            _usable_skill_count_at_rank(hero, rank)
        ])
    return "\n".join(lines)

func _combat_is_in_progress() -> bool:
    return combat_active_hero_id != "" and not GameState.battle_enemies.is_empty() and not GameState.alive_enemies().is_empty()

# -----------------------------------------------------------------------------
# COMBAT — les sous-menus sont remontés dans la zone réellement visible du
# viewport web/mobile. POSITION propose R1–R4 directement et consomme l'action.
# -----------------------------------------------------------------------------

func _render_combat_position_menu(hero: Dictionary) -> void:
    var panel := PanelContainer.new()
    panel.name = "CombatPositionMenuV42"
    panel.position = Vector2(500, 418)
    panel.size = Vector2(742, 88)
    panel.z_index = 40
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.97)))
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    panel.add_child(box)
    box.add_child(make_label("POSITION · choisir un rang consomme l'action de %s" % str(hero.get("name", "ce héros")), 12, GOLD))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    box.add_child(row)
    var current := int(hero.get("combat_position", 0))
    for rank in range(4):
        var occupant := _hero_at_combat_position(rank)
        var name := str(occupant.get("name", "Libre"))
        var button := make_button("R%d\n%s" % [rank + 1, name], func(target_rank = rank): _change_combat_position_to(int(target_rank)), Vector2(132, 42))
        button.disabled = rank == current
        button.tooltip_text = "Position actuelle" if rank == current else "Permuter vers R%d · coûte l'action" % (rank + 1)
        row.add_child(button)
    row.add_child(make_button("ANNULER", func(): combat_position_menu = false; show_screen("combat"), Vector2(142, 42)))

func _change_combat_position(delta: int) -> void:
    var hero := _active_combat_hero()
    if hero.is_empty():
        return
    _change_combat_position_to(int(hero.get("combat_position", 0)) + delta)

func _change_combat_position_to(target_position: int) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        return
    var current := int(hero.get("combat_position", 0))
    target_position = clampi(target_position, 0, 3)
    if target_position == current:
        combat_position_menu = false
        if GameState.current_screen != "combat":
            GameState.request_screen("combat")
        else:
            show_screen("combat")
        return

    var other := _hero_at_combat_position(target_position)
    if not other.is_empty() and str(other.get("id", "")) != str(hero.get("id", "")):
        other["combat_position"] = current
    hero["combat_position"] = target_position
    GameState.add_log("%s change de position : R%d → R%d. Son action est consommée." % [
        str(hero.get("name", "Héros")),
        current + 1,
        target_position + 1
    ])
    combat_position_menu = false
    combat_item_menu = false
    formation_selected_hero_id = ""
    battle_locked = true
    _complete_active_hero_turn()

func _render_combat_item_menu() -> void:
    var hero := _active_combat_hero()
    if hero.is_empty():
        return

    var panel := PanelContainer.new()
    panel.name = "CombatItemMenuV42"
    panel.position = Vector2(490, 395)
    panel.size = Vector2(752, 112)
    panel.z_index = 40
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.97)))
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    panel.add_child(box)

    if combat_item_transfer_mode == "give_item":
        _render_give_item_choices(box, hero)
        return
    if combat_item_transfer_mode in ["target_use", "target_give"]:
        _render_item_target_choices(box, hero)
        return

    box.add_child(make_label(
        "OBJETS DE %s · UTILISER = ACTION · DONNER = GRATUIT" % str(hero.get("name", "Héros")),
        11,
        GOLD
    ))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    box.add_child(row)
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    for resource_id in ["bandages", "medicine", "grenades"]:
        var rule: Dictionary = item_rules.get(resource_id, {})
        var label := str(rule.get("label", _item_label(resource_id))).to_upper()
        var quantity := PLAYTEST_COMBAT_INVENTORY_RULES.quantity(hero, resource_id)
        var button := make_button(
            "%s ×%d" % [label, quantity],
            func(item_id = resource_id): _begin_use_carried_item(str(item_id)),
            Vector2(136, 38)
        )
        button.disabled = quantity <= 0
        if quantity <= 0:
            button.tooltip_text = "Aucun exemplaire porté par ce héros."
        row.add_child(button)
    row.add_child(make_button("DONNER", func(): _open_give_item_menu(), Vector2(130, 38)))
    row.add_child(make_button("FERMER", func(): combat_item_menu = false; _clear_pending_item_transfer(); show_screen("combat"), Vector2(120, 38)))

# -----------------------------------------------------------------------------
# CONTRAT D'INTERACTION — les boutons placés directement en bas des anciens
# écrans sont ramenés dans le viewport, et les compétences impossibles restent
# touchables afin d'afficher leur raison d'indisponibilité au lieu d'être muettes.
# -----------------------------------------------------------------------------

func _postprocess_playtest_controls() -> void:
    if not is_instance_valid(content):
        return
    _keep_direct_buttons_inside_viewport()
    if GameState.current_screen == "combat":
        _make_combat_skill_buttons_explanatory()
    elif GameState.current_screen == "title":
        _patch_web_title_controls()

func _keep_direct_buttons_inside_viewport() -> void:
    var bounds := content.size
    if bounds.x < 100.0 or bounds.y < 100.0:
        return
    for child in content.get_children():
        if child is not Button:
            continue
        var button := child as Button
        if not button.visible:
            continue
        var width := maxf(button.size.x, button.custom_minimum_size.x)
        var height := maxf(button.size.y, button.custom_minimum_size.y)
        button.position.x = clampf(button.position.x, 8.0, maxf(8.0, bounds.x - width - 8.0))
        button.position.y = clampf(button.position.y, 8.0, maxf(8.0, bounds.y - height - 8.0))

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
            button.disabled = false
            if not COMBAT_POSITION_RULES.is_usable(hero, skill):
                button.tooltip_text += "\nTouchez pour voir pourquoi cette technique est impossible depuis le rang actuel."
            else:
                var targetable := COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies) if str(skill.get("effect", "")) == "attack" else [0]
                if targetable.is_empty():
                    button.tooltip_text += "\nTouchez pour voir pourquoi aucune cible n'est actuellement atteignable."
            break

func _patch_web_title_controls() -> void:
    var buttons := content.find_children("*", "Button", true, false)
    for node_value: Variant in buttons:
        var button := node_value as Button
        if button == null:
            continue
        if button.text == "QUITTER" and OS.has_feature("web"):
            button.visible = false
        elif button.text == "CONTINUER" and not bool(button.get_meta("litd_continue_feedback_v42", false)):
            button.set_meta("litd_continue_feedback_v42", true)
            button.pressed.connect(func():
                if GameState.current_screen == "title":
                    call_deferred("_show_inline_control_feedback", "Aucune sauvegarde exploitable n'a été trouvée. Choisissez NOUVELLE PARTIE.")
            )

func _show_inline_control_feedback(message: String) -> void:
    if not is_instance_valid(content):
        return
    var existing := content.get_node_or_null("PlaytestControlFeedbackV42")
    if existing != null:
        existing.queue_free()
    var label := make_label(message, 14, Color("#e4c989"))
    label.name = "PlaytestControlFeedbackV42"
    label.position = Vector2(180, 610)
    label.size = Vector2(920, 34)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.z_index = 60
    content.add_child(label)
