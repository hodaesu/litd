extends RefCounted

const TARGETING_RULES := preload("res://scripts/core/combat_targeting_rules.gd")

static func combat_state_signature(controller: Control) -> String:
    var acted: Array[String] = []
    for hero_id_value in controller.combat_acted_hero_ids:
        acted.append(str(hero_id_value))
    acted.sort()
    return "%d:%d:%d:%d:r%d:a%s:t%s:l%s:e%d:p%d:c%s" % [
        _party_hp_total(),
        _enemy_hp_total(),
        GameState.alive_heroes().size(),
        GameState.alive_enemies().size(),
        int(controller.combat_round_number),
        str(acted),
        str(controller.combat_active_hero_id),
        str(bool(controller.battle_locked)),
        int(controller.selected_enemy),
        int(controller.pending_target_skill_slot),
        str(controller.pending_choice_kind)
    ]

static func requires_enemy_target(skill: Dictionary) -> bool:
    var target := str(skill.get("target", ""))
    if target.begins_with("enemy"):
        return true
    return target == "" and str(skill.get("effect", "attack")) == "attack"

static func best_legal_target_index(hero: Dictionary, skill: Dictionary) -> int:
    var best_index := -1
    var best_hp := 2147483647
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        var hp := int(enemy.get("hp", 0))
        if hp <= 0:
            continue
        if not TARGETING_RULES.can_target(hero, skill, enemy, GameState.battle_enemies):
            continue
        if hp < best_hp:
            best_hp = hp
            best_index = index
    return best_index

static func resolve_pending_player_choice(controller: Control, preferred_enemy_index: int = -1) -> bool:
    if int(controller.pending_target_skill_slot) >= 0:
        var targets: Array[int] = controller.pending_target_indices
        if targets.is_empty():
            return false
        var enemy_index := preferred_enemy_index if targets.has(preferred_enemy_index) else int(targets[0])
        controller._confirm_pending_enemy_target(enemy_index)
        return true

    if str(controller.pending_choice_kind) == "skill":
        var ally_ids: Array[String] = controller.pending_ally_ids
        if ally_ids.is_empty():
            return false
        var best_id := ally_ids[0]
        var best_ratio := 2.0
        for ally_id in ally_ids:
            for hero_value in GameState.party:
                var hero: Dictionary = hero_value
                if str(hero.get("id", "")) != ally_id or int(hero.get("hp", 0)) <= 0:
                    continue
                var ratio := float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("max_hp", 1)))
                if ratio < best_ratio:
                    best_ratio = ratio
                    best_id = ally_id
        controller._confirm_ally_target_v46(best_id)
        return true

    return false

static func _party_hp_total() -> int:
    var total := 0
    for hero_value in GameState.party:
        total += maxi(0, int((hero_value as Dictionary).get("hp", 0)))
    return total

static func _enemy_hp_total() -> int:
    var total := 0
    for enemy_value in GameState.battle_enemies:
        total += maxi(0, int((enemy_value as Dictionary).get("hp", 0)))
    return total
