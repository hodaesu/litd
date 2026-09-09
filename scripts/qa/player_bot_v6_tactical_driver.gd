extends "res://scripts/qa/player_bot_v6_real_campaign.gd"

const POSITION_RULES_V6 := preload("res://scripts/core/combat_position_rules.gd")
const TARGETING_RULES_V6 := preload("res://scripts/core/combat_targeting_rules.gd")
const MAX_LOCKED_WAIT_FRAMES_V6 := 300

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

func _choose_campaign_skill(hero: Dictionary) -> Dictionary:
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    var lowest_ratio := _lowest_party_hp_ratio()
    var selected_target: Dictionary = {}
    if not GameState.battle_enemies.is_empty():
        controller.selected_enemy = clampi(controller.selected_enemy, 0, GameState.battle_enemies.size() - 1)
        selected_target = GameState.battle_enemies[controller.selected_enemy]
    var best_slot := -1
    var best_score := -99999.0
    for slot in range(loadout.size()):
        var skill_id := str(loadout[slot])
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty() or not POSITION_RULES_V6.is_usable(hero, skill):
            continue
        var effect := str(skill.get("effect", "attack"))
        if effect == "attack":
            if selected_target.is_empty() or not TARGETING_RULES_V6.can_target(hero, skill, selected_target, GameState.battle_enemies):
                continue
        var score := _skill_score(skill)
        if effect in ["heal", "support", "medical"]:
            score += 80.0 if lowest_ratio < 0.45 else -25.0
        elif effect in ["guard", "posture"] and lowest_ratio < 0.62:
            score += 30.0
        if score > best_score:
            best_score = score
            best_slot = slot
    if best_slot < 0:
        return {"usable": false}
    return {"usable": true, "slot": best_slot, "skill_id": str(loadout[best_slot])}

func _drive_combat(seed_value: int, expedition_index: int, combat_index: int, room: Dictionary) -> Dictionary:
    _reset_controller_state()
    controller._start_roguelike_room_battle(room)
    await get_tree().process_frame
    if GameState.battle_enemies.is_empty():
        return {"victory": false, "reason": "no_enemies", "actions": 0, "deaths": 0}
    var alive_before := GameState.alive_heroes().size()
    var actions := 0
    var no_progress := 0
    var locked_wait_frames := 0
    var last_signature := _hp_signature()

    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and actions < MAX_ACTIONS_PER_COMBAT:
        if bool(controller.battle_locked):
            await get_tree().process_frame
            locked_wait_frames += 1
            if locked_wait_frames >= MAX_LOCKED_WAIT_FRAMES_V6:
                failures.append("seed_%d_exp_%d_combat_%d_battle_locked" % [seed_value, expedition_index, combat_index])
                break
            continue
        locked_wait_frames = 0
        controller._ensure_combat_state()
        var hero: Dictionary = controller._active_combat_hero()
        if hero.is_empty():
            await get_tree().process_frame
            no_progress += 1
            if no_progress >= NO_PROGRESS_LIMIT:
                failures.append("seed_%d_exp_%d_combat_%d_no_active_hero" % [seed_value, expedition_index, combat_index])
                break
            continue
        _select_lowest_hp_enemy()
        if ContentScopeDirector.is_unlocked("capture") and _try_real_capture():
            actions += 1
            await get_tree().process_frame
            no_progress = 0
            last_signature = _hp_signature()
            continue
        var choice := _choose_campaign_skill(hero)
        if not bool(choice.get("usable", false)):
            controller._pass_combat_turn()
        else:
            controller._use_combat_skill(int(choice.get("slot", 0)))
        await get_tree().process_frame
        actions += 1
        var signature := _hp_signature()
        if signature == last_signature:
            no_progress += 1
        else:
            no_progress = 0
            last_signature = signature
        if no_progress >= NO_PROGRESS_LIMIT:
            failures.append("seed_%d_exp_%d_combat_%d_no_progress" % [seed_value, expedition_index, combat_index])
            break

    if actions >= MAX_ACTIONS_PER_COMBAT and not GameState.alive_enemies().is_empty():
        failures.append("seed_%d_exp_%d_combat_%d_action_cap" % [seed_value, expedition_index, combat_index])
    return {
        "victory": GameState.alive_enemies().is_empty(),
        "actions": actions,
        "deaths": maxi(0, alive_before - GameState.alive_heroes().size()),
        "party_hp_remaining": _party_hp_total()
    }

func _analyze_v6_campaigns() -> void:
    for campaign_value in campaigns:
        var campaign: Dictionary = campaign_value
        var seed_value := int(campaign.get("seed", 0))
        var victories := int(campaign.get("victories", 0))
        if victories > 0 and int(campaign.get("production_xp_events", 0)) == 0:
            alerts.append({"severity":"high","code":"production_xp_missing","seed":seed_value,"victories":victories,"message":"Des victoires réelles ont eu lieu sans aucun changement de niveau ou d'XP."})
        if int(campaign.get("recruitment_needed", 0)) > 0:
            alerts.append({"severity":"medium","code":"recruitment_not_exercised_by_v6","seed":seed_value,"deaths":int(campaign.get("recruitment_needed", 0)),"message":"Le service de recrutement existe, mais Bot v6 ne l'invoque pas encore pendant sa campagne réelle."})
        if int(campaign.get("ending_gold", 0)) == int(campaign.get("starting_gold", 0)) and victories > 0:
            alerts.append({"severity":"medium","code":"gold_flow_flat","seed":seed_value})
        if int(campaign.get("ending_essence", 0)) == int(campaign.get("starting_essence", 0)) and victories > 0:
            alerts.append({"severity":"medium","code":"essence_flow_flat","seed":seed_value})
        if int(campaign.get("save_roundtrips", 0)) == 0 and int(campaign.get("expeditions", 0)) >= V6_SAVE_INTERVAL:
            alerts.append({"severity":"high","code":"save_roundtrip_missing","seed":seed_value})
        if int(campaign.get("extractions", 0)) == 0 and int(campaign.get("expeditions", 0)) > 0:
            alerts.append({"severity":"high","code":"extraction_never_completed","seed":seed_value})
