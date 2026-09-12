extends Node

var failures: Array[String] = []

class InteractionProbe:
    extends Node
    var available := true
    var performed := 0

    func interaction_descriptor(_actor: Object = null) -> Dictionary:
        return EnvironmentInteractionContract.descriptor(
            "presentation:probe",
            EnvironmentInteractionContract.KIND_RESOURCE,
            "Ressource témoin",
            "RÉCOLTER",
            available,
            "depleted" if not available else "",
            not available
        )

    func perform_interaction(_actor: Object = null) -> Dictionary:
        var current := interaction_descriptor()
        if not available:
            return EnvironmentInteractionContract.result(current, false, "blocked", "depleted")
        performed += 1
        return EnvironmentInteractionContract.result(current, true, "harvested", "", {"performed": performed})

class ControllerProbe:
    extends ExplorationPartyController
    var probe_target: Object = null

    func _probe_interaction_target() -> Object:
        return probe_target

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    _check_controller_target_lifecycle()
    _check_hud_text_contract()
    _finish()

func _check_controller_target_lifecycle() -> void:
    var controller := ControllerProbe.new()
    var target := InteractionProbe.new()
    add_child(controller)
    add_child(target)
    controller.probe_target = target

    var target_updates: Array[Dictionary] = []
    var feedback: Array[Dictionary] = []
    controller.interaction_target_changed.connect(func(value: Dictionary) -> void: target_updates.append(value.duplicate(true)))
    controller.interaction_feedback.connect(func(value: Dictionary) -> void: feedback.append(value.duplicate(true)))

    controller._refresh_interaction_target()
    var descriptor := controller.get_interaction_descriptor()
    _check(str(descriptor.get("interaction_id", "")) == "presentation:probe", "controller publishes current interaction id")
    _check(bool(descriptor.get("available", false)), "available target remains available")
    _check(target_updates.size() == 1, "target acquisition emits one update")

    controller._refresh_interaction_target()
    _check(target_updates.size() == 1, "unchanged target does not spam updates")

    target.available = false
    controller._refresh_interaction_target()
    descriptor = controller.get_interaction_descriptor()
    _check(not bool(descriptor.get("available", true)), "availability changes are republished")
    _check(str(descriptor.get("blocked_reason", "")) == "depleted", "blocked reason reaches controller descriptor")

    var blocked := controller._try_interact()
    _check(not bool(blocked.get("success", true)), "blocked target does not execute")
    _check(target.performed == 0, "blocked target preserves specialized effect")
    _check(feedback.size() == 1 and str(feedback[0].get("reason", "")) == "depleted", "blocked result is emitted as feedback")

    target.available = true
    var completed := controller._try_interact()
    _check(bool(completed.get("success", false)), "available target executes")
    _check(target.performed == 1, "specialized effect executes exactly once")
    _check(feedback.size() == 2 and bool(feedback[1].get("success", false)), "successful result is emitted as feedback")

    controller.probe_target = null
    controller._refresh_interaction_target()
    _check(controller.get_interaction_descriptor().is_empty(), "losing target clears descriptor")
    _check(not target_updates.is_empty() and target_updates[-1].is_empty(), "losing target emits empty descriptor")

    controller.queue_free()
    target.queue_free()

func _check_hud_text_contract() -> void:
    var hud := AshlandsHUD.new()
    var available := EnvironmentInteractionContract.descriptor(
        "presentation:available",
        EnvironmentInteractionContract.KIND_RESOURCE,
        "Ressource témoin",
        "RÉCOLTER"
    )
    _check(hud._interaction_prompt_text(available) == "RÉCOLTER — Ressource témoin", "available prompt stays compact and actionable")

    var blocked := EnvironmentInteractionContract.descriptor(
        "presentation:blocked",
        EnvironmentInteractionContract.KIND_RESOURCE,
        "Ressource témoin",
        "RÉCOLTER",
        false,
        "depleted",
        true
    )
    var blocked_text := hud._interaction_prompt_text(blocked)
    _check(blocked_text.contains("INDISPONIBLE"), "blocked prompt explicitly states unavailable state")
    _check(blocked_text.contains("Rien de plus ici."), "blocked prompt explains reason with text")
    _check(hud._interaction_prompt_text({}).is_empty(), "no target produces no prompt")

    var success := EnvironmentInteractionContract.result(available, true, "harvested")
    _check(hud._feedback_text(success) == "Ressource récupérée.", "successful interaction has short qualitative feedback")
    var failure := EnvironmentInteractionContract.result(blocked, false, "blocked", "depleted")
    _check(hud._feedback_text(failure) == "Rien de plus ici.", "failed interaction feedback explains cause")
    hud.free()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("PLAYER_INTERACTION_PRESENTATION_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_INTERACTION_PRESENTATION_FAIL: %s" % failure)
    get_tree().quit(1)
