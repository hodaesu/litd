extends Node

const REPORT_PATH := "res://reports/player-bot-v8-fast-combat-contract.json"
const POSITION_RULES := preload("res://scripts/core/combat_position_rules.gd")
const TARGETING_RULES := preload("res://scripts/core/combat_targeting_rules.gd")
const MAX_ACTIONS := 24
const MAX_LOCKED_WAIT_FRAMES := 240

var controller: Control
var failures: Array[String] = []
var actions: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(8808)
    CreatureManager.reset_new_game(8818)
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition(8828)

    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        failures.append("main_scene_missing")
        _finish()
        return
    controller = packed.instantiate() as Control
    if controller == null:
        failures.append("main_scene_instantiate")
        _finish()
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    var room := {"id":"v8_contract","type":"combat","depth":1}
    controller._start_roguelike_room_battle(room)
    await get_tree().process_frame
    if GameState.battle_enemies.is_empty():
        failures.append("no_enemies")
        _finish()
        return

    var action_count := 0
    var locked_frames := 0
    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and action_count < MAX_ACTIONS:
        if bool(controller.battle_locked):
            await get_tree().process_frame
            locked_frames += 1
            if locked_frames >= MAX_LOCKED_WAIT_FRAMES:
                failures.append("battle_locked_timeout")
                break
            continue
        locked_frames = 0
        controller._ensure_combat_state()
        var hero: Dictionary = controller._active_combat_hero()
        if hero.is_empty():
            await get_tree().process_frame
            continue

        var choice := _legal_choice(hero)
        if not bool(choice.get("usable", false)):
            controller._pass_combat_turn()
            actions.append({"hero":str(hero.get("id","")),"action":"pass"})
        else:
            var slot := int(choice.get("slot", -1))
            var skill: Dictionary = choice.get("skill", {})
            var target_index := int(choice.get("target", -1))
            if slot < 0 or skill.is_empty() or target_index < 0:
                failures.append("invalid_choice_shape")
                break
            controller.selected_enemy = target_index
            var target: Dictionary = GameState.battle_enemies[target_index]
            if not POSITION_RULES.is_usable(hero, skill):
                failures.append("illegal_source_rank_%s" % str(skill.get("id", "skill")))
                break
            if str(skill.get("effect", "attack")) == "attack" and not TARGETING_RULES.can_target(hero, skill, target, GameState.battle_enemies):
                failures.append("illegal_target_%s" % str(skill.get("id", "skill")))
                break
            controller._use_combat_skill(slot)
            actions.append({"hero":str(hero.get("id","")),"action":str(skill.get("id","")),"target":target_index})
        action_count += 1
        await get_tree().process_frame

    if actions.is_empty():
        failures.append("no_actions_exercised")
    _finish()

func _legal_choice(hero: Dictionary) -> Dictionary:
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    for slot in range(loadout.size()):
        var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
        if skill.is_empty() or not POSITION_RULES.is_usable(hero, skill):
            continue
        if str(skill.get("effect", "attack")) != "attack":
            return {"usable":true,"slot":slot,"skill":skill,"target":_first_living_enemy()}
        var targets := TARGETING_RULES.targetable_indices(hero, skill, GameState.battle_enemies)
        if not targets.is_empty():
            return {"usable":true,"slot":slot,"skill":skill,"target":int(targets[0])}
    return {"usable":false}

func _first_living_enemy() -> int:
    for index in range(GameState.battle_enemies.size()):
        if int((GameState.battle_enemies[index] as Dictionary).get("hp", 0)) > 0:
            return index
    return -1

func _finish() -> void:
    var report := {
        "schema_version":8,
        "suite":"player_bot_v8_fast_combat_contract",
        "actions":actions,
        "failures":failures,
        "status":"passed" if failures.is_empty() else "failed"
    }
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  "))
        file.store_line("")
        file.close()
    if failures.is_empty():
        print("PLAYER_BOT_V8_OK actions=%d" % actions.size())
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("PLAYER_BOT_V8: " + failure)
        get_tree().quit(1)
