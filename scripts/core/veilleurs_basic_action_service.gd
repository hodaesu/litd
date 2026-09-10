extends RefCounted
class_name VeilleursBasicActionService

const DATA_PATH := "res://data/veilleurs/v06/basic_actions_roster.json"
const ACTIONS_PER_COMBATANT := 4

var payload: Dictionary = {}
var load_errors: Array[String] = []

func _init() -> void:
    reload()

func reload() -> void:
    payload.clear()
    load_errors.clear()
    if not FileAccess.file_exists(DATA_PATH):
        load_errors.append("missing_basic_actions_roster")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if not (parsed is Dictionary):
        load_errors.append("invalid_basic_actions_json")
        return
    payload = parsed as Dictionary
    _validate_contract()

func is_valid() -> bool:
    return load_errors.is_empty()

func definition_id(runtime_id: String, combatant: Dictionary = {}) -> String:
    var explicit := str(combatant.get("definition_id", ""))
    if explicit != "":
        return explicit
    var suffix := runtime_id.find("#")
    return runtime_id.substr(0, suffix) if suffix >= 0 else runtime_id

func actions_for(runtime_id: String, combatant: Dictionary = {}) -> Array[Dictionary]:
    var entity_id := definition_id(runtime_id, combatant)
    var watchers: Dictionary = payload.get("watchers", {})
    if watchers.has(entity_id):
        var row: Dictionary = watchers.get(entity_id, {})
        var source: Array = row.get("actions", [])
        var result: Array[Dictionary] = []
        for value: Variant in source:
            if value is Dictionary:
                result.append((value as Dictionary).duplicate(true))
        return result
    var enemies: Dictionary = payload.get("enemies", {})
    var enemy_rows: Array = enemies.get(entity_id, [])
    var result: Array[Dictionary] = []
    for index in range(enemy_rows.size()):
        var value: Variant = enemy_rows[index]
        if not (value is Array):
            continue
        var row: Array = value
        if row.size() < 3:
            continue
        result.append({
            "id":"BA_%s_%02d" % [entity_id.trim_prefix("ENT_ENEMY_"), index + 1],
            "name":str(row[0]),
            "positions":_parse_positions(str(row[1])),
            "target":_target_for_kind(str(row[2])),
            "kind":str(row[2]),
            "requires":"none"
        })
    return result

func natural_ranks_for(runtime_id: String, combatant: Dictionary = {}) -> Array[int]:
    var entity_id := definition_id(runtime_id, combatant)
    var watchers: Dictionary = payload.get("watchers", {})
    if watchers.has(entity_id):
        var row: Dictionary = watchers.get(entity_id, {})
        var result: Array[int] = []
        for value: Variant in row.get("natural_ranks", []):
            result.append(int(value))
        return result
    var counts := {1:0, 2:0, 3:0, 4:0}
    for action: Dictionary in actions_for(entity_id):
        for value: Variant in action.get("positions", []):
            var rank := int(value)
            counts[rank] = int(counts.get(rank, 0)) + 1
    var best_count := -1
    var result: Array[int] = []
    for rank in [1, 2, 3, 4]:
        var count := int(counts.get(rank, 0))
        if count > best_count:
            best_count = count
            result = [rank]
        elif count == best_count:
            result.append(rank)
    return result

func preferred_rank(runtime_id: String, combatant: Dictionary = {}) -> int:
    var ranks := natural_ranks_for(runtime_id, combatant)
    return ranks[0] if not ranks.is_empty() else 1

func available_actions(runtime_id: String, combatant: Dictionary, rank: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for action: Dictionary in actions_for(runtime_id, combatant):
        if (action.get("positions", []) as Array).has(rank):
            result.append(action)
    return result

func action(runtime_id: String, combatant: Dictionary, action_id: String) -> Dictionary:
    for candidate: Dictionary in actions_for(runtime_id, combatant):
        if str(candidate.get("id", "")) == action_id:
            return candidate
    return {}

func _validate_contract() -> void:
    var rules: Dictionary = payload.get("rules", {})
    if int(rules.get("actions_per_combatant", 0)) != ACTIONS_PER_COMBATANT:
        load_errors.append("actions_per_combatant_contract")
    if not bool(rules.get("generic_attack_forbidden", false)) or not bool(rules.get("generic_heal_forbidden", false)):
        load_errors.append("generic_action_guardrail")
    var watchers: Dictionary = payload.get("watchers", {})
    var enemies: Dictionary = payload.get("enemies", {})
    if watchers.size() != 4:
        load_errors.append("watcher_basic_action_count")
    if enemies.size() != 24:
        load_errors.append("enemy_basic_action_count")
    for entity_value: Variant in watchers.keys():
        var entity_id := str(entity_value)
        var actions := actions_for(entity_id)
        if actions.size() != ACTIONS_PER_COMBATANT:
            load_errors.append("watcher_action_partition:%s" % entity_id)
            continue
        var natural: Array = (watchers.get(entity_id, {}) as Dictionary).get("natural_ranks", [])
        for rank_value: Variant in natural:
            if available_actions(entity_id, {}, int(rank_value)).is_empty():
                load_errors.append("natural_rank_without_action:%s:%d" % [entity_id, int(rank_value)])
    for entity_value: Variant in enemies.keys():
        var entity_id := str(entity_value)
        if actions_for(entity_id).size() != ACTIONS_PER_COMBATANT:
            load_errors.append("enemy_action_partition:%s" % entity_id)
    for entity_id in _all_entity_ids():
        for candidate: Dictionary in actions_for(entity_id):
            var name := str(candidate.get("name", "")).strip_edges().to_lower()
            if name in ["frappe", "soin"]:
                load_errors.append("generic_action_name:%s" % entity_id)

func _all_entity_ids() -> Array[String]:
    var result: Array[String] = []
    for value: Variant in (payload.get("watchers", {}) as Dictionary).keys():
        result.append(str(value))
    for value: Variant in (payload.get("enemies", {}) as Dictionary).keys():
        result.append(str(value))
    return result

func _parse_positions(text: String) -> Array[int]:
    var result: Array[int] = []
    var clean := text.strip_edges()
    if clean.find("-") >= 0:
        var parts := clean.split("-", false)
        if parts.size() == 2:
            var first := clampi(int(parts[0]), 1, 4)
            var last := clampi(int(parts[1]), 1, 4)
            for rank in range(first, last + 1):
                result.append(rank)
            return result
    var rank := clampi(int(clean), 1, 4)
    result.append(rank)
    return result

func _target_for_kind(kind: String) -> String:
    if kind in ["guard", "retreat", "advance", "reposition", "evade_reposition", "evasion_reposition", "adaptive_defense", "self_restore_from_drain"]:
        return "self"
    if kind in ["guard_ally", "restore_requires_resource"]:
        return "ally"
    return "enemy"
