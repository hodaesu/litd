extends Node

const UI_SCRIPT := preload("res://scripts/ui/combat_sandbox_ui_v48.gd")

func _ready() -> void:
    var ui := UI_SCRIPT.new()
    var failures: Array[String] = []
    _check(ui.has_method("_sandbox_move_active_to_slot"), "missing formation tap handler", failures)
    _check(ui.has_method("_sandbox_trigger_contextual_synergy"), "missing contextual synergy handler", failures)
    _check(ui.has_method("_sandbox_use_active_ultimate"), "missing ultimate handler", failures)
    _check(ui.has_method("_sandbox_action_ready"), "missing target-aware action readiness", failures)
    _check(ui.has_method("_control_label"), "missing visible control duration label support", failures)
    _check(ui.has_method("_sandbox_default_ultimate_tree"), "missing compact ultimate-tree mapping", failures)
    ui.free()
    if not failures.is_empty():
        for failure in failures:
            push_error("VEILLEURS_MOBILE_ADVANCED_HUD_SMOKE_FAIL: %s" % failure)
        get_tree().quit(1)
        return
    print("VEILLEURS_MOBILE_ADVANCED_HUD_SMOKE_OK")
    get_tree().quit(0)

func _check(condition: bool, message: String, failures: Array[String]) -> void:
    if not condition:
        failures.append(message)
