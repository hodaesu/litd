extends Node

# Final presentation pass outside the pause menu. This adapter only restructures
# and styles already-existing controls; gameplay callbacks, state and save data
# remain owned by their original runtimes.

const ART_REGISTRY := preload("res://scripts/visual/canonical_art_registry.gd")

const FALLBACK_GOLD := Color("#d5b26c")
const FALLBACK_PALE := Color("#e4c989")
const FALLBACK_TEXT := Color("#e5dccb")
const FALLBACK_MUTED := Color("#a49884")
const SURFACE := Color(0.024, 0.026, 0.034, 0.94)
const SURFACE_STRONG := Color(0.014, 0.016, 0.022, 0.975)

var _main: Node
var _art := ART_REGISTRY.new()
var _polish_scheduled := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _install() -> void:
    _main = get_parent()
    if _main == null:
        push_warning("HUDContextSanctuaryPolishAdapter: Main indisponible.")
        return
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not GameState.state_changed.is_connected(_on_state_changed):
        GameState.state_changed.connect(_on_state_changed)
    if not get_tree().node_added.is_connected(_on_tree_node_added):
        get_tree().node_added.connect(_on_tree_node_added)
    _schedule_polish()

func _on_screen_requested(_screen_name: String) -> void:
    _schedule_polish()

func _on_state_changed() -> void:
    _schedule_polish()

func _on_tree_node_added(node: Node) -> void:
    if node.name == "PsychologyEventBanner" or node.name == "TransientExplorationHUD":
        call_deferred("_polish_transient_panel", node)
    elif node.name == "CanonicalLocationFeedback":
        _schedule_polish()

func _schedule_polish() -> void:
    if _polish_scheduled:
        return
    _polish_scheduled = true
    call_deferred("_polish_current_screen")

func _polish_current_screen() -> void:
    _polish_scheduled = false
    if _main == null:
        return
    _polish_header()
    match str(GameState.current_screen):
        "combat":
            _polish_combat_hud()
        "hud_reference":
            _polish_hud_reference()
        "contextual":
            _polish_contextual_screen()
        "sanctuary":
            _polish_sanctuary()
    _polish_existing_transient_overlays()

func _main_root() -> Control:
    if _main == null:
        return null
    var value: Variant = _main.get("root")
    if value is Control:
        return value as Control
    return null

func _main_content() -> Control:
    if _main == null:
        return null
    var value: Variant = _main.get("content")
    if value is Control:
        return value as Control
    return null

func _polish_header() -> void:
    var root := _main_root()
    if root == null:
        return
    var header := root.get_node_or_null("Header") as HBoxContainer
    if header == null:
        return

    header.add_theme_constant_override("separation", 10)
    var surface := root.get_node_or_null("CanonicalHeaderSurface") as PanelContainer
    if surface == null:
        surface = PanelContainer.new()
        surface.name = "CanonicalHeaderSurface"
        surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
        surface.set_anchors_preset(Control.PRESET_TOP_WIDE)
        surface.offset_bottom = 64.0
        root.add_child(surface)
        root.move_child(surface, header.get_index())
    surface.visible = header.visible
    surface.add_theme_stylebox_override("panel", _flat_style(
        SURFACE_STRONG,
        Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.34),
        0,
        1,
        0.0
    ))

    for key in ["Gold", "Essence", "Lumière", "Vivres"]:
        var label := header.get_node_or_null(key) as Label
        if label == null:
            continue
        label.custom_minimum_size = Vector2(104.0, 44.0)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 14)
        label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))
        label.add_theme_stylebox_override("normal", _flat_style(
            Color(0.032, 0.034, 0.043, 0.92),
            Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.28),
            5,
            1,
            8.0
        ))

    for child in header.get_children():
        if child is Label:
            var title := child as Label
            if title.text == "LIGHT IN THE DARK":
                title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                title.add_theme_font_size_override("font_size", 24)
                title.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
        elif child is Button:
            var action := child as Button
            if action.name == "CanonicalMenu" or action.name == "CanonicalContext":
                _style_header_action(action)

func _polish_combat_hud() -> void:
    var content := _main_content()
    if content == null:
        return
    var panel := content.get_node_or_null("CanonicalCombatHUD") as PanelContainer
    if panel == null:
        return

    panel.position = Vector2(874.0, 10.0)
    panel.size = Vector2(376.0, 48.0 + float(GameState.party.size()) * 25.0)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _flat_style(
        Color(0.012, 0.013, 0.019, 0.94),
        Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.66),
        5,
        1,
        10.0
    ))

    for child in panel.get_children():
        panel.remove_child(child)
        child.queue_free()

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    panel.add_child(column)

    var heading := HBoxContainer.new()
    column.add_child(heading)
    var title := _label("ÉTAT DE COMBAT", 12, _token_color("pale_bronze", FALLBACK_PALE))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title)
    heading.add_child(_label("VEILLEURS", 10, _token_color("muted_text", FALLBACK_MUTED)))

    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(0.0, 21.0)
        row.add_theme_constant_override("separation", 8)
        column.add_child(row)

        var hero_name := _label(str(hero.get("name", "Veilleur")), 11, _token_color("bone_text", FALLBACK_TEXT))
        hero_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hero_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        row.add_child(hero_name)
        row.add_child(_label("PV %d/%d" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 0))], 11, _token_color("bone_text", FALLBACK_TEXT)))
        row.add_child(_label("P %d · F %d" % [int(hero.get("fear", 0)), int(hero.get("madness", 0))], 10, _token_color("muted_text", FALLBACK_MUTED)))

func _polish_hud_reference() -> void:
    var content := _main_content()
    if content == null:
        return
    for node_value in content.find_children("*", "VBoxContainer", true, false):
        var box := node_value as VBoxContainer
        if box == null:
            continue
        for child in box.get_children():
            if child is not Label:
                continue
            var label := child as Label
            if label.text.contains(" · PV ") and label.get_parent() == box:
                _wrap_label(box, label, "HUDReferenceHero", false)

func _polish_contextual_screen() -> void:
    var content := _main_content()
    if content == null:
        return
    for node_value in content.find_children("*", "VBoxContainer", true, false):
        var box := node_value as VBoxContainer
        if box == null:
            continue
        for child in box.get_children():
            if child is not Label:
                continue
            var label := child as Label
            var text := label.text.strip_edges()
            if text.length() >= 4 and text.substr(0, 1).is_valid_int() and text.contains("·") and label.get_parent() == box:
                _wrap_label(box, label, "ContextTip", true)

    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null and button.text == "RETOUR":
            _style_action_button(button, true)

func _polish_sanctuary() -> void:
    var content := _main_content()
    if content == null:
        return

    var veil := content.get_node_or_null("SanctuaryTopVeil") as ColorRect
    if veil == null:
        veil = ColorRect.new()
        veil.name = "SanctuaryTopVeil"
        veil.color = Color(0.006, 0.007, 0.011, 0.68)
        veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
        veil.set_anchors_preset(Control.PRESET_TOP_WIDE)
        veil.offset_bottom = 78.0
        content.add_child(veil)
        content.move_child(veil, mini(1, content.get_child_count() - 1))

    for node_value in content.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label == null:
            continue
        if label.text == "SANCTUAIRE DU PREMIER VOILE":
            label.add_theme_font_size_override("font_size", 25)
            label.add_theme_constant_override("outline_size", 3)
            label.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
            label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))

    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null:
            continue
        if bool(button.get_meta("litd_location_hotspot", false)):
            _polish_location_feedback(button)
            continue
        if button.text == "SAUVEGARDER":
            _style_action_button(button, true)
        elif button.text == "CARACTÉRISTIQUES DU HÉROS":
            _style_action_button(button, false)

func _polish_location_feedback(button: Button) -> void:
    var overlay := button.get_node_or_null("CanonicalLocationFeedback") as Control
    if overlay == null:
        return
    var glow := overlay.get_node_or_null("Glow") as Label
    var underline := overlay.get_node_or_null("Underline") as ColorRect
    if glow != null:
        glow.add_theme_font_size_override("font_size", 18)
        glow.add_theme_constant_override("outline_size", 4)
    if underline != null and underline.color.a > 0.0:
        var gold := _token_color("worn_bronze", FALLBACK_GOLD)
        underline.color = Color(gold, underline.color.a)

func _polish_existing_transient_overlays() -> void:
    for node_name in ["PsychologyEventBanner", "TransientExplorationHUD"]:
        var panel := get_tree().root.find_child(node_name, true, false) as PanelContainer
        if panel != null:
            _polish_transient_panel(panel)

func _polish_transient_panel(node: Node) -> void:
    if node is not PanelContainer:
        return
    var panel := node as PanelContainer
    var stronger := panel.name == "PsychologyEventBanner"
    panel.add_theme_stylebox_override("panel", _flat_style(
        Color(0.016, 0.018, 0.024, 0.96 if stronger else 0.92),
        Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.78 if stronger else 0.52),
        5,
        2 if stronger else 1,
        12.0
    ))
    for child in panel.get_children():
        if child is Label:
            var label := child as Label
            label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))
            label.add_theme_font_size_override("font_size", 15 if stronger else 14)
            label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _wrap_label(parent: VBoxContainer, label: Label, base_name: String, accent: bool) -> void:
    if label.get_parent() != parent:
        return
    var index: int = label.get_index()
    var card := PanelContainer.new()
    card.name = "%s_%d" % [base_name, index]
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override("panel", _card_style(accent))
    parent.remove_child(label)
    card.add_child(label)
    parent.add_child(card)
    parent.move_child(card, index)
    label.custom_minimum_size = Vector2(0.0, 38.0)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))

func _style_header_action(button: Button) -> void:
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
    button.add_theme_color_override("font_hover_color", _token_color("bone_text", FALLBACK_TEXT))
    button.add_theme_stylebox_override("normal", _flat_style(Color(0.022, 0.024, 0.031, 0.78), Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.30), 5, 1, 8.0))
    button.add_theme_stylebox_override("hover", _flat_style(Color(0.066, 0.055, 0.041, 0.94), Color(_token_color("pale_bronze", FALLBACK_PALE), 0.72), 5, 1, 8.0))
    button.add_theme_stylebox_override("pressed", _flat_style(Color(0.088, 0.067, 0.043, 0.98), _token_color("pale_bronze", FALLBACK_PALE), 5, 1, 8.0))
    button.add_theme_stylebox_override("focus", _flat_style(Color(0.0, 0.0, 0.0, 0.0), Color(_token_color("pale_bronze", FALLBACK_PALE), 0.86), 5, 1, 5.0))

func _style_action_button(button: Button, primary: bool) -> void:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var pale := _token_color("pale_bronze", FALLBACK_PALE)
    button.focus_mode = Control.FOCUS_ALL
    button.flat = false
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", pale if primary else _token_color("bone_text", FALLBACK_TEXT))
    button.add_theme_stylebox_override("normal", _flat_style(
        Color(0.078, 0.060, 0.039, 0.94) if primary else Color(0.020, 0.022, 0.029, 0.86),
        Color(gold, 0.82 if primary else 0.40),
        5,
        1,
        9.0
    ))
    button.add_theme_stylebox_override("hover", _flat_style(Color(0.096, 0.073, 0.047, 0.98), Color(pale, 0.86), 5, 1, 9.0))
    button.add_theme_stylebox_override("pressed", _flat_style(Color(0.055, 0.045, 0.035, 1.0), pale, 5, 1, 9.0))
    button.add_theme_stylebox_override("focus", _flat_style(Color(0.0, 0.0, 0.0, 0.0), Color(pale, 0.90), 5, 1, 5.0))

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return label

func _card_style(accent: bool) -> StyleBoxFlat:
    return _flat_style(
        Color(0.031, 0.032, 0.041, 0.92),
        Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.54 if accent else 0.28),
        5,
        2 if accent else 1,
        12.0
    )

func _flat_style(background: Color, border: Color, radius: int, border_width: int, margin: float) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin * 0.65
    style.content_margin_bottom = margin * 0.65
    return style

func _token_color(token_name: String, fallback: Color) -> Color:
    var value := str(_art.token("colors", token_name, ""))
    if value == "":
        return fallback
    return Color.from_string(value, fallback)
