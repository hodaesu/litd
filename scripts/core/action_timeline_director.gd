extends Node

const TIMELINE_QUANTUM := 100.0
const MIN_INTERVAL := 0.1
const MAX_SLOW_MULTIPLIER := 4.0
const MAX_CONSECUTIVE_ACTIONS := 8

var round_index := 1
var initiative: Array[Dictionary] = []
var timeline_clock := 0.0
var continuous_entries: Array[Dictionary] = []
var _continuous_sequence := 0
var _last_actor_id := ""
var _consecutive_actions := 0

func rebuild(heroes: Array, enemies: Array) -> Array[Dictionary]:
    initiative.clear()
    var sequence := 0
    for hero_value: Variant in heroes:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        var hero_entry := _entry(hero, false)
        hero_entry["sequence"] = sequence
        sequence += 1
        initiative.append(hero_entry)
    for enemy_value: Variant in enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        var enemy_entry := _entry(enemy, true)
        enemy_entry["sequence"] = sequence
        sequence += 1
        initiative.append(enemy_entry)
    _sort_initiative()
    return initiative.duplicate(true)

func preview_lines(heroes: Array, enemies: Array) -> Array[String]:
    var lines: Array[String] = []
    for entry: Dictionary in rebuild(heroes, enemies):
        var suffix := ""
        if bool(entry.get("enemy", false)):
            suffix = " · " + String(entry.get("intent", "intention incertaine"))
        if bool(entry.get("guarding", false)):
            suffix += " · garde"
        if int(entry.get("riposte", 0)) > 0:
            suffix += " · riposte %d%%" % int(entry.get("riposte", 0))
        lines.append("%s %s%s" % ["ENNEMI" if bool(entry.get("enemy", false)) else "HÉROS", String(entry.get("name", "")), suffix])
    return lines

func modify_initiative(character_id: String, amount: float) -> void:
    for entry: Dictionary in initiative:
        if String(entry.get("id", "")) == character_id:
            entry["initiative"] = float(entry.get("initiative", 0)) + amount
            break
    _sort_initiative()

func next_round() -> void:
    round_index += 1

# --- Timeline continue -----------------------------------------------------
# La timeline historique `rebuild()` reste disponible pour les vues d'initiative.
# Ces fonctions ajoutent un scheduler réellement consommable : chaque acteur a
# un prochain instant d'action, mis à jour après son action ou un tour sauté.

func begin_continuous(heroes: Array, enemies: Array) -> Array[Dictionary]:
    timeline_clock = 0.0
    continuous_entries.clear()
    _continuous_sequence = 0
    _last_actor_id = ""
    _consecutive_actions = 0
    for hero_value: Variant in heroes:
        if hero_value is not Dictionary:
            continue
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        continuous_entries.append(_continuous_entry(hero, false))
    for enemy_value: Variant in enemies:
        if enemy_value is not Dictionary:
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        continuous_entries.append(_continuous_entry(enemy, true))
    _sort_continuous()
    return continuous_snapshot()

func continuous_snapshot() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in continuous_entries:
        if value is Dictionary:
            var entry: Dictionary = value
            var copy := entry.duplicate(true)
            copy.erase("source")
            result.append(copy)
    return result

func set_continuous_status(character_id: String, status: String, value: Variant) -> bool:
    var entry := _continuous_entry_by_id(character_id)
    if entry.is_empty():
        return false
    match status:
        "stun_turns":
            entry["stun_turns"] = maxi(0, int(value))
        "slow_multiplier":
            entry["slow_multiplier"] = clampf(float(value), 1.0, MAX_SLOW_MULTIPLIER)
        "speed":
            entry["speed"] = maxf(1.0, float(value))
        _:
            entry[status] = value
    _sort_continuous()
    return true

func peek_next_action() -> Dictionary:
    _prune_dead_continuous_entries()
    if continuous_entries.is_empty():
        return {}
    _sort_continuous()
    return _public_continuous_entry(continuous_entries[0])

func consume_next_action() -> Dictionary:
    _prune_dead_continuous_entries()
    if continuous_entries.is_empty():
        return {"valid": false, "reason": "empty_timeline"}
    _sort_continuous()
    _apply_anti_lock_guard()
    _sort_continuous()

    var entry: Dictionary = continuous_entries[0]
    timeline_clock = maxf(timeline_clock, float(entry.get("next_action_at", timeline_clock)))
    var actor_id := str(entry.get("id", ""))
    var interval := _interval_for_entry(entry)
    var event := {
        "valid": true,
        "id": actor_id,
        "name": str(entry.get("name", "Combattant")),
        "enemy": bool(entry.get("enemy", false)),
        "time": timeline_clock,
        "interval": interval,
        "skipped": false,
        "reason": "action",
        "recovered": false,
        "anti_lock": bool(entry.get("anti_lock_pending", false))
    }
    entry["anti_lock_pending"] = false

    var stun_turns := maxi(0, int(entry.get("stun_turns", 0)))
    if stun_turns > 0:
        stun_turns -= 1
        entry["stun_turns"] = stun_turns
        event["skipped"] = true
        event["reason"] = "stunned"
        event["recovered"] = stun_turns == 0
        entry["next_action_at"] = timeline_clock + interval
        # Un tour sauté rompt la séquence d'actions effectives : il ne doit pas
        # alimenter le garde anti-lock comme s'il s'agissait d'une vraie attaque.
        _last_actor_id = ""
        _consecutive_actions = 0
    else:
        entry["acted_count"] = int(entry.get("acted_count", 0)) + 1
        entry["next_action_at"] = timeline_clock + interval
        if actor_id == _last_actor_id:
            _consecutive_actions += 1
        else:
            _last_actor_id = actor_id
            _consecutive_actions = 1

    _sort_continuous()
    event["next_action_at"] = float(entry.get("next_action_at", timeline_clock + interval))
    return event

func simulate_continuous(action_events: int, safety_iterations: int = 4096) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var iterations := 0
    while result.size() < maxi(0, action_events) and iterations < maxi(1, safety_iterations):
        iterations += 1
        var event := consume_next_action()
        if not bool(event.get("valid", false)):
            break
        result.append(event)
    return result

func _continuous_entry(character: Dictionary, enemy: bool) -> Dictionary:
    var base := _entry(character, enemy)
    var sequence := _continuous_sequence
    _continuous_sequence += 1
    var entry := {
        "id": str(base.get("id", "")),
        "name": str(base.get("name", "Combattant")),
        "enemy": enemy,
        "source": character,
        "speed": maxf(1.0, float(base.get("initiative", 10.0))),
        "slow_multiplier": clampf(float(character.get("slow_multiplier", 1.0)), 1.0, MAX_SLOW_MULTIPLIER),
        "stun_turns": maxi(0, int(character.get("stun_turns", character.get("stunned_turns", 0)))),
        "sequence": sequence,
        "acted_count": 0,
        "anti_lock_pending": false
    }
    entry["next_action_at"] = _interval_for_entry(entry)
    return entry

func _interval_for_entry(entry: Dictionary) -> float:
    var speed := maxf(1.0, float(entry.get("speed", 10.0)))
    var slow := clampf(float(entry.get("slow_multiplier", 1.0)), 1.0, MAX_SLOW_MULTIPLIER)
    return maxf(MIN_INTERVAL, TIMELINE_QUANTUM / speed * slow)

func _continuous_entry_by_id(character_id: String) -> Dictionary:
    for value: Variant in continuous_entries:
        if value is Dictionary:
            var entry: Dictionary = value
            if str(entry.get("id", "")) == character_id:
                return entry
    return {}

func _prune_dead_continuous_entries() -> void:
    for index in range(continuous_entries.size() - 1, -1, -1):
        var entry: Dictionary = continuous_entries[index]
        var source_value: Variant = entry.get("source", {})
        if source_value is Dictionary and int((source_value as Dictionary).get("hp", 0)) <= 0:
            continuous_entries.remove_at(index)

func _apply_anti_lock_guard() -> void:
    if _last_actor_id == "" or _consecutive_actions < MAX_CONSECUTIVE_ACTIONS or continuous_entries.size() < 2:
        return
    _sort_continuous()
    var first: Dictionary = continuous_entries[0]
    if str(first.get("id", "")) != _last_actor_id:
        return
    var competitor_index := -1
    for index in range(1, continuous_entries.size()):
        if str((continuous_entries[index] as Dictionary).get("id", "")) != _last_actor_id:
            competitor_index = index
            break
    if competitor_index < 0:
        return
    var competitor: Dictionary = continuous_entries[competitor_index]
    first["next_action_at"] = maxf(float(first.get("next_action_at", 0.0)), float(competitor.get("next_action_at", 0.0)) + MIN_INTERVAL)
    first["anti_lock_pending"] = true
    _last_actor_id = ""
    _consecutive_actions = 0

func _public_continuous_entry(entry: Dictionary) -> Dictionary:
    var copy := entry.duplicate(true)
    copy.erase("source")
    return copy

func _sort_initiative() -> void:
    initiative.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_value := float(left.get("initiative", 0.0))
        var right_value := float(right.get("initiative", 0.0))
        if not is_equal_approx(left_value, right_value):
            return left_value > right_value
        return int(left.get("sequence", 0)) < int(right.get("sequence", 0))
    )

func _sort_continuous() -> void:
    continuous_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_time := float(left.get("next_action_at", 0.0))
        var right_time := float(right.get("next_action_at", 0.0))
        if not is_equal_approx(left_time, right_time):
            return left_time < right_time
        return int(left.get("sequence", 0)) < int(right.get("sequence", 0))
    )

func _entry(character: Dictionary, enemy: bool) -> Dictionary:
    var fear_penalty := float(character.get("enemy_fear", character.get("fear_gauge", 0))) * 0.08 if enemy else float(character.get("fear", 0)) * 0.03
    return {
        "id": String(character.get("id", "")),
        "name": String(character.get("name", "Combattant")),
        "enemy": enemy,
        "initiative": float(character.get("speed", 10)) - fear_penalty,
        "intent": EnemyCombatDirector.intent_preview(character) if enemy else "",
        "guarding": bool(character.get("guarding", false)),
        "riposte": int(character.get("riposte_chance", 0))
    }
