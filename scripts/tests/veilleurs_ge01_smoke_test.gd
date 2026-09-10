extends Node

const SESSION := preload("res://scripts/core/veilleurs_ge01_session_runtime.gd")

func _ready() -> void:
    var session: RefCounted = SESSION.new()
    var started: Dictionary = session.call("start", "GE01_SMOKE")
    assert(bool(started.get("active", false)))
    assert(str(started.get("current_room", "")) == "ge_01")
    assert(int(started.get("light", -1)) == 99)
    assert(str(started.get("light_state", "")) == "clear")

    var move_02: Dictionary = session.call("enter_room", "ge_02")
    assert(bool(move_02.get("success", false)))
    assert(int((move_02.get("state", {}) as Dictionary).get("light", -1)) == 97)

    var blocked_secret: Dictionary = session.call("enter_room", "ge_14")
    assert(not bool(blocked_secret.get("success", false)))

    session.call("enter_room", "ge_03")
    session.call("enter_room", "ge_04")
    var escape: Dictionary = session.call("register_enemy_escape", "ENTITY_GE01_001", "ghoul_hungry", {"right_arm": "injured"})
    assert(bool(escape.get("success", false)))
    assert(str((escape.get("candidate", {}) as Dictionary).get("memory_rank", "")) == "NORMAL")
    assert(bool(session.call("can_enemy_attempt_flee", "ghoul_hungry", 0.20, false, false, true, false)))
    assert(bool(session.call("flee_succeeds", "ghoul_hungry", 10)))
    assert(not bool(session.call("flee_succeeds", "ghoul_hungry", 90)))

    session.call("enter_room", "ge_05")
    session.call("reveal_secret", "smoke_test")
    assert("ge_14" in session.call("available_neighbors"))

    session.call("enter_room", "ge_06")
    session.call("enter_room", "ge_07")
    session.call("enter_room", "ge_08")
    var before_refuge := int((session.call("snapshot") as Dictionary).get("light", 0))
    session.call("resolve_refuge", "rekindle")
    var after_refuge := int((session.call("snapshot") as Dictionary).get("light", 0))
    assert(after_refuge == mini(100, before_refuge + 10))

    session.call("enter_room", "ge_09")
    session.call("enter_room", "ge_10")
    assert("ge_13" in session.call("available_neighbors"))
    assert("ge_11" in session.call("available_neighbors"))

    session.call("enter_room", "ge_11")
    var persistent: Dictionary = session.call("encounter_for", "ge_11", 20)
    assert(bool(persistent.get("persistent", false)))
    assert(str(persistent.get("entity_id", "")) == "ENTITY_GE01_001")

    var save_data: Dictionary = session.call("serialize")
    var restored: RefCounted = SESSION.new()
    assert(bool(restored.call("deserialize", save_data)))
    assert(str(restored.call("current_room")) == "ge_11")

    print("GE01_SMOKE_OK")
    get_tree().quit(0)
