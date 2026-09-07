extends Control
class_name VeilleursDungeonSliceDemo

const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_dungeon_slice_runtime.gd")

var runtime: VeilleursDungeonSliceRuntime
var title_label: Label
var detail_label: Label
var encounter_label: Label
var status_label: Label
var actions: VBoxContainer

func _ready() -> void:
    _build_shell()
    runtime = RUNTIME_SCRIPT.new() as VeilleursDungeonSliceRuntime
    var result := runtime.start()
    if not bool(result.get("ok", false)):
        status_label.text = "Erreur slice : %s" % ", ".join(runtime.load_errors)
        return
    _refresh()

func _build_shell() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.028, 0.026, 0.022, 1.0)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var root := VBoxContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 32
    root.offset_top = 24
    root.offset_right = -32
    root.offset_bottom = -24
    root.add_theme_constant_override("separation", 12)
    add_child(root)

    var header := HBoxContainer.new()
    root.add_child(header)
    var heading := Label.new()
    heading.text = "KHAR-SEN — SLICE DE DONJON v0.6.1"
    heading.add_theme_font_size_override("font_size", 26)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(heading)
    var back := Button.new()
    back.text = "Retour QA"
    back.custom_minimum_size = Vector2(140, 46)
    back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/qa/qa_validation_room.tscn"))
    header.add_child(back)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 15)
    root.add_child(status_label)

    var panel := PanelContainer.new()
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 20)
    panel.add_child(row)

    var info := VBoxContainer.new()
    info.custom_minimum_size = Vector2(720, 0)
    info.add_theme_constant_override("separation", 12)
    row.add_child(info)
    title_label = Label.new()
    title_label.add_theme_font_size_override("font_size", 23)
    info.add_child(title_label)
    detail_label = Label.new()
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.add_theme_font_size_override("font_size", 16)
    detail_label.custom_minimum_size = Vector2(700, 150)
    info.add_child(detail_label)
    encounter_label = Label.new()
    encounter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    encounter_label.add_theme_font_size_override("font_size", 15)
    encounter_label.custom_minimum_size = Vector2(700, 220)
    info.add_child(encounter_label)

    actions = VBoxContainer.new()
    actions.custom_minimum_size = Vector2(410, 0)
    actions.add_theme_constant_override("separation", 8)
    row.add_child(actions)

func _refresh() -> void:
    if runtime == null or runtime.current_node == "":
        return
    var node: Dictionary = runtime.nodes_by_id.get(runtime.current_node, {})
    title_label.text = "%s · %s" % [runtime.current_node, str(node.get("title_fr", "Salle"))]
    detail_label.text = "Type : %s\nDanger : %s\nExtraction : %s\nVisitées : %d/%d\nCicatrices actives : %d" % [
        str(node.get("kind", "room")),
        str(node.get("hazard", "none")),
        "oui" if runtime.can_extract() else "non",
        runtime.visited.size(),
        runtime.nodes_by_id.size(),
        RemanenceRuntime.world_scars.size()
    ]
    encounter_label.text = _encounter_text(runtime.active_encounter)
    status_label.text = "Objectif atteint : %s · Historique rencontres : %d" % ["oui" if bool(runtime.progress_summary().get("objective_reached", false)) else "non", runtime.encounter_director.recent_templates.size()]
    _rebuild_actions(node)

func _rebuild_actions(node: Dictionary) -> void:
    for child: Node in actions.get_children():
        child.queue_free()
    var completed := bool((runtime.node_flags.get(runtime.current_node, {}) as Dictionary).get("completed", false))
    if not completed:
        if bool(node.get("encounter", false)):
            actions.add_child(_button("RÉSOUDRE : VICTOIRE", func() -> void:
                runtime.complete_current("victory")
                _refresh()))
            actions.add_child(_button("VICTOIRE AVEC MUTILATION", func() -> void:
                runtime.complete_current("victory_with_mutilation")
                _refresh()))
        else:
            actions.add_child(_button("VALIDER LA SALLE", func() -> void:
                runtime.complete_current("cleared")
                _refresh()))
        if runtime.can_extract():
            actions.add_child(_button("EXTRAIRE MAINTENANT", func() -> void:
                runtime.complete_current("retreat")
                status_label.text = "Extraction enregistrée ; les conséquences restent persistantes."))
        return

    var next_nodes := runtime.available_next()
    if next_nodes.is_empty():
        actions.add_child(_button("OBJECTIF TERMINÉ — RECOMMENCER", _restart))
    else:
        var label := Label.new()
        label.text = "CHEMIN SUIVANT"
        label.add_theme_font_size_override("font_size", 16)
        actions.add_child(label)
        for next_id: String in next_nodes:
            var next_row: Dictionary = runtime.nodes_by_id.get(next_id, {})
            actions.add_child(_button("%s\n%s" % [next_id, str(next_row.get("title_fr", "Salle"))], func(id_value = next_id) -> void:
                runtime.choose_next(id_value)
                _refresh()))
    actions.add_child(_button("RECOMMENCER LE SLICE", _restart))

func _encounter_text(encounter: Dictionary) -> String:
    if encounter.is_empty():
        return "Aucune rencontre de combat matérialisée dans cette salle."
    var members: Array[String] = []
    for value: Variant in encounter.get("composition", []):
        if value is Dictionary:
            var row: Dictionary = value
            var suffix := " [%s]" % str(row.get("remanence_stage", "")) if row.has("remanence_stage") else ""
            members.append("• %s%s" % [str(row.get("definition_id", "?")), suffix])
    return "Rencontre : %s · palier %d\nObjectif : %s\nMenace : %.2f / %.2f\nContre-jeu : %s\n%s" % [
        str(encounter.get("template_id", "?")),
        int(encounter.get("tier", 1)),
        str(encounter.get("objective", "survive")),
        float(encounter.get("actual_threat", 0.0)),
        float(encounter.get("target_threat", 0.0)),
        str(encounter.get("counterplay", "")),
        "\n".join(members)
    ]

func _restart() -> void:
    RemanenceRuntime.reset_new_game()
    runtime = RUNTIME_SCRIPT.new() as VeilleursDungeonSliceRuntime
    runtime.start()
    _refresh()

func _button(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(390, 56)
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.pressed.connect(callback)
    return button
