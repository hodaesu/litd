extends Node

const BRIDGE := preload("res://scripts/world/veilleurs_ge01_playable_bridge.gd")
const CORPSE_TACTICS := preload("res://scripts/core/veilleurs_corpse_tactical_runtime.gd")
const CORPSE_SKILLS := preload("res://scripts/core/veilleurs_corpse_skill_runtime.gd")
const TACTICAL_SKILLS := preload("res://scripts/core/veilleurs_ge01_tactical_skill_runtime.gd")

func _ready() -> void:
    GameState.reset_new_game()
    var bridge: VeilleursGE01PlayableBridge = BRIDGE.new() as VeilleursGE01PlayableBridge
    add_child(bridge)
    bridge.make_persistent_root()
    bridge.start("GE01_COMBAT_SMOKE")
    bridge.enter_room("ge_02"); bridge.enter_room("ge_03"); bridge.enter_room("ge_04")
    var ge04_encounter: Dictionary = bridge.session.call("encounter_for", "ge_04", 10)
    var ge04_enemies: Array = bridge.call("_build_encounter_enemies", ge04_encounter, "ge_04")
    assert(ge04_enemies.size() == 2)
    var fleeing: Dictionary = ge04_enemies[0]
    fleeing["hp"] = 5; fleeing["ge01_flee_chance"] = 100
    GameState.battle_enemies = ge04_enemies
    bridge.pending_combat = {"encounter_id": "ge01_04", "room_id": "ge_04", "encounter": ge04_encounter}
    var ai_action: Dictionary = EnemyCombatDirector.choose_action(fleeing, GameState.alive_heroes())
    assert(str(ai_action.get("id", "")) == "ge01_flee")
    var entity_id := str(fleeing.get("remanence_id", ""))
    assert(entity_id != "" and RemanenceRuntime.entities.has(entity_id))
    bridge.pending_combat.clear()

    for room_id in ["ge_05", "ge_06", "ge_07", "ge_08", "ge_09"]: bridge.enter_room(room_id)
    bridge.call("_ensure_ossuary_corpses")
    var corpse_ids: Array = bridge.tactical_corpse_context().keys(); corpse_ids.sort()
    assert(corpse_ids.size() == 2)
    var corpse_tactics: VeilleursCorpseTacticalRuntime = CORPSE_TACTICS.new()
    var corpse_skills: VeilleursCorpseSkillRuntime = CORPSE_SKILLS.new()
    var tactical_skills: VeilleursGE01TacticalSkillRuntime = TACTICAL_SKILLS.new()
    assert(corpse_skills.available_actions(corpse_ids, "hero").size() == 3)

    var first_scar_id := str(corpse_ids[0]); var second_scar_id := str(corpse_ids[1])
    var barricade := corpse_skills.barricade(first_scar_id, 2, "hero", 40)
    assert(bool(barricade.get("ok", false)))
    assert(not corpse_tactics.can_move_to_slot(2, corpse_ids, "hero"))
    assert(corpse_tactics.cover_for_slot(2, corpse_ids, "hero") >= 40)

    var enemy_blocker := bridge.call("_build_unit", "emaciated") as Dictionary; enemy_blocker["combat_position"] = 0
    var enemy_mover := bridge.call("_build_unit", "ash_roamer") as Dictionary; enemy_mover["combat_position"] = 1
    var enemy_line: Array = [enemy_blocker, enemy_mover]
    var projected := corpse_skills.project(second_scar_id, enemy_mover, enemy_line, 1)
    assert(bool(projected.get("ok", false)))
    assert(not corpse_tactics.can_move_to_slot(1, corpse_ids, "enemy"))
    assert(bool(projected.get("displaced", false)))

    var generic_target := {"hp":30, "max_hp":40}
    var expose := tactical_skills.expose_zone(generic_target, "right_arm")
    assert(bool(expose.get("ok", false)))
    var bonus := tactical_skills.exposed_bonus(generic_target, "right_arm")
    assert(bool(bonus.get("active", false)))
    assert(int(bonus.get("precision_bonus", 0)) == 12)
    assert(tactical_skills.target_is_wounded(generic_target))

    var generic_actor := {"id":"canonical_probe", "hp":30, "combat_position":1}
    var generic_allies: Array = [generic_actor]
    var options := tactical_skills.reposition_options(generic_actor, true, generic_allies)
    assert(bool(options.get("ok", false)))
    assert(not (options.get("destinations", []) as Array).is_empty())

    corpse_tactics.destroy(first_scar_id, "smoke_test")
    corpse_tactics.destroy(second_scar_id, "smoke_test")
    bridge.enter_room("ge_10"); bridge.enter_room("ge_11")
    var ge11_encounter: Dictionary = bridge.session.call("encounter_for", "ge_11", 20)
    assert(bool(ge11_encounter.get("persistent", false)))
    var return_enemies: Array = bridge.call("_build_encounter_enemies", ge11_encounter, "ge_11")
    assert(return_enemies.size() == 1 and str((return_enemies[0] as Dictionary).get("remanence_id", "")) == entity_id)
    bridge.enter_room("ge_12")
    var ge12_veteran: Dictionary = bridge.session.call("encounter_for", "ge_12", 65)
    var deep_enemies: Array = bridge.call("_build_encounter_enemies", ge12_veteran, "ge_12")
    assert(deep_enemies.size() >= 1 and bool((deep_enemies[0] as Dictionary).get("ge01_preexisting_veteran", false)))
    print("GE01_COMBAT_SMOKE_OK")
    get_tree().quit(0)
