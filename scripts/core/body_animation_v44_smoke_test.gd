extends Node

var failures: Array[String] = []

func _ready() -> void:
    _test_humanoid_asymmetry_and_equipment_fallback()
    _test_locomotion_damage()
    _test_non_humanoid_modes()
    if failures.is_empty():
        print("BODY_ANIMATION_V44_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("BODY_ANIMATION_V44_SMOKE: %s" % failure)
    get_tree().quit(1)

func _test_humanoid_asymmetry_and_equipment_fallback() -> void:
    var runtime := SystemicBodyAnimationRuntime.new()
    var healthy := runtime.build_plan({"morphology": "HUMANOID"})
    _expect(int(healthy.get("version", 0)) == 44, "v44 contract version")
    _expect(healthy.get("gameplay_untouched", false) == true, "v44 remains gameplay-neutral")
    _expect(str(healthy.get("global_state", "")) == "F0", "healthy state resolves F0")
    _expect(str(healthy.get("attack_profile", "")) == "default", "healthy humanoid keeps default attack profile")

    var f3 := runtime.build_plan({
        "morphology": "HUMANOID",
        "critically_disabled_parts": ["right_arm"]
    })
    _expect(int(f3.get("severity", 0)) == 3, "F3 drives severity 3")
    _expect(not bool(f3.get("right_manipulator_available", true)), "F3 right arm disables right manipulator")
    _expect(bool(f3.get("left_manipulator_available", false)), "F3 keeps left manipulator available")
    _expect(str(f3.get("attack_profile", "")) == "one_hand_left", "F3 requests one-hand-left fallback")
    _expect((f3.get("action_requests", []) as Array).has("body_f3_arm_right"), "F3 requests part-specific body action")
    _expect((f3.get("action_requests", []) as Array).has("combat_idle_1h_left"), "F3 requests asymmetric one-hand idle")

    var f4 := runtime.build_plan({
        "morphology": "HUMANOID",
        "dismembered_parts": ["left_arm", "right_arm"]
    })
    _expect(str(f4.get("attack_profile", "")) == "no_compatible_manipulator", "F4 never invents replacement manipulators")
    _expect((f4.get("action_requests", []) as Array).has("body_f4_arm_left"), "F4 requests left missing-part action")
    _expect((f4.get("action_requests", []) as Array).has("body_f4_arm_right"), "F4 requests right missing-part action")

func _test_locomotion_damage() -> void:
    var runtime := SystemicBodyAnimationRuntime.new()
    var f2 := runtime.build_plan({
        "morphology": "HUMANOID",
        "functional_body_states": {"leg_left": "F2"}
    })
    _expect(int(f2.get("severity", 0)) == 2, "F2 drives severity 2")
    _expect(float(f2.get("locomotion_damage", 0.0)) >= 0.5, "F2 leg creates locomotion presentation weight")
    _expect(str(f2.get("global_state", "")) == "F2", "F2 uses guarded global state")

    var f4 := runtime.build_plan({
        "morphology": "HUMANOID",
        "dismembered_parts": ["left_leg"]
    })
    _expect(float(f4.get("locomotion_damage", 0.0)) == 1.0, "F4 leg creates maximum locomotion presentation weight")
    _expect((f4.get("action_requests", []) as Array).has("move_f4_leg_left"), "F4 leg requests asymmetric locomotion action")

func _test_non_humanoid_modes() -> void:
    var runtime := SystemicBodyAnimationRuntime.new()
    var insectoid := runtime.build_plan({
        "morphology": "INSECTOID_ORGANIC",
        "dismembered_parts": ["leg_left_1"]
    })
    _expect(str(insectoid.get("locomotion_mode", "")) == "multi_limb_compensation", "insectoid uses multi-limb compensation")

    var quadruped := runtime.build_plan({
        "morphology": "QUADRUPED_ORGANIC",
        "critically_disabled_parts": ["front_leg_right"]
    })
    _expect(str(quadruped.get("locomotion_mode", "")) == "quadruped_limp", "quadruped uses quadruped limp instead of biped animation")

    var serpentine := runtime.build_plan({
        "morphology": "SERPENTINE_ORGANIC",
        "dismembered_parts": ["tail"]
    })
    _expect(str(serpentine.get("locomotion_mode", "")) == "serpentine_segment_loss", "serpentine uses segment-loss locomotion")

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
