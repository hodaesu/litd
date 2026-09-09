extends "res://scripts/qa/player_bot_v2_autotest.gd"

const TARGETING_RULES := preload("res://scripts/core/combat_targeting_rules.gd")

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

func _choose_real_skill(hero: Dictionary) -> Dictionary:
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    var injured_ratio := _lowest_party_hp_ratio()
    var best_slot := -1
    var best_score := -9999.0
    var selected_target: Dictionary = {}
    if not GameState.battle_enemies.is_empty():
        controller.selected_enemy = clampi(controller.selected_enemy, 0, GameState.battle_enemies.size() - 1)
        selected_target = GameState.battle_enemies[controller.selected_enemy]

    for slot in range(loadout.size()):
        var skill_id := str(loadout[slot])
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty() or not COMBAT_POSITION_RULES.is_usable(hero, skill):
            continue
        var effect := str(skill.get("effect", "attack"))
        if effect == "attack":
            if selected_target.is_empty() or not TARGETING_RULES.can_target(hero, skill, selected_target, GameState.battle_enemies):
                continue
        var score := 0.0
        if effect in ["heal", "support", "medical"]:
            score = 95.0 if injured_ratio < 0.42 else 10.0
            score += float(skill.get("heal", 0))
        elif effect in ["guard", "posture"]:
            score = 45.0 if injured_ratio < 0.65 else 15.0
        elif effect == "diagnostic":
            score = 24.0
        else:
            score = 50.0 + float(skill.get("power", 1.0)) * 20.0
            score += float(skill.get("critical_bonus", 0)) * 0.2
            score += float(skill.get("status_chance", 0)) * 0.1
        score += float(abs((skill_id + ":" + str(hero.get("id", ""))).hash()) % 11) * 0.01
        if score > best_score:
            best_score = score
            best_slot = slot
    if best_slot < 0:
        return {"usable": false}
    return {"usable": true, "slot": best_slot, "skill_id": str(loadout[best_slot])}
