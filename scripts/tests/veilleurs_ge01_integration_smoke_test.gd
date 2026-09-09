extends Node

const BRIDGE := preload("res://scripts/world/veilleurs_ge01_playable_bridge.gd")

func _ready() -> void:
    RemanenceRuntime.reset_new_game()
    ExpeditionManager.reset_new_game()
    ExplorationDirector.reset_new_game()

    var bridge := BRIDGE.new()
    add_child(bridge)
    var started: Dictionary = bridge.start("GE01_INTEGRATION_SMOKE")
    assert(bool(started.get("active", false)))
    assert(ExpeditionManager.expedition_active)
    assert(str(started.get("current_room", "")) == "ge_01")
    assert(is_equal_approx(ExplorationDirector.light_level, 0.99))

    assert(bool((bridge.enter_room("ge_02") as Dictionary).get("success", false)))
    assert(bool((bridge.enter_room("ge_03") as Dictionary).get("success", false)))
    assert(bool((bridge.enter_room("ge_04") as Dictionary).get("success", false)))

    var enemy := {
        "id": "ghoul_hungry",
        "species_id": "ghoul_hungry",
        "name": "Goule affamée",
        "hp": 7,
        "max_hp": 24,
        "persistent_injuries": [
            {"id": "arm_wound", "severity": "serious", "stabilized": false}
        ]
    }
    var escaped: Dictionary = bridge.record_enemy_escape(enemy, {"right_arm": "injured"})
    assert(bool(escaped.get("success", false)))
    var entity_id := str(escaped.get("entity_id", ""))
    assert(entity_id != "")
    assert(RemanenceRuntime.entities.has(entity_id))
    var remanence_record: Dictionary = RemanenceRuntime.entities.get(entity_id, {})
    assert(str(remanence_record.get("region_id", "")) == "galeries_eteintes")
    assert(int(remanence_record.get("encounters", 0)) >= 1)
    assert(not (remanence_record.get("body_snapshot", {}) as Dictionary).is_empty())

    assert(bool((bridge.enter_room("ge_05") as Dictionary).get("success", false)))
    assert(bool((bridge.mark_objective_complete("corpse_examined") as Dictionary).get("success", false)))
    var secret: Dictionary = bridge.reveal_secret("integration_smoke")
    assert(bool(secret.get("success", false)))
    assert("ge_14" in bridge.session.call("available_neighbors"))

    bridge.enter_room("ge_06")
    bridge.enter_room("ge_07")
    bridge.enter_room("ge_08")
    var refuge: Dictionary = bridge.resolve_refuge("rekindle")
    assert(bool(refuge.get("success", false)))
    bridge.enter_room("ge_09")
    bridge.enter_room("ge_10")
    bridge.enter_room("ge_13")

    var saved: Dictionary = bridge.serialize()
    assert(not saved.is_empty())
    var extraction: Dictionary = bridge.extract("ge01_smoke_exit")
    assert(bool(extraction.get("success", false)))
    assert(not ExpeditionManager.expedition_active)

    print("GE01_INTEGRATION_SMOKE_OK")
    get_tree().quit(0)
