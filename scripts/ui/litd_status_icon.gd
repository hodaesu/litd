extends Button
class_name LITDStatusIcon

@export var status_id := ""
@export var description := ""
@export var glyph := "!"
@export_range(0, 4, 1) var severity := 1

func _ready() -> void:
    custom_minimum_size = Vector2(UITokens.TOUCH_MIN_SIZE, UITokens.TOUCH_MIN_SIZE)
    focus_mode = Control.FOCUS_ALL
    refresh()

func bind_status(data: Dictionary) -> void:
    status_id = str(data.get("id", data.get("status_id", "")))
    description = str(data.get("description", data.get("name", status_id)))
    glyph = str(data.get("glyph", "!"))
    severity = clampi(int(data.get("severity", 1)), 0, 4)
    refresh()

func refresh() -> void:
    text = glyph
    tooltip_text = description if description != "" else status_id
    add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    var style := StyleBoxFlat.new()
    style.bg_color = UITokens.COLOR_SURFACE
    style.border_color = _severity_color()
    style.set_border_width_all(2 if severity >= 3 else 1)
    style.corner_radius_top_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_top_right = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_right = UITokens.CORNER_RADIUS_M
    add_theme_stylebox_override("normal", style)
    add_theme_stylebox_override("hover", style.duplicate())
    add_theme_stylebox_override("pressed", style.duplicate())
    add_theme_stylebox_override("focus", style.duplicate())

func _severity_color() -> Color:
    match severity:
        4:
            return UITokens.COLOR_BLOOD_BRIGHT
        3:
            return UITokens.COLOR_BLOOD
        2:
            return UITokens.COLOR_OCHRE
        1:
            return UITokens.COLOR_COLD_BLUE
        _:
            return UITokens.COLOR_BORDER_METAL
