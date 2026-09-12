extends Node

var failures: Array[String] = []

class Probe:
    extends Node3D
    var id := ""

    func interaction_descriptor(_actor: Object = null) -> Dictionary:
        return EnvironmentInteractionContract.descriptor(
            "probe:%s" % id,
            EnvironmentInteractionContract.KIND_GENERIC,
            "Probe %s" % id,
            "INTERAGIR"
        )

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller := ExplorationPartyController.new()
    add_child(controller)
    controller.interaction_distance = 2.4
    controller.interaction_switch_margin = 0.18

    var a := Probe.new()
    a.id = "a"
    add_child(a)
    var b := Probe.new()
    b.id = "b"
    add_child(b)

    var score_front := controller._interaction_candidate_score(1.5, 0.95)
    var score_side := controller._interaction_candidate_score(1.5, 0.45)
    _check(score_front > score_side, "forward alignment outranks equally distant side target")

    var score_near := controller._interaction_candidate_score(0.8, 0.80)
    var score_far := controller._interaction_candidate_score(2.0, 0.80)
    _check(score_near > score_far, "near target outranks equally aligned far target")

    controller._set_interaction_target(a, a.interaction_descriptor(controller))
    var stable_choice := controller._choose_interaction_candidate([
        {"target": a, "distance": 1.2, "alignment": 0.85, "score": 2.20},
        {"target": b, "distance": 1.1, "alignment": 0.88, "score": 2.30},
    ])
    _check(stable_choice == a, "small challenger advantage does not steal current target")

    var decisive_choice := controller._choose_interaction_candidate([
        {"target": a, "distance": 1.4, "alignment": 0.72, "score": 1.90},
        {"target": b, "distance": 0.8, "alignment": 0.98, "score": 2.40},
    ])
    _check(decisive_choice == b, "clearly better challenger replaces current target")

    controller._set_interaction_target(a, a.interaction_descriptor(controller))
    var lost_current := controller._choose_interaction_candidate([
        {"target": b, "distance": 1.0, "alignment": 0.90, "score": 2.20},
    ])
    _check(lost_current == b, "selection switches immediately when current target is no longer valid")

    var none := controller._choose_interaction_candidate([])
    _check(none == null, "empty candidate set clears target")

    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("STABLE_INTERACTION_TARGETING_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("STABLE_INTERACTION_TARGETING_FAIL: %s" % failure)
    get_tree().quit(1)
