extends Node

const UI_SCRIPT := preload("res://scripts/ui/main_v49.gd")

func _ready() -> void:
    var ui := UI_SCRIPT.new()
    _check(ui.has_method("_sandbox_mobile_polish_pass"), "missing mobile polish pass")
    _check(ui.has_method("_enforce_sandbox_touch_targets"), "missing touch target enforcement")
    _check(ui.has_method("_reflow_advanced_mobile_controls"), "missing compact reflow")
    _check(ui.has_method("_render_sandbox_result"), "missing compact result panel override")
    _check(float(ui.get("SANDBOX_MIN_TOUCH")) >= 48.0, "touch targets below 48 px")
    _check(int(ui.get("SANDBOX_PHONE_BOTTOM_Y")) >= 600, "formation dock moved too high")
    ui.free()
    print("VEILLEURS_MOBILE_PHONE_POLISH_SMOKE_OK")
    get_tree().quit(0)

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    push_error("VEILLEURS_MOBILE_PHONE_POLISH_SMOKE_FAIL: %s" % message)
    get_tree().quit(1)
