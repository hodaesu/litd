extends CanvasLayer

# Le CanvasLayer conserve le rendu historique du header et des bannières.
# La décision de ce qui mérite d'être visible appartient désormais à HUDDirector.
const HUD_VISIBLE_SCREENS := {
    "combat": true,
    "market": true,
    "campfire": true
}

const HEADER_HEIGHT := 64.0

var _header: Control
var _main_content: Control
var _psychology_banner: PanelContainer
var _psychology_banner_label: Label
var _psychology_feedback_generation: int = 0

func _ready() -> void:
    layer = 40
    GameState.screen_requested.connect(_on_screen_requested)
    get_tree().node_added.connect(_on_tree_node_added)
    if not PsychologyRuntime.feedback_requested.is_connected(_on_psychology_feedback):
        PsychologyRuntime.feedback_requested.connect(_on_psychology_feedback)
    if not HUDDirector.event_presented.is_connected(_on_hud_event_presented):
        HUDDirector.event_presented.connect(_on_hud_event_presented)
    HUDDirector.set_screen_context(GameState.current_screen)
    call_deferred("_apply_current_context")

func _on_screen_requested(screen_name: String) -> void:
    HUDDirector.set_screen_context(screen_name)
    call_deferred("_apply_context", screen_name)

func _on_tree_node_added(node: Node) -> void:
    if node.name == "Header":
        _header = node as Control
        _main_content = null
        call_deferred("_apply_current_context")

func _apply_current_context() -> void:
    _apply_context(GameState.current_screen)

func hud_is_useful(screen_name: String) -> bool:
    return bool(HUD_VISIBLE_SCREENS.get(screen_name, false))

func _resolve_main_ui() -> bool:
    if is_instance_valid(_header) and is_instance_valid(_main_content):
        return true
    _header = get_tree().root.find_child("Header", true, false) as Control
    if not is_instance_valid(_header):
        return false
    var parent := _header.get_parent()
    if parent == null:
        return false
    for child in parent.get_children():
        if child == _header:
            continue
        if child is Control and not (child is ColorRect) and not (child is Container):
            var candidate := child as Control
            if candidate.anchor_right == 1.0 and candidate.anchor_bottom == 1.0:
                _main_content = candidate
                break
    return is_instance_valid(_main_content)

func _apply_context(screen_name: String) -> void:
    if not _resolve_main_ui():
        return
    var visible := hud_is_useful(screen_name)
    _header.visible = visible
    _main_content.offset_top = HEADER_HEIGHT if visible else 0.0

func show_temporarily() -> void:
    if _resolve_main_ui():
        _header.visible = true
        _main_content.offset_top = HEADER_HEIGHT

func restore_context() -> void:
    HUDDirector.set_screen_context(GameState.current_screen)
    _apply_context(GameState.current_screen)

func _on_psychology_feedback(title: String, text: String) -> void:
    _psychology_feedback_generation += 1
    var payload := {
        "title": title,
        "text": text,
        "renderer": "psychology_banner",
        "context_active": true,
    }
    HUDDirector.route_event(
        "psychology_feedback_%d" % _psychology_feedback_generation,
        "ACTIONABLE",
        HUDDirector.LEVEL_CONTEXT,
        payload,
        2.2
    )

func _on_hud_event_presented(item: Dictionary) -> void:
    var payload: Dictionary = item.get("payload", {})
    var renderer := str(payload.get("renderer", ""))
    if renderer != "psychology_banner" and not bool(payload.get("use_context_banner", false)):
        return
    var title := str(payload.get("title", ""))
    var text := str(payload.get("text", ""))
    if title.is_empty() and text.is_empty():
        return
    _show_context_banner(title, text, float(item.get("ttl_seconds", 2.2)))

func _show_context_banner(title: String, text: String, ttl_seconds: float) -> void:
    _ensure_psychology_banner()
    _psychology_feedback_generation += 1
    var generation := _psychology_feedback_generation
    _psychology_banner_label.text = "%s\n%s" % [title, text] if not title.is_empty() else text
    _psychology_banner.visible = true
    var motion := HUDDirector.motion_profile()
    var appearance_seconds := float(motion.get("appearance_seconds", 0.15))
    if appearance_seconds > 0.0:
        _psychology_banner.modulate.a = 0.0
        var tween := create_tween()
        tween.tween_property(_psychology_banner, "modulate:a", 1.0, appearance_seconds)
    else:
        _psychology_banner.modulate.a = 1.0
    await get_tree().create_timer(maxf(ttl_seconds, 0.1)).timeout
    if generation == _psychology_feedback_generation and is_instance_valid(_psychology_banner):
        _psychology_banner.visible = false

func _ensure_psychology_banner() -> void:
    if is_instance_valid(_psychology_banner) and is_instance_valid(_psychology_banner_label):
        return
    _psychology_banner = PanelContainer.new()
    _psychology_banner.name = "PsychologyEventBanner"
    _psychology_banner.position = Vector2(350, 78)
    _psychology_banner.size = Vector2(580, 88)
    _psychology_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.027, 0.035, 0.96)
    style.border_color = Color(0.58, 0.44, 0.22, 0.95)
    style.set_border_width_all(1)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    _psychology_banner.add_theme_stylebox_override("panel", style)
    add_child(_psychology_banner)

    _psychology_banner_label = Label.new()
    _psychology_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _psychology_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _psychology_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _psychology_banner_label.add_theme_font_size_override("font_size", 15)
    _psychology_banner_label.add_theme_color_override("font_color", Color("#e5dccb"))
    _psychology_banner.add_child(_psychology_banner_label)
    _psychology_banner.visible = false
