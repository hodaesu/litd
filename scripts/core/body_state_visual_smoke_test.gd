extends Node

var failures: Array[String] = []

func _ready() -> void:
    var actor := Node3D.new()
    actor.name = "Actor"
    var visual := Node3D.new()
    visual.name = "Visual"
    actor.add_child(visual)
    add_child(actor)

    var adapter := BodyStateVisualAdapter.new()
    add_child(adapter)
    adapter.configure("darius", actor, {"id":"darius","hp":100,"max_hp":100,"fear":0})
    await get_tree().process_frame

    var calm: Dictionary = adapter.snapshot()
    _expect(calm.get("pose_target_found", false), "proxy pose target")
    _expect(calm.get("profile", {}).get("psychological_state") == "neutral", "neutral profile")

    adapter.update_character({"id":"darius","hp":45,"max_hp":100,"fear":82})
    for index in range(8):
        adapter._process(0.1)
    var afraid: Dictionary = adapter.snapshot()
    _expect(afraid.get("profile", {}).get("psychological_state") == "terrified", "fear reaches visible adapter")
    _expect(afraid.get("profile", {}).get("physical_state") == "injured", "injury reaches visible adapter")
    _expect(float(afraid.get("animation_parameters", {}).get("fear_blend", 0.0)) > 0.8, "fear blend")
    _expect(float(afraid.get("animation_parameters", {}).get("injury_blend", 0.0)) > 0.5, "injury blend")
    _expect(absf(visual.rotation.x) > 0.01 or absf(visual.rotation.z) > 0.01, "procedural pose moves proxy")

    var plan: Dictionary = adapter.set_action("attack_heavy")
    _expect(bool(plan.get("valid", false)), "combat action plan")
    _expect((plan.get("required_markers", []) as Array).has("impact"), "impact remains authored")

    var hit: Dictionary = adapter.set_hit_reaction("leg", "critical")
    _expect(str(hit.get("clip", "")) == "collapse_leg", "body-part reaction")

    if failures.is_empty():
        print("BODY_STATE_VISUAL_ADAPTER_SMOKE_OK")
        get_tree().quit(0)
    else:
        for failure: String in failures:
            push_error("BODY_STATE_VISUAL_ADAPTER_SMOKE: %s" % failure)
        get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
