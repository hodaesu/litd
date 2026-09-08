extends Button
class_name LITDBaseButton

## Shared dark-fantasy button skin for Les Veilleurs.
## Text stays native Godot text so localization and accessibility remain intact.

@export_enum("primary", "secondary", "contextual", "destructive")
var button_kind: String = "primary":
    set(value):
        button_kind = value
        if is_inside_tree():
            _apply_visuals()

@export var selected := false:
    set(value):
        selected = value
        if is_inside_tree():
            _apply_visuals()

func _ready() -> void:
    custom_minimum_size.y = UITokens.TOUCH_PRIMARY_SIZE
    focus_mode = Control.FOCUS_ALL
    _apply_visuals()

func _apply_visuals() -> void:
    var accent := _accent_color()
    var normal := _style(UITokens.COLOR_SURFACE, UITokens.COLOR_BORDER_METAL, 1)
    var hover := _style(UITokens.COLOR_SURFACE_RAISED, accent.darkened(0.15), 1)
    var pressed := _style(UITokens.COLOR_SURFACE_PRESSED, accent, 2)
    var focus := _style(UITokens.COLOR_SURFACE_RAISED, accent, 2)
    var disabled_style := _style(UITokens.COLOR_BACKGROUND, UITokens.COLOR_DISABLED, 1)

    if selected:
        normal = _style(UITokens.COLOR_SURFACE_RAISED, accent, 2)

    add_theme_stylebox_override("normal", normal)
    add_theme_stylebox_override("hover", hover)
    add_theme_stylebox_override("pressed", pressed)
    add_theme_stylebox_override("focus", focus)
    add_theme_stylebox_override("disabled", disabled_style)

    add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    add_theme_color_override("font_hover_color", UITokens.COLOR_IVORY)
    add_theme_color_override("font_pressed_color", UITokens.COLOR_IVORY)
    add_theme_color_override("font_focus_color", UITokens.COLOR_IVORY)
    add_theme_color_override("font_disabled_color", UITokens.COLOR_DISABLED.lightened(0.2))
    add_theme_font_size_override("font_size", UITokens.TEXT_BODY)

func _accent_color() -> Color:
    match button_kind:
        "destructive":
            return UITokens.COLOR_BLOOD_BRIGHT
        "contextual":
            return UITokens.COLOR_DESAT_GREEN
        "secondary":
            return UITokens.COLOR_COLD_BLUE
        _:
            return UITokens.COLOR_OCHRE

func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.corner_radius_top_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_top_right = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_right = UITokens.CORNER_RADIUS_M
    style.content_margin_left = UITokens.SPACE_M
    style.content_margin_right = UITokens.SPACE_M
    style.content_margin_top = UITokens.SPACE_S
    style.content_margin_bottom = UITokens.SPACE_S
    return style
