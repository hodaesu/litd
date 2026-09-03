extends Node

signal enemy_fear_changed(enemy: Dictionary, before: int, after: int, reason: String)
signal hero_renown_changed(hero_id: String, score: float)

const DATA_PATH := "res://data/enemy_fear_renown.json"

var data: Dictionary = {}
var hero_records: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> bool:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}
    return not data.is_empty()

func reset_new_game() -> void:
    hero_records.clear()

func prepare_hero(hero: Dictionary) -> Dictionary:
    var hero_id: String = str(hero.get("id", ""))
    if hero_id == "":
        return {}
    if not hero_records.has(hero_id):
        hero_records[hero_id] = {
            "dungeons_survived": 0,
            "bosses_defeated": 0,
            "enemies_defeated": 0,
            "critical_hits": 0,
            "ultimates_used": 0,
            "heroic_rescues": 0,
            "perfect_dungeons": 0,
            "deeds": {},
            "family_victories": {}
        }
    return hero_records[hero_id]

func renown_score(hero: Dictionary) -> float:
    var record: Dictionary = prepare_hero(hero)
    var weights: Dictionary = data.get("renown_weights", {})
    var score := float(hero.get("level", 1)) * float(weights.get("level", 0.45))
    score += float(record.get("dungeons_survived", 0)) * float(weights.get("dungeon_survived", 5.0))
    score += float(record.get("bosses_defeated", 0)) * float(weights.get("boss_defeated", 12.0))
    score += float(record.get("enemies_defeated", 0)) * float(weights.get("enemy_defeated", 0.35))
    score += float(record.get("critical_hits", 0)) * float(weights.get("critical_hit", 0.6))
    score += float(record.get("ultimates_used", 0)) * float(weights.get("ultimate_used", 2.0))
    score += float(record.get("heroic_rescues", 0)) * float(weights.get("heroic_rescue", 4.0))
    score += float(record.get("perfect_dungeons", 0)) * float(weights.get("perfect_dungeon", 8.0))
    return clampf(score, 0.0, 100.0)

func party_threat(heroes: Array) -> float:
    var scores: Array[float] = []
    for hero_value: Variant in heroes:
        if hero_value is Dictionary and int((hero_value as Dictionary).get("hp", 0)) > 0:
            scores.append(renown_score(hero_value))
    if scores.is_empty():
        return 0.0
    scores.sort()
    scores.reverse()
    var party_rule: Dictionary = data.get("party_reputation", {})
    var total := scores[0] * float(party_rule.get("strongest_weight", 1.0))
    for index in range(1, scores.size()):
        total += scores[index] * float(party_rule.get("other_heroes_weight", 0.35))
    return minf(total, float(party_rule.get("max_starting_fear", 70.0)))

func initialize_enemy(enemy: Dictionary, heroes: Array) -> int:
    var courage: Dictionary = data.get("courage", {})
    var multiplier := float(courage.get("default_multiplier", 1.0))
    if bool(enemy.get("boss", false)):
        multiplier = float(courage.get("boss_multiplier", 0.55))
    elif bool(enemy.get("elite", false)):
        multiplier = float(courage.get("elite_multiplier", 0.75))
    var starting := int(round(party_threat(heroes) * multiplier))
    var trait_modifiers: Dictionary = CharacterTraitDirector.modifiers(enemy)
    starting -= int(round(float(trait_modifiers.get("fear_resistance", 0.0))))
    starting -= int(enemy.get("remanence_fear_resistance", 0))
    starting = clampi(starting, int(courage.get("minimum_starting_fear", 0)), 100)
    enemy["enemy_fear"] = starting
    enemy["enemy_fear_state"] = state_for(starting)
    enemy["enemy_fear_initial"] = starting
    return starting

func apply_event(enemy: Dictionary, event_id: String, context: Dictionary = {}) -> Dictionary:
    if enemy.is_empty() or int(enemy.get("hp", 0)) <= 0:
        return {}
    var events: Dictionary = data.get("encounter_events", {})
    var rule: Dictionary = events.get(event_id, {})
    if rule.is_empty():
        return {}
    var delta := float(rule.get("fear", rule.get("flat", 0.0)))
    if event_id == "hero_damage":
        var max_hp := maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
        delta += clampf(float(context.get("damage", 0)) / float(max_hp), 0.0, 1.0) * float(rule.get("hp_ratio", 0.0))
    if bool(enemy.get("boss", false)) and delta > 0.0:
        delta *= float(data.get("courage", {}).get("boss_multiplier", 0.55))
    return change_fear(enemy, int(round(delta)), event_id)

func apply_witness_event(enemies: Array, event_id: String, context: Dictionary = {}) -> Array:
    var results: Array = []
    for enemy_value: Variant in enemies:
        if enemy_value is Dictionary:
            var result := apply_event(enemy_value, event_id, context)
            if not result.is_empty():
                results.append(result)
    return results

func change_fear(enemy: Dictionary, delta: int, reason: String) -> Dictionary:
    var before := clampi(int(enemy.get("enemy_fear", 0)), 0, 100)
    var after := clampi(before + delta, 0, 100)
    enemy["enemy_fear"] = after
    enemy["enemy_fear_state"] = state_for(_effective_fear(enemy))
    if before != after:
        enemy_fear_changed.emit(enemy, before, after, reason)
    return {"before": before, "after": after, "delta": after - before, "state": state_for(_effective_fear(enemy)), "reason": reason}

func state_for(value: int) -> String:
    var fear := clampi(value, 0, 100)
    var thresholds: Dictionary = data.get("thresholds", {})
    if fear >= int(thresholds.get("panic", 100)):
        return "panic"
    if fear >= int(thresholds.get("terrified", 75)):
        return "terrified"
    if fear >= int(thresholds.get("shaken", 50)):
        return "shaken"
    if fear >= int(thresholds.get("wary", 25)):
        return "wary"
    return "calm"

func combat_modifiers(enemy: Dictionary) -> Dictionary:
    var state := state_for(_effective_fear(enemy))
    if state == "calm":
        return {"state": state, "accuracy_multiplier": 1.0, "damage_multiplier": 1.0, "retreat_bias": 0.0}
    var values: Dictionary = data.get("gameplay", {}).get(state, {})
    var result := values.duplicate(true)
    result["state"] = state
    return result

func body_psychological_state(enemy: Dictionary) -> String:
    var state := state_for(_effective_fear(enemy))
    if state == "wary":
        return "tense"
    if state == "shaken" or state == "terrified":
        return "terrified"
    if state == "panic":
        return "panic"
    return "neutral"

func should_panic(enemy: Dictionary, round_number: int) -> bool:
    var effective := _effective_fear(enemy)
    if state_for(effective) != "panic":
        return false
    var chance := float(data.get("gameplay", {}).get("panic", {}).get("panic_action_chance", 0.45))
    var seed_text := "%s|%d|%d" % [str(enemy.get("id", enemy.get("name", "enemy"))), round_number, effective]
    return float(abs(seed_text.hash()) % 1000) / 1000.0 < chance

func _effective_fear(enemy: Dictionary) -> int:
    return clampi(int(enemy.get("enemy_fear", 0)) - int(enemy.get("remanence_fear_resistance", 0)), 0, 100)

func record_deed(hero: Dictionary, deed_id: String, amount: int = 1, family_id: String = "") -> void:
    var hero_id: String = str(hero.get("id", ""))
    var record: Dictionary = prepare_hero(hero)
    if record.is_empty():
        return
    var field_map := {
        "dungeon_survived": "dungeons_survived",
        "boss_defeated": "bosses_defeated",
        "enemy_defeated": "enemies_defeated",
        "critical_hit": "critical_hits",
        "ultimate_used": "ultimates_used",
        "heroic_rescue": "heroic_rescues",
        "perfect_dungeon": "perfect_dungeons"
    }
    var field := str(field_map.get(deed_id, ""))
    if field != "":
        record[field] = maxi(0, int(record.get(field, 0)) + amount)
    var deeds: Dictionary = record.get("deeds", {})
    deeds[deed_id] = maxi(0, int(deeds.get(deed_id, 0)) + amount)
    record["deeds"] = deeds
    if family_id != "":
        var families: Dictionary = record.get("family_victories", {})
        families[family_id] = maxi(0, int(families.get(family_id, 0)) + amount)
        record["family_victories"] = families
    hero_records[hero_id] = record
    hero_renown_changed.emit(hero_id, renown_score(hero))

func serialize() -> Dictionary:
    return {"hero_records": hero_records.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    hero_records = payload.get("hero_records", {}).duplicate(true)
