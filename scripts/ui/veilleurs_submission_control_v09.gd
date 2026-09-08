extends Node
class_name VeilleursSubmissionControlV09

var overlay: CanvasLayer
var button: Button
var info_panel: PanelContainer
var info_label: Label

func _ready() -> void:
    overlay = CanvasLayer.new()
    overlay.layer = 120
    overlay.name = "SubmissionOverlay"
    add_child(overlay)

    var shell := Control.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(shell)

    info_panel = PanelContainer.new()
    info_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    info_panel.offset_left = -386
    info_panel.offset_top = -214
    info_panel.offset_right = -16
    info_panel.offset_bottom = -140
    info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(info_panel)

    info_label = Label.new()
    info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.add_theme_font_size_override("font_size", 13)
    info_panel.add_child(info_label)

    button = Button.new()
    button.text = "Soumettre cible"
    button.custom_minimum_size = Vector2(180, 48)
    button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    button.offset_left = -196
    button.offset_top = -132
    button.offset_right = -16
    button.offset_bottom = -84
    button.pressed.connect(_on_pressed)
    shell.add_child(button)

    set_process(true)
    _refresh()

func _process(_delta: float) -> void:
    _refresh()

func _root_qa() -> VeilleursVerticalSliceQAV09:
    var node: Node = get_parent()
    while node != null:
        if node is VeilleursVerticalSliceQAV09:
            return node as VeilleursVerticalSliceQAV09
        node = node.get_parent()
    return null

func _refresh() -> void:
    if button == null or info_panel == null or info_label == null:
        return
    var qa: VeilleursVerticalSliceQAV09 = _root_qa()
    if qa == null or qa.slice == null or qa.slice.combat == null:
        button.visible = false
        info_panel.visible = false
        return

    button.visible = true
    info_panel.visible = true
    var target_id := str(qa.selected_target)
    var runtime: Variant = qa.slice.combat
    if target_id == "" or not runtime.has_method("subdue_status"):
        button.disabled = true
        button.tooltip_text = "Sélectionnez un ennemi vivant."
        info_label.text = "SOUMISSION · Sélectionnez un ennemi vivant."
        return

    var state: Dictionary = runtime.call("subdue_status", target_id)
    button.disabled = not bool(state.get("ok", false))
    var target_name := qa._display(target_id)
    if button.disabled:
        var reason := str(state.get("reason", "conditions_non_remplies"))
        if reason == "boss_not_subduable":
            button.tooltip_text = "Les boss ne peuvent pas être soumis."
            info_label.text = "SOUMISSION · %s est un boss : impossible." % target_name
            return
        if reason == "already_subdued":
            button.tooltip_text = "Cet ennemi est déjà soumis."
            info_label.text = "SOUMISSION · %s est déjà hors combat." % target_name
            return
        if reason == "target_dead":
            button.tooltip_text = "Une cible morte ne peut pas être soumise."
            info_label.text = "SOUMISSION · %s est mort." % target_name
            return
        if reason == "target_not_submittable":
            var hp_ratio := float(state.get("hp_ratio", 1.0)) * 100.0
            var resolve := int(state.get("resolve", 99))
            button.tooltip_text = "Soumission indisponible — PV %.0f%%, Résolution %d." % [hp_ratio, resolve]
            info_label.text = "SOUMISSION · %s · PV %.0f%% · Résolution %d\nVulnérable si PV ≤35%% OU Résolution ≤20 OU contrôle." % [target_name, hp_ratio, resolve]
            return
        button.tooltip_text = "Soumission indisponible."
        info_label.text = "SOUMISSION · %s · indisponible (%s)." % [target_name, reason]
        return

    var hp_ratio := float(state.get("hp_ratio", 1.0)) * 100.0
    var resolve := int(state.get("resolve", 0))
    var control := str(state.get("control_status", ""))
    var trigger := "contrôle %s" % control if control != "" else ("PV %.0f%%" % hp_ratio if hp_ratio <= 35.0 else "Résolution %d" % resolve)
    button.tooltip_text = "L'ennemi est vulnérable : le soumettre le retire du combat sans le tuer."
    info_label.text = "SOUMISSION DISPONIBLE · %s · %s\nLa cible restera vivante pour la décision post-combat." % [target_name, trigger]

func _on_pressed() -> void:
    var qa: VeilleursVerticalSliceQAV09 = _root_qa()
    if qa == null or qa.slice == null or qa.slice.combat == null:
        return
    var target_id := str(qa.selected_target)
    var result: Dictionary = qa.slice.combat.call("attempt_subdue", target_id)
    if not bool(result.get("ok", false)):
        qa.message_label.text = "Soumission impossible : %s" % str(result.get("reason", "conditions_non_remplies"))
        _refresh()
        return
    qa.message_label.text = "%s se rend. Il reste vivant et pourra être recruté, épargné ou abandonné après le combat." % qa._display(target_id)
    qa._check_combat_end_or_enemy_phase()
