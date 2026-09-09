extends Node

const BRIDGE := preload("res://scripts/world/veilleurs_ge01_playable_bridge.gd")

func _ready() -> void:
    GameState.reset_new_game()
    var bridge: VeilleursGE01PlayableBridge = BRIDGE.new() as VeilleursGE01PlayableBridge
    add_child(bridge)
    bridge.start("GE01_COMBAT_SMOKE")

    bridge.enter_room("ge_02")
    bridge.enter_room("ge_03")
    bridge.enter_room("ge_04")
    var ge04_encounter: Dictionary = bridge.session.call("encounter_for", "ge_04", 10)
    var ge04_enemies: Array = bridge.call("_build_encounter_enemies", ge04_encounter, "ge_04")
    assert(ge04_enemies.size() == 2)
    assert(str((ge04_enemies[0] as Dictionary).get("species_id", "")) == "ghoul_hungry")
    assert(bool((ge04_enemies[0] as Dictionary).get("ge01_can_flee", false)))

    var fleeing: Dictionary = ge04_enemies[0]
    fleeing["hp"] = 5
    GameState.battle_enemies = ge04_enemies
    bridge.pending_combat = {"encounter_id": "ge01_04", "room_id": "ge_04", "encounter": ge04_encounter}
    var flee_result: Dictionary = bridge.try_flee_enemy(fleeing, 0)
    assert(bool(flee_result.get("success", false)))
    var entity_id := str(flee_result.get("entity_id", ""))
    assert(entity_id != "")
    assert(RemanenceRuntime.entities.has(entity_id))
    assert((bridge.snapshot().get("persistent_candidates", {}) as Dictionary).has(entity_id))
    bridge.pending_combat.clear()

    bridge.enter_room("ge_05")
    bridge.enter_room("ge_06")
    bridge.enter_room("ge_07")
    bridge.enter_room("ge_08")
    bridge.enter_room("ge_09")
    bridge.call("_ensure_ossuary_corpses")
    var corpses: Dictionary = bridge.tactical_corpse_context()
    assert(corpses.size() == 2)
    for scar_id_value: Variant in corpses.keys():
        var scar_id := str(scar_id_value)
        assert(RemanenceRuntime.world_scars.has(scar_id))
        var preview: Dictionary = VeilleursCorpseInteractionRuntime.preview(scar_id)
        assert(bool(preview.get("ok", false)))

    bridge.enter_room("ge_10")
    bridge.enter_room("ge_11")
    var ge11_encounter: Dictionary = bridge.session.call("encounter_for", "ge_11", 20)
    assert(bool(ge11_encounter.get("persistent", false)))
    var return_enemies: Array = bridge.call("_build_encounter_enemies", ge11_encounter, "ge_11")
    assert(return_enemies.size() == 1)
    assert(str((return_enemies[0] as Dictionary).get("remanence_id", "")) == entity_id)

    bridge.enter_room("ge_12")
    var ge12_veteran: Dictionary = bridge.session.call("encounter_for", "ge_12", 65)
    var deep_enemies: Array = bridge.call("_build_encounter_enemies", ge12_veteran, "ge_12")
    assert(deep_enemies.size() >= 1)
    assert(bool((deep_enemies[0] as Dictionary).get("ge01_preexisting_veteran", false)))

    print("GE01_COMBAT_SMOKE_OK")
    get_tree().quit(0)
