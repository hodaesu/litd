extends Node

const UI_SCRIPT := preload("res://scripts/ui/combat_sandbox_ui_v51.gd")

func _ready() -> void:
    var ui := UI_SCRIPT.new()
    _check(ui.has_method("_sandbox_build_preview_v51"), "missing non-destructive preview builder")
    _check(ui.has_method("_sandbox_confirm_prepared_v51"), "missing explicit confirmation step")
    _check(ui.has_method("_restore_sandbox_focus_v51"), "missing deterministic focus restoration")
    ui.call("_ensure_sandbox_started")
    var before: Dictionary = (ui.get("_sandbox") as RefCounted).call("active_hero").duplicate(true)
    var actions: Array = (ui.get("_sandbox") as RefCounted).call("available_actions")
    _check(not actions.is_empty(), "sandbox exposes actions")
    if not actions.is_empty():
        var action: Dictionary = actions[0]
        ui.set("_sandbox_selected_action", str(action.get("id", "")))
        var target_type := str(action.get("target", "enemy"))
        if target_type.begins_with("enemy"):
            ui.set("_sandbox_selected_target", 0)
        elif target_type == "ally":
            ui.set("_sandbox_selected_ally", 0)
        var preview: Dictionary = ui.call("_sandbox_build_preview_v51")
        _check(str(preview.get("action_id", "")) == str(action.get("id", "")), "preview keeps prepared action")
        _check(int(preview.get("ap", -1)) == int(action.get("ap", 1)), "preview exposes AP cost")
        var after: Dictionary = (ui.get("_sandbox") as RefCounted).call("active_hero").duplicate(true)
        _check(before == after, "building preview must not mutate combat state")
    ui.free()
    print("VEILLEURS_P0_FOCUS_PREVIEW_SMOKE_OK")
    get_tree().quit(0)

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    push_error("VEILLEURS_P0_FOCUS_PREVIEW_SMOKE_FAIL: %s" % message)
    get_tree().quit(1)
