extends Node

const UI_SCRIPT := preload("res://scripts/ui/main_v50.gd")

func _ready() -> void:
    var ui := UI_SCRIPT.new()
    _check(ui.has_method("_sandbox_execute_v50"), "missing low-tap execute flow")
    _check(ui.has_method("_render_sandbox_flow_hint_v50"), "missing contextual flow hint")
    _check(ui.has_method("_render_sandbox_feedback_v50"), "missing transient impact feedback")
    _check(ui.has_method("_render_sandbox_turn_banner_v50"), "missing turn-change banner")
    _check(ui.has_method("_feedback_from_result_v50"), "missing consequence summarizer")

    var hit := {"ok":true,"hit":true,"zone":"right_leg","severity":3,"functional_loss":"impaired"}
    var text := str(ui.call("_feedback_from_result_v50", hit))
    _check(text.contains("Jambe droite"), "feedback must expose anatomical zone")
    _check(text.contains("lésion sévère"), "feedback must expose lesion severity")
    _check(text.contains("fonction diminuée"), "feedback must expose functional consequence")

    var miss := {"ok":true,"hit":false,"zone":"head"}
    _check(str(ui.call("_feedback_from_result_v50", miss)).contains("Raté"), "miss feedback must be immediate")

    ui.free()
    print("VEILLEURS_MOBILE_COMBAT_FEEL_SMOKE_OK")
    get_tree().quit(0)

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    push_error("VEILLEURS_MOBILE_COMBAT_FEEL_SMOKE_FAIL: %s" % message)
    get_tree().quit(1)
