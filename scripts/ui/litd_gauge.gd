extends ProgressBar
class_name LITDGauge

## Reusable LITD gauge using the approved Les Veilleurs palette.
## The gauge remains readable without color through its frame, value text option,
## and optional semantic icon/label supplied by the parent UI.

@export_enum("health", "danger", "focus", "knowledge", "recovery", "rare", "neutral")
var gauge_kind: String = "health":
    set(value):
        gauge_kind = value
        if is_inside_tree():
            _apply_visuals()

@export var show_numeric_value := false:
    set(value):
        show_numeric_value = value
        show_percentage = value

@export var compact := false:
    set(value):
        compact = value
        if is_inside_tree():
            _apply_visuals()

func _ready() -> void:
    show_percentage = show_numeric_value
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _apply_visuals()

func set_ratio01(ratio: float) -> void:
    min_value = 0.0
    max_value = 1.0
    value = clampf(ratio, 0.0, 1.0)

func set_values(current: float, maximum: float) -> void:
    min_value = 0.0
    max_value = maxf(maximum, 1.0)
    value = clampf(current, 0.0, max_value)

func _apply_visuals() -> void:
    custom_minimum_size.y = 12.0 if compact else 18.0

    var background := StyleBoxFlat.new()
    background.bg_color = UITokens.COLOR_BACKGROUND
    background.border_color = UITokens.COLOR_BORDER_METAL
    background.set_border_width_all(1)
    background.corner_radius_top_left = UITokens.CORNER_RADIUS_S
    background.corner_radius_top_right = UITokens.CORNER_RADIUS_S
    background.corner_radius_bottom_left = UITokens.CORNER_RADIUS_S
    background.corner_radius_bottom_right = UITokens.CORNER_RADIUS_S

    var fill := StyleBoxFlat.new()
    fill.bg_color = UITokens.gauge_color(gauge_kind)
    fill.border_color = UITokens.COLOR_BONE.darkened(0.35)
    fill.set_border_width_all(1)
    fill.corner_radius_top_left = UITokens.CORNER_RADIUS_S
    fill.corner_radius_top_right = UITokens.CORNER_RADIUS_S
    fill.corner_radius_bottom_left = UITokens.CORNER_RADIUS_S
    fill.corner_radius_bottom_right = UITokens.CORNER_RADIUS_S

    add_theme_stylebox_override("background", background)
    add_theme_stylebox_override("fill", fill)
    add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    add_theme_color_override("font_outline_color", UITokens.COLOR_BACKGROUND)
    add_theme_constant_override("outline_size", 2)
