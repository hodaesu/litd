extends Node

const DATA_PATH := "res://data/psychology_social_combat.json"

var data: Dictionary = {}
var _last_companion_intervention: Dictionary = {}

func _ready() -> void:
    _load_data()
    if not AshlandsCombatBridge.ashlands_combat_started.is_connected(_on_campaign_combat_started):
        AshlandsCombatBridge.ashlands_combat_started.connect(_on_campaign_combat_started)

func _load_data() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func reset_runtime() -> void:
    _last_companion_intervention.clear()

func _on_campaign_combat_started(_encounter_id: String, _encounter_type: String) -> void:
    reset_runtime()

func select_enemy_target(enemy: Dictionary, targets: Array, round_number: int) -> Dictionary:
    if targets.is_empty():
        return {}
    var best: Dictionary = targets[0]
    var best_score := -INF
    for target_value in targets:
        var target: Dictionary = target_value
        var score := target_score(enemy, target, round_number)
        if score > best_score:
            best = target
            best_score = score
    return best

func target_score(enemy: Dictionary, hero: Dictionary, round_number: int = 1) -> float:
    var rules: Dictionary = data.get("targeting", {})
    var fear := float(clampi(int(hero.get("fear", 0)), 0, 100))
    var max_hp := maxi(1, int(hero.get("max_hp", 1)))
    var hp_ratio := clampf(float(hero.get("hp", 0)) / float(max_hp), 0.0, 1.0)
    var score := fear * float(rules.get("fear_weight", 1.0))
    score += (1.0 - hp_ratio) * float(rules.get("low_hp_weight", 28.0))

    if fear >= 100.0:
        score += float(rules.get("panic_bonus", 45.0))
    elif fear >= 75.0:
        score += float(rules.get("terrified_bonus", 24.0))

    var psychology := PsychologyRuntime.state_for(hero)
    score += float(psychology.get("traumas", []).size()) * float(rules.get("trauma_bonus", 8.0))

    var boss := _is_boss(enemy)
    if boss:
        score *= float(rules.get("boss_fear_multiplier", 1.35))
    elif int(enemy.get("fear", 0)) >= int(data.get("enemy_pressure", {}).get("minimum_enemy_fear", 5)):
        score *= float(rules.get("high_fear_enemy_multiplier", 1.20))

    var boss_rule := _boss_rule(enemy)
    score += float(boss_rule.get("fear_target_bonus", 0.0)) * (fear / 100.0)

    # Départage déterministe : assez faible pour ne jamais écraser la logique tactique.
    score += float(_stable_index("%s|%s|%d" % [str(enemy.get("name", "enemy")), str(hero.get("id", "hero")), round_number], 100)) / 1000.0
    return score

func apply_enemy_pressure(enemy: Dictionary, hero: Dictionary, round_number: int) -> Dictionary:
    if enemy.is_empty() or hero.is_empty() or int(hero.get("hp", 0)) <= 0:
        return {}
    var rules: Dictionary = data.get("enemy_pressure", {})
    var enemy_fear := int(enemy.get("fear", 0))
    var boss := _is_boss(enemy)
    if enemy_fear < int(rules.get("minimum_enemy_fear", 5)) and not boss:
        return {}

    var extra := 0
    var fear_before := int(hero.get("fear", 0))
    if fear_before >= 75:
        extra += int(rules.get("terrified_extra_fear", 2))
    if boss:
        extra += int(rules.get("boss_extra_fear", 3))
    if fear_before >= int(rules.get("panic_edge_threshold", 90)):
        extra += int(rules.get("panic_edge_extra_fear", 2))
    extra += int(_boss_rule(enemy).get("pressure_bonus", 0))
    if extra <= 0:
        return {}

    hero["fear"] = clampi(fear_before + extra, 0, 100)
    var archetype := enemy_archetype(enemy)
    var line := _enemy_line(enemy, hero, archetype, round_number)
    return {
        "extra_fear": extra,
        "fear_before": fear_before,
        "fear_after": int(hero.get("fear", 0)),
        "archetype": archetype,
        "line": line
    }

func companion_intervention(round_number: int) -> Dictionary:
    var creature := CreatureManager.active_creature()
    if creature.is_empty():
        return {}
    var species_id := str(creature.get("species_id", ""))
    var rule: Dictionary = data.get("companion_roles", {}).get(species_id, {})
    if rule.is_empty():
        return {}
    var instance_id := str(creature.get("instance_id", species_id))
    var round_key := "%s:%s" % [str(GameState.expedition_room), round_number]
    if str(_last_companion_intervention.get(instance_id, "")) == round_key:
        return {}

    var target := _most_fearful_hero()
    if target.is_empty() or int(target.get("fear", 0)) < int(rule.get("trigger_fear", 75)):
        return {}

    _last_companion_intervention[instance_id] = round_key
    var before := int(target.get("fear", 0))
    var relief := maxi(0, int(rule.get("fear_relief", 0)))
    target["fear"] = maxi(0, before - relief)
    if bool(rule.get("guard", false)):
        target["guarding"] = true
        target["guard_power"] = maxi(int(target.get("guard_power", 0)), 8)

    var hope_event := str(rule.get("hope_event", ""))
    if hope_event != "":
        PsychologyRuntime.apply_named_event(
            hope_event,
            {"source": "companion", "species_id": species_id, "round": round_number},
            [target]
        )

    var line := str(rule.get("line", ""))
    line = line.replace("{hero}", str(target.get("name", "le héros")))
    return {
        "creature": str(creature.get("name", "Le compagnon")),
        "hero_id": str(target.get("id", "")),
        "fear_before": before,
        "fear_after": int(target.get("fear", 0)),
        "guard": bool(rule.get("guard", false)),
        "line": line,
        "role": str(rule.get("role", "support"))
    }

func enemy_archetype(enemy: Dictionary) -> String:
    var boss_rule := _boss_rule(enemy)
    if not boss_rule.is_empty():
        return str(boss_rule.get("archetype", "breaker"))
    if _is_boss(enemy):
        return "breaker"
    if int(enemy.get("fear", 0)) >= int(data.get("enemy_pressure", {}).get("minimum_enemy_fear", 5)):
        return "predator"
    return "opportunist"

func _most_fearful_hero() -> Dictionary:
    var best: Dictionary = {}
    var best_fear := -1
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var fear := int(hero.get("fear", 0))
        if fear > best_fear:
            best = hero
            best_fear = fear
    return best

func _enemy_line(enemy: Dictionary, hero: Dictionary, archetype: String, round_number: int) -> String:
    var boss_rule := _boss_rule(enemy)
    var line := str(boss_rule.get("line", ""))
    if line == "":
        var lines: Array = data.get("enemy_lines", {}).get(archetype, [])
        if not lines.is_empty():
            var index := _stable_index("%s|%s|%d|%s" % [str(enemy.get("name", "enemy")), str(hero.get("id", "hero")), round_number, archetype], lines.size())
            line = str(lines[index])
    line = line.replace("{enemy}", str(enemy.get("name", "L'ennemi")))
    line = line.replace("{hero}", str(hero.get("name", "le héros")))
    return line

func _boss_rule(enemy: Dictionary) -> Dictionary:
    var boss_id := str(enemy.get("chapter_boss_id", ""))
    if boss_id == "" and AshlandsCombatBridge.active:
        boss_id = AshlandsCombatBridge.encounter_id
    var value = data.get("boss_overrides", {}).get(boss_id, {})
    return value if value is Dictionary else {}

func _is_boss(enemy: Dictionary) -> bool:
    return bool(enemy.get("boss", false)) \
        or bool(enemy.get("is_boss", false)) \
        or bool(enemy.get("deep_vestige_boss", false)) \
        or str(enemy.get("chapter_boss_id", "")) != ""

func _stable_index(key: String, size: int) -> int:
    if size <= 1:
        return 0
    var checksum := 29
    for index in range(key.length()):
        checksum = (checksum * 31 + key.unicode_at(index)) % 100000
    return checksum % size
