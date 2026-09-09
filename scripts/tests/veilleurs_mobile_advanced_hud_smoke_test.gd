extends Node

const UI_SCRIPT := preload("res://scripts/ui/main_v48.gd")

func _ready() -> void:
    var ui := UI_SCRIPT.new()
    _check(ui.has_method("_sandbox_move_active_to_slot"), "missing formation tap handler")
    _check(ui.has_method("_sandbox_trigger_contextual_synergy"), "missing contextual synergy handler")
    _check(ui.has_method("_sandbox_use_active_ultimate"), "missing ultimate handler")
    _check(ui.has_method("_sandbox_action_ready"), "missing target-aware action readiness")
    _check(ui.has_method("_control_label"), "missing visible control duration label support")
    _check(int(ui.get("SANDBOX_TEST_LEVEL")) == 16, "sandbox ultimate level must validate first charge threshold")
    ui.free()
    print("VEILLEURS_MOBILE_ADVANCED_HUD_SMOKE_OK")
    get_tree().quit(0)

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    push_error("VEILLEURS_MOBILE_ADVANCED_HUD_SMOKE_FAIL: %s" % message)
    get_tree().quit(1)
