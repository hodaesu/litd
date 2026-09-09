extends "res://scripts/ui/main_v45.gd"

# v46 — contrat de ciblage unifié.
# Règle : le joueur choisit uniquement lorsqu'une action lui laisse réellement
# un choix. Les cibles déterministes restent automatiques. Les zones imposées
# prévisualisent toutes leurs cibles ensemble puis s'exécutent sans clic cible.

var pending_choice_kind: String = ""
var pending_choice_skill_slot: int = -1
var pending_choice_item_id: String = ""
var pending_ally_ids: Array[String] = []
var forced_support_target_id: String = ""
var forced_item_target_id: String = ""
var pending_auto_group_skill_slot: int = -1
var pending_auto_group_indices: Array[int] = []

func show_combat() -> void:
    super.show_combat()
    if GameState.current_screen != "combat" or not is_instance_valid(content):
        return
    if pending_choice_kind != "":
        _remove_inspection_hotspots_v46()
        _render_ally_target_picker_v46()
    elif pending_auto_group_skill_slot >= 0:
        _remove_inspection_hotspots_v46()
        _highlight_automatic_group_v46()
        _render_automatic_group_notice_v46()

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

    var effect := str(skill.get("effect", "attack"))
    if effect in ["heal", "support"] and _requires_player_ally_choice_v46(skill):
        var ally_ids := _living_ally_ids_v46()
        if ally_ids.size() == 1:
            forced_support_target_id = ally_ids[0]
            super._use_combat_skill(slot)
            return
        if ally_ids.size() > 1:
            pending_choice_kind = "skill"
            pending_choice_skill_slot = slot
            pending_choice_item_id = ""
            pending_ally_ids = ally_ids
            combat_item_menu = false
            combat_position_menu = false
            show_screen("combat")
            return

    if effect == "attack" and _is_automatic_multi_target_v46(skill):
        var targets := _automatic_group_indices_v46(hero, skill)
        if targets.size() > 1:
            pending_auto_group_skill_slot = slot
            pending_auto_group_indices = targets
            battle_locked = true
            show_screen("combat")
            call_deferred("_execute_automatic_group_v46")
            return

    super._use_combat_skill(slot)

func _requires_player_ally_choice_v46(payload: Dictionary) -> bool:
    var selection := str(payload.get("target_selection", "")).to_lower()
    if selection in ["manual", "choice", "player", "select", "player_choice"]:
        return true
    var policy := str(payload.get("target_policy", "")).to_lower()
    if policy in ["manual", "choice", "player_choice"]:
        return true
    var target := str(payload.get("target", "")).to_lower()
    return target in ["ally_choice", "chosen_ally", "one_ally_choice", "ally_manual"]

func _living_ally_ids_v46() -> Array[String]:
    var result: Array[String] = []
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) > 0:
            result.append(str(hero.get("id", "")))
    return result

func _render_ally_target_picker_v46() -> void:
    if pending_choice_kind == "" or pending_ally_ids.is_empty():
        return
    var panel := PanelContainer.new()
    panel.name = "AllyTargetPickerV46"
    panel.position = Vector2(250, 390)
    panel.size = Vector2(760, 118)
    panel.z_index = 140
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.012, 0.014, 0.020, 0.98)))
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    panel.add_child(box)
    var title := make_label("CHOISIR UN ALLIÉ", 14, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    box.add_child(row)
    for hero_id: String in pending_ally_ids:
        var hero := _hero_by_id_v46(hero_id)
        if hero.is_empty():
            continue
        var hp := int(hero.get("hp", 0))
        var max_hp := maxi(1, int(hero.get("max_hp", 1)))
        var button := make_button(
            "%s\n%d/%d PV" % [str(hero.get("name", "Allié")), hp, max_hp],
            func(target_id = hero_id): _confirm_ally_target_v46(str(target_id)),
            Vector2(142, 58)
        )
        _apply_target_button_highlight(button, true)
        row.add_child(button)
    row.add_child(make_button("ANNULER", func(): _cancel_ally_target_v46(), Vector2(118, 58)))

func _confirm_ally_target_v46(hero_id: String) -> void:
    if not pending_ally_ids.has(hero_id):
        return
    var kind := pending_choice_kind
    var slot := pending_choice_skill_slot
    var item_id := pending_choice_item_id
    _clear_pending_ally_choice_v46()
    if kind == "skill":
        forced_support_target_id = hero_id
        super._use_combat_skill(slot)
    elif kind == "item":
        forced_item_target_id = hero_id
        _use_combat_item(item_id)

func _cancel_ally_target_v46() -> void:
    _clear_pending_ally_choice_v46()
    show_screen("combat")

func _clear_pending_ally_choice_v46() -> void:
    pending_choice_kind = ""
    pending_choice_skill_slot = -1
    pending_choice_item_id = ""
    pending_ally_ids.clear()

func _hero_by_id_v46(hero_id: String) -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _resolve_skill_support(hero: Dictionary, skill: Dictionary) -> void:
    if forced_support_target_id == "":
        super._resolve_skill_support(hero, skill)
        return
    var target := _hero_by_id_v46(forced_support_target_id)
    forced_support_target_id = ""
    if target.is_empty() or int(target.get("hp", 0)) <= 0:
        super._resolve_skill_support(hero, skill)
        return
    var heal := int(skill.get("heal", 0))
    if heal > 0:
        heal = int(round(float(heal) * (1.0 + float(hero_bonuses(hero).get("healing_power", 0)) / 100.0)))
        target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + heal)
    target["hope"] = mini(100 + int(hero_bonuses(target).get("max_hope", 0)), int(target.get("hope", 0)) + int(skill.get("hope_gain", 0)))
    target["fear"] = maxi(0, int(target.get("fear", 0)) - int(skill.get("fear_reduction", 0)))
    GameState.add_log("%s utilise %s sur %s." % [hero.name, str(skill.get("name", "Soutien")), target.name])

func _use_combat_item(resource_id: String) -> void:
    if forced_item_target_id != "":
        _execute_forced_ally_item_v46(resource_id)
        return
    if battle_locked or int(ExpeditionManager.inventory.get(resource_id, 0)) <= 0:
        return
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var item: Dictionary = item_rules.get(resource_id, {})
    if item.is_empty():
        return
    if _requires_player_ally_choice_v46(item):
        var ally_ids := _living_ally_ids_v46()
        if ally_ids.size() == 1:
            forced_item_target_id = ally_ids[0]
            _execute_forced_ally_item_v46(resource_id)
            return
        if ally_ids.size() > 1:
            pending_choice_kind = "item"
            pending_choice_skill_slot = -1
            pending_choice_item_id = resource_id
            pending_ally_ids = ally_ids
            combat_item_menu = false
            combat_position_menu = false
            show_screen("combat")
            return
    # Les objets déterministes restent gérés par le resolver existant : soin du
    # plus blessé, grenade sur tous les ennemis, etc.
    super._use_combat_item(resource_id)

func _execute_forced_ally_item_v46(resource_id: String) -> void:
    var target_id := forced_item_target_id
    forced_item_target_id = ""
    if battle_locked or int(ExpeditionManager.inventory.get(resource_id, 0)) <= 0:
        return
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var item: Dictionary = item_rules.get(resource_id, {})
    var target := _hero_by_id_v46(target_id)
    var hero := _active_combat_hero()
    if item.is_empty() or target.is_empty() or hero.is_empty():
        return
    battle_locked = true
    ExpeditionManager.consume_bundle({resource_id: 1})
    var amount := int(item.get("heal", 0))
    if amount > 0:
        target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + amount)
    target["hope"] = mini(100 + int(hero_bonuses(target).get("max_hope", 0)), int(target.get("hope", 0)) + int(item.get("hope_gain", 0)))
    target["fear"] = maxi(0, int(target.get("fear", 0)) - int(item.get("fear_reduction", 0)))
    GameState.add_log("%s utilise %s sur %s%s." % [hero.name, str(item.get("label", "Objet")), target.name, " : +%d PV" % amount if amount > 0 else ""])
    combat_item_menu = false
    _complete_active_hero_turn()

func _is_automatic_multi_target_v46(skill: Dictionary) -> bool:
    var mode := str(skill.get("target_selection", "")).to_lower()
    if mode in ["fixed_group", "automatic_group", "fixed_aoe", "automatic_aoe"]:
        return true
    if mode not in ["automatic", "auto", "fixed"]:
        return false
    if int(skill.get("target_count", 1)) > 1:
        return true
    var scope := str(skill.get("target_scope", skill.get("target_group", ""))).to_lower()
    return scope in ["all", "front", "middle", "rear", "adjacent", "group", "aoe"]

func _automatic_group_indices_v46(hero: Dictionary, skill: Dictionary) -> Array[int]:
    var candidates: Array[int] = COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
    var result: Array[int] = []
    var scope := str(skill.get("target_scope", skill.get("target_group", "all"))).to_lower()
    for enemy_index: int in candidates:
        if enemy_index < 0 or enemy_index >= GameState.battle_enemies.size():
            continue
        var enemy: Dictionary = GameState.battle_enemies[enemy_index]
        if int(enemy.get("hp", 0)) <= 0:
            continue
        var pos := int(enemy.get("combat_position", 0))
        var include := true
        if scope == "front":
            include = pos <= 1
        elif scope == "middle":
            include = pos in [1, 2]
        elif scope == "rear":
            include = pos >= 2
        elif scope == "adjacent":
            var anchor_pos := 0
            if selected_enemy >= 0 and selected_enemy < GameState.battle_enemies.size():
                anchor_pos = int((GameState.battle_enemies[selected_enemy] as Dictionary).get("combat_position", 0))
            include = absi(pos - anchor_pos) <= 1
        if include:
            result.append(enemy_index)
    var target_count := int(skill.get("target_count", 0))
    if target_count > 0 and result.size() > target_count:
        result.resize(target_count)
    return result

func _execute_automatic_group_v46() -> void:
    await get_tree().create_timer(0.32).timeout
    if pending_auto_group_skill_slot < 0:
        battle_locked = false
        return
    var slot := pending_auto_group_skill_slot
    pending_auto_group_skill_slot = -1
    pending_auto_group_indices.clear()
    battle_locked = false
    super._use_combat_skill(slot)

func _resolve_skill_attack(hero: Dictionary, skill: Dictionary) -> void:
    if not _is_automatic_multi_target_v46(skill):
        super._resolve_skill_attack(hero, skill)
        return
    var indices := _automatic_group_indices_v46(hero, skill)
    if indices.is_empty():
        super._resolve_skill_attack(hero, skill)
        return
    var previous_selected := selected_enemy
    for enemy_index: int in indices:
        if enemy_index < 0 or enemy_index >= GameState.battle_enemies.size():
            continue
        if int((GameState.battle_enemies[enemy_index] as Dictionary).get("hp", 0)) <= 0:
            continue
        selected_enemy = enemy_index
        super._resolve_skill_attack(hero, skill)
    selected_enemy = clampi(previous_selected, 0, maxi(0, GameState.battle_enemies.size() - 1))

func _highlight_automatic_group_v46() -> void:
    for node_value: Variant in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null:
            continue
        var text_blob := _button_descendant_text(button)
        var matching_index := -1
        for index in range(GameState.battle_enemies.size()):
            var enemy: Dictionary = GameState.battle_enemies[index]
            var enemy_name := str(enemy.get("name", ""))
            if enemy_name != "" and text_blob.contains(enemy_name):
                matching_index = index
                break
        if matching_index < 0:
            continue
        var affected := pending_auto_group_indices.has(matching_index)
        button.modulate = Color(1.0, 1.0, 1.0, 1.0) if affected else Color(0.45, 0.45, 0.45, 0.62)
        if affected:
            _apply_target_button_highlight(button, true)

func _render_automatic_group_notice_v46() -> void:
    var notice := make_label("CIBLES DE ZONE", 14, GOLD)
    notice.name = "AutomaticGroupNoticeV46"
    notice.position = Vector2(770, 125)
    notice.size = Vector2(310, 28)
    notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice.z_index = 145
    content.add_child(notice)

func _remove_inspection_hotspots_v46() -> void:
    for node_value: Variant in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null:
            continue
        var node_name := str(button.name)
        if node_name.begins_with("InspectHeroV45_") or node_name.begins_with("InspectEnemyV45_"):
            button.queue_free()
