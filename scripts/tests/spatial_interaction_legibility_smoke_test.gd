extends Node

var failures: Array[String] = []

class Probe:
    extends Node3D

    func interaction_descriptor(_actor: Object = null) -> Dictionary:
        return EnvironmentInteractionContract.descriptor(
            "probe:spatial",
            EnvironmentInteractionContract.KIND_GENERIC,
            "Probe spatial",
            "INTERAGIR"
        )

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller := ExplorationPartyController.new()
    add_child(controller)

    var probe := Probe.new()
    probe.global_position = Vector3(1.0, 0.5, -1.0)
    add_child(probe)

    controller._set_interaction_target(probe, probe.interaction_descriptor(controller))
    var indicator := controller.get_node_or_null("InteractionTargetIndicator")
    _check(indicator != null, "controller creates one world interaction indicator")
    if indicator != null:
        _check(indicator.visible, "indicator becomes visible for active target")
        _check(indicator.get_target() == probe, "indicator tracks active interaction target")
        indicator._process(0.0)
        var expected: Vector3 = probe.global_position + Vector3.UP * float(indicator.vertical_offset)
        _check(indicator.global_position.distance_to(expected) < 0.001, "indicator follows target in world space")
        var label := indicator.get_node_or_null("TargetGlyph") as Label3D
        _check(label != null, "indicator exposes a visible glyph")
        if label != null:
            _check(label.text == "◇", "glyph is shape-based and not color-only")
            _check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "glyph faces the camera")
            _check(not label.no_depth_test, "glyph respects scene occlusion")

        probe.global_position = Vector3(-0.5, 1.0, -1.5)
        indicator._process(0.0)
        expected = probe.global_position + Vector3.UP * float(indicator.vertical_offset)
        _check(indicator.global_position.distance_to(expected) < 0.001, "indicator follows a moving target without animation dependency")

    controller._set_interaction_target(null, {})
    if indicator != null:
        _check(not indicator.visible, "indicator disappears immediately when target is cleared")
        _check(indicator.get_target() == null, "clearing target releases indicator reference")

    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("SPATIAL_INTERACTION_LEGIBILITY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("SPATIAL_INTERACTION_LEGIBILITY_FAIL: %s" % failure)
    get_tree().quit(1)
