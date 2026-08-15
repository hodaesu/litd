extends Node
class_name CorpseHarvest

signal harvest_started(source_id: String)
signal harvest_completed(source_id: String, rewards: Array)
signal harvest_failed(source_id: String, reason: String)

var tables: Dictionary = {}

func _ready() -> void:
    _load_tables()

func _load_tables() -> void:
    var path := "res://data/resources/corpse_harvest_tables.json"
    if not FileAccess.file_exists(path):
        push_error("CorpseHarvest: table absente: " + path)
        return
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        tables = parsed.get("tables", {})

func can_harvest(source_type: String) -> bool:
    return tables.has(source_type)

func get_harvest_time(source_type: String) -> float:
    if not can_harvest(source_type):
        return 0.0
    return float(tables[source_type].get("harvest_time_seconds", 0.0))

func requires_tool(source_type: String) -> bool:
    if not can_harvest(source_type):
        return false
    return bool(tables[source_type].get("tool_required", false))

func roll_rewards(source_type: String, rng: RandomNumberGenerator = null) -> Array:
    if not can_harvest(source_type):
        harvest_failed.emit(source_type, "unknown_source")
        return []
    var random := rng if rng != null else RandomNumberGenerator.new()
    if rng == null:
        random.randomize()
    harvest_started.emit(source_type)
    var rewards: Array = []
    for drop in tables[source_type].get("drops", []):
        if random.randf() <= float(drop.get("chance", 0.0)):
            var amount := random.randi_range(int(drop.get("min", 0)), int(drop.get("max", 0)))
            if amount > 0:
                rewards.append({
                    "id": str(drop.get("id", "")),
                    "category": str(drop.get("category", "misc")),
                    "amount": amount
                })
    harvest_completed.emit(source_type, rewards)
    return rewards
