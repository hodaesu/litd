extends Control
class_name VeilleursTacticalDemoV2

const SESSION_SCRIPT := preload("res://scripts/core/veilleurs_tactical_session_v2.gd")
const UI_SCENE := preload("res://scenes/veilleurs/v06_tactical_combat.tscn")

var session: VeilleursTacticalSessionV2
var tactical_ui: VeilleursTacticalUI
var selected_watcher := "ENT_WATCHER_SAHEN"
var selected_target := "ENT_ENEMY_GOULE_AFFAMEE"
var selected_zone := "torso"
var skill_ids: Array[String] = []
var message_label: Label
var status_label: Label

func _ready() -> void:
    _build_shell()
    session = SESSION_SCRIPT.new() as VeilleursTacticalSessionV2
    add_child(session)
    var setup := session.start_first_combat()
    if not bool(setup.get("ok", false)):
        message_label.text = "Échec d'initialisation : %s" % str(setup.get("reason", "inconnu"))
        return
    _refresh()

func _build_shell() -> void:
    var background := ColorRect.new()
    background.color = Color(0.025, 0.028, 0.038, 1.0)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var header := HBoxContainer.new()
    header.set_anchors_preset(Control.PRESET_TOP_WIDE)
    header.offset_left = 12
    header.offset_top = 6
    header.offset_right = -12
    header.offset_bottom = 58
    header.add_theme_constant_override("separation", 8)
    add_child(header)

    var title := Label.new()
    title.text = "LITD : LES VEILLEURS — TACTIQUE v0.6.1"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 21)
    header.add_child(title)

    status_label = Label.new()
    status_label.custom_minimum_size = Vector2(280, 48)
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_child(status_label)

    var save_button := Button.new()
    save_button.text = "Sauvegarder"
    save_button.custom_minimum_size = Vector2(116, 46)
    save_button.pressed.connect(_on_save)
    header.add_child(save_button)

    var load_button := Button.new()
    load_button.text = "Reprendre"
    load_button.custom_minimum_size = Vector2(108, 46)
    load_button.pressed.connect(_on_load)
    header.add_child(load_button)

    var back := Button.new()
    back.text = "Retour QA"
    back.custom_minimum_size = Vector2(110, 46)
    back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/qa/qa_validation_room.tscn"))
    header.add_child(back)

    tactical_ui = UI_SCENE.instantiate() as VeilleursTacticalUI
    tactical_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    tactical_ui.offset_top = 64
    tactical_ui.offset_bottom = -76
    tactical_ui.tactical_cell_pressed.connect(_on_cell)
    tactical_ui.skill_slot_pressed.connect(_on_skill)
    tactical_ui.body_zone_pressed.connect(_on_zone)
    tactical_ui.retreat_pressed.connect(_on_retreat)
    add_child(tactical_ui)

    message_label = Label.new()
    message_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    message_label.offset_left = 16
    message_label.offset_right = -16
    message_label.offset_top = -68
    message_label.offset_bottom = -8
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(message_label)

func _refresh() -> void:
    if session == null or not session.is_active():
        return
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    tactical_ui.bind_snapshot(session.snapshot())
    skill_ids.clear()
    var available: Array = runtime.content_db.skills_for(selected_watcher)
    for value: Variant in available:
        if not (value is Dictionary):
            continue
        var skill: Dictionary = value
        if int(skill.get("unlock_level", 99)) <= 1:
            skill_ids.append(str(skill.get("skill_id", "")))
    skill_ids.sort()
    var names: Array[String] = []
    for skill_id: String in skill_ids:
        names.append(str(runtime.content_db.skill(skill_id).get("name_fr", skill_id)))
    tactical_ui.set_skill_labels(names)
    var selected: Dictionary = runtime.combatants.get(selected_watcher, {})
    var target: Dictionary = runtime.combatants.get(selected_target, {})
    status_label.text = "Tour %d · %s %d/%d · RES %d" % [runtime.round_index, _display(selected_watcher), int(selected.get("hp", 0)), int(selected.get("max_hp", 0)), int(selected.get("resolve_current", 0))]
    message_label.text = "%s → %s · zone %s. Touchez un Veilleur/ennemi pour le sélectionner, ou une case adjacente pour bouger." % [_display(selected_watcher), str(target.get("name", selected_target)), _zone_name(selected_zone)]

func _on_cell(cell: Vector2i) -> void:
    if session == null or not session.is_active():
        return
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    var occupant := runtime.grid.occupant(cell)
    if occupant.begins_with("ENT_WATCHER_"):
        selected_watcher = occupant
        _repair_target()
        _refresh()
        return
    if occupant.begins_with("ENT_ENEMY_"):
        selected_target = occupant
        _refresh()
        return
    var origin := runtime.grid.position_of(selected_watcher)
    if absi(origin.x - cell.x) + absi(origin.y - cell.y) != 1:
        message_label.text = "Déplacement refusé : choisissez une case adjacente libre."
        return
    if runtime.grid.move(selected_watcher, cell):
        _enemy_phase()
        _refresh()

func _on_zone(zone: String) -> void:
    selected_zone = zone
    _refresh()

func _on_skill(slot: int) -> void:
    if session == null or not session.is_active() or slot < 0 or slot >= skill_ids.size():
        return
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    var skill_id := skill_ids[slot]
    var skill := runtime.content_db.skill(skill_id)
    var action := runtime.skill_behavior.effective_action(skill)
    var target_id := selected_target
    if action in ["guard", "heal", "passive_modifier", "move"]:
        target_id = selected_watcher
    elif action == "support":
        target_id = selected_watcher
    var result := session.resolve_skill(selected_watcher, target_id, skill_id, selected_zone, -1)
    if not bool(result.get("ok", false)):
        if str(result.get("reason", "")) == "out_of_range":
            message_label.text = "%s hors de portée (%d/%d)." % [str(skill.get("name_fr", skill_id)), int(result.get("distance", 0)), int(result.get("required_range", 0))]
        else:
            message_label.text = "Action refusée : %s" % str(result.get("reason", "inconnue"))
        return
    message_label.text = _result_text(skill, result)
    _check_end_or_enemy_phase()
    _refresh()

func _result_text(skill: Dictionary, result: Dictionary) -> String:
    var name := str(skill.get("name_fr", result.get("skill_id", "Compétence")))
    if bool(result.get("attack_deferred", false)):
        return "%s : déplacement tactique effectué, attaque différée." % name
    if bool(result.get("non_damage", false)):
        if result.has("knowledge_reveal"):
            return "%s révèle %d niveau(x) d'information." % [name, int(result.get("knowledge_reveal", 0))]
        if result.has("resolve_delta"):
            return "%s : RES %d, %s." % [name, int(result.get("resolve_delta", 0)), str(result.get("status_applied", "pression"))]
        if result.has("healed"):
            return "%s restaure %d PV sans effacer les séquelles." % [name, int(result.get("healed", 0))]
        if result.has("guard_delta"):
            return "%s prépare %d de garde." % [name, int(result.get("guard_delta", 0))]
        return "%s modifie l'état tactique." % name
    if bool(result.get("hit", false)):
        var suffix := " · %s" % str(result.get("status_applied", "")) if str(result.get("status_applied", "")) != "" else ""
        return "%s : %d dégâts sur %s%s." % [name, int(result.get("damage", 0)), _zone_name(selected_zone), suffix]
    return "%s manque sa cible." % name

func _enemy_phase() -> void:
    if session == null or not session.is_active():
        return
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    for enemy_id: String in runtime.alive_ids("enemy"):
        session.enemy_step(enemy_id)
    runtime.next_round()

func _check_end_or_enemy_phase() -> void:
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    if runtime.alive_ids("enemy").is_empty():
        var finish := session.finish("victory")
        message_label.text = "Victoire · %d Veilleurs debout · conséquences enregistrées." % (finish.get("watchers_alive", []) as Array).size()
        return
    _enemy_phase()
    if runtime.alive_ids("watcher").is_empty():
        session.finish("defeat")
        message_label.text = "Défaite : les survivants ennemis et les blessures restent dans la Rémanence."
    _repair_selection()

func _on_save() -> void:
    if session == null or not session.is_active():
        message_label.text = "Aucun combat actif à sauvegarder."
        return
    message_label.text = "Combat v0.6.1 sauvegardé." if session.save_snapshot() else "Échec de sauvegarde."

func _on_load() -> void:
    if session != null:
        session.queue_free()
    session = SESSION_SCRIPT.new() as VeilleursTacticalSessionV2
    add_child(session)
    if not session.load_snapshot():
        message_label.text = "Aucune sauvegarde v0.6.1 valide."
        return
    _repair_selection()
    _refresh()
    message_label.text = "Combat repris : états, blessures et Rémanence restaurés."

func _on_retreat() -> void:
    if session != null and session.is_active():
        session.finish("retreat")
    message_label.text = "Retraite : les ennemis survivants gagnent de la Rémanence."

func _repair_selection() -> void:
    if session == null or session.runtime == null:
        return
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    if not runtime.combatants.has(selected_watcher) or int((runtime.combatants[selected_watcher] as Dictionary).get("hp", 0)) <= 0:
        var watchers := runtime.alive_ids("watcher")
        if not watchers.is_empty():
            selected_watcher = watchers[0]
    _repair_target()

func _repair_target() -> void:
    if session == null or session.runtime == null:
        return
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    if not runtime.combatants.has(selected_target) or int((runtime.combatants[selected_target] as Dictionary).get("hp", 0)) <= 0:
        var enemies := runtime.alive_ids("enemy")
        if not enemies.is_empty():
            selected_target = enemies[0]

func _display(entity_id: String) -> String:
    if session == null or session.runtime == null:
        return entity_id
    return str((session.runtime.combatants.get(entity_id, {}) as Dictionary).get("name", entity_id))

func _zone_name(zone: String) -> String:
    return {"head":"tête", "torso":"torse", "left_arm":"bras gauche", "right_arm":"bras droit", "left_leg":"jambe gauche", "right_leg":"jambe droite"}.get(zone, zone)
