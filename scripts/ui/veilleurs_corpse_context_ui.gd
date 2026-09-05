extends CanvasLayer
class_name VeilleursCorpseContextUI

var panel: PanelContainer
var title_label: Label
var description_label: Label
var options: VBoxContainer
var current_scar_id := ""
var pending_irreversible := ""

func _ready() -> void:
    layer = 42
    _build()
    VeilleursCorpseInteractionRuntime.corpse_previewed.connect(_on_preview)
    VeilleursCorpseInteractionRuntime.corpse_action_resolved.connect(_on_resolved)
    get_viewport().size_changed.connect(_apply_layout)
    _apply_layout()

func _build() -> void:
    panel = PanelContainer.new()
    panel.name = "CorpseContextPanel"
    panel.visible = false
    add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    panel.add_child(column)

    var header := HBoxContainer.new()
    header.custom_minimum_size = Vector2(0, 54)
    column.add_child(header)
    title_label = Label.new()
    title_label.add_theme_font_size_override("font_size", 21)
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_label)
    var close := Button.new()
    close.text = "FERMER"
    close.custom_minimum_size = Vector2(120, 54)
    close.pressed.connect(_close)
    header.add_child(close)

    description_label = Label.new()
    description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description_label.custom_minimum_size = Vector2(0, 72)
    description_label.add_theme_font_size_override("font_size", 15)
    column.add_child(description_label)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 250)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)
    options = VBoxContainer.new()
    options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    options.add_theme_constant_override("separation", 8)
    scroll.add_child(options)

func _apply_layout() -> void:
    if panel == null:
        return
    var size := get_viewport().get_visible_rect().size
    if size.x < 950.0:
        panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        panel.offset_left = 12
        panel.offset_right = -12
        panel.offset_top = -410
        panel.offset_bottom = -86
    else:
        panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
        panel.offset_left = -550
        panel.offset_right = -20
        panel.offset_top = -300
        panel.offset_bottom = 300

func _on_preview(scar_id: String, preview: Dictionary) -> void:
    current_scar_id = scar_id
    pending_irreversible = ""
    panel.visible = true
    title_label.text = str(preview.get("title", "Corps"))
    description_label.text = str(preview.get("description", ""))
    _clear_options()
    for value: Variant in preview.get("options", []):
        if not (value is Dictionary):
            continue
        var option: Dictionary = value
        var action_id := str(option.get("id", ""))
        var button := Button.new()
        button.text = str(option.get("label", action_id.to_upper()))
        button.tooltip_text = str(option.get("description", ""))
        button.custom_minimum_size = Vector2(320, 56)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_choose.bind(action_id, bool(option.get("irreversible", false))))
        options.add_child(button)

func _choose(action_id: String, irreversible: bool) -> void:
    if current_scar_id == "":
        return
    if irreversible:
        pending_irreversible = action_id
        _show_confirmation(action_id)
        return
    VeilleursCorpseInteractionRuntime.execute(current_scar_id, action_id)

func _show_confirmation(action_id: String) -> void:
    _clear_options()
    var warning := Label.new()
    warning.text = "Action irréversible : elle modifiera durablement ce corps et sa Rémanence."
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warning.add_theme_font_size_override("font_size", 16)
    options.add_child(warning)
    var confirm := Button.new()
    confirm.text = "CONFIRMER"
    confirm.custom_minimum_size = Vector2(320, 58)
    confirm.pressed.connect(_confirm.bind(action_id))
    options.add_child(confirm)
    var cancel := Button.new()
    cancel.text = "ANNULER"
    cancel.custom_minimum_size = Vector2(320, 56)
    cancel.pressed.connect(_repreview)
    options.add_child(cancel)

func _confirm(action_id: String) -> void:
    if action_id != pending_irreversible or current_scar_id == "":
        return
    pending_irreversible = ""
    VeilleursCorpseInteractionRuntime.execute(current_scar_id, action_id)

func _on_resolved(scar_id: String, action_id: String, result: Dictionary) -> void:
    if not bool(result.get("ok", false)):
        GameState.add_log("Action sur le corps impossible : %s" % str(result.get("reason", "indisponible")))
        if scar_id == current_scar_id:
            _repreview()
        return
    if action_id != "inspect":
        _materialize_world()
        if VeilleursVS001WorldRuntime.is_active():
            SaveManager.autosave("VS001 · corps %s · %s" % [scar_id, action_id])
    if scar_id == current_scar_id:
        _repreview()

func _materialize_world() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var layer_node := scene.get_node_or_null("PersistentWorld")
    if layer_node != null and layer_node.has_method("materialize_corpses"):
        layer_node.call_deferred("materialize_corpses")

func _repreview() -> void:
    if current_scar_id != "":
        VeilleursCorpseInteractionRuntime.preview(current_scar_id)

func _close() -> void:
    current_scar_id = ""
    pending_irreversible = ""
    panel.visible = false
    _clear_options()

func _clear_options() -> void:
    if options == null:
        return
    for child: Node in options.get_children():
        child.queue_free()
