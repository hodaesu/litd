extends Node
class_name VeilleursDarkUIRuntimeAdapter

## Runtime bridge that applies the approved Les Veilleurs dark-fantasy palette
## to UI built dynamically by the hub, menus, contextual panels, Remanence,
## inventory/equipment and skill screens. It never changes gameplay data.

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_apply_to_tree")

func _exit_tree() -> void:
    if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)

func _apply_to_tree() -> void:
    _apply_recursive(get_tree().root)

func _on_node_added(node: Node) -> void:
    if not is_inside_tree():
        return
    call_deferred("_apply_recursive", node)

func _apply_recursive(node: Node) -> void:
    if node == null or not is_instance_valid(node):
        return
    if node is Control:
        _skin_control(node as Control)
    for child: Node in node.get_children():
        _apply_recursive(child)

func _skin_control(control: Control) -> void:
    if control.get_meta("litd_dark_palette_applied", false):
        return
    control.set_meta("litd_dark_palette_applied", true)

    if control is Label:
        var label := control as Label
        if not label.has_theme_color_override("font_color"):
            label.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
        return

    if control is RichTextLabel:
        var rich := control as RichTextLabel
        rich.add_theme_color_override("default_color", UITokens.COLOR_IVORY)
        rich.add_theme_color_override("font_shadow_color", UITokens.COLOR_BACKGROUND)
        return

    if control is ProgressBar:
        _skin_progress(control as ProgressBar)
        return

    if control is Button:
        _skin_button(control as Button)
        return

    if control is LineEdit:
        _skin_line_edit(control as LineEdit)
        return

    if control is ItemList:
        _skin_item_list(control as ItemList)
        return

    if control is PanelContainer:
        (control as PanelContainer).add_theme_stylebox_override("panel", _panel_style())

func _skin_button(button: Button) -> void:
    button.focus_mode = Control.FOCUS_ALL
    if button.custom_minimum_size.y > 0.0:
        button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, UITokens.TOUCH_MIN_SIZE)
    var destructive := _looks_destructive(button.text)
    var accent := UITokens.COLOR_BLOOD_BRIGHT if destructive else UITokens.COLOR_OCHRE
    button.add_theme_stylebox_override("normal", _button_style(UITokens.COLOR_SURFACE, UITokens.COLOR_BORDER_METAL, 1))
    button.add_theme_stylebox_override("hover", _button_style(UITokens.COLOR_SURFACE_RAISED, accent.darkened(0.12), 1))
    button.add_theme_stylebox_override("pressed", _button_style(UITokens.COLOR_SURFACE_PRESSED, accent, 2))
    button.add_theme_stylebox_override("focus", _button_style(UITokens.COLOR_SURFACE_RAISED, accent, 2))
    button.add_theme_stylebox_override("disabled", _button_style(UITokens.COLOR_BACKGROUND, UITokens.COLOR_DISABLED, 1))
    button.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    button.add_theme_color_override("font_hover_color", UITokens.COLOR_IVORY)
    button.add_theme_color_override("font_pressed_color", UITokens.COLOR_IVORY)
    button.add_theme_color_override("font_focus_color", UITokens.COLOR_IVORY)
    button.add_theme_color_override("font_disabled_color", UITokens.COLOR_TEXT_MUTED.darkened(0.25))

func _skin_progress(bar: ProgressBar) -> void:
    var background := StyleBoxFlat.new()
    background.bg_color = UITokens.COLOR_BACKGROUND
    background.border_color = UITokens.COLOR_BORDER_METAL
    background.set_border_width_all(1)
    background.corner_radius_top_left = UITokens.CORNER_RADIUS_S
    background.corner_radius_top_right = UITokens.CORNER_RADIUS_S
    background.corner_radius_bottom_left = UITokens.CORNER_RADIUS_S
    background.corner_radius_bottom_right = UITokens.CORNER_RADIUS_S

    var fill := StyleBoxFlat.new()
    fill.bg_color = _semantic_gauge_color(bar)
    fill.border_color = UITokens.COLOR_BONE.darkened(0.35)
    fill.set_border_width_all(1)
    fill.corner_radius_top_left = UITokens.CORNER_RADIUS_S
    fill.corner_radius_top_right = UITokens.CORNER_RADIUS_S
    fill.corner_radius_bottom_left = UITokens.CORNER_RADIUS_S
    fill.corner_radius_bottom_right = UITokens.CORNER_RADIUS_S

    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    bar.add_theme_color_override("font_color", UITokens.COLOR_IVORY)

func _semantic_gauge_color(bar: ProgressBar) -> Color:
    var key := "%s %s" % [bar.name, str(bar.get_meta("semantic", ""))]
    key = key.to_lower()
    if "fear" in key or "folie" in key or "mental" in key:
        return UITokens.COLOR_VIOLET
    if "knowledge" in key or "remanence" in key or "rémanence" in key:
        return UITokens.COLOR_COLD_BLUE
    if "hope" in key or "focus" in key or "progress" in key:
        return UITokens.COLOR_OCHRE
    if "recovery" in key or "heal" in key or "stability" in key:
        return UITokens.COLOR_DESAT_GREEN
    return UITokens.COLOR_BLOOD

func _skin_line_edit(line_edit: LineEdit) -> void:
    line_edit.add_theme_stylebox_override("normal", _field_style(UITokens.COLOR_SURFACE, UITokens.COLOR_BORDER_METAL))
    line_edit.add_theme_stylebox_override("focus", _field_style(UITokens.COLOR_SURFACE_RAISED, UITokens.COLOR_COLD_BLUE))
    line_edit.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    line_edit.add_theme_color_override("font_placeholder_color", UITokens.COLOR_TEXT_MUTED)
    line_edit.add_theme_color_override("caret_color", UITokens.COLOR_OCHRE)

func _skin_item_list(item_list: ItemList) -> void:
    item_list.add_theme_stylebox_override("panel", _panel_style())
    item_list.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    item_list.add_theme_color_override("font_selected_color", UITokens.COLOR_IVORY)
    item_list.add_theme_color_override("guide_color", UITokens.COLOR_BORDER_METAL)

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = UITokens.COLOR_SURFACE
    style.border_color = UITokens.COLOR_BORDER_METAL
    style.set_border_width_all(1)
    style.corner_radius_top_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_top_right = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_right = UITokens.CORNER_RADIUS_M
    style.content_margin_left = UITokens.SPACE_M
    style.content_margin_right = UITokens.SPACE_M
    style.content_margin_top = UITokens.SPACE_M
    style.content_margin_bottom = UITokens.SPACE_M
    return style

func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.corner_radius_top_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_top_right = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_right = UITokens.CORNER_RADIUS_M
    style.content_margin_left = UITokens.SPACE_M
    style.content_margin_right = UITokens.SPACE_M
    style.content_margin_top = UITokens.SPACE_S
    style.content_margin_bottom = UITokens.SPACE_S
    return style

func _field_style(background: Color, border: Color) -> StyleBoxFlat:
    var style := _button_style(background, border, 1)
    style.content_margin_top = UITokens.SPACE_S
    style.content_margin_bottom = UITokens.SPACE_S
    return style

func _looks_destructive(text: String) -> bool:
    var lowered := text.to_lower()
    return "retour" in lowered or "quitter" in lowered or "abandon" in lowered or "détruire" in lowered or "supprimer" in lowered or "retraite" in lowered
