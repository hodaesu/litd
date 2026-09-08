extends Control
class_name LITDSectionFrame

## Decorative, non-interactive dark-fantasy frame used to turn generic runtime
## panels into canonical Les Veilleurs surfaces without touching gameplay.

@export var accent: Color = UITokens.COLOR_OCHRE:
    set(value):
        accent = value
        queue_redraw()

@export var intensity := 0.75:
    set(value):
        intensity = clampf(value, 0.0, 1.0)
        queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    queue_redraw()

func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    if rect.size.x < 12.0 or rect.size.y < 12.0:
        return

    var metal := Color(UITokens.COLOR_BORDER_METAL.r, UITokens.COLOR_BORDER_METAL.g, UITokens.COLOR_BORDER_METAL.b, 0.72 * intensity)
    var glow := Color(accent.r, accent.g, accent.b, 0.66 * intensity)
    var faint := Color(accent.r, accent.g, accent.b, 0.22 * intensity)
    var inset := 5.0
    var corner := minf(18.0, minf(rect.size.x, rect.size.y) * 0.08)

    draw_rect(Rect2(Vector2(inset, inset), rect.size - Vector2(inset * 2.0, inset * 2.0)), metal, false, 1.0)

    # Broken engraved corners: asymmetry is intentional and keeps the frame
    # closer to worn ritual metal than to a clean sci-fi rectangle.
    _draw_corner(Vector2(inset, inset), Vector2(1, 1), corner, glow)
    _draw_corner(Vector2(rect.size.x - inset, inset), Vector2(-1, 1), corner * 0.78, faint)
    _draw_corner(Vector2(inset, rect.size.y - inset), Vector2(1, -1), corner * 0.72, faint)
    _draw_corner(Vector2(rect.size.x - inset, rect.size.y - inset), Vector2(-1, -1), corner, glow)

    if rect.size.x > 180.0:
        var center := rect.size.x * 0.5
        draw_line(Vector2(center - 26.0, inset), Vector2(center - 7.0, inset), faint, 1.0)
        draw_line(Vector2(center + 7.0, inset), Vector2(center + 26.0, inset), faint, 1.0)
        var diamond := PackedVector2Array([
            Vector2(center, inset - 3.0), Vector2(center + 4.0, inset),
            Vector2(center, inset + 3.0), Vector2(center - 4.0, inset)
        ])
        draw_polyline(diamond, glow, 1.0)
        draw_line(diamond[diamond.size() - 1], diamond[0], glow, 1.0)

func _draw_corner(origin: Vector2, direction: Vector2, length: float, color: Color) -> void:
    draw_line(origin, origin + Vector2(direction.x * length, 0.0), color, 2.0)
    draw_line(origin, origin + Vector2(0.0, direction.y * length), color, 2.0)
    var notch_origin := origin + Vector2(direction.x * length * 0.55, direction.y * 2.0)
    draw_line(notch_origin, notch_origin + Vector2(direction.x * 5.0, direction.y * 5.0), color, 1.0)
