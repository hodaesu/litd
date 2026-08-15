extends Node
class_name AshlandsZoneRuntime

signal shortcut_unlocked(shortcut_id: String)
signal zone_discovered(zone_id: String)
signal campfire_used(zone_id: String)

var discovered_zones: Dictionary = {}
var unlocked_shortcuts: Dictionary = {}
var current_zone_id := ""

func enter_zone(zone_id: String) -> void:
    current_zone_id = zone_id
    if not discovered_zones.has(zone_id):
        discovered_zones[zone_id] = true
        zone_discovered.emit(zone_id)

func unlock_shortcut(shortcut_id: String) -> void:
    if shortcut_id == "":
        return
    if not unlocked_shortcuts.has(shortcut_id):
        unlocked_shortcuts[shortcut_id] = true
        shortcut_unlocked.emit(shortcut_id)

func is_shortcut_unlocked(shortcut_id: String) -> bool:
    return bool(unlocked_shortcuts.get(shortcut_id, false))

func can_ash_hide(marker_type: String) -> bool:
    return marker_type in ["normal_enemy", "loot", "resource"]

func can_miniboss_be_hidden_by_ash() -> bool:
    return false

func can_spawn_normal_miniboss(zone_data: Dictionary, alternate_route_available: bool) -> bool:
    return bool(zone_data.get("miniboss_normal_pool", false)) and alternate_route_available

func use_campfire(zone_id: String) -> void:
    campfire_used.emit(zone_id)

func serialize() -> Dictionary:
    return {
        "discovered_zones": discovered_zones,
        "unlocked_shortcuts": unlocked_shortcuts,
        "current_zone_id": current_zone_id
    }

func deserialize(data: Dictionary) -> void:
    discovered_zones = data.get("discovered_zones", {}).duplicate(true)
    unlocked_shortcuts = data.get("unlocked_shortcuts", {}).duplicate(true)
    current_zone_id = str(data.get("current_zone_id", ""))
