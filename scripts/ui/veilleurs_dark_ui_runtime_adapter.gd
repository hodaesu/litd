extends Node
class_name VeilleursDarkUIRuntimeAdapter

## Runtime bridge that applies the approved Les Veilleurs dark-fantasy palette
## and dedicated ornamental surfaces to UI built dynamically by the hub, menus,
## contextual panels, Remanence, inventory/equipment and skill screens.
## It never changes gameplay data.

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
        _skin_label(control as Label)
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

    if control is OptionButton:
        _skin_option_button(control as OptionButton)
        return

    if control is PanelContainer:
        _skin_panel(control as PanelContainer)
        return

    if control is HSeparator or control is VSeparator:
        control.modulate = Color(UITokens.COLOR_OCHRE.r, UITokens.COLOR_OCHRE.g, UITokens.COLOR_OCHRE.b, 0.42)

func _skin_label(label: Label) -> void:
    if not label.has_theme_color_override("font_color"):
        label.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    var size := label.get_theme_font_size("font_size")
    if size >= UITokens.TEXT_TITLE:
        label.add_theme_color_override("font_color", UITokens.COLOR_BONE)
        label.add_theme_color_override("font_shadow_color", UITokens.COLOR_BACKGROUND)
        label.add_theme_constant_override("shadow_offset_x", 1)
        label.add_theme_constant_override("shadow_offset_y", 2)
    elif size <= UITokens.TEXT_SMALL:
        label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

func _skin_button(button: Button) -> void:
    button.focus_mode = Control.FOCUS_ALL
    if button.custom_minimum_size.y > 0.0:
        button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, UITokens.TOUCH_MIN_SIZE)
    var accent := _semantic_button_accent(button)
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
    button.set_meta("litd_semantic_accent", accent.to_html())

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
    if "hope" in key or "focus" in key or "progress" in key or "xp" in key:
        return UITokens.COLOR_OCHRE
    if "recovery" in key or "heal" in key or "stability" in key or "stabil" in key:
        return UITokens.COLOR_DESAT_GREEN
    return UITokens.COLOR_BLOOD

func _skin_line_edit(line_edit: LineEdit) -> void:
    line_edit.add_theme_stylebox_override("normal", _field_style(UITokens.COLOR_SURFACE, UITokens.COLOR_BORDER_METAL))
    line_edit.add_theme_stylebox_override("focus", _field_style(UITokens.COLOR_SURFACE_RAISED, UITokens.COLOR_COLD_BLUE))
    line_edit.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    line_edit.add_theme_color_override("font_placeholder_color", UITokens.COLOR_TEXT_MUTED)
    line_edit.add_theme_color_override("caret_color", UITokens.COLOR_OCHRE)

func _skin_item_list(item_list: ItemList) -> void:
    item_list.add_theme_stylebox_override("panel", _panel_style(UITokens.COLOR_COLD_BLUE.darkened(0.45)))
    item_list.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    item_list.add_theme_color_override("font_selected_color", UITokens.COLOR_IVORY)
    item_list.add_theme_color_override("guide_color", UITokens.COLOR_BORDER_METAL)

func _skin_option_button(option: OptionButton) -> void:
    _skin_button(option)
    option.add_theme_icon_override("arrow", option.get_theme_icon("arrow"))

func _skin_panel(panel: PanelContainer) -> void:
    var accent := _semantic_panel_accent(panel)
    panel.add_theme_stylebox_override("panel", _panel_style(accent.darkened(0.42)))
    panel.set_meta("litd_semantic_accent", accent.to_html())
    if panel.get_node_or_null("LITDSectionFrame") == null:
        var frame := LITDSectionFrame.new()
        frame.name = "LITDSectionFrame"
        frame.accent = accent
        frame.intensity = 0.72
        panel.add_child(frame)
        panel.move_child(frame, panel.get_child_count() - 1)

func _semantic_button_accent(button: Button) -> Color:
    var text := button.text.to_lower()
    var name_key := button.name.to_lower()
    var key := "%s %s" % [text, name_key]
    if _looks_destructive(text):
        return UITokens.COLOR_BLOOD_BRIGHT
    if "archive" in key or "bestiaire" in key or "rémanence" in key or "remanence" in key or "connaissance" in key:
        return UITokens.COLOR_COLD_BLUE
    if "soin" in key or "infirmerie" in key or "stabilis" in key or "guér" in key:
        return UITokens.COLOR_DESAT_GREEN
    if "arbre" in key or "compétence" in key or "skill" in key or "ultime" in key:
        return UITokens.COLOR_VIOLET
    if "inventaire" in key or "équipement" in key or "equip" in key or "réserve" in key or "forge" in key:
        return UITokens.COLOR_OCHRE
    if "expédition" in key or "partir" in key or "combat" in key or "atta" in key:
        return UITokens.COLOR_BLOOD
    if "inspect" in key or "examiner" in key or "fouiller" in key or "étudier" in key:
        return UITokens.COLOR_DESAT_GREEN
    return UITokens.COLOR_OCHRE

func _semantic_panel_accent(panel: PanelContainer) -> Color:
    var key := _node_context_key(panel)
    if "archive" in key or "bestiaire" in key or "rémanence" in key or "remanence" in key or "knowledge" in key:
        return UITokens.COLOR_COLD_BLUE
    if "injur" in key or "bless" in key or "infirmer" in key or "anatom" in key:
        return UITokens.COLOR_DESAT_GREEN
    if "skill" in key or "compétence" in key or "arbre" in key or "training" in key:
        return UITokens.COLOR_VIOLET
    if "inventory" in key or "inventaire" in key or "equip" in key or "reserve" in key or "réserve" in key:
        return UITokens.COLOR_OCHRE
    if "combat" in key or "target" in key or "expedition" in key or "expédition" in key:
        return UITokens.COLOR_BLOOD
    return UITokens.COLOR_OCHRE

func _node_context_key(node: Node) -> String:
    var parts: Array[String] = []
    var cursor: Node = node
    var depth := 0
    while cursor != null and depth < 5:
        parts.append(cursor.name)
        cursor = cursor.get_parent()
        depth += 1
    if "GameState" in ProjectSettings.get_global_class_list():
        pass
    return " ".join(parts).to_lower()

func _panel_style(border: Color = UITokens.COLOR_BORDER_METAL) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = UITokens.COLOR_SURFACE
    style.border_color = border
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
