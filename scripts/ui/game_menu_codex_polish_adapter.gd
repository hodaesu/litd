extends Node

# Final presentation pass for the remaining information-heavy game-menu sections.
# This adapter only reorganizes and styles existing runtime controls; gameplay data,
# callbacks, save rules and progression systems remain owned by GameMenuUI.

const ART_REGISTRY := preload("res://scripts/visual/canonical_art_registry.gd")

const FALLBACK_GOLD := Color("#d5b26c")
const FALLBACK_PALE := Color("#e4c989")
const FALLBACK_TEXT := Color("#e5dccb")
const FALLBACK_MUTED := Color("#a49884")
const PANEL_BG := Color(0.028, 0.030, 0.039, 0.97)
const PANEL_BG_ALT := Color(0.052, 0.045, 0.035, 0.97)

var _menu
var _art := ART_REGISTRY.new()
var _polish_scheduled := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _install() -> void:
    _menu = get_node_or_null("/root/GameMenuUI")
    if _menu == null or not is_instance_valid(_menu.content):
        push_warning("GameMenuCodexPolishAdapter: GameMenuUI indisponible.")
        return
    if not bool(_menu.content.get_meta("litd_codex_polish_connected", false)):
        _menu.content.set_meta("litd_codex_polish_connected", true)
        _menu.content.child_entered_tree.connect(_on_content_changed)
    if is_instance_valid(_menu.overlay) and not bool(_menu.overlay.get_meta("litd_codex_polish_visibility", false)):
        _menu.overlay.set_meta("litd_codex_polish_visibility", true)
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
        "map":
            _polish_map()
        "bestiary":
            _polish_bestiary()
        "records":
            _polish_records()
        "chronicle":
            _polish_chronicle()
        "reports":
            _polish_reports()
        "help":
            _polish_help()
        "saves":
            _polish_saves()

func _polish_map() -> void:
    _style_summary_prefix("Zones découvertes :")
    _style_section_label("RACCOURCIS OUVERTS")
    _insert_section_before_first_marker("ZONES DÉCOUVERTES", "MapZonesHeader", ["◆ ", "◇ "])

    var children: Array[Node] = _direct_children_snapshot()
    for child: Node in children:
        if child is not Label or child.get_parent() != _menu.content:
            continue
        var label := child as Label
        if label.text.begins_with("Position actuelle :"):
            _style_lead_label(label)
            _panelize_label(label, "MapCurrentPosition", true)
        elif label.text.begins_with("◆ "):
            _style_entry_title(label, true, false)
            _panelize_label(label, "MapCurrentZone", true)
        elif label.text.begins_with("◇ "):
            _style_entry_title(label, false, false)
            _panelize_label(label, "MapKnownZone", false)
        elif label.text.begins_with("• "):
            _style_secondary_line(label)
            _panelize_label(label, "MapShortcut", false)

func _polish_bestiary() -> void:
    _style_summary_prefix("Le codex révèle progressivement")
    var children: Array[Node] = _direct_children_snapshot()
    var index: int = 0
    while index < children.size():
        var node: Node = children[index]
        if node is Label and node.get_parent() == _menu.content:
            var title := node as Label
            if title.text.begins_with("◆ ") and title.text.contains("CONNAISSANCE"):
                var detail: Label = null
                if index + 1 < children.size():
                    var candidate: Node = children[index + 1]
                    if candidate is Label and candidate.get_parent() == _menu.content:
                        var candidate_label := candidate as Label
                        if not candidate_label.text.begins_with("◆ "):
                            detail = candidate_label
                var revealed := not title.text.contains("Silhouette inconnue")
                var captured := title.text.contains("CAPTURÉE")
                _style_entry_title(title, captured, not revealed)
                if detail != null:
                    _style_secondary_line(detail)
                _group_labels(title, detail, "BestiaryEntry", captured)
                if detail != null:
                    index += 1
        index += 1

func _polish_records() -> void:
    _style_section_label("CONTRATS DE CHASSE ACTIFS")
    _style_section_label("FAITS D’ARMES DE LA COMPAGNIE")
    var children: Array[Node] = _direct_children_snapshot()
    for child: Node in children:
        if child is not Label or child.get_parent() != _menu.content:
            continue
        var label := child as Label
        if label.text.begins_with("• "):
            _style_entry_title(label, false, false)
            _panelize_label(label, "BountyContract", true)
        elif label.text.begins_with("◆ "):
            var empty_deed := label.text.contains("aucun fait d’armes")
            _style_entry_title(label, not empty_deed, empty_deed)
            _panelize_label(label, "CompanyDeed", not empty_deed)

func _polish_chronicle() -> void:
    for heading: String in ["MÉMORIAL", "DÉCISIONS ET CONSÉQUENCES", "ADVERSAIRES NOTABLES", "ÉVOLUTION DU SANCTUAIRE"]:
        _style_section_label(heading)
    var children: Array[Node] = _direct_children_snapshot()
    var section := ""
    for child: Node in children:
        if child is not Label or child.get_parent() != _menu.content:
            continue
        var label := child as Label
        if label.text in ["MÉMORIAL", "DÉCISIONS ET CONSÉQUENCES", "ADVERSAIRES NOTABLES", "ÉVOLUTION DU SANCTUAIRE"]:
            section = label.text
            continue
        if label.text.begins_with("◆ ") or label.text.begins_with("• "):
            var accent := section == "MÉMORIAL" or section == "ADVERSAIRES NOTABLES"
            _style_entry_title(label, accent, false)
            _panelize_label(label, "ChronicleEntry", accent)

func _polish_reports() -> void:
    var children: Array[Node] = _direct_children_snapshot()
    var index: int = 0
    while index < children.size():
        var node: Node = children[index]
        if node is Label and node.get_parent() == _menu.content:
            var title := node as Label
            if title.text.begins_with("◆ ") and (title.text.contains("VICTOIRE") or title.text.contains("ÉCHEC")):
                var detail: Label = null
                if index + 1 < children.size():
                    var candidate: Node = children[index + 1]
                    if candidate is Label and candidate.get_parent() == _menu.content:
                        detail = candidate as Label
                var victory := title.text.contains("VICTOIRE")
                _style_entry_title(title, victory, false)
                if detail != null:
                    _style_secondary_line(detail)
                _group_labels(title, detail, "ExpeditionReport", victory)
                if detail != null:
                    index += 1
        index += 1

func _polish_help() -> void:
    var children: Array[Node] = _direct_children_snapshot()
    var index: int = 0
    while index < children.size():
        var node: Node = children[index]
        if node is Label and node.get_parent() == _menu.content:
            var title := node as Label
            if title.text.begins_with("◆ "):
                var body: Label = null
                if index + 1 < children.size():
                    var candidate: Node = children[index + 1]
                    if candidate is Label and candidate.get_parent() == _menu.content:
                        body = candidate as Label
                _style_entry_title(title, true, false)
                if body != null:
                    body.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))
                    body.add_theme_font_size_override("font_size", 14)
                    body.custom_minimum_size.y = 38
                _group_labels(title, body, "HelpTopic", false)
                if body != null:
                    index += 1
        index += 1

func _polish_saves() -> void:
    var children: Array[Node] = _direct_children_snapshot()
    for child: Node in children:
        if child is Label and child.get_parent() == _menu.content:
            var status := child as Label
            if not status.text.is_empty():
                _style_summary_label(status)
        elif child is HBoxContainer and child.get_parent() == _menu.content:
            var row := child as HBoxContainer
            var slot_label := _first_label(row)
            var save_button := _find_button(row, "SAUVER")
            var load_button := _find_button(row, "CHARGER")
            if slot_label != null:
                var is_empty := slot_label.text.contains("— Vide")
                slot_label.add_theme_font_size_override("font_size", 15)
                slot_label.add_theme_color_override("font_color", _token_color("muted_text", FALLBACK_MUTED) if is_empty else _token_color("bone_text", FALLBACK_TEXT))
            if save_button != null:
                _style_action_button(save_button, false)
                if save_button.disabled:
                    _style_disabled_button(save_button)
            if load_button != null:
                _style_action_button(load_button, true)
                if load_button.disabled:
                    _style_disabled_button(load_button)
            var accent := slot_label != null and not slot_label.text.contains("— Vide")
            _panelize_control(row, "SaveSlot", accent)

func _insert_section_before_first_marker(header_text: String, node_name: String, prefixes: Array[String]) -> void:
    if _menu.content.get_node_or_null(node_name) != null:
        return
    for child: Node in _menu.content.get_children():
        if child is not Label:
            continue
        var label := child as Label
        var matches := false
        for prefix: String in prefixes:
            if label.text.begins_with(prefix):
                matches = true
                break
        if not matches:
            continue
        var header := Label.new()
        header.name = node_name
        header.text = header_text
        header.custom_minimum_size = Vector2(0, 34)
        header.add_theme_font_size_override("font_size", 17)
        header.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
        var position: int = int(child.get_index())
        _menu.content.add_child(header)
        _menu.content.move_child(header, position)
        return

func _style_section_label(exact_text: String) -> void:
    for child: Node in _menu.content.get_children():
        if child is Label and (child as Label).text == exact_text:
            var label := child as Label
            label.add_theme_font_size_override("font_size", 17)
            label.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
            label.custom_minimum_size.y = 34
            return

func _style_summary_prefix(prefix: String) -> void:
    for child: Node in _menu.content.get_children():
        if child is Label and (child as Label).text.begins_with(prefix):
            _style_summary_label(child as Label)
            return

func _style_summary_label(label: Label) -> void:
    label.add_theme_color_override("font_color", _token_color("muted_text", FALLBACK_MUTED))
    label.add_theme_font_size_override("font_size", 14)
    label.custom_minimum_size.y = 28

func _style_lead_label(label: Label) -> void:
    label.add_theme_font_size_override("font_size", 17)
    label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))
    label.custom_minimum_size.y = 36

func _style_entry_title(label: Label, accent: bool, muted: bool) -> void:
    label.add_theme_font_size_override("font_size", 16)
    if muted:
        label.add_theme_color_override("font_color", _token_color("muted_text", FALLBACK_MUTED))
    elif accent:
        label.add_theme_color_override("font_color", _token_color("pale_bronze", FALLBACK_PALE))
    else:
        label.add_theme_color_override("font_color", _token_color("bone_text", FALLBACK_TEXT))
    label.custom_minimum_size.y = 30

func _style_secondary_line(label: Label) -> void:
    label.add_theme_color_override("font_color", _token_color("muted_text", FALLBACK_MUTED))
    label.add_theme_font_size_override("font_size", 13)
    label.custom_minimum_size.y = 24

func _style_action_button(button: Button, primary: bool) -> void:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var pale := _token_color("pale_bronze", FALLBACK_PALE)
    button.add_theme_color_override("font_color", pale if primary else _token_color("bone_text", FALLBACK_TEXT))
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_stylebox_override("normal", _flat_style(
        Color(0.086, 0.067, 0.043, 0.98) if primary else Color(0.031, 0.033, 0.041, 0.96),
        Color(gold, 0.88 if primary else 0.48), 5, 1, 10.0))
    button.add_theme_stylebox_override("hover", _flat_style(Color(0.112, 0.082, 0.050, 0.99), pale, 5, 1, 10.0))
    button.add_theme_stylebox_override("pressed", _flat_style(Color(0.060, 0.049, 0.038, 1.0), Color(gold, 0.95), 5, 1, 10.0))
    button.add_theme_stylebox_override("focus", _flat_style(Color(0.0, 0.0, 0.0, 0.0), Color(pale, 0.88), 5, 1, 6.0))

func _style_disabled_button(button: Button) -> void:
    button.add_theme_color_override("font_disabled_color", Color(_token_color("muted_text", FALLBACK_MUTED), 0.52))
    button.add_theme_stylebox_override("disabled", _flat_style(Color(0.018, 0.020, 0.026, 0.68), Color(_token_color("worn_bronze", FALLBACK_GOLD), 0.14), 5, 1, 10.0))

func _panelize_label(label: Label, base_name: String, accent: bool) -> void:
    _panelize_control(label, base_name, accent)

func _panelize_control(control: Control, base_name: String, accent: bool) -> void:
    if control.get_parent() != _menu.content:
        return
    if bool(control.get_meta("litd_codex_panelized", false)):
        return
    control.set_meta("litd_codex_panelized", true)
    var position: int = int(control.get_index())
    var panel := PanelContainer.new()
    panel.name = "%s_%d" % [base_name, position]
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _card_style(accent))
    _menu.content.remove_child(control)
    panel.add_child(control)
    _menu.content.add_child(panel)
    _menu.content.move_child(panel, position)

func _group_labels(title: Label, detail: Label, base_name: String, accent: bool) -> void:
    if title.get_parent() != _menu.content:
        return
    if bool(title.get_meta("litd_codex_grouped", false)):
        return
    title.set_meta("litd_codex_grouped", true)
    var position: int = int(title.get_index())
    var panel := PanelContainer.new()
    panel.name = "%s_%d" % [base_name, position]
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _card_style(accent))
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 4)
    _menu.content.remove_child(title)
    stack.add_child(title)
    if detail != null and detail.get_parent() == _menu.content:
        detail.set_meta("litd_codex_grouped", true)
        _menu.content.remove_child(detail)
        stack.add_child(detail)
    panel.add_child(stack)
    _menu.content.add_child(panel)
    _menu.content.move_child(panel, position)

func _first_label(container: Container) -> Label:
    for child: Node in container.get_children():
        if child is Label:
            return child as Label
    return null

func _find_button(container: Container, exact_text: String) -> Button:
    for child: Node in container.get_children():
        if child is Button and (child as Button).text == exact_text:
            return child as Button
    return null

func _direct_children_snapshot() -> Array[Node]:
    var result: Array[Node] = []
    for child: Node in _menu.content.get_children():
        result.append(child)
    return result

func _card_style(accent: bool) -> StyleBoxFlat:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG_ALT if accent else PANEL_BG
    style.border_color = Color(gold, 0.58 if accent else 0.23)
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

func _token_color(key: String, fallback: Color) -> Color:
    var value: Variant = _art.token("colors", key, fallback.to_html())
    if value is Color:
        return value
    var text := String(value)
    if Color.html_is_valid(text):
        return Color(text)
    return fallback
