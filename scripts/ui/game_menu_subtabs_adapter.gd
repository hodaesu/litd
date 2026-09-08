extends Node

# Presentation-only adapter for the unified GameMenuUI.
# The primary menu navigation is handled by game_menu_tabs_adapter.gd; this
# companion pass replaces the remaining character-sheet button rows with
# native Godot TabBars while leaving the existing renderers/actions intact.

const ART_REGISTRY := preload("res://scripts/visual/canonical_art_registry.gd")

const CHARACTER_PANEL_IDS := ["stats", "equipment", "items", "skills"]
const CHARACTER_PANEL_LABELS := ["STATS ET ÉTATS", "ÉQUIPEMENT", "SOINS ET GRENADES", "COMPÉTENCES"]
const FALLBACK_GOLD := Color("#d5b26c")
const FALLBACK_TEXT := Color("#e5dccb")
const FALLBACK_MUTED := Color("#a49884")

var _menu
var _game_state
var _art := ART_REGISTRY.new()
var _polish_scheduled := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _install() -> void:
    _menu = get_node_or_null("/root/GameMenuUI")
    _game_state = get_node_or_null("/root/GameState")
    if _menu == null or not is_instance_valid(_menu.content):
        push_warning("GameMenuSubtabsAdapter: GameMenuUI indisponible.")
        return

    if not bool(_menu.content.get_meta("litd_subtabs_adapter_connected", false)):
        _menu.content.set_meta("litd_subtabs_adapter_connected", true)
        _menu.content.child_entered_tree.connect(_on_content_changed)
    if is_instance_valid(_menu.overlay) and not bool(_menu.overlay.get_meta("litd_subtabs_visibility_connected", false)):
        _menu.overlay.set_meta("litd_subtabs_visibility_connected", true)
        _menu.overlay.visibility_changed.connect(_schedule_polish)
    _schedule_polish()

func _on_content_changed(_node: Node) -> void:
    _schedule_polish()

func _schedule_polish() -> void:
    if _polish_scheduled:
        return
    _polish_scheduled = true
    call_deferred("_polish_dynamic_content")

func _polish_dynamic_content() -> void:
    _polish_scheduled = false
    if _menu == null or not is_instance_valid(_menu.content):
        return
    if String(_menu.active_tab) != "characters":
        return

    _replace_character_panel_navigation()
    _replace_skill_slot_navigation()
    _replace_hero_selector()

func _replace_character_panel_navigation() -> void:
    for child in _menu.content.get_children():
        if child is not HBoxContainer:
            continue
        var buttons := _direct_buttons(child)
        if buttons.size() != CHARACTER_PANEL_LABELS.size():
            continue
        var labels: Array[String] = []
        for button in buttons:
            labels.append(_clean_button_label(button.text))
        if labels != CHARACTER_PANEL_LABELS:
            continue

        var current_index := CHARACTER_PANEL_IDS.find(String(_menu.character_panel))
        if current_index < 0:
            current_index = 0
        var tabs := _make_tab_bar(CHARACTER_PANEL_LABELS, current_index, "CharacterPanelTabs", 54)
        tabs.tab_changed.connect(func(index: int):
            if index < 0 or index >= CHARACTER_PANEL_IDS.size():
                return
            _menu.character_panel = CHARACTER_PANEL_IDS[index]
            _menu._render()
        )
        _replace_content_child(child, tabs)
        return

func _replace_skill_slot_navigation() -> void:
    if String(_menu.character_panel) != "skills":
        return
    for child in _menu.content.get_children():
        if child is not HBoxContainer:
            continue
        var buttons := _direct_buttons(child)
        if buttons.size() < 2:
            continue
        var labels: Array[String] = []
        var valid := true
        for index in range(buttons.size()):
            var clean := _clean_button_label(buttons[index].text)
            if not clean.begins_with("%d ·" % (index + 1)):
                valid = false
                break
            labels.append(clean)
        if not valid:
            continue

        var current_index := clampi(int(_menu.selected_skill_slot), 0, labels.size() - 1)
        var tabs := _make_tab_bar(labels, current_index, "CombatSkillSlotTabs", 50)
        tabs.max_tab_width = 270
        tabs.tab_changed.connect(func(index: int):
            _menu.selected_skill_slot = index
            _menu._render()
        )
        _replace_content_child(child, tabs)
        return

func _replace_hero_selector() -> void:
    if _game_state == null:
        return
    var party: Array = _game_state.party
    if party.is_empty():
        return
    var expected_names: Array[String] = []
    var hero_ids: Array[String] = []
    var current_index := 0
    for index in range(party.size()):
        var hero = party[index]
        if hero is not Dictionary:
            return
        expected_names.append(String(hero.get("name", "Héros")))
        hero_ids.append(String(hero.get("id", "")))
        if hero_ids[index] == String(_menu.selected_hero_id):
            current_index = index

    for child in _menu.content.get_children():
        if child is not HBoxContainer:
            continue
        var buttons := _direct_buttons(child)
        if buttons.size() != expected_names.size():
            continue
        var labels: Array[String] = []
        for button in buttons:
            labels.append(_clean_button_label(button.text))
        if labels != expected_names:
            continue

        var tabs := _make_tab_bar(expected_names, current_index, "HeroSelectorTabs", 50)
        tabs.max_tab_width = 250
        tabs.tab_changed.connect(func(index: int):
            if index < 0 or index >= hero_ids.size():
                return
            _menu.selected_hero_id = hero_ids[index]
            _menu._render()
        )
        _replace_content_child(child, tabs)
        return

func _replace_content_child(old_control: Control, replacement: Control) -> void:
    var index := old_control.get_index()
    _menu.content.remove_child(old_control)
    old_control.queue_free()
    _menu.content.add_child(replacement)
    _menu.content.move_child(replacement, index)

func _direct_buttons(container: Container) -> Array:
    var result: Array = []
    for child in container.get_children():
        if child is Button:
            result.append(child)
    return result

func _clean_button_label(value: String) -> String:
    var text := value.strip_edges()
    if text.begins_with("▶ "):
        text = text.substr(2).strip_edges()
    return text

func _make_tab_bar(labels: Array[String], current_index: int, node_name: String, height: int) -> TabBar:
    var tabs := TabBar.new()
    tabs.name = node_name
    tabs.custom_minimum_size = Vector2(0, height)
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.focus_mode = Control.FOCUS_ALL
    tabs.clip_tabs = true
    tabs.scrolling_enabled = true
    tabs.select_with_rmb = false
    tabs.deselect_enabled = false
    tabs.max_tab_width = 290
    for label in labels:
        tabs.add_tab(label)
    if not labels.is_empty():
        tabs.current_tab = clampi(current_index, 0, labels.size() - 1)
    _apply_tab_theme(tabs)
    return tabs

func _apply_tab_theme(tabs: TabBar) -> void:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var pale_gold := _token_color("pale_bronze", FALLBACK_GOLD.lightened(0.14))
    var text := _token_color("bone_text", FALLBACK_TEXT)
    var muted := _token_color("muted_text", FALLBACK_MUTED)

    tabs.add_theme_font_size_override("font_size", 14)
    tabs.add_theme_color_override("font_selected_color", pale_gold)
    tabs.add_theme_color_override("font_hovered_color", text)
    tabs.add_theme_color_override("font_unselected_color", muted)
    tabs.add_theme_color_override("font_disabled_color", Color(muted.r, muted.g, muted.b, 0.42))
    tabs.add_theme_stylebox_override("tab_selected", _tab_style(
        Color(0.066, 0.058, 0.047, 0.98),
        Color(gold.r, gold.g, gold.b, 0.90),
        true
    ))
    tabs.add_theme_stylebox_override("tab_hovered", _tab_style(
        Color(0.050, 0.046, 0.041, 0.92),
        Color(gold.r, gold.g, gold.b, 0.60),
        false
    ))
    tabs.add_theme_stylebox_override("tab_unselected", _tab_style(
        Color(0.024, 0.026, 0.033, 0.86),
        Color(gold.r, gold.g, gold.b, 0.24),
        false
    ))

func _tab_style(background: Color, border: Color, selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = 1
    style.border_width_top = 2 if selected else 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 2
    style.corner_radius_bottom_right = 2
    style.content_margin_left = 16.0
    style.content_margin_right = 16.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    return style

func _token_color(token_name: String, fallback: Color) -> Color:
    var value := String(_art.token("colors", token_name, ""))
    if value == "":
        return fallback
    return Color.from_string(value, fallback)
