extends "res://scripts/ui/main_v13.gd"

# v14 : garde-fous mobiles/tactiles.
# Le gameplay reste celui de v13 ; cette couche impose seulement une taille
# minimale aux contrôles interactifs pour les écrans tactiles.
const MOBILE_MIN_TOUCH_HEIGHT: float = 48.0
const MOBILE_MIN_TOUCH_WIDTH: float = 96.0

func make_button(text: String, callback: Callable, min_size := Vector2(190, 52)) -> Button:
    var touch_size := Vector2(
        maxf(float(min_size.x), MOBILE_MIN_TOUCH_WIDTH),
        maxf(float(min_size.y), MOBILE_MIN_TOUCH_HEIGHT)
    )
    return super.make_button(text, callback, touch_size)
