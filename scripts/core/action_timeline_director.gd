extends Node

var round_index := 1
var initiative: Array[Dictionary] = []
var cycle_queue: Array[Dictionary] = []
var cycle_reactions: Array[Dictionary] = []
var cycle_consumed_tokens: Array[String] = []
var cycle_status: Dictionary = {}
var _cycle_sequence := 0

func rebuild(heroes: Array, enemies: Array) -> Array[Dictionary]:
    initiative.clear()
    var sequence := 0
    for hero_value: Variant in heroes:
        if hero_value is not Dictionary:
            continue
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        var hero_entry := _entry(hero, false)
        hero_entry["sequence"] = sequence
        sequence += 1
        initiative.append(hero_entry)
    for enemy_value: Variant in enemies:
        if enemy_value is not Dictionary:
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        var enemy_entry := _entry(enemy, true)
        enemy_entry["sequence"] = sequence
        sequence += 1
        initiative.append(enemy_entry)
    _sort_initiative(initiative)
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
    _sort_initiative(initiative)

func next_round() -> void:
    round_index += 1

# --- Scheduler cyclique canonique -----------------------------------------
# Tests_48 impose une action primaire par acteur et par cycle. Une réaction
# reste un événement hors-tour. Les boss multi-actions reçoivent des jetons
# supplémentaires explicites : aucune action gratuite n'est cachée au joueur.

func begin_cycle(heroes: Array, enemies: Array) -> Array[Dictionary]:
    cycle_queue.clear()
    cycle_reactions.clear()
    cycle_consumed_tokens.clear()
    cycle_status.clear()
    _cycle_sequence = 0

    var primaries: Array[Dictionary] = []
    var boss_extras: Array[Dictionary] = []
    for hero_value: Variant in heroes:
        if hero_value is not Dictionary:
            continue
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        primaries.append(_cycle_token(hero, false, 1, false))
    for enemy_value: Variant in enemies:
        if enemy_value is not Dictionary:
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        primaries.append(_cycle_token(enemy, true, 1, false))
        var actions_per_cycle := _actions_per_cycle(enemy)
        for action_index in range(2, actions_per_cycle + 1):
            boss_extras.append(_cycle_token(enemy, true, action_index, true))

    _sort_cycle_tokens(primaries)
    # Les actions supplémentaires restent séparées et visibles. Elles sont
    # ajoutées après les actions primaires par défaut ; un système de boss peut
    # ensuite les avancer/retarder explicitement via apply_cycle_shifts().
    cycle_queue.append_array(primaries)
    cycle_queue.append_array(boss_extras)
    return cycle_snapshot()

func cycle_snapshot() -> Array[Dictionary]:
    return cycle_queue.duplicate(true)

func apply_cycle_shifts(shifts: Dictionary) -> Array[Dictionary]:
    # Mutation atomique : on applique toutes les avances/retards avant un seul tri,
    # ce qui évite qu'un effet simultané dépende de l'ordre d'itération.
    for token: Dictionary in cycle_queue:
        var actor_id := str(token.get("id", ""))
        if not shifts.has(actor_id):
            continue
        token["initiative"] = float(token.get("initiative", 0.0)) + float(shifts.get(actor_id, 0.0))
    _sort_cycle_tokens(cycle_queue)
    return cycle_snapshot()

func set_cycle_status(character_id: String, status: String, value: Variant) -> void:
    var actor_status: Dictionary = cycle_status.get(character_id, {})
    actor_status[status] = value
    cycle_status[character_id] = actor_status

func register_reaction(character_id: String, reaction_id: String = "reaction") -> Dictionary:
    var reaction := {
        "id": character_id,
        "reaction_id": reaction_id,
        "round_index": round_index,
        "reaction": true,
        "grants_turn": false
    }
    cycle_reactions.append(reaction)
    return reaction.duplicate(true)

func consume_cycle_action() -> Dictionary:
    if cycle_queue.is_empty():
        return {"valid": false, "reason": "cycle_complete"}
    var token: Dictionary = cycle_queue.pop_front()
    var token_id := str(token.get("token_id", ""))
    if cycle_consumed_tokens.has(token_id):
        return {"valid": false, "reason": "duplicate_token", "token_id": token_id}
    cycle_consumed_tokens.append(token_id)

    var actor_id := str(token.get("id", ""))
    var status: Dictionary = cycle_status.get(actor_id, {})
    var stun_turns := maxi(0, int(status.get("stun_turns", 0)))
    var result := token.duplicate(true)
    result["valid"] = true
    result["skipped"] = false
    result["reason"] = "action"
    result["recovered"] = false
    if stun_turns > 0:
        stun_turns -= 1
        status["stun_turns"] = stun_turns
        cycle_status[actor_id] = status
        result["skipped"] = true
        result["reason"] = "stunned"
        result["recovered"] = stun_turns == 0
    return result

func cycle_complete() -> bool:
    return cycle_queue.is_empty()

func cycle_actor_action_counts(include_boss_extras: bool = true) -> Dictionary:
    var counts: Dictionary = {}
    for token_value: Variant in cycle_queue:
        if token_value is not Dictionary:
            continue
        var token: Dictionary = token_value
        if not include_boss_extras and bool(token.get("boss_extra", false)):
            continue
        var actor_id := str(token.get("id", ""))
        counts[actor_id] = int(counts.get(actor_id, 0)) + 1
    return counts

func _cycle_token(character: Dictionary, enemy: bool, action_index: int, boss_extra: bool) -> Dictionary:
    var base := _entry(character, enemy)
    var sequence := _cycle_sequence
    _cycle_sequence += 1
    var actor_id := str(base.get("id", ""))
    return {
        "token_id": "%s:cycle:%d:action:%d" % [actor_id, round_index, action_index],
        "id": actor_id,
        "name": str(base.get("name", "Combattant")),
        "enemy": enemy,
        "initiative": float(base.get("initiative", 0.0)),
        "intent": str(base.get("intent", "")),
        "guarding": bool(base.get("guarding", false)),
        "riposte": int(base.get("riposte", 0)),
        "action_index": action_index,
        "boss_extra": boss_extra,
        "visible": true,
        "sequence": sequence
    }

func _actions_per_cycle(character: Dictionary) -> int:
    if not bool(character.get("boss", false)):
        return 1
    return clampi(int(character.get("actions_per_cycle", character.get("boss_actions_per_cycle", 1))), 1, 4)

func _sort_initiative(entries: Array[Dictionary]) -> void:
    entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_value := float(left.get("initiative", 0.0))
        var right_value := float(right.get("initiative", 0.0))
        if not is_equal_approx(left_value, right_value):
            return left_value > right_value
        return int(left.get("sequence", 0)) < int(right.get("sequence", 0))
    )

func _sort_cycle_tokens(entries: Array[Dictionary]) -> void:
    entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_value := float(left.get("initiative", 0.0))
        var right_value := float(right.get("initiative", 0.0))
        if not is_equal_approx(left_value, right_value):
            return left_value > right_value
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
