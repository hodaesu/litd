extends "res://scripts/qa/player_bot_v3_build_matrix.gd"

const POSITION_RULES := preload("res://scripts/core/combat_position_rules.gd")
const TARGETING_RULES := preload("res://scripts/core/combat_targeting_rules.gd")
const MAX_LOCKED_WAIT_FRAMES := 300

func _select_lowest_hp_enemy() -> void:
    var best_index := -1
    var best_hp := 2147483647
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        var hp := int(enemy.get("hp", 0))
        var position := int(enemy.get("combat_position", 0))
        if hp > 0 and position <= 1 and hp < best_hp:
            best_hp = hp
            best_index = index
    if best_index < 0:
        for index in range(GameState.battle_enemies.size()):
            var enemy: Dictionary = GameState.battle_enemies[index]
            var hp := int(enemy.get("hp", 0))
            if hp > 0 and hp < best_hp:
                best_hp = hp
                best_index = index
    if best_index >= 0:
        controller.selected_enemy = best_index

func _choose_skill(hero: Dictionary) -> Dictionary:
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    var lowest_ratio := 1.0
    for hero_value in GameState.alive_heroes():
        var ally: Dictionary = hero_value
        lowest_ratio = minf(lowest_ratio, float(ally.get("hp", 0)) / maxf(1.0, float(ally.get("max_hp", 1))))
    var selected_target: Dictionary = {}
    if not GameState.battle_enemies.is_empty():
        controller.selected_enemy = clampi(controller.selected_enemy, 0, GameState.battle_enemies.size() - 1)
        selected_target = GameState.battle_enemies[controller.selected_enemy]
    var best_slot := -1
    var best_score := -99999.0
    for slot in range(loadout.size()):
        var skill_id := str(loadout[slot])
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty() or not POSITION_RULES.is_usable(hero, skill):
            continue
        var effect := str(skill.get("effect", "attack"))
        if effect == "attack":
            if selected_target.is_empty() or not TARGETING_RULES.can_target(hero, skill, selected_target, GameState.battle_enemies):
                continue
        var score := 0.0
        if effect in ["heal", "support", "medical"]:
            score = (100.0 if lowest_ratio < 0.45 else 12.0) + float(skill.get("heal", 0))
        elif effect in ["guard", "posture"]:
            score = 48.0 if lowest_ratio < 0.65 else 18.0
        elif effect == "diagnostic":
            score = 28.0
        else:
            score = 55.0 + float(skill.get("power", 1.0)) * 20.0 + float(skill.get("status_chance", 0)) * 0.1
        if score > best_score:
            best_score = score
            best_slot = slot
    if best_slot < 0:
        return {"usable": false}
    return {"usable": true, "slot": best_slot, "skill_id": str(loadout[best_slot])}

func _drive_scenario(seed_value: int, build: Dictionary, scenario: Dictionary, skill_usage: Dictionary) -> Dictionary:
    var room := {"id":"v3_%s_%s_%d" % [str(build.get("id", "build")), str(scenario.get("id", "scenario")), seed_value], "type":str(scenario.get("type", "combat")), "depth":int(scenario.get("depth", 1))}
    controller._start_roguelike_room_battle(room)
    await get_tree().process_frame
    var start_round := int(controller.combat_round_number)
    var actions := 0
    var no_progress := 0
    var locked_wait_frames := 0
    var last_signature := _hp_signature()
    var damage_total := 0
    var healing_total := 0

    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and actions < MAX_ACTIONS:
        if bool(controller.battle_locked):
            await get_tree().process_frame
            locked_wait_frames += 1
            if locked_wait_frames >= MAX_LOCKED_WAIT_FRAMES:
                failures.append("battle_locked_%s_%s_%d" % [str(build.get("id", "build")), str(scenario.get("id", "scenario")), seed_value])
                break
            continue
        locked_wait_frames = 0
        controller._ensure_combat_state()
        var hero: Dictionary = controller._active_combat_hero()
        if hero.is_empty():
            await get_tree().process_frame
            no_progress += 1
            if no_progress >= NO_PROGRESS_LIMIT:
                failures.append("softlock_%s_%s_%d" % [str(build.get("id", "build")), str(scenario.get("id", "scenario")), seed_value])
                break
            continue
        _select_lowest_hp_enemy()
        var choice := _choose_skill(hero)
        var before_enemy := _enemy_hp_total()
        var before_party := _party_hp_total()
        var skill_id := "__pass__"
        if not bool(choice.get("usable", false)):
            controller._pass_combat_turn()
        else:
            skill_id = str(choice.get("skill_id", "basic_strike"))
            controller._use_combat_skill(int(choice.get("slot", 0)))
        await get_tree().process_frame
        actions += 1
        skill_usage[skill_id] = int(skill_usage.get(skill_id, 0)) + 1
        damage_total += maxi(0, before_enemy - _enemy_hp_total())
        healing_total += maxi(0, _party_hp_total() - before_party)
        var signature := _hp_signature()
        if signature == last_signature:
            no_progress += 1
        else:
            no_progress = 0
            last_signature = signature
        if no_progress >= NO_PROGRESS_LIMIT:
            failures.append("no_progress_%s_%s_%d" % [str(build.get("id", "build")), str(scenario.get("id", "scenario")), seed_value])
            break

    return {
        "scenario_id": str(scenario.get("id", "scenario")),
        "victory": GameState.alive_enemies().is_empty(),
        "actions": actions,
        "rounds": maxi(1, int(controller.combat_round_number) - start_round + 1),
        "deaths": GameState.party.size() - GameState.alive_heroes().size(),
        "damage": damage_total,
        "healing": healing_total,
        "party_hp_remaining": _party_hp_total()
    }
