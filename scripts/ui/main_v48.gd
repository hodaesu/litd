extends "res://scripts/ui/main_v47.gd"

# v48 — Combat Sandbox mobile avancé.
# Rend visibles et manipulables sans surcharge : formation R1-R4, contrôles temporisés,
# synergies contextuelles et charges d'ultime. R1 reste à droite de l'écran.

const SANDBOX_TEST_LEVEL := 16
var _sandbox_selected_ally := -1

func _show_combat_sandbox() -> void:
    super._show_combat_sandbox()
    if not _sandbox_started:
        return
    _render_sandbox_formation_mobile()
    _render_sandbox_contextual_synergy()
    _render_sandbox_ultimate_mobile()

func _render_sandbox_status() -> void:
    var active: Dictionary = _sandbox.call("active_hero")
    var heroes: Array = _sandbox.get("heroes")
    var enemies: Array = _sandbox.get("enemies")
    var round_number := int(_sandbox.get("round"))

    var top := HBoxContainer.new()
    top.position = Vector2(52, 112)
    top.size = Vector2(1170, 70)
    top.add_theme_constant_override("separation", 10)
    content.add_child(top)
    for hero_index in range(heroes.size()):
        var hero: Dictionary = heroes[hero_index]
        var current := str(hero.get("id", "")) == str(active.get("id", ""))
        var ally_selected := hero_index == _sandbox_selected_ally
        var prefix := "◆ " if current else ("◇ " if ally_selected else "")
        var label := "%s%s · R%d\nPV %d/%d · %d PA" % [prefix, str(hero.get("name", "Veilleur")), int(hero.get("formation_slot", hero_index + 1)), int(hero.get("hp", 0)), int(hero.get("max_hp", 0)), int(hero.get("ap", 0))]
        var button := make_button(label, func(i = hero_index): _sandbox_select_ally_or_inspect(int(i)), Vector2(270, 62))
        button.tooltip_text = "Touchez : cible alliée · retouchez : examen 0 PA"
        top.add_child(button)

    var enemy_row := HBoxContainer.new()
    enemy_row.position = Vector2(52, 194)
    enemy_row.size = Vector2(1170, 72)
    enemy_row.add_theme_constant_override("separation", 12)
    content.add_child(enemy_row)
    for enemy_index in range(enemies.size()):
        var enemy: Dictionary = enemies[enemy_index]
        var selected := enemy_index == _sandbox_selected_target
        var control_rounds := int(enemy.get("control_rounds", 0))
        var control_text := ""
        if control_rounds > 0:
            control_text = " · %s %dT" % [_control_label(str(enemy.get("control_state", "contrôlé"))), control_rounds]
        var label := "%s%s\n%s%s" % ["◆ " if selected else "", str(enemy.get("name", "Ennemi")), _sandbox_vital_label(enemy), control_text]
        var button := make_button(label, func(i = enemy_index): _sandbox_select_target(int(i)), Vector2(300, 62))
        button.disabled = int(enemy.get("hp", 0)) <= 0
        button.tooltip_text = "Sélectionner comme cible"
        enemy_row.add_child(button)
        var inspect := make_button("EXAMINER", func(i = enemy_index): _sandbox_open_inspection("enemy", int(i)), Vector2(120, 62))
        inspect.disabled = int(enemy.get("hp", 0)) <= 0
        inspect.tooltip_text = "Informations connues · 0 PA"
        enemy_row.add_child(inspect)

    var round_label := make_label("ROUND %d · %s actif" % [round_number, str(active.get("name", "Veilleur"))], 13, CANON_GOLD)
    round_label.position = Vector2(960, 82)
    round_label.size = Vector2(260, 28)
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(round_label)

func _render_sandbox_formation_mobile() -> void:
    var heroes: Array = _sandbox.get("heroes")
    var active_index := int(_sandbox.get("active_hero_index"))
    var active: Dictionary = _sandbox.call("active_hero")
    var panel := VBoxContainer.new()
    panel.name = "SandboxFormationMobileV48"
    panel.position = Vector2(52, 638)
    panel.size = Vector2(560, 92)
    panel.add_theme_constant_override("separation", 4)
    content.add_child(panel)
    panel.add_child(make_label("FORMATION · touchez un rang pour déplacer %s · 1 PA" % str(active.get("name", "Veilleur")), 11, CANON_GOLD))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    panel.add_child(row)
    # Affichage gauche→droite R4,R3,R2,R1 : R1 est donc bien à droite.
    for slot in [4, 3, 2, 1]:
        var occupant := "—"
        for hero_value: Variant in heroes:
            if hero_value is Dictionary and int((hero_value as Dictionary).get("formation_slot", 0)) == slot:
                occupant = str((hero_value as Dictionary).get("name", "Veilleur"))
                break
        var current: bool = int(active.get("formation_slot", active_index + 1)) == int(slot)
        var text := "%sR%d\n%s" % ["◆ " if current else "", slot, occupant]
        var button := make_button(text, func(s = slot): _sandbox_move_active_to_slot(int(s)), Vector2(132, 54))
        button.name = "SandboxRankR%dV48" % slot
        button.disabled = int(active.get("ap", 0)) < 1 or current
        row.add_child(button)

func _render_sandbox_contextual_synergy() -> void:
    var synergies := _sandbox_available_synergies_ui()
    if synergies.is_empty():
        return
    var panel := VBoxContainer.new()
    panel.name = "SandboxContextualSynergyV48"
    panel.position = Vector2(628, 638)
    panel.size = Vector2(300, 92)
    panel.add_theme_constant_override("separation", 4)
    content.add_child(panel)
    panel.add_child(make_label("SYNERGIE DISPONIBLE", 11, CANON_GOLD))
    for entry: Dictionary in synergies:
        var label := "%s · %s" % [str(entry.get("label", "Synergie")), str(entry.get("ally_name", "Allié"))]
        var button := make_button(label, func(e = entry): _sandbox_trigger_contextual_synergy(e), Vector2(290, 48))
        button.name = "SandboxSynergyButtonV48"
        panel.add_child(button)

func _render_sandbox_ultimate_mobile() -> void:
    var heroes: Array = _sandbox.get("heroes")
    var active_index := int(_sandbox.get("active_hero_index"))
    if active_index < 0 or active_index >= heroes.size():
        return
    var hero: Dictionary = heroes[active_index]
    var tree_id := _sandbox_default_ultimate_tree(str(hero.get("id", "")))
    var total := int(_sandbox.call("ultimate_charges_for_level", SANDBOX_TEST_LEVEL))
    var uses: Dictionary = hero.get("ultimate_uses", {})
    var used := int(uses.get(tree_id, 0))
    var remaining := maxi(0, total - used)

    var panel := VBoxContainer.new()
    panel.name = "SandboxUltimateMobileV48"
    panel.position = Vector2(944, 638)
    panel.size = Vector2(276, 92)
    panel.add_theme_constant_override("separation", 4)
    content.add_child(panel)
    panel.add_child(make_label("SIGNATURE", 11, CANON_GOLD))
    var button := make_button("ULTIME · %d/%d" % [remaining, total], func(): _sandbox_use_active_ultimate(), Vector2(270, 48))
    button.name = "SandboxUltimateButtonV48"
    button.disabled = remaining <= 0
    button.tooltip_text = "Charge d'expédition · niveau sandbox %d" % SANDBOX_TEST_LEVEL
    panel.add_child(button)

func _sandbox_select_ally_or_inspect(index: int) -> void:
    if _sandbox_selected_ally == index:
        _sandbox_open_inspection("hero", index)
        return
    _sandbox_selected_ally = index
    show_screen("combat_sandbox")

func _sandbox_move_active_to_slot(slot: int) -> void:
    var active_index := int(_sandbox.get("active_hero_index"))
    _sandbox_last_result = _sandbox.call("move_hero", active_index, slot, 1)
    show_screen("combat_sandbox")

func _sandbox_trigger_contextual_synergy(entry: Dictionary) -> void:
    var active_index := int(_sandbox.get("active_hero_index"))
    _sandbox_last_result = _sandbox.call("trigger_synergy", active_index, int(entry.get("ally_index", -1)), str(entry.get("id", "")))
    show_screen("combat_sandbox")

func _sandbox_use_active_ultimate() -> void:
    var active_index := int(_sandbox.get("active_hero_index"))
    var heroes: Array = _sandbox.get("heroes")
    if active_index < 0 or active_index >= heroes.size():
        return
    var tree_id := _sandbox_default_ultimate_tree(str((heroes[active_index] as Dictionary).get("id", "")))
    var target := _sandbox_selected_target
    if target < 0:
        target = 0
    _sandbox_last_result = _sandbox.call("use_tree_ultimate", active_index, tree_id, SANDBOX_TEST_LEVEL, target)
    show_screen("combat_sandbox")

func _sandbox_execute() -> void:
    if _sandbox_selected_action == "":
        return
    var action := _sandbox_selected_action_data()
    if action.is_empty():
        return
    var target_type := str(action.get("target", "enemy"))
    var target_index := -1
    if target_type.begins_with("enemy"):
        target_index = _sandbox_selected_target
        if target_index < 0:
            return
    elif target_type == "ally":
        target_index = _sandbox_selected_ally
        if target_index < 0:
            return
    elif target_type == "self":
        target_index = int(_sandbox.get("active_hero_index"))
    _sandbox_last_result = _sandbox.call("perform_action", _sandbox_selected_action, target_index, _sandbox_selected_zone)
    if int(_sandbox_last_result.get("remaining_ap", 1)) <= 0:
        _sandbox.call("end_active_turn")
        _sandbox_selected_action = ""
        _sandbox_selected_target = -1
        _sandbox_selected_ally = -1
    show_screen("combat_sandbox")

func _render_sandbox_controls() -> void:
    var box := VBoxContainer.new()
    box.position = Vector2(920, 286)
    box.size = Vector2(300, 220)
    box.add_theme_constant_override("separation", 8)
    content.add_child(box)
    box.add_child(make_label("DÉCISION", 13, CANON_GOLD))
    var execute := make_button("EXÉCUTER", func(): _sandbox_execute(), Vector2(280, 52))
    execute.disabled = not _sandbox_action_ready()
    box.add_child(execute)
    box.add_child(make_button("FIN DU TOUR", func(): _sandbox_end_turn(), Vector2(280, 48)))
    box.add_child(make_button("RÉINITIALISER", func(): _sandbox_reset(), Vector2(280, 44)))
    box.add_child(make_button("RETOUR", func(): GameState.request_screen("navigation"), Vector2(280, 44)))

func _sandbox_action_ready() -> bool:
    var action := _sandbox_selected_action_data()
    if action.is_empty():
        return false
    var target_type := str(action.get("target", "enemy"))
    if target_type.begins_with("enemy"):
        return _sandbox_selected_target >= 0
    if target_type == "ally":
        return _sandbox_selected_ally >= 0
    return target_type == "self"

func _sandbox_selected_action_data() -> Dictionary:
    for value: Variant in _sandbox.call("available_actions"):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == _sandbox_selected_action:
            return (value as Dictionary).duplicate(true)
    return {}

func _sandbox_available_synergies_ui() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var heroes: Array = _sandbox.get("heroes")
    var enemies: Array = _sandbox.get("enemies")
    var active_index := int(_sandbox.get("active_hero_index"))
    if active_index < 0 or active_index >= heroes.size():
        return result
    var active: Dictionary = heroes[active_index]
    var active_id := str(active.get("id", ""))
    for i in range(heroes.size()):
        if i == active_index:
            continue
        var ally: Dictionary = heroes[i]
        var ally_id := str(ally.get("id", ""))
        if active_id in ["mathilde", "marec"] and ally_id in ["mathilde", "marec"]:
            result.append({"id":"shared_guard","ally_index":i,"label":"Garde partagée","ally_name":str(ally.get("name", "Allié"))})
        elif active_id == "anouk" and ally_id in ["mathilde", "marec"] and _sandbox_enemy_has_opening(enemies):
            result.append({"id":"observed_opening","ally_index":i,"label":"Ouverture observée","ally_name":str(ally.get("name", "Allié"))})
        elif active_id == "aurelien" and ally_id == "marec" and _sandbox_has_reduced_function(ally):
            result.append({"id":"stabilized_push","ally_index":i,"label":"Poussée stabilisée","ally_name":str(ally.get("name", "Allié"))})
    return result

func _sandbox_enemy_has_opening(enemies: Array) -> bool:
    for enemy_value: Variant in enemies:
        if not enemy_value is Dictionary:
            continue
        var enemy: Dictionary = enemy_value
        if str(enemy.get("exposed_zone", "")) != "" or int(enemy.get("control_rounds", 0)) > 0:
            return true
    return false

func _sandbox_has_reduced_function(hero: Dictionary) -> bool:
    var anatomy: Dictionary = hero.get("anatomy", {})
    for zone in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
        var function := str((anatomy.get(zone, {}) as Dictionary).get("function", "functional"))
        if function in ["impaired", "stabilized"]:
            return true
    return false

func _sandbox_default_ultimate_tree(hero_id: String) -> String:
    match hero_id:
        "mathilde": return "lame_juste"
        "marec": return "force_directe"
        "anouk": return "trame"
        "aurelien": return "coordination"
    return ""

func _control_label(state: String) -> String:
    match state:
        "deviated": return "Dévié"
        "trame_bound": return "Lié"
        "none": return ""
    return state.capitalize()

func _sandbox_result_text(result: Dictionary) -> String:
    if not bool(result.get("ok", false)):
        return "Action impossible · %s" % str(result.get("reason", "raison inconnue"))
    match str(result.get("kind", "")):
        "formation":
            return "FORMATION · R%d → R%d%s · %d PA restant(s)." % [int(result.get("from", 0)), int(result.get("to", 0)), " · échange" if bool(result.get("swapped", false)) else "", int(result.get("remaining_ap", 0))]
        "synergy":
            return "SYNERGIE · %s · %s + %s." % [str(result.get("id", "")), str(result.get("source", "")), str(result.get("ally", ""))]
        "ultimate":
            return "ULTIME · %s · %d charge(s) restante(s)." % [str(result.get("effect", "effet systémique")), int(result.get("charges_remaining", 0))]
        "persistent_control":
            return "CONTRÔLE · %s · %d tour(s)." % [str(result.get("state", "")), int(result.get("rounds", 0))]
    return super._sandbox_result_text(result)