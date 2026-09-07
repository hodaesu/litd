extends Control
class_name VeilleursSubmissionControlV09

var button: Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    offset_left = -196
    offset_top = -132
    offset_right = -16
    offset_bottom = -80
    button = Button.new()
    button.text = "Soumettre cible"
    button.custom_minimum_size = Vector2(180, 48)
    button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    button.pressed.connect(_on_pressed)
    add_child(button)
    set_process(true)
    _refresh()

func _process(_delta: float) -> void:
    _refresh()

func _root_qa() -> Node:
    var node: Node = get_parent()
    while node != null:
        if node is VeilleursVerticalSliceQAV09:
            return node
        node = node.get_parent()
    return null

func _refresh() -> void:
    if button == null:
        return
    var qa := _root_qa()
    if qa == null or qa.slice == null or qa.slice.combat == null:
        visible = false
        return
    visible = true
    var target_id := str(qa.selected_target)
    var runtime: Variant = qa.slice.combat
    if target_id == "" or not runtime.has_method("subdue_status"):
        button.disabled = true
        button.tooltip_text = "Sélectionnez un ennemi vivant."
        return
    var state: Dictionary = runtime.call("subdue_status", target_id)
    button.disabled = not bool(state.get("ok", false))
    if button.disabled:
        var hp_ratio := float(state.get("hp_ratio", 1.0)) * 100.0
        var resolve := int(state.get("resolve", 99))
        button.tooltip_text = "Soumission indisponible — PV %.0f%%, Résolution %d. Seuils : PV ≤35%%, Résolution ≤20 ou contrôle." % [hp_ratio, resolve]
    else:
        button.tooltip_text = "L'ennemi est vulnérable : le soumettre le retire du combat sans le tuer."

func _on_pressed() -> void:
    var qa := _root_qa()
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
