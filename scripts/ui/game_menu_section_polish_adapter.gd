extends Node

# Presentation-only polish pass for the unified game menu. It keeps the
# existing gameplay callbacks and data sources intact, and upgrades the four
# remaining utility-heavy sections so they read like final game UI rather than
# debug output.

const ART_REGISTRY := preload("res://scripts/visual/canonical_art_registry.gd")

const FALLBACK_GOLD := Color("#d5b26c")
const FALLBACK_PALE := Color("#e4c989")
const FALLBACK_TEXT := Color("#e5dccb")
const FALLBACK_MUTED := Color("#a49884")
const PANEL_BG := Color(0.032, 0.034, 0.044, 0.96)
const PANEL_BG_ALT := Color(0.047, 0.043, 0.038, 0.96)

var _menu
var _art := ART_REGISTRY.new()
var _polish_scheduled := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _install() -> void:
    _menu = get_node_or_null("/root/GameMenuUI")
    if _menu == null or not is_instance_valid(_menu.content):
        push_warning("GameMenuSectionPolishAdapter: GameMenuUI indisponible.")
        return
    if not bool(_menu.content.get_meta("litd_section_polish_connected", false)):
        _menu.content.set_meta("litd_section_polish_connected", true)
        _menu.content.child_entered_tree.connect(_on_content_changed)
    if is_instance_valid(_menu.overlay) and not bool(_menu.overlay.get_meta("litd_section_polish_visibility", false)):
        _menu.overlay.set_meta("litd_section_polish_visibility", true)
        _menu.overlay.visibility_changed.connect(_schedule_polish)
    _schedule_polish()

func _on_content_changed(_node: Node) -> void:
    _schedule_polish()

func _schedule_polish() -> void:
    if _polish_scheduled:
        return
    _polish_scheduled = true
    call_deferred("_polish_current_section")

func _polish_current_section() -> void:
    _polish_scheduled = false
    if _menu == null or not is_instance_valid(_menu.content):
        return
    match String(_menu.active_tab):
        "inventory":
            _polish_inventory()
        "journal":
            _polish_journal()
        "characters":
            if String(_menu.character_panel) == "equipment":
                _polish_equipment()
        "options":
            _polish_options()

func _polish_inventory() -> void:
    _style_section_label("CONSOMMABLES — 10 maximum par pile")
    _style_section_label("COFFRE COMMUN")
    _style_summary_label("Objets transportés :")

    for child in _menu.content.get_children():
        if child is HBoxContainer:
            var action := _find_button(child, "ÉQUIPER")
            if action != null:
                _style_action_button(action, false)
                _panelize_direct_child(child, "InventoryItemCard", false)
        elif child is Label:
            var label := child as Label
            if label.text.begins_with("• "):
                _style_secondary_line(label)

func _polish_equipment() -> void:
    _style_section_label("ÉQUIPEMENT PORTÉ")
    _style_section_label("ÉQUIPEMENT COMPATIBLE DISPONIBLE")

    for child in _menu.content.get_children():
        if child is HBoxContainer:
            var action := _find_button(child, "ÉQUIPER")
            if action != null:
                _style_action_button(action, false)
                _panelize_direct_child(child, "EquipmentCandidateCard", false)
        elif child is Label:
            var label := child as Label
            var text := label.text
            if text.begins_with("ARME ·") or text.begins_with("ARMURE ·") or text.begins_with("ANNEAU 1 ·") or text.begins_with("ANNEAU 2 ·") or text.begins_with("COLLIER ·"):
                _panelize_direct_child(label, "EquippedSlotCard", true)

func _polish_journal() -> void:
    _style_section_label("QUÊTES PRINCIPALES")
    _style_section_label("QUÊTES DE DONJON")
    _style_section_label("CONTRATS DE CHASSE")

    for child in _menu.content.get_children():
        if child is Button:
            var button := child as Button
            if button.text.begins_with("RENCONTRER "):
                _style_action_button(button, true)
                _panelize_direct_child(button, "QuestContactCard", true)
        elif child is Label:
            var label := child as Label
            if label.text.begins_with("◆ ") or label.text.begins_with("✓ ") or label.text.begins_with("◇ "):
                _style_quest_title(label)
            elif label.text.begins_with("Chapitre "):
                label.add_theme_font_size_override("font_size", 20)
                label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))

func _polish_options() -> void:
    _insert_options_header_before("Volume général", "AUDIO", "OptionsAudioHeader")
    _insert_options_header_before("Plein écran", "AFFICHAGE", "OptionsDisplayHeader")
    _insert_options_header_before("Taille du texte", "ACCESSIBILITÉ", "OptionsAccessibilityHeader")
    _insert_options_header_before("Vitesse des animations", "CONFORT", "OptionsComfortHeader")
    _insert_options_header_before("Plage dynamique", "RENDU ET ASSISTANCE", "OptionsRenderHeader")

    for child in _menu.content.get_children():
        if child is HBoxContainer:
            _style_option_row(child)
            _panelize_direct_child(child, "OptionRowCard", false)
        elif child is Button:
            var button := child as Button
            if button.text == "SAUVEGARDER LA PARTIE":
                _style_action_button(button, true)
            elif button.text == "RETOUR AU SANCTUAIRE":
                _style_action_button(button, false)
        elif child is Label:
            var label := child as Label
            if label.text.begins_with("Les réglages sont appliqués"):
                _style_summary_label("Les réglages sont appliqués")

func _style_option_row(row: HBoxContainer) -> void:
    row.add_theme_constant_override("separation", 18)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for child in row.get_children():
        if child is Label:
            var label := child as Label
            label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))
            label.add_theme_font_size_override("font_size", 15)
        elif child is HSlider:
            _style_slider(child as HSlider)
        elif child is CheckButton:
            _style_check_button(child as CheckButton)
        elif child is Button:
            _style_choice_button(child as Button)

func _style_slider(slider: HSlider) -> void:
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.add_theme_stylebox_override("slider", _flat_style(
        Color(0.018, 0.020, 0.027, 0.92),
        Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.36),
        5,
        1,
        3.0
    ))
    slider.add_theme_stylebox_override("grabber_area", _flat_style(
        Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.44),
        Color(_token_color("pale_bronze", FALLBACK_PALE), 0.72),
        5,
        1,
        3.0
    ))
    slider.add_theme_stylebox_override("grabber_area_highlight", _flat_style(
        Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.62),
        Color(_token_color("pale_bronze", FALLBACK_PALE), 0.94),
        5,
        1,
        3.0
    ))

func _style_check_button(toggle: CheckButton) -> void:
    var text := _token_color("bone_text", FALLBACK_TEXT)
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    toggle.add_theme_color_override("font_color", text)
    toggle.add_theme_color_override("font_hover_color", _token_color("pale_bronze", FALLBACK_PALE))
    toggle.add_theme_stylebox_override("normal", _flat_style(Color(0.020, 0.022, 0.029, 0.55), Color(gold, 0.18), 5, 1, 8.0))
    toggle.add_theme_stylebox_override("hover", _flat_style(Color(0.055, 0.048, 0.039, 0.82), Color(gold, 0.52), 5, 1, 8.0))
    toggle.add_theme_stylebox_override("focus", _flat_style(Color(0.0, 0.0, 0.0, 0.0), Color(gold, 0.78), 5, 1, 6.0))

func _style_choice_button(button: Button) -> void:
    var selected := button.text.begins_with("✓ ")
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var pale := _token_color("pale_bronze", FALLBACK_PALE)
    button.add_theme_color_override("font_color", pale if selected else _token_color("muted_text", FALLBACK_MUTED))
    button.add_theme_stylebox_override("normal", _flat_style(
        Color(0.072, 0.060, 0.043, 0.92) if selected else Color(0.022, 0.024, 0.031, 0.88),
        Color(gold, 0.78 if selected else 0.25),
        5,
        1,
        8.0
    ))
    button.add_theme_stylebox_override("hover", _flat_style(Color(0.080, 0.065, 0.046, 0.96), Color(gold, 0.72), 5, 1, 8.0))
    button.add_theme_stylebox_override("pressed", _flat_style(Color(0.095, 0.073, 0.047, 0.98), pale, 5, 1, 8.0))

func _style_action_button(button: Button, primary: bool) -> void:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var pale := _token_color("pale_bronze", FALLBACK_PALE)
    button.add_theme_color_override("font_color", pale if primary else _token_color("bone_text", FALLBACK_TEXT))
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_stylebox_override("normal", _flat_style(
        Color(0.086, 0.067, 0.043, 0.98) if primary else Color(0.031, 0.033, 0.041, 0.96),
        Color(gold, 0.88 if primary else 0.48),
        5,
        1,
        10.0
    ))
    button.add_theme_stylebox_override("hover", _flat_style(Color(0.112, 0.082, 0.050, 0.99), pale, 5, 1, 10.0))
    button.add_theme_stylebox_override("pressed", _flat_style(Color(0.060, 0.049, 0.038, 1.0), Color(gold, 0.95), 5, 1, 10.0))
    button.add_theme_stylebox_override("focus", _flat_style(Color(0.0, 0.0, 0.0, 0.0), Color(pale, 0.88), 5, 1, 6.0))

func _style_section_label(exact_text: String) -> void:
    for child in _menu.content.get_children():
        if child is Label and (child as Label).text == exact_text:
            var label := child as Label
            label.add_theme_font_size_override("font_size", 17)
            label.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
            label.custom_minimum_size.y = 34
            return

func _style_summary_label(prefix: String) -> void:
    for child in _menu.content.get_children():
        if child is Label and (child as Label).text.begins_with(prefix):
            var label := child as Label
            label.add_theme_color_override("font_color", _token_color("muted_text", FALLBACK_MUTED))
            label.add_theme_font_size_override("font_size", 14)
            return

func _style_secondary_line(label: Label) -> void:
    label.add_theme_color_override("font_color", _token_color("muted_text", FALLBACK_MUTED))
    label.add_theme_font_size_override("font_size", 13)

func _style_quest_title(label: Label) -> void:
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))
    label.custom_minimum_size.y = 28

func _insert_options_header_before(row_title: String, header_text: String, node_name: String) -> void:
    if _menu.content.get_node_or_null(node_name) != null:
        return
    for child in _menu.content.get_children():
        if child is not HBoxContainer:
            continue
        if _row_title(child) != row_title:
            continue
        var header := Label.new()
        header.name = node_name
        header.text = header_text
        header.custom_minimum_size = Vector2(0, 34)
        header.add_theme_font_size_override("font_size", 16)
        header.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
        var index: int = int(child.get_index())
        _menu.content.add_child(header)
        _menu.content.move_child(header, index)
        return

func _row_title(row: HBoxContainer) -> String:
    for child in row.get_children():
        if child is Label:
            return (child as Label).text
    return ""

func _find_button(container: Container, exact_text: String) -> Button:
    for child in container.get_children():
        if child is Button and (child as Button).text == exact_text:
            return child as Button
    return null

func _panelize_direct_child(control: Control, base_name: String, accent: bool) -> void:
    if control.get_parent() != _menu.content:
        return
    if bool(control.get_meta("litd_panelized", false)):
        return
    control.set_meta("litd_panelized", true)
    var index: int = control.get_index()
    var panel := PanelContainer.new()
    panel.name = "%s_%d" % [base_name, index]
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _card_style(accent))
    _menu.content.remove_child(control)
    panel.add_child(control)
    _menu.content.add_child(panel)
    _menu.content.move_child(panel, index)

func _card_style(accent: bool) -> StyleBoxFlat:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG_ALT if accent else PANEL_BG
    style.border_color = Color(gold, 0.54 if accent else 0.24)
    style.border_width_left = 2 if accent else 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 9.0
    style.content_margin_bottom = 9.0
    return style

func _flat_style(background: Color, border: Color, radius: int, border_width: int, margin: float) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin * 0.55
    style.content_margin_bottom = margin * 0.55
    return style

func _token_color(token_name: String, fallback: Color) -> Color:
    var value := String(_art.token("colors", token_name, ""))
    if value == "":
        return fallback
    return Color.from_string(value, fallback)
