extends Node

const BRIDGE := preload("res://scripts/world/veilleurs_ge01_playable_bridge.gd")
const CORPSE_TACTICS := preload("res://scripts/core/veilleurs_corpse_tactical_runtime.gd")

func _ready() -> void:
    GameState.reset_new_game()
    var bridge: VeilleursGE01PlayableBridge = BRIDGE.new() as VeilleursGE01PlayableBridge
    add_child(bridge)
    bridge.make_persistent_root()
    bridge.start("GE01_COMBAT_SMOKE")

    bridge.enter_room("ge_02")
    bridge.enter_room("ge_03")
    bridge.enter_room("ge_04")
    var ge04_encounter: Dictionary = bridge.session.call("encounter_for", "ge_04", 10)
    var ge04_enemies: Array = bridge.call("_build_encounter_enemies", ge04_encounter, "ge_04")
    assert(ge04_enemies.size() == 2)
    var fleeing: Dictionary = ge04_enemies[0]
    fleeing["hp"] = 5
    fleeing["ge01_flee_chance"] = 100
    GameState.battle_enemies = ge04_enemies
    bridge.pending_combat = {"encounter_id": "ge01_04", "room_id": "ge_04", "encounter": ge04_encounter}
    var ai_action: Dictionary = EnemyCombatDirector.choose_action(fleeing, GameState.alive_heroes())
    assert(str(ai_action.get("id", "")) == "ge01_flee")
    assert(bool(fleeing.get("ge01_fled", false)))
    assert(not bool(fleeing.get("captured", false)))
    assert(not GameState.battle_enemies.has(fleeing))
    var entity_id := str(fleeing.get("remanence_id", ""))
    assert(entity_id != "" and RemanenceRuntime.entities.has(entity_id))
    bridge.pending_combat.clear()

    bridge.enter_room("ge_05")
    bridge.enter_room("ge_06")
    bridge.enter_room("ge_07")
    bridge.enter_room("ge_08")
    bridge.enter_room("ge_09")
    bridge.call("_ensure_ossuary_corpses")
    var corpses: Dictionary = bridge.tactical_corpse_context()
    assert(corpses.size() == 2)
    var corpse_ids: Array = corpses.keys()
    corpse_ids.sort()
    var corpse_tactics: VeilleursCorpseTacticalRuntime = CORPSE_TACTICS.new()

    # Les vieux corps fournissent de la couverture, mais ne bloquent rien tant
    # qu'une action tactique ne les a pas explicitement placés comme obstacle.
    var battlefield: Dictionary = corpse_tactics.snapshot(corpse_ids, "hero")
    assert(int(battlefield.get("corpse_count", 0)) == 2)
    assert((battlefield.get("blocked_slots", []) as Array).is_empty())
    assert(corpse_tactics.can_move_to_slot(0, corpse_ids, "hero"))

    var first_scar_id := str(corpse_ids[0])
    var second_scar_id := str(corpse_ids[1])
    var moved := corpse_tactics.place(first_scar_id, 2, true, "hero")
    assert(bool(moved.get("ok", false)))
    battlefield = corpse_tactics.snapshot(corpse_ids, "hero")
    assert((battlefield.get("blocked_slots", []) as Array).has(2))
    assert(not corpse_tactics.can_move_to_slot(2, corpse_ids, "hero"))

    # Le runtime commun de position lit le même obstacle.
    var mover := {"id": "hero_mover", "name": "Mouvement", "hp": 30, "max_hp": 30, "combat_position": 1}
    var free_ally := {"id": "hero_ally", "name": "Allié", "hp": 30, "max_hp": 30, "combat_position": 0}
    assert(not CombatPositionRuntime.can_move(mover, 2, [mover, free_ally], "hero"))

    # L'IA ennemie peut sacrifier son action pour avancer vers son rang préféré.
    var enemy_blocker := bridge.call("_build_unit", "emaciated") as Dictionary
    enemy_blocker["combat_position"] = 0
    var enemy_mover := bridge.call("_build_unit", "ash_roamer") as Dictionary
    enemy_mover["combat_position"] = 2
    var enemy_line: Array = [enemy_blocker, enemy_mover]
    var move_action: Dictionary = CombatPositionRuntime.enemy_move_action(enemy_mover, enemy_line)
    assert(bool(move_action.get("tactical_move", false)))
    assert(int(enemy_mover.get("combat_position", -1)) == 1)

    # Un corps peut aussi être projeté côté ennemi pour fermer une ligne.
    var enemy_block_corpse := corpse_tactics.place(second_scar_id, 1, true, "enemy")
    assert(bool(enemy_block_corpse.get("ok", false)))
    enemy_mover["combat_position"] = 2
    var blocked_enemy_move: Dictionary = CombatPositionRuntime.enemy_move_action(enemy_mover, enemy_line)
    assert(blocked_enemy_move.is_empty())
    assert(int(enemy_mover.get("combat_position", -1)) == 2)

    # Couverture : un corps non bloquant reste utile à la position correspondante.
    corpse_tactics.place(second_scar_id, 1, false, "hero")
    var front := {"id": "cover_front", "name": "Avant", "hp": 30, "max_hp": 30, "combat_position": 1, "positive_traits": [], "negative_traits": []}
    var rear := {"id": "cover_rear", "name": "Arrière", "hp": 30, "max_hp": 30, "combat_position": 3, "positive_traits": [], "negative_traits": []}
    var cover_heroes: Array = [front, rear]
    var ge09_enemy := bridge.call("_build_unit", "ghoul_hungry") as Dictionary
    ge09_enemy["ge01_room_id"] = "ge_09"
    EnemyCombatDirector.call("_apply_ge01_corpse_cover", ge09_enemy, cover_heroes, 0)
    assert(float(CharacterTraitDirector.modifiers(front).get("physical_resistance", 0.0)) >= 15.0)

    var scar: Dictionary = RemanenceRuntime.world_scars[second_scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    payload["prepared_as_cover"] = true
    payload["cover_quality"] = 40
    RemanenceRuntime.update_world_scar(second_scar_id, {"payload": payload})
    EnemyCombatDirector.call("_apply_ge01_corpse_cover", ge09_enemy, cover_heroes, 0)
    assert(float(CharacterTraitDirector.modifiers(front).get("physical_resistance", 0.0)) >= 40.0)

    var skill_context := corpse_tactics.skill_context(corpse_ids)
    assert(bool(skill_context.get("corpse_skill_available", false)))
    assert(int(skill_context.get("corpse_count", 0)) == 2)
    var skill_use := corpse_tactics.consume_for_skill(first_scar_id, "TEST_CORPSE_SKILL", "mark")
    assert(bool(skill_use.get("ok", false)))
    assert(str((RemanenceRuntime.world_scars[first_scar_id].get("payload", {}) as Dictionary).get("last_skill_id", "")) == "TEST_CORPSE_SKILL")

    var destroyed := corpse_tactics.destroy(second_scar_id, "smoke_test")
    assert(bool(destroyed.get("ok", false)))
    battlefield = corpse_tactics.snapshot(corpse_ids)
    assert(int(battlefield.get("corpse_count", 0)) == 1)

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