extends Node

var failures: Array[String] = []

class Probe:
    extends Node3D

    func descriptor(salience: String) -> Dictionary:
        return EnvironmentInteractionContract.descriptor(
            "probe:salience-visual",
            EnvironmentInteractionContract.KIND_GENERIC,
            "Interaction témoin",
            "INTERAGIR",
            true,
            "",
            false,
            {},
            salience
        )

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var controller := ExplorationPartyController.new()
    add_child(controller)

    var probe := Probe.new()
    probe.global_position = Vector3(0.0, 0.0, -1.0)
    add_child(probe)

    var indicator := controller.get_node_or_null("InteractionTargetIndicator") as InteractionTargetIndicator
    _check(indicator != null, "controller exposes one interaction indicator")
    if indicator == null:
        _finish()
        return

    controller._set_interaction_target(
        probe,
        probe.descriptor(EnvironmentInteractionContract.SALIENCE_IMMEDIATE)
    )
    var label := indicator.get_node_or_null("TargetGlyph") as Label3D
    _check(label != null, "indicator keeps the existing diamond glyph")
    if label == null:
        _finish()
        return
    var immediate_font := label.font_size
    var immediate_outline := label.outline_size
    var immediate_alpha := label.modulate.a
    _check(indicator.get_salience() == EnvironmentInteractionContract.SALIENCE_IMMEDIATE, "immediate salience reaches world indicator")

    controller._set_interaction_target(
        probe,
        probe.descriptor(EnvironmentInteractionContract.SALIENCE_CONTEXTUAL)
    )
    var contextual_font := label.font_size
    var contextual_outline := label.outline_size
    var contextual_alpha := label.modulate.a
    _check(indicator.get_salience() == EnvironmentInteractionContract.SALIENCE_CONTEXTUAL, "contextual salience reaches same target without retargeting")

    controller._set_interaction_target(
        probe,
        probe.descriptor(EnvironmentInteractionContract.SALIENCE_INSPECT)
    )
    var inspect_font := label.font_size
    var inspect_outline := label.outline_size
    var inspect_alpha := label.modulate.a
    _check(indicator.get_salience() == EnvironmentInteractionContract.SALIENCE_INSPECT, "inspect salience reaches same target without retargeting")

    _check(immediate_font > contextual_font and contextual_font > inspect_font, "world marker size grades immediate > contextual > inspect")
    _check(immediate_outline > contextual_outline and contextual_outline > inspect_outline, "world marker outline grades immediate > contextual > inspect")
    _check(immediate_alpha > contextual_alpha and contextual_alpha > inspect_alpha, "world marker presence grades immediate > contextual > inspect")
    _check(label.text == "◇", "salience does not introduce new icons")
    _check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "salience preserves billboard behavior")
    _check(not label.no_depth_test, "salience preserves scene occlusion")
    _check(indicator.get_target() == probe, "salience styling never changes selected target")

    var hud_immediate := AshlandsHUD.interaction_salience_presentation_profile(EnvironmentInteractionContract.SALIENCE_IMMEDIATE)
    var hud_contextual := AshlandsHUD.interaction_salience_presentation_profile(EnvironmentInteractionContract.SALIENCE_CONTEXTUAL)
    var hud_inspect := AshlandsHUD.interaction_salience_presentation_profile(EnvironmentInteractionContract.SALIENCE_INSPECT)
    _check(int(hud_immediate.get("font_size", 0)) > int(hud_contextual.get("font_size", 0)), "HUD prompt makes immediate more legible")
    _check(int(hud_contextual.get("font_size", 0)) > int(hud_inspect.get("font_size", 0)), "HUD prompt makes inspect deliberately quieter")
    _check(float(hud_immediate.get("alpha", 0.0)) > float(hud_contextual.get("alpha", 0.0)), "HUD presence distinguishes immediate from contextual")
    _check(float(hud_contextual.get("alpha", 0.0)) > float(hud_inspect.get("alpha", 0.0)), "HUD presence distinguishes contextual from inspect")
    for profile: Dictionary in [hud_immediate, hud_contextual, hud_inspect]:
        _check(float(profile.get("min_height", 0.0)) >= 48.0, "all salience prompts preserve 48px touch target")

    controller._set_interaction_target(null, {})
    _check(not indicator.visible, "visual hierarchy still disappears with no target")
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("INTERACTION_SALIENCE_VISUAL_HIERARCHY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("INTERACTION_SALIENCE_VISUAL_HIERARCHY_FAIL: %s" % failure)
    get_tree().quit(1)
