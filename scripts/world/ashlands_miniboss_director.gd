extends Node

signal rotation_changed(assignments: Dictionary)

const DATA_PATH := "res://data/levels/ashlands_minibosses.json"

var data: Dictionary = {}
var assignments: Dictionary = {}
var expedition_seed := 0

func _ready() -> void:
    _load_data()

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("AshlandsMinibossDirector: missing data")
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        data = parsed

func roll_for_expedition(seed_value: int) -> Dictionary:
    expedition_seed = seed_value
    assignments.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value

    var normal_pool: Array = data.get("normal_pool", [])
    if not normal_pool.is_empty():
        var normal_boss: Dictionary = normal_pool[rng.randi_range(0, normal_pool.size() - 1)]
        var normal_zones: Array = normal_boss.get("allowed_zones", [])
        if not normal_zones.is_empty():
            var zone_id := str(normal_zones[rng.randi_range(0, normal_zones.size() - 1)])
            assignments[zone_id] = _assignment(normal_boss, "normal")

    var secret_pool: Array = data.get("secret_pool", [])
    if not secret_pool.is_empty():
        var secret_boss: Dictionary = secret_pool[rng.randi_range(0, secret_pool.size() - 1)]
        var secret_zones: Array = secret_boss.get("allowed_zones", [])
        if not secret_zones.is_empty():
            var secret_zone := str(secret_zones[rng.randi_range(0, secret_zones.size() - 1)])
            assignments[secret_zone] = _assignment(secret_boss, "secret")

    rotation_changed.emit(assignments.duplicate(true))
    return assignments.duplicate(true)

func _assignment(source: Dictionary, pool_type: String) -> Dictionary:
    return {
        "id": str(source.get("id", "")),
        "name": str(source.get("name", "")),
        "archetype": str(source.get("archetype", "")),
        "loot_tier": str(source.get("loot_tier", "major")),
        "pool_type": pool_type,
        "recruitable": false,
        "mandatory": false,
        "can_be_hidden_by_ash": false
    }

func get_assignment(zone_id: String) -> Dictionary:
    return assignments.get(zone_id, {}).duplicate(true)

func has_miniboss(zone_id: String) -> bool:
    return assignments.has(zone_id)

func get_loot_table(tier: String) -> Dictionary:
    return data.get("loot_tables", {}).get(tier, {}).duplicate(true)

func serialize() -> Dictionary:
    return {"assignments": assignments, "expedition_seed": expedition_seed}

func deserialize(payload: Dictionary) -> void:
    assignments = payload.get("assignments", {}).duplicate(true)
    expedition_seed = int(payload.get("expedition_seed", 0))
    rotation_changed.emit(assignments.duplicate(true))
