extends CanvasLayer

var filter: ColorRect

func _ready() -> void:
    layer = 200
    process_mode = Node.PROCESS_MODE_ALWAYS
    filter = ColorRect.new()
    filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(filter)
    GameSettings.settings_changed.connect(apply_settings)
    apply_settings()

func apply_settings() -> void:
    get_tree().root.content_scale_factor = GameSettings.ui_scale
    filter.color = _filter_color()
    filter.visible = GameSettings.high_contrast or GameSettings.color_assist != "none"

func allows_screen_shake() -> bool:
    return GameSettings.screen_shake

func allows_flash() -> bool:
    return not GameSettings.reduce_flashes

func subtitles_enabled() -> bool:
    return GameSettings.subtitles

func adjusted_flash_duration(requested: float) -> float:
    return 0.0 if GameSettings.reduce_flashes else requested

func adjusted_shake_strength(requested: float) -> float:
    return requested if GameSettings.screen_shake else 0.0

func audio_channels(left: float, right: float) -> Vector2:
    if not GameSettings.mono_output:
        return Vector2(left, right)
    var mono := (left + right) * 0.5
    return Vector2(mono, mono)

func dynamic_range_multiplier() -> float:
    return {"night":0.65,"medium":0.82,"wide":1.0}.get(GameSettings.dynamic_range, 0.82)

func _filter_color() -> Color:
    if GameSettings.high_contrast:
        return Color(0.02, 0.02, 0.02, 0.12)
    return {
        "deuteranopia":Color(0.10, 0.03, 0.12, 0.07),
        "protanopia":Color(0.03, 0.08, 0.14, 0.07),
        "tritanopia":Color(0.12, 0.06, 0.01, 0.07)
    }.get(GameSettings.color_assist, Color(0, 0, 0, 0))
