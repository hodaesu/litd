extends "res://scripts/ui/main_v13.gd"

# v14 : garde-fous mobiles/tactiles.
# Le gameplay reste celui de v13 ; cette couche impose une taille minimale
# aux contrôles interactifs et garde les contrôles autonomes dans le cadre.
const MOBILE_MIN_TOUCH_HEIGHT: float = 48.0
const MOBILE_MIN_TOUCH_WIDTH: float = 96.0
const MOBILE_DESIGN_SIZE := Vector2(1280.0, 720.0)
const MOBILE_EDGE_PADDING: float = 8.0

func make_button(text: String, callback: Callable, min_size := Vector2(190, 52)) -> Button:
    var touch_size := Vector2(
        maxf(float(min_size.x), MOBILE_MIN_TOUCH_WIDTH),
        maxf(float(min_size.y), MOBILE_MIN_TOUCH_HEIGHT)
    )
    return super.make_button(text, callback, touch_size)

func show_screen(name: String) -> void:
    super.show_screen(name)
    call_deferred("_postprocess_mobile_screen")

func show_sanctuary() -> void:
    super.show_sanctuary()
    _keep_last_button_with_text("INFIRMERIE\nSoins et blessures")

func _keep_last_button_with_text(text: String) -> void:
    var matches: Array[Button] = []
    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null and button.text == text and not button.is_queued_for_deletion():
            matches.append(button)
    while matches.size() > 1:
        var obsolete := matches.pop_front()
        obsolete.queue_free()

func _postprocess_mobile_screen() -> void:
    if not is_instance_valid(content):
        return
    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or button.is_queued_for_deletion():
            continue
        button.custom_minimum_size = Vector2(
            maxf(button.custom_minimum_size.x, MOBILE_MIN_TOUCH_WIDTH),
            maxf(button.custom_minimum_size.y, MOBILE_MIN_TOUCH_HEIGHT)
        )
        if button.get_parent() is Container:
            continue
        _clamp_free_button(button)

func _clamp_free_button(button: Button) -> void:
    var rect := button.get_global_rect()
    var delta := Vector2.ZERO
    var min_corner := Vector2(MOBILE_EDGE_PADDING, MOBILE_EDGE_PADDING)
    var max_corner := MOBILE_DESIGN_SIZE - Vector2(MOBILE_EDGE_PADDING, MOBILE_EDGE_PADDING)
    if rect.position.x < min_corner.x:
        delta.x += min_corner.x - rect.position.x
    if rect.position.y < min_corner.y:
        delta.y += min_corner.y - rect.position.y
    if rect.end.x > max_corner.x:
        delta.x -= rect.end.x - max_corner.x
    if rect.end.y > max_corner.y:
        delta.y -= rect.end.y - max_corner.y
    if delta != Vector2.ZERO:
        button.global_position += delta
