extends Node

const PLAYABLE := preload("res://scenes/world/veilleurs/galeries_eteintes_playable.tscn")

func _ready() -> void:
    var world := PLAYABLE.instantiate()
    add_child(world)
    await get_tree().process_frame

    var runtime: Node = world.get_node("Runtime")
    assert(runtime != null)
    var start_state: Dictionary = runtime.call("snapshot")
    assert(str(start_state.get("current_room", "")) == "ge_01")

    var enter_02: Dictionary = runtime.call("enter_room", "ge_02")
    assert(bool(enter_02.get("success", false)))
    world.set("current_room_id", "ge_02")
    var options_02: Array = world.call("interaction_options", "ge_02")
    assert("deep_observe" in options_02)
    var light_before := int((runtime.call("snapshot") as Dictionary).get("light", 0))
    var observe: Dictionary = world.call("execute_interaction", "deep_observe")
    assert(bool(observe.get("success", false)))
    assert(int((runtime.call("snapshot") as Dictionary).get("light", 0)) < light_before)

    runtime.call("enter_room", "ge_03")
    runtime.call("enter_room", "ge_04")
    runtime.call("enter_room", "ge_05")
    world.set("current_room_id", "ge_05")
    var corpse: Dictionary = world.call("execute_interaction", "examine_corpse")
    assert(bool(corpse.get("success", false)))
    assert(bool((runtime.call("snapshot") as Dictionary).get("objective_complete", false)))

    runtime.call("enter_room", "ge_06")
    world.set("current_room_id", "ge_06")
    var obstacle: Dictionary = world.call("execute_interaction", "detour")
    assert(bool(obstacle.get("success", false)))

    runtime.call("enter_room", "ge_07")
    runtime.call("enter_room", "ge_08")
    world.set("current_room_id", "ge_08")
    var refuge: Dictionary = world.call("execute_interaction", "rekindle")
    assert(bool(refuge.get("success", false)))

    runtime.call("reveal_secret", "physical_smoke")
    runtime.call("enter_room", "ge_07")
    runtime.call("enter_room", "ge_06")
    runtime.call("enter_room", "ge_05")
    runtime.call("enter_room", "ge_14")
    world.set("current_room_id", "ge_14")
    var archive: Dictionary = world.call("execute_interaction", "read_archive")
    assert(bool(archive.get("success", false)))

    print("GE01_PHYSICAL_SMOKE_OK")
    get_tree().quit(0)
