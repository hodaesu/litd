extends Control
class_name VeilleursDungeonSliceDemo

const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_dungeon_slice_runtime.gd")
const FLOW_SCRIPT := preload("res://scripts/core/veilleurs_khar_sen_flow_bridge.gd")
const TACTICAL_SCENE := "res://scenes/veilleurs/v061_tactical_demo.tscn"
const QA_SCENE := "res://scenes/qa/qa_validation_room.tscn"

var runtime: VeilleursDungeonSliceRuntime
var flow_bridge: VeilleursKharSenFlowBridge
var terminal_outcome := ""
var return_message := ""
var title_label: Label
var detail_label: Label
var encounter_label: Label
var status_label: Label
var actions: VBoxContainer

func _ready() -> void:
    _build_shell()
    flow_bridge = FLOW_SCRIPT.new() as VeilleursKharSenFlowBridge
    runtime = RUNTIME_SCRIPT.new() as VeilleursDungeonSliceRuntime
    var returned: Dictionary = flow_bridge.consume_result()
    if not returned.is_empty():
        _resume_after_combat(returned)
    else:
        var result := runtime.start()
        if not bool(result.get("ok", false)):
            status_label.text = "Erreur slice : %s" % ", ".join(runtime.load_errors)
            return
    _refresh()

func _resume_after_combat(payload: Dictionary) -> void:
    var dungeon_state: Dictionary = payload.get("dungeon_state", {})
    if not runtime.deserialize(dungeon_state):
        return_message = "Retour combat illisible : le slice a été réinitialisé."
        runtime.start()
        return
    var expected_node := str(payload.get("node_id", ""))
    if expected_node == "" or expected_node != runtime.current_node:
        return_message = "Retour combat incohérent : nœud Khar-Sen non reconnu."
        runtime.start()
        return
    var outcome := str(payload.get("outcome", "defeat"))
    var context := {
        "watcher_aftermath":(payload.get("watcher_aftermath", {}) as Dictionary).duplicate(true),
        "combat_summary":(payload.get("summary", {}) as Dictionary).duplicate(true),
        "summary":"Khar-Sen %s — combat réel v0.6.1 : %s" % [expected_node, outcome]
    }
    var completion := runtime.complete_current(outcome, context)
    terminal_outcome = outcome if outcome in ["defeat", "retreat"] else ""
    var summary: Dictionary = payload.get("summary", {})
    return_message = "Combat %s · tour %d · %d Veilleur(s) debout · Rémanence %s" % [
        outcome,
        int(summary.get("round", 0)),
        (summary.get("watchers_alive", []) as Array).size(),
        "mise à jour" if bool(completion.get("ok", false)) else "incomplète"
    ]

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
    back.pressed.connect(_return_qa)
    header.add_child(back)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 15)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
    var base_status := "Objectif atteint : %s · Historique rencontres : %d" % ["oui" if bool(runtime.progress_summary().get("objective_reached", false)) else "non", runtime.encounter_director.recent_templates.size()]
    status_label.text = "%s\n%s" % [return_message, base_status] if return_message != "" else base_status
    _rebuild_actions(node)

func _rebuild_actions(node: Dictionary) -> void:
    for child: Node in actions.get_children():
        child.queue_free()
    if terminal_outcome != "":
        var terminal := Label.new()
        terminal.text = "EXPÉDITION TERMINÉE : %s" % terminal_outcome.to_upper()
        terminal.add_theme_font_size_override("font_size", 18)
        actions.add_child(terminal)
        actions.add_child(_button("RECOMMENCER KHAR-SEN", _restart))
        actions.add_child(_button("RETOUR QA", _return_qa))
        return
    var completed := bool((runtime.node_flags.get(runtime.current_node, {}) as Dictionary).get("completed", false))
    if not completed:
        if bool(node.get("encounter", false)):
            actions.add_child(_button("LANCER LE COMBAT v0.6.1", _launch_combat))
        else:
            actions.add_child(_button("VALIDER LA SALLE", func() -> void:
                runtime.complete_current("cleared")
                return_message = "Salle validée sans combat."
                _refresh()))
        if runtime.can_extract():
            actions.add_child(_button("EXTRAIRE MAINTENANT", _extract_now))
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
                return_message = ""
                _refresh()))
    actions.add_child(_button("RECOMMENCER LE SLICE", _restart))

func _launch_combat() -> void:
    if runtime.active_encounter.is_empty():
        return_message = "Aucune rencontre matérialisée à lancer."
        _refresh()
        return
    if not flow_bridge.begin_combat(runtime.serialize(), runtime.active_encounter, runtime.current_node):
        return_message = "Impossible de préparer le passage vers le combat."
        _refresh()
        return
    var error := get_tree().change_scene_to_file(TACTICAL_SCENE)
    if error != OK:
        flow_bridge.clear()
        return_message = "Impossible d'ouvrir le combat v0.6.1."
        _refresh()

func _extract_now() -> void:
    runtime.complete_current("retreat", {"summary":"Extraction volontaire depuis Khar-Sen"})
    terminal_outcome = "retreat"
    return_message = "Extraction enregistrée ; les conséquences restent persistantes."
    _refresh()

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
    flow_bridge.clear()
    RemanenceRuntime.reset_new_game()
    terminal_outcome = ""
    return_message = ""
    runtime = RUNTIME_SCRIPT.new() as VeilleursDungeonSliceRuntime
    runtime.start()
    _refresh()

func _return_qa() -> void:
    flow_bridge.clear()
    get_tree().change_scene_to_file(QA_SCENE)

func _button(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(390, 56)
    button.pressed.connect(callback)
    return button
