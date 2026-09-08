extends Node

# Presentation adapter for the autoloaded GameMenuUI.
# It keeps every existing screen renderer and action intact, but replaces the
# generated grid of navigation Buttons with a native TabBar and a connected
# content frame using the canonical v41 visual tokens.

const UI_SECTIONS := preload("res://scripts/ui/ui_section_registry.gd")
const ART_REGISTRY := preload("res://scripts/visual/canonical_art_registry.gd")

const FALLBACK_GOLD := Color("#d5b26c")
const FALLBACK_TEXT := Color("#e5dccb")
const FALLBACK_MUTED := Color("#a49884")
const FALLBACK_PANEL := Color(0.035, 0.036, 0.046, 0.96)

var _menu
var _tabs: TabBar
var _tab_ids: Array[String] = []
var _art := ART_REGISTRY.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _install() -> void:
    _menu = get_node_or_null("/root/GameMenuUI")
    if _menu == null or not is_instance_valid(_menu.overlay):
        push_warning("GameMenuTabsAdapter: GameMenuUI indisponible.")
        return

    var shell := _find_shell(_menu.overlay)
    if shell == null:
        push_warning("GameMenuTabsAdapter: conteneur principal introuvable.")
        return

    var old_navigation := _find_legacy_navigation(shell)
    if old_navigation == null:
        return

    var navigation_index := old_navigation.get_index()
    shell.remove_child(old_navigation)
    old_navigation.queue_free()

    _tabs = TabBar.new()
    _tabs.name = "PrimaryNavigationTabs"
    _tabs.custom_minimum_size = Vector2(0, 52)
    _tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tabs.focus_mode = Control.FOCUS_ALL
    _tabs.clip_tabs = true
    _tabs.scrolling_enabled = true
    _tabs.select_with_rmb = false
    _tabs.deselect_enabled = false
    _tabs.max_tab_width = 190

    _tab_ids.clear()
    for entry: Dictionary in UI_SECTIONS.entries():
        var section_id := String(entry.get("id", ""))
        var section_label := String(entry.get("label", ""))
        _tab_ids.append(section_id)
        _tabs.add_tab(section_label)

    _apply_tab_theme(_tabs)
    _tabs.tab_changed.connect(_on_tab_changed)
    shell.add_child(_tabs)
    shell.move_child(_tabs, navigation_index)

    _wrap_content_in_canonical_frame(shell)
    _menu.overlay.visibility_changed.connect(_sync_from_menu)
    _sync_from_menu()

func _find_shell(root: Control) -> VBoxContainer:
    for child: Node in root.get_children():
        if child is VBoxContainer:
            return child as VBoxContainer
    return null

func _find_legacy_navigation(shell: VBoxContainer) -> GridContainer:
    for child: Node in shell.get_children():
        if child is GridContainer:
            return child as GridContainer
    return null

func _wrap_content_in_canonical_frame(shell: VBoxContainer) -> void:
    if shell.get_node_or_null("MenuContentFrame") != null:
        return

    var scroll: ScrollContainer = null
    for child: Node in shell.get_children():
        if child is ScrollContainer:
            scroll = child as ScrollContainer
            break
    if scroll == null:
        return

    var scroll_index := scroll.get_index()
    shell.remove_child(scroll)

    var frame := PanelContainer.new()
    frame.name = "MenuContentFrame"
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    frame.add_theme_stylebox_override("panel", _content_frame_style())
    shell.add_child(frame)
    shell.move_child(frame, scroll_index)

    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    frame.add_child(scroll)

func _on_tab_changed(index: int) -> void:
    if _menu == null or index < 0 or index >= _tab_ids.size():
        return
    _menu.active_tab = _tab_ids[index]
    _menu._render()

func _sync_from_menu() -> void:
    if _tabs == null or _menu == null:
        return
    var index := _tab_ids.find(String(_menu.active_tab))
    if index >= 0 and _tabs.current_tab != index:
        _tabs.current_tab = index

func _apply_tab_theme(tab_bar: TabBar) -> void:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var pale_gold := _token_color("pale_bronze", FALLBACK_GOLD.lightened(0.14))
    var text := _token_color("bone_text", FALLBACK_TEXT)
    var muted := _token_color("muted_text", FALLBACK_MUTED)

    tab_bar.add_theme_font_size_override("font_size", 15)
    tab_bar.add_theme_color_override("font_selected_color", pale_gold)
    tab_bar.add_theme_color_override("font_hovered_color", text)
    tab_bar.add_theme_color_override("font_unselected_color", muted)
    tab_bar.add_theme_color_override("font_disabled_color", Color(muted.r, muted.g, muted.b, 0.42))

    tab_bar.add_theme_stylebox_override("tab_selected", _tab_style(
        Color(0.055, 0.050, 0.044, 0.99),
        Color(gold.r, gold.g, gold.b, 0.92),
        true
    ))
    tab_bar.add_theme_stylebox_override("tab_hovered", _tab_style(
        Color(0.050, 0.046, 0.042, 0.92),
        Color(gold.r, gold.g, gold.b, 0.64),
        false
    ))
    tab_bar.add_theme_stylebox_override("tab_unselected", _tab_style(
        Color(0.018, 0.020, 0.027, 0.86),
        Color(gold.r, gold.g, gold.b, 0.28),
        false
    ))
    tab_bar.add_theme_stylebox_override("tab_disabled", _tab_style(
        Color(0.012, 0.014, 0.020, 0.62),
        Color(gold.r, gold.g, gold.b, 0.16),
        false
    ))

func _tab_style(background: Color, border: Color, selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = 1
    style.border_width_top = 2 if selected else 1
    style.border_width_right = 1
    style.border_width_bottom = 0 if selected else 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 0
    style.corner_radius_bottom_right = 0
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 11.0
    style.content_margin_bottom = 11.0
    return style

func _content_frame_style() -> StyleBoxFlat:
    var gold := _token_color("worn_bronze", FALLBACK_GOLD)
    var style := StyleBoxFlat.new()
    style.bg_color = FALLBACK_PANEL
    style.border_color = Color(gold.r, gold.g, gold.b, 0.50)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 0
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_left = 3
    style.corner_radius_bottom_right = 3
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 12.0
    return style

func _token_color(token_name: String, fallback: Color) -> Color:
    var value := String(_art.token("colors", token_name, ""))
    if value == "":
        return fallback
    return Color.from_string(value, fallback)
