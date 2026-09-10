extends "res://scripts/ui/main_v48.gd"

# v49 — ciblage joueur complet pour le playtest.
# - choix manuel multi-cible quand une technique demande N cibles au choix ;
# - diagnostic hostile explicite quand plusieurs ennemis sont possibles ;
# - soin médical clinique explicite quand le joueur doit choisir un allié ;
# - ancre déterministe pour les zones adjacentes quand la compétence la déclare.

var pending_multi_target_skill_slot: int = -1
var pending_multi_target_required: int = 0
var pending_multi_target_candidates: Array[int] = []
var pending_multi_target_selected: Array[int] = []
var forced_manual_group_indices: Array[int] = []
var forcing_manual_group_execution: bool = false
var forced_clinical_ally_target_id: String = ""

func show_combat() -> void:
    super.show_combat()
    if GameState.current_screen != "combat" or not is_instance_valid(content):
        return
    if pending_multi_target_skill_slot >= 0:
        _remove_inspection_hotspots_v46()
        _refresh_multi_target_candidates_v49()
        _highlight_multi_enemy_targets_v49()
        _render_multi_target_picker_v49()

func _use_combat_skill(slot: int) -> void:
    if forcing_manual_group_execution:
        super._use_combat_skill(slot)
        return
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

    var effect := str(skill.get("effect", "attack")).to_lower()
    var manual_hostile := effect in ["attack", "diagnostic"] and _requires_manual_hostile_choice_v49(skill)
    if manual_hostile:
        if effect == "attack" and not COMBAT_POSITION_RULES.is_usable(hero, skill):
            super._use_combat_skill(slot)
            return
        var candidates: Array[int] = COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
        var required := clampi(int(skill.get("target_count", 1)), 1, maxi(1, candidates.size()))
        if candidates.size() == 1 and required == 1:
            selected_enemy = candidates[0]
            super._use_combat_skill(slot)
            return
        if candidates.size() > 1:
            pending_multi_target_skill_slot = slot
            pending_multi_target_required = required
            pending_multi_target_candidates = candidates.duplicate()
            pending_multi_target_selected.clear()
            combat_item_menu = false
            combat_position_menu = false
            show_screen("combat")
            return

    if effect == "medical" and _requires_player_ally_choice_v46(skill):
        var ally_ids := _living_ally_ids_v46()
        if ally_ids.size() == 1:
            forced_clinical_ally_target_id = ally_ids[0]
            super._use_combat_skill(slot)
            return
        if ally_ids.size() > 1:
            pending_choice_kind = "clinical_medical"
            pending_choice_skill_slot = slot
            pending_choice_item_id = ""
            pending_ally_ids = ally_ids
            combat_item_menu = false
            combat_position_menu = false
            show_screen("combat")
            return

    super._use_combat_skill(slot)

func _requires_manual_hostile_choice_v49(skill: Dictionary) -> bool:
    var mode := str(skill.get("target_selection", "")).to_lower()
    if mode in ["manual", "choice", "player", "select", "player_choice"]:
        return true
    var policy := str(skill.get("target_policy", "")).to_lower()
    if policy in ["manual", "choice", "player_choice"]:
        return true
    var target := str(skill.get("target", "")).to_lower()
    if target in ["enemy_choice", "chosen_enemy", "hostile_choice", "enemy_manual"]:
        return true
    return int(skill.get("target_count", 1)) > 1 and not _is_automatic_multi_target_v46(skill)

func _refresh_multi_target_candidates_v49() -> void:
    if pending_multi_target_skill_slot < 0:
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        _clear_multi_target_v49()
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if pending_multi_target_skill_slot >= loadout.size():
        _clear_multi_target_v49()
        return
    var skill := HeroSkillManager.combat_skill(hero, str(loadout[pending_multi_target_skill_slot]))
    if skill.is_empty():
        _clear_multi_target_v49()
        return
    pending_multi_target_candidates = COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
    var still_selected: Array[int] = []
    for index in pending_multi_target_selected:
        if pending_multi_target_candidates.has(index):
            still_selected.append(index)
    pending_multi_target_selected = still_selected
    pending_multi_target_required = clampi(int(skill.get("target_count", 1)), 1, maxi(1, pending_multi_target_candidates.size()))
    if pending_multi_target_candidates.is_empty():
        _clear_multi_target_v49()

func _render_multi_target_picker_v49() -> void:
    if pending_multi_target_skill_slot < 0 or pending_multi_target_candidates.is_empty():
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if pending_multi_target_skill_slot >= loadout.size():
        return
    var skill := HeroSkillManager.combat_skill(hero, str(loadout[pending_multi_target_skill_slot]))

    var panel := PanelContainer.new()
    panel.name = "MultiTargetPickerV49"
    panel.position = Vector2(570, 386)
    panel.size = Vector2(670, 132)
    panel.z_index = 150
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.012, 0.014, 0.020, 0.98)))
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    panel.add_child(box)
    var title := make_label(
        "CHOISIR %d CIBLE(S) · %s · %d/%d" % [pending_multi_target_required, str(skill.get("name", "Technique")), pending_multi_target_selected.size(), pending_multi_target_required],
        13,
        GOLD
    )
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    box.add_child(row)
    for enemy_index in pending_multi_target_candidates:
        if enemy_index < 0 or enemy_index >= GameState.battle_enemies.size():
            continue
        var enemy: Dictionary = GameState.battle_enemies[enemy_index]
        var selected := pending_multi_target_selected.has(enemy_index)
        var button := make_button(
            "%s%s\nE%d" % ["✓ " if selected else "", str(enemy.get("name", "Ennemi")), int(enemy.get("combat_position", 0)) + 1],
            func(index = enemy_index): _toggle_multi_target_v49(int(index)),
            Vector2(128, 54)
        )
        _apply_target_button_highlight(button, selected)
        row.add_child(button)

    var confirm := make_button("CONFIRMER", func(): _confirm_multi_target_v49(), Vector2(126, 54))
    confirm.disabled = pending_multi_target_selected.size() != pending_multi_target_required
    row.add_child(confirm)
    row.add_child(make_button("ANNULER", func(): _cancel_multi_target_v49(), Vector2(110, 54)))

func _toggle_multi_target_v49(enemy_index: int) -> void:
    if not pending_multi_target_candidates.has(enemy_index):
        return
    if pending_multi_target_selected.has(enemy_index):
        pending_multi_target_selected.erase(enemy_index)
    elif pending_multi_target_selected.size() < pending_multi_target_required:
        pending_multi_target_selected.append(enemy_index)
    show_screen("combat")

func _confirm_multi_target_v49() -> void:
    if pending_multi_target_skill_slot < 0 or pending_multi_target_selected.size() != pending_multi_target_required:
        return
    var slot := pending_multi_target_skill_slot
    forced_manual_group_indices = pending_multi_target_selected.duplicate()
    _clear_multi_target_v49()
    forcing_manual_group_execution = true
    super._use_combat_skill(slot)
    forcing_manual_group_execution = false
    forced_manual_group_indices.clear()

func _cancel_multi_target_v49() -> void:
    _clear_multi_target_v49()
    show_screen("combat")

func _clear_multi_target_v49() -> void:
    pending_multi_target_skill_slot = -1
    pending_multi_target_required = 0
    pending_multi_target_candidates.clear()
    pending_multi_target_selected.clear()

func _skill_has_automatic_group_targeting(skill: Dictionary) -> bool:
    if forcing_manual_group_execution and not forced_manual_group_indices.is_empty():
        return true
    return super._skill_has_automatic_group_targeting(skill)

func _resolve_skill_attack(hero: Dictionary, skill: Dictionary) -> void:
    if forcing_manual_group_execution and not forced_manual_group_indices.is_empty():
        var previous_selected := selected_enemy
        var indices := forced_manual_group_indices.duplicate()
        for enemy_index in indices:
            if enemy_index < 0 or enemy_index >= GameState.battle_enemies.size():
                continue
            if int((GameState.battle_enemies[enemy_index] as Dictionary).get("hp", 0)) <= 0:
                continue
            selected_enemy = enemy_index
            super._resolve_skill_attack(hero, skill)
        _restore_selected_enemy_v49(previous_selected)
        return
    super._resolve_skill_attack(hero, skill)

func _restore_selected_enemy_v49(previous_selected: int) -> void:
    if GameState.battle_enemies.is_empty():
        selected_enemy = 0
        return
    if previous_selected >= 0 and previous_selected < GameState.battle_enemies.size():
        var previous: Dictionary = GameState.battle_enemies[previous_selected]
        if int(previous.get("hp", 0)) > 0:
            selected_enemy = previous_selected
            return
    _normalize_selected_enemy_v48()

func _confirm_ally_target_v46(hero_id: String) -> void:
    if pending_choice_kind == "clinical_medical":
        if not pending_ally_ids.has(hero_id):
            return
        var slot := pending_choice_skill_slot
        _clear_pending_ally_choice_v46()
        forced_clinical_ally_target_id = hero_id
        super._use_combat_skill(slot)
        return
    super._confirm_ally_target_v46(hero_id)

func _resolve_clinical_medical(hero: Dictionary, skill: Dictionary) -> void:
    if forced_clinical_ally_target_id == "":
        super._resolve_clinical_medical(hero, skill)
        return
    var patient := _hero_by_id_v46(forced_clinical_ally_target_id)
    forced_clinical_ally_target_id = ""
    if patient.is_empty() or int(patient.get("hp", 0)) <= 0:
        super._resolve_clinical_medical(hero, skill)
        return
    var result := VeilleursSkillResolverRouter.resolve_combat(hero, patient, skill, 0, GameState.party)
    _log_clinical_result(hero, patient, skill, result)

func _automatic_group_indices_v46(hero: Dictionary, skill: Dictionary) -> Array[int]:
    var candidates: Array[int] = COMBAT_TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
    var result: Array[int] = []
    var scope := str(skill.get("target_scope", skill.get("target_group", "all"))).to_lower()
    var declared_anchor := _declared_anchor_position_v49(skill)
    for enemy_index in candidates:
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
            var anchor_pos := declared_anchor
            if anchor_pos < 0:
                anchor_pos = int((GameState.battle_enemies[candidates[0]] as Dictionary).get("combat_position", 0)) if not candidates.is_empty() else 0
            include = absi(pos - anchor_pos) <= 1
        if include:
            result.append(enemy_index)
    var target_count := int(skill.get("target_count", 0))
    if target_count > 0 and result.size() > target_count:
        result.resize(target_count)
    return result

func _declared_anchor_position_v49(skill: Dictionary) -> int:
    if skill.has("target_anchor_position"):
        return clampi(int(skill.get("target_anchor_position", 0)), 0, 3)
    if skill.has("target_anchor_rank"):
        return clampi(int(skill.get("target_anchor_rank", 1)) - 1, 0, 3)
    var anchor := str(skill.get("target_anchor", "")).to_lower()
    if anchor in ["front", "frontmost", "first"]:
        return 0
    if anchor in ["middle", "center", "centre"]:
        return 1
    if anchor in ["rear", "back", "last"]:
        return 3
    return -1

func _highlight_multi_enemy_targets_v49() -> void:
    for node_value in content.find_children("*", "Button", true, false):
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
        var candidate := pending_multi_target_candidates.has(matching_index)
        var selected := pending_multi_target_selected.has(matching_index)
        button.modulate = Color(1.0, 1.0, 1.0, 1.0) if candidate else Color(0.45, 0.45, 0.45, 0.62)
        if candidate:
            _apply_target_button_highlight(button, selected)

func _clear_combat_transients_v48() -> void:
    _clear_multi_target_v49()
    forced_manual_group_indices.clear()
    forcing_manual_group_execution = false
    forced_clinical_ally_target_id = ""
    super._clear_combat_transients_v48()
