extends Node

var failures: Array[String] = []

func _ready() -> void:
    _test_humanoid_f3_f4_and_weapon_transfer()
    _test_non_humanoid_mapping()
    _test_custom_boss_markers()

    if failures.is_empty():
        print("BODY_VISUAL_V42_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("BODY_VISUAL_V42_SMOKE: %s" % failure)
    get_tree().quit(1)

func _test_humanoid_f3_f4_and_weapon_transfer() -> void:
    var actor := Node3D.new()
    actor.name = "HumanoidActor"
    var visual := Node3D.new()
    visual.name = "Visual"
    actor.add_child(visual)
    add_child(actor)

    var left_arm := _marker("BODY_arm_left", visual)
    var left_hand := _marker("BODY_hand_left", visual)
    var right_arm := _marker("BODY_arm_right", visual)
    var right_hand := _marker("BODY_hand_right", visual)
    var right_stump := _marker("STUMP_arm_right", visual)
    var right_f3_pose := _marker("POSE_F3_arm_right", visual)

    var socket_left := _marker("SOCKET_weapon_l", visual)
    var socket_right := _marker("SOCKET_weapon_r", visual)
    var weapon := _marker("EQUIP_weapon_primary", socket_right)
    weapon.set_meta("litd_equipment_role", "weapon")
    var right_bracer := _marker("EQUIP_bracer_right", visual)
    right_bracer.set_meta("litd_equipment_for", "arm_right")

    var adapter := BodyStateVisualAdapter.new()
    add_child(adapter)
    adapter.configure("qa_v42", actor, {
        "id": "qa_v42",
        "hp": 100,
        "max_hp": 100,
        "morphology": "HUMANOID",
        "weapon_hand": "right"
    })

    var healthy := adapter.body_visual_snapshot()
    _expect(int(healthy.get("version", 0)) == 42, "v42 contract version")
    _expect(healthy.get("gameplay_untouched", false) == true, "v42 remains gameplay-neutral")
    _expect(right_arm.visible and right_hand.visible, "healthy right limb remains visible")
    _expect(not right_stump.visible, "healthy limb hides stump marker")
    _expect(not right_f3_pose.visible, "healthy limb hides F3 pose marker")
    _expect(weapon.get_parent() == socket_right, "healthy weapon stays in preferred right socket")

    adapter.update_character({
        "id": "qa_v42",
        "hp": 100,
        "max_hp": 100,
        "morphology": "HUMANOID",
        "weapon_hand": "right",
        "critically_disabled_parts": ["right_arm"]
    })
    var f3 := adapter.body_visual_snapshot()
    _expect((f3.get("disabled_segments", []) as Array).has("arm_right"), "F3 records disabled right arm")
    _expect((f3.get("disabled_segments", []) as Array).has("hand_right"), "F3 propagates from arm to hand")
    _expect(right_arm.visible and right_hand.visible, "F3 keeps the limb physically present")
    _expect(not right_stump.visible, "F3 does not show an amputation stump")
    _expect(right_f3_pose.visible, "F3 activates the dedicated disabled-limb pose marker")
    _expect(weapon.get_parent() == socket_left, "F3 transfers weapon to functional opposite hand")
    _expect(str(f3.get("weapon", {}).get("status", "")) == "reassigned", "F3 reports weapon reassignment")
    _expect(right_bracer.visible, "F3 does not erase equipment still physically attached")

    adapter.update_character({
        "id": "qa_v42",
        "hp": 100,
        "max_hp": 100,
        "morphology": "HUMANOID",
        "weapon_hand": "right",
        "dismembered_parts": ["bras_droit"]
    })
    var f4 := adapter.body_visual_snapshot()
    _expect((f4.get("removed_segments", []) as Array).has("arm_right"), "F4 resolves French alias to right arm")
    _expect((f4.get("removed_segments", []) as Array).has("hand_right"), "F4 propagates removal to child hand")
    _expect(not right_arm.visible and not right_hand.visible, "F4 removes the visual limb segments")
    _expect(right_stump.visible, "F4 exposes the matching stump marker")
    _expect(not right_f3_pose.visible, "F4 disables the F3 pose alternative")
    _expect(not right_bracer.visible, "F4 removes equipment attached to the missing segment")
    _expect(weapon.get_parent() == socket_left and weapon.visible, "F4 keeps weapon in remaining functional hand")

    adapter.update_character({
        "id": "qa_v42",
        "hp": 100,
        "max_hp": 100,
        "morphology": "HUMANOID",
        "weapon_hand": "right"
    })
    _expect(left_arm.visible and left_hand.visible and right_arm.visible and right_hand.visible, "state reset restores visible body markers")
    _expect(not right_stump.visible and not right_f3_pose.visible, "state reset clears F3/F4 alternatives")
    _expect(right_bracer.visible, "state reset restores attached equipment")
    _expect(weapon.get_parent() == socket_right, "state reset returns weapon to preferred hand")

func _test_non_humanoid_mapping() -> void:
    var actor := Node3D.new()
    actor.name = "InsectoidActor"
    add_child(actor)
    var right_manipulator := _marker("BODY_manipulator_right_1", actor)
    var runtime := SystemicBodyVisualRuntime.new()
    var snapshot := runtime.apply(actor, {
        "id": "qa_insectoid",
        "morphology": "INSECTOID_ORGANIC",
        "dismembered_parts": ["right_manipulator_1"]
    })
    _expect(str(snapshot.get("morphology", "")) == "INSECTOID_ORGANIC", "insectoid keeps its real morphology")
    _expect((snapshot.get("removed_segments", []) as Array).has("manipulator_right_1"), "insectoid alias maps to its own appendage")
    _expect(not right_manipulator.visible, "insectoid appendage can be removed without humanoid mannequin logic")

func _test_custom_boss_markers() -> void:
    var actor := Node3D.new()
    actor.name = "BossActor"
    add_child(actor)
    var anchor := _marker("BODY_anchor_plate_1", actor)
    var runtime := SystemicBodyVisualRuntime.new()
    var snapshot := runtime.apply(actor, {
        "id": "qa_boss",
        "morphology": "ISHAR_CONSTRUCT_CUSTOM",
        "functional_body_states": {"anchor_plate_1": "F4"}
    })
    _expect(str(snapshot.get("morphology", "")) == "BOSS_CUSTOM", "unknown boss profile uses declared custom markers")
    _expect((snapshot.get("removed_segments", []) as Array).has("anchor_plate_1"), "custom boss part remains addressable")
    _expect(not anchor.visible, "custom boss marker follows F4 without fake humanoid parts")

func _marker(marker_name: String, parent: Node) -> Node3D:
    var node := Node3D.new()
    node.name = marker_name
    parent.add_child(node)
    return node

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
