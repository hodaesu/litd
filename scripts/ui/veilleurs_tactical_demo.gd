extends Control

const SESSION_SCRIPT := preload("res://scripts/core/veilleurs_tactical_session.gd")
const UI_SCENE := preload("res://scenes/veilleurs/v06_tactical_combat.tscn")

var session: Node
var tactical_ui: VeilleursTacticalUI
var selected_watcher := "ENT_WATCHER_SAHEN"
var selected_target := "ENT_ENEMY_GOULE_AFFAMEE"
var selected_zone := "torso"
var skill_ids: Array[String] = []
var message_label: Label

func _ready() -> void:
    _build_shell()
    session = SESSION_SCRIPT.new()
    add_child(session)
    var setup: Dictionary = session.call("start_first_combat")
    if not bool(setup.get("ok", false)):
        message_label.text = "Échec d'initialisation : %s" % str(setup.get("reason", "inconnu"))
        return
    _refresh()

func _build_shell() -> void:
    var background := ColorRect.new()
    background.color = Color(0.035, 0.038, 0.05, 1.0)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var header := HBoxContainer.new()
    header.set_anchors_preset(Control.PRESET_TOP_WIDE)
    header.offset_left = 16
    header.offset_top = 8
    header.offset_right = -16
    header.offset_bottom = 58
    add_child(header)

    var title := Label.new()
    title.text = "LITD : LES VEILLEURS — PROTOTYPE TACTIQUE v0.6"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 22)
    header.add_child(title)

    var back := Button.new()
    back.text = "Retour menu"
    back.custom_minimum_size = Vector2(130, 48)
    back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))
    header.add_child(back)

    tactical_ui = UI_SCENE.instantiate() as VeilleursTacticalUI
    tactical_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    tactical_ui.offset_top = 64
    tactical_ui.offset_bottom = -72
    tactical_ui.tactical_cell_pressed.connect(_on_cell)
    tactical_ui.skill_slot_pressed.connect(_on_skill)
    tactical_ui.body_zone_pressed.connect(_on_zone)
    tactical_ui.retreat_pressed.connect(_on_retreat)
    add_child(tactical_ui)

    message_label = Label.new()
    message_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    message_label.offset_left = 16
    message_label.offset_right = -16
    message_label.offset_top = -64
    message_label.offset_bottom = -8
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(message_label)

func _refresh() -> void:
    if not bool(session.call("is_active")):
        return
    var runtime: VeilleursTacticalCombatRuntime = session.runtime
    tactical_ui.bind_snapshot(session.call("snapshot"))
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
    message_label.text = "%s — cible : %s — zone : %s. Touchez une case libre adjacente pour vous déplacer." % [_display(selected_watcher), _display(selected_target), _zone_name(selected_zone)]

func _on_cell(cell: Vector2i) -> void:
    if not bool(session.call("is_active")):
        return
    var runtime: VeilleursTacticalCombatRuntime = session.runtime
    var occupant := runtime.grid.occupant(cell)
    if occupant.begins_with("ENT_WATCHER_"):
        selected_watcher = occupant
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
    if slot < 0 or slot >= skill_ids.size() or not bool(session.call("is_active")):
        return
    var runtime: VeilleursTacticalCombatRuntime = session.runtime
    var skill_id := skill_ids[slot]
    var skill := runtime.content_db.skill(skill_id)
    var action := str(skill.get("action_type", "attack"))
    var target_id := selected_target
    if action in ["guard", "heal", "support", "passive_modifier"]:
        target_id = selected_watcher
    if not runtime.combatants.has(target_id):
        message_label.text = "Aucune cible valide."
        return
    var result: Dictionary = session.call("resolve_skill", selected_watcher, target_id, skill_id, selected_zone, -1)
    if not bool(result.get("ok", false)):
        message_label.text = "Action refusée : %s" % str(result.get("reason", "inconnue"))
        return
    if bool(result.get("non_damage", false)):
        message_label.text = "%s utilise %s." % [_display(selected_watcher), str(skill.get("name_fr", skill_id))]
    elif bool(result.get("hit", false)):
        message_label.text = "%s : %d dégâts, zone %s." % [str(skill.get("name_fr", skill_id)), int(result.get("damage", 0)), _zone_name(selected_zone)]
    else:
        message_label.text = "%s manque sa cible." % str(skill.get("name_fr", skill_id))
    _check_end_or_enemy_phase()
    _refresh()

func _enemy_phase() -> void:
    if not bool(session.call("is_active")):
        return
    var runtime: VeilleursTacticalCombatRuntime = session.runtime
    for enemy_id: String in runtime.alive_ids("enemy"):
        session.call("enemy_step", enemy_id)
    runtime.next_round()

func _check_end_or_enemy_phase() -> void:
    var runtime: VeilleursTacticalCombatRuntime = session.runtime
    if runtime.alive_ids("enemy").is_empty():
        var finish: Dictionary = session.call("finish", "victory")
        message_label.text = "Victoire. %d Veilleurs sont encore debout. Retournez au menu pour poursuivre le développement." % (finish.get("watchers_alive", []) as Array).size()
        return
    _enemy_phase()
    if runtime.alive_ids("watcher").is_empty():
        session.call("finish", "defeat")
        message_label.text = "L'équipe est tombée. Les conséquences ont été transmises à la Rémanence."

func _on_retreat() -> void:
    if bool(session.call("is_active")):
        session.call("finish", "retreat")
    message_label.text = "Retraite enregistrée. Les survivants ennemis peuvent désormais revenir par la Rémanence."

func _display(entity_id: String) -> String:
    if session == null or session.runtime == null:
        return entity_id
    var row: Dictionary = session.runtime.combatants.get(entity_id, {})
    return str(row.get("name", entity_id))

func _zone_name(zone: String) -> String:
    return {"head":"tête", "torso":"torse", "left_arm":"bras gauche", "right_arm":"bras droit", "left_leg":"jambe gauche", "right_leg":"jambe droite"}.get(zone, zone)
