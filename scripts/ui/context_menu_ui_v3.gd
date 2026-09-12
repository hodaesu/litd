extends "res://scripts/ui/context_menu_ui_v2.gd"

# P0 menu UX contract: explicit focus, focus restoration and responsive reflow.
# Gameplay/state semantics remain owned by ContextMenuUI v2 and the existing managers.

const P0_MIN_TOUCH_HEIGHT := 48.0
const P0_MAX_UI_SCALE := 1.4
const P0_MAX_TEXT_SCALE := 1.5

var _p0_focus_before_menu: Control
var _p0_focus_by_tab: Dictionary = {}
var _p0_last_compact := false
var _p0_reflow_guard := false

func _ready() -> void:
    super._ready()
    var viewport := get_viewport()
    if viewport != null and not viewport.size_changed.is_connected(_p0_on_viewport_size_changed):
        viewport.size_changed.connect(_p0_on_viewport_size_changed)
    call_deferred("_p0_apply_frame_contract")

func _button(text: String, callback: Callable, min_size: Vector2 = Vector2(180, 44)) -> Button:
    var requested := min_size
    requested.y = maxf(P0_MIN_TOUCH_HEIGHT, requested.y * GameSettings.ui_scale)
    var button := super._button(text, callback, requested)
    button.focus_mode = Control.FOCUS_ALL
    var focus_style := _style(Color(0.16, 0.115, 0.055, 1.0))
    focus_style.border_color = Color("#f2d99b")
    focus_style.set_border_width_all(3)
    button.add_theme_stylebox_override("focus", focus_style)
    return button

func _build_overlay() -> void:
    super._build_overlay()
    _p0_apply_frame_contract()

func open_menu(tab: String = "") -> void:
    var focused := get_viewport().gui_get_focus_owner()
    if focused != null and is_instance_valid(focused) and (overlay == null or not overlay.is_ancestor_of(focused)):
        _p0_focus_before_menu = focused
    super.open_menu(tab)
    call_deferred("_p0_finalize_menu_contract")

func close_menu() -> void:
    _p0_remember_current_focus()
    super.close_menu()
    call_deferred("_p0_restore_external_focus")

func _select_tab(tab: String) -> void:
    _p0_remember_current_focus()
    super._select_tab(tab)
    call_deferred("_p0_finalize_menu_contract")

func _render_current_tab() -> void:
    _p0_remember_current_focus()
    super._render_current_tab()
    call_deferred("_p0_finalize_menu_contract")

func _input(event: InputEvent) -> void:
    if overlay != null and overlay.visible and event.is_action_pressed("ui_cancel"):
        close_menu()
        get_viewport().set_input_as_handled()
        return
    super._input(event)

func _two_panes(left_width: float = 520.0) -> Array:
    if not _p0_is_compact_layout():
        return super._two_panes(left_width)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    var stack := VBoxContainer.new()
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_theme_constant_override("separation", 10)
    scroll.add_child(stack)
    var left := _p0_compact_pane(stack)
    var right := _p0_compact_pane(stack)
    return [left, right]

func _p0_compact_pane(parent: VBoxContainer) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _style(Color(0.019, 0.022, 0.030, 0.98)))
    parent.add_child(panel)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 8)
    panel.add_child(column)
    return column

func _compact_hero_selector(parent: VBoxContainer) -> void:
    if not _p0_is_compact_layout():
        super._compact_hero_selector(parent)
        return
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    parent.add_child(grid)
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        var selected := hero_id == selected_hero_id
        var button := _button("%s%s · %d" % ["◆ " if selected else "", str(hero.get("name", "Héros")), int(hero.get("level", 1))], func(value = hero_id):
            selected_hero_id = str(value)
            selected_item_id = ""
            selected_skill_id = ""
            _render_current_tab(), Vector2(0, 48))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        grid.add_child(button)

func _render_accessibility_options(parent: VBoxContainer) -> void:
    parent.add_child(_label("ACCESSIBILITÉ DU MENU", 17, Color("#d5b26c")))
    parent.add_child(_label("Taille du texte", 13, Color("#a49884")))
    var text_row := HBoxContainer.new()
    text_row.add_theme_constant_override("separation", 6)
    parent.add_child(text_row)
    for scale_value in [1.0, 1.15, 1.30, 1.50]:
        var scale := float(scale_value)
        text_row.add_child(_button("%s%d %%" % ["◆ " if is_equal_approx(menu_text_scale, scale) else "", int(round(scale * 100.0))], func(value = scale):
            menu_text_scale = float(value)
            GameSettings.set_text_scale(float(value))
            _save_options()
            _rebuild_overlay_keep_state(), Vector2(0, 48)))

    parent.add_child(_label("Échelle de l’interface", 13, Color("#a49884")))
    var ui_row := HBoxContainer.new()
    ui_row.add_theme_constant_override("separation", 6)
    parent.add_child(ui_row)
    for scale_value in [1.0, 1.15, 1.25, 1.40]:
        var scale := float(scale_value)
        ui_row.add_child(_button("%s%d %%" % ["◆ " if is_equal_approx(GameSettings.ui_scale, scale) else "", int(round(scale * 100.0))], func(value = scale):
            GameSettings.set_ui_scale(float(value))
            _rebuild_overlay_keep_state(), Vector2(0, 48)))

    var contrast := CheckButton.new()
    contrast.text = "Contraste renforcé"
    contrast.button_pressed = high_contrast
    contrast.focus_mode = Control.FOCUS_ALL
    contrast.custom_minimum_size.y = P0_MIN_TOUCH_HEIGHT
    contrast.toggled.connect(func(enabled: bool):
        high_contrast = enabled
        GameSettings.set_high_contrast(enabled)
        _save_options()
        _rebuild_overlay_keep_state())
    parent.add_child(contrast)
    parent.add_child(_label("Texte et forme restent redondants : aucune information importante ne dépend uniquement d'une couleur.", 12, Color("#a49884")))

func _rebuild_overlay_keep_state() -> void:
    _p0_remember_current_focus()
    super._rebuild_overlay_keep_state()
    _p0_apply_frame_contract()
    call_deferred("_p0_finalize_menu_contract")

func _load_options() -> void:
    super._load_options()
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) == OK:
        menu_text_scale = clampf(float(config.get_value("accessibility", "menu_text_scale", GameSettings.text_scale)), 1.0, P0_MAX_TEXT_SCALE)
    else:
        menu_text_scale = clampf(GameSettings.text_scale, 1.0, P0_MAX_TEXT_SCALE)
    high_contrast = high_contrast or GameSettings.high_contrast

func _save_options() -> void:
    super._save_options()
    GameSettings.text_scale = clampf(menu_text_scale, 0.9, P0_MAX_TEXT_SCALE)
    GameSettings.high_contrast = high_contrast
    GameSettings.save_settings()

func _p0_on_viewport_size_changed() -> void:
    if _p0_reflow_guard:
        return
    var compact_before := _p0_last_compact
    _p0_apply_frame_contract()
    var compact_after := _p0_is_compact_layout()
    if overlay != null and overlay.visible and compact_before != compact_after:
        _p0_reflow_guard = true
        _render_current_tab()
        _p0_reflow_guard = false

func _p0_apply_frame_contract() -> void:
    if overlay == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var contract := _p0_layout_contract(viewport_size, GameSettings.ui_scale, menu_text_scale)
    _p0_last_compact = bool(contract.get("compact", false))
    var margin := float(contract.get("margin", 16.0))
    for child_value: Variant in overlay.get_children():
        var child := child_value as Control
        if child is PanelContainer:
            child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            child.offset_left = margin
            child.offset_top = margin
            child.offset_right = -margin
            child.offset_bottom = -margin
            break

func _p0_layout_contract(viewport_size: Vector2, ui_scale_value: float, text_scale_value: float) -> Dictionary:
    var safe_width := maxf(320.0, viewport_size.x)
    var safe_height := maxf(240.0, viewport_size.y)
    var pressure := maxf(ui_scale_value / P0_MAX_UI_SCALE, text_scale_value / P0_MAX_TEXT_SCALE)
    var compact := safe_width < 1100.0 or safe_height < 620.0 or ui_scale_value >= 1.25 or text_scale_value >= 1.35
    var margin := clampf(minf(safe_width, safe_height) * 0.025 / maxf(0.75, pressure), 12.0, 32.0)
    return {
        "compact": compact,
        "margin": margin,
        "frame_size": Vector2(maxf(1.0, safe_width - margin * 2.0), maxf(1.0, safe_height - margin * 2.0)),
        "max_ui_scale": P0_MAX_UI_SCALE,
        "max_text_scale": P0_MAX_TEXT_SCALE,
    }

func _p0_is_compact_layout() -> bool:
    var viewport_size := get_viewport().get_visible_rect().size
    return bool(_p0_layout_contract(viewport_size, GameSettings.ui_scale, menu_text_scale).get("compact", false))

func _p0_finalize_menu_contract() -> void:
    if overlay == null or not overlay.visible or not is_instance_valid(overlay):
        return
    _p0_apply_frame_contract()
    var controls := _p0_focusable_controls()
    _p0_wire_focus_graph(controls)
    if _p0_restore_tab_focus(controls):
        return
    var preferred := tab_buttons.get(current_tab) as Control
    if preferred != null and preferred.visible and preferred.focus_mode != Control.FOCUS_NONE:
        preferred.grab_focus()
        return
    if not controls.is_empty():
        controls[0].grab_focus()

func _p0_focusable_controls() -> Array[Control]:
    var result: Array[Control] = []
    if overlay == null:
        return result
    for node_value: Variant in overlay.find_children("*", "Control", true, false):
        var control := node_value as Control
        if control == null or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
            continue
        if control is BaseButton or control is Slider or control is LineEdit or control is SpinBox:
            control.set_meta("p0_focus_key", _p0_focus_key(control, result.size()))
            result.append(control)
    return result

func _p0_focus_key(control: Control, occurrence: int = 0) -> String:
    var text := ""
    if control is BaseButton:
        text = (control as BaseButton).text
    text = text.replace("◆ ", "").replace("\n", "|").strip_edges()
    if text == "":
        text = str(control.name)
    return "%s::%s::%d" % [control.get_class(), text, occurrence]

func _p0_remember_current_focus() -> void:
    if overlay == null or not overlay.visible:
        return
    var focused := get_viewport().gui_get_focus_owner()
    if focused == null or not is_instance_valid(focused) or not overlay.is_ancestor_of(focused):
        return
    _p0_focus_by_tab[current_tab] = str(focused.get_meta("p0_focus_key", _p0_focus_key(focused)))

func _p0_restore_tab_focus(controls: Array[Control]) -> bool:
    var key := str(_p0_focus_by_tab.get(current_tab, ""))
    if key == "":
        return false
    for control in controls:
        if str(control.get_meta("p0_focus_key", "")) == key:
            control.grab_focus()
            return true
    return false

func _p0_restore_external_focus() -> void:
    if _p0_focus_before_menu != null and is_instance_valid(_p0_focus_before_menu) and _p0_focus_before_menu.is_visible_in_tree() and _p0_focus_before_menu.focus_mode != Control.FOCUS_NONE:
        _p0_focus_before_menu.grab_focus()
    elif launcher != null and is_instance_valid(launcher) and launcher.visible:
        launcher.grab_focus()
    _p0_focus_before_menu = null

func _p0_wire_focus_graph(controls: Array[Control]) -> void:
    if controls.is_empty():
        return
    for index in range(controls.size()):
        var control := controls[index]
        control.focus_mode = Control.FOCUS_ALL
        var previous := controls[(index - 1 + controls.size()) % controls.size()]
        var next := controls[(index + 1) % controls.size()]
        control.focus_previous = control.get_path_to(previous)
        control.focus_next = control.get_path_to(next)
        control.focus_neighbor_left = _p0_neighbor_path(control, controls, Vector2.LEFT, previous)
        control.focus_neighbor_right = _p0_neighbor_path(control, controls, Vector2.RIGHT, next)
        control.focus_neighbor_top = _p0_neighbor_path(control, controls, Vector2.UP, previous)
        control.focus_neighbor_bottom = _p0_neighbor_path(control, controls, Vector2.DOWN, next)

func _p0_neighbor_path(origin: Control, controls: Array[Control], direction: Vector2, fallback: Control) -> NodePath:
    var origin_center := origin.get_global_rect().get_center()
    var best: Control = null
    var best_score := INF
    for candidate in controls:
        if candidate == origin:
            continue
        var delta := candidate.get_global_rect().get_center() - origin_center
        var primary := delta.dot(direction)
        if primary <= 1.0:
            continue
        var perpendicular := absf(delta.cross(direction))
        var score := primary + perpendicular * 2.25
        if score < best_score:
            best_score = score
            best = candidate
    return origin.get_path_to(best if best != null else fallback)
