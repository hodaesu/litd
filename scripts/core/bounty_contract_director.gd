extends Node

signal bounty_board_changed
signal bounty_progressed(contract_id: String)
signal bounty_completed(contract_id: String)

const DATA_PATH := "res://data/bounty_contracts.json"

var data: Dictionary = {}
var offered_contracts: Array = []
var active_contracts: Array = []
var completed_contracts: Array = []
var board_seed := 0
var completed_dungeon_runs := 0
var completion_streak := 0

func _ready() -> void:
    data = _load_json(DATA_PATH)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    offered_contracts = []
    active_contracts = []
    completed_contracts = []
    board_seed = 0
    completed_dungeon_runs = 0
    completion_streak = 0
    bounty_board_changed.emit()

func generate_dungeon_board(dungeon_id: String, dungeon_tier: int, context: Dictionary, seed_value: int) -> Array:
    board_seed = seed_value
    var candidates: Array = []
    for value in data.get("archetypes", []):
        var archetype: Dictionary = value
        var targets: Array = _targets_for(archetype, context)
        if targets.is_empty():
            continue
        for target_value in targets:
            candidates.append(_instantiate(archetype, dungeon_id, dungeon_tier, String(target_value), seed_value + candidates.size()))
    offered_contracts = _deterministic_pick(candidates, int(data.get("rules", {}).get("board_size", 3)), seed_value)
    bounty_board_changed.emit()
    return offered_contracts.duplicate(true)

func generate_campaign_board(chapter_id: String, campaign_tier: int, context: Dictionary, seed_value: int) -> Array:
    var candidates: Array = []
    for value in data.get("campaign_bounties", {}).get("archetypes", []):
        var archetype: Dictionary = value
        var targets: Array = context.get("enemy_families", ["any"])
        for target_value in targets:
            var contract := _instantiate(archetype, chapter_id, campaign_tier, String(target_value), seed_value + candidates.size())
            contract["scope"] = "campaign"
            contract["reward_multiplier"] = float(archetype.get("reward_multiplier", 2.0))
            candidates.append(contract)
    board_seed = seed_value
    var campaign_offers := _deterministic_pick(candidates, int(data.get("campaign_bounties", {}).get("board_size", 2)), seed_value)
    for offer_value: Variant in campaign_offers:
        var offer: Dictionary = offer_value
        var already_present := false
        for existing_value: Variant in offered_contracts:
            if String((existing_value as Dictionary).get("id", "")) == String(offer.get("id", "")):
                already_present = true
                break
        if not already_present:
            offered_contracts.append(offer)
    bounty_board_changed.emit()
    return campaign_offers.duplicate(true)

func _targets_for(archetype: Dictionary, context: Dictionary) -> Array:
    match String(archetype.get("target_source", "")):
        "enemy_family": return context.get("enemy_families", [])
        "dungeon_elites": return context.get("elites", [])
        "capturable_enemy_family": return context.get("capturable_families", [])
        "enemy_anatomy": return context.get("body_parts", [])
        "dungeon": return [String(context.get("dungeon_id", "dungeon"))]
    return []

func _instantiate(archetype: Dictionary, scope_id: String, tier: int, target: String, salt: int) -> Dictionary:
    var counts: Array = archetype.get("counts", [1])
    var required := int(counts[abs(salt) % counts.size()])
    var contract_id := "%s:%s:%s:%d" % [scope_id, String(archetype.get("id", "contract")), target, abs(salt)]
    var scaling: Dictionary = data.get("reward_scaling", {})
    return {
        "id": contract_id,
        "archetype_id": String(archetype.get("id", "")),
        "name": String(archetype.get("name", "Contrat")),
        "scope": "dungeon",
        "scope_id": scope_id,
        "event": String(archetype.get("event", "")),
        "target": target,
        "required": required,
        "progress": 0,
        "status": "offered",
        "expires_after": int(data.get("rules", {}).get("expiry_runs", 3)),
        "reward": {
            "gold": int(scaling.get("base_gold", 25)) + max(0, tier - 1) * int(scaling.get("gold_per_dungeon_tier", 12)),
            "essence": int(scaling.get("base_essence", 2)) + max(0, tier - 1) * int(scaling.get("essence_per_difficulty", 1)),
            "renown": int(scaling.get("renown_per_contract", 3))
        }
    }

func _deterministic_pick(candidates: Array, count: int, seed_value: int) -> Array:
    var pool := candidates.duplicate(true)
    var result: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    while not pool.is_empty() and result.size() < count:
        result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
    return result

func accept_contract(contract_id: String) -> bool:
    if active_contracts.size() >= int(data.get("rules", {}).get("max_active", 2)):
        return false
    for value in offered_contracts:
        var contract: Dictionary = value
        if String(contract.get("id", "")) == contract_id:
            contract["status"] = "active"
            active_contracts.append(contract.duplicate(true))
            offered_contracts.erase(value)
            bounty_board_changed.emit()
            return true
    return false

func record_event(event_id: String, target_id: String = "", amount: int = 1) -> void:
    for value in active_contracts:
        var contract: Dictionary = value
        if String(contract.get("status", "")) != "active" or String(contract.get("event", "")) != event_id:
            continue
        var expected := String(contract.get("target", "any"))
        if expected != "any" and target_id != "" and expected != target_id:
            continue
        contract["progress"] = mini(int(contract.get("required", 1)), int(contract.get("progress", 0)) + max(0, amount))
        bounty_progressed.emit(String(contract.get("id", "")))
        if int(contract["progress"]) >= int(contract.get("required", 1)):
            contract["status"] = "completed"
            bounty_completed.emit(String(contract.get("id", "")))
    bounty_board_changed.emit()

func claim_contract(contract_id: String) -> Dictionary:
    for value in active_contracts:
        var contract: Dictionary = value
        if String(contract.get("id", "")) != contract_id or String(contract.get("status", "")) != "completed":
            continue
        var reward: Dictionary = contract.get("reward", {}).duplicate(true)
        var streak_bonus: int = mini(completion_streak, int(data.get("reward_scaling", {}).get("streak_cap", 5)))
        reward["gold"] = roundi(int(reward.get("gold", 0)) * (1.0 + streak_bonus * float(data.get("reward_scaling", {}).get("streak_bonus_percent", 10)) / 100.0))
        GameState.gold += int(reward.get("gold", 0))
        GameState.essence += int(reward.get("essence", 0))
        completion_streak += 1
        contract["status"] = "claimed"
        completed_contracts.append(contract.duplicate(true))
        active_contracts.erase(value)
        bounty_board_changed.emit()
        return reward
    return {}

func close_dungeon_run(success: bool) -> void:
    completed_dungeon_runs += 1
    if not success:
        completion_streak = 0
    for value in active_contracts:
        var contract: Dictionary = value
        if String(contract.get("scope", "")) == "dungeon" and String(contract.get("status", "")) == "active":
            contract["expires_after"] = int(contract.get("expires_after", 1)) - 1
            if int(contract["expires_after"]) <= 0:
                contract["status"] = "expired"
    bounty_board_changed.emit()

func serialize() -> Dictionary:
    return {
        "offered": offered_contracts.duplicate(true),
        "active": active_contracts.duplicate(true),
        "completed": completed_contracts.duplicate(true),
        "board_seed": board_seed,
        "completed_dungeon_runs": completed_dungeon_runs,
        "completion_streak": completion_streak
    }

func deserialize(payload: Dictionary) -> void:
    offered_contracts = payload.get("offered", []).duplicate(true)
    active_contracts = payload.get("active", []).duplicate(true)
    completed_contracts = payload.get("completed", []).duplicate(true)
    board_seed = int(payload.get("board_seed", 0))
    completed_dungeon_runs = int(payload.get("completed_dungeon_runs", 0))
    completion_streak = int(payload.get("completion_streak", 0))
    bounty_board_changed.emit()
