extends Node
class_name LevelFlowController

signal zone_entered(zone_id: String)
signal zone_completed(zone_id: String)
signal expedition_completed(level_id: String)

@export_file("*.json") var level_manifest_path := "res://data/levels/terre_des_cendres.json"

var manifest: Dictionary = {}
var zones: Array = []
var current_zone_index: int = -1
var completed_zones: Array[String] = []

func _ready() -> void:
    load_manifest(level_manifest_path)

func load_manifest(path: String) -> bool:
    if not FileAccess.file_exists(path):
        push_error("LevelFlowController: manifest introuvable: " + path)
        return false
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("LevelFlowController: JSON invalide: " + path)
        return false
    manifest = parsed
    zones = manifest.get("zones", [])
    current_zone_index = -1
    completed_zones.clear()
    return true

func start_level() -> bool:
    if zones.is_empty():
        return false
    current_zone_index = 0
    zone_entered.emit(current_zone_id())
    return true

func current_zone() -> Dictionary:
    if current_zone_index < 0 or current_zone_index >= zones.size():
        return {}
    return zones[current_zone_index]

func current_zone_id() -> String:
    return str(current_zone().get("id", ""))

func complete_current_zone() -> bool:
    var zone_id := current_zone_id()
    if zone_id == "":
        return false
    if zone_id not in completed_zones:
        completed_zones.append(zone_id)
    zone_completed.emit(zone_id)
    if current_zone_index + 1 >= zones.size():
        expedition_completed.emit(str(manifest.get("id", "")))
        return true
    current_zone_index += 1
    zone_entered.emit(current_zone_id())
    return true

func encounter_slots_for_current_zone() -> Array:
    return current_zone().get("encounter_slots", [])

func has_rest_slot() -> bool:
    return bool(current_zone().get("rest_slot", false))

func serialize() -> Dictionary:
    return {
        "level_id": manifest.get("id", ""),
        "current_zone_index": current_zone_index,
        "completed_zones": completed_zones
    }

func deserialize(data: Dictionary) -> void:
    current_zone_index = int(data.get("current_zone_index", -1))
    completed_zones.assign(data.get("completed_zones", []))
