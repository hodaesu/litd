extends Node
class_name AshlandsZoneRuntime

signal shortcut_unlocked(shortcut_id: String)
signal zone_discovered(zone_id: String)
signal campfire_used(zone_id: String)
signal transition_requested(zone_id: String)
signal resource_collected(resource_id: String)
signal encounter_cleared(encounter_id: String)

var discovered_zones: Dictionary = {}
var unlocked_shortcuts: Dictionary = {}
var collected_resources: Dictionary = {}
var cleared_encounters: Dictionary = {}
var current_zone_id := ""
var previous_zone_id := ""
var campfires_used_this_run: Dictionary = {}

func enter_zone(zone_id: String) -> void:
    previous_zone_id = current_zone_id
    current_zone_id = zone_id
    if not discovered_zones.has(zone_id):
        discovered_zones[zone_id] = true
        zone_discovered.emit(zone_id)
    ExpeditionManager.on_zone_entered(zone_id)

func request_zone_transition(zone_id: String) -> void:
    transition_requested.emit(zone_id)

func unlock_shortcut(shortcut_id: String) -> void:
    if shortcut_id == "":
        return
    if not unlocked_shortcuts.has(shortcut_id):
        unlocked_shortcuts[shortcut_id] = true
        shortcut_unlocked.emit(shortcut_id)

func is_shortcut_unlocked(shortcut_id: String) -> bool:
    return bool(unlocked_shortcuts.get(shortcut_id, false))

func is_zone_discovered(zone_id: String) -> bool:
    return bool(discovered_zones.get(zone_id, false))

func mark_resource_collected(resource_id: String) -> void:
    if resource_id == "":
        return
    collected_resources[resource_id] = true
    resource_collected.emit(resource_id)

func is_resource_collected(resource_id: String) -> bool:
    return bool(collected_resources.get(resource_id, false))

func mark_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "":
        return
    cleared_encounters[encounter_id] = true
    encounter_cleared.emit(encounter_id)

func is_encounter_cleared(encounter_id: String) -> bool:
    return bool(cleared_encounters.get(encounter_id, false))

func can_ash_hide(marker_type: String) -> bool:
    return marker_type in ["normal_enemy", "loot", "resource"]

func can_miniboss_be_hidden_by_ash() -> bool:
    return false

func can_spawn_normal_miniboss(zone_data: Dictionary, alternate_route_available: bool) -> bool:
    return bool(zone_data.get("miniboss_normal_pool", false)) and alternate_route_available

func use_campfire(zone_id: String) -> void:
    campfires_used_this_run[zone_id] = true
    campfire_used.emit(zone_id)

func was_campfire_used_this_run(zone_id: String) -> bool:
    return bool(campfires_used_this_run.get(zone_id, false))

func begin_new_expedition() -> void:
    campfires_used_this_run.clear()
    current_zone_id = ""
    previous_zone_id = ""

func reset_world_progression() -> void:
    discovered_zones.clear()
    unlocked_shortcuts.clear()
    collected_resources.clear()
    cleared_encounters.clear()
    campfires_used_this_run.clear()
    current_zone_id = ""
    previous_zone_id = ""

func serialize() -> Dictionary:
    return {
        "discovered_zones": discovered_zones,
        "unlocked_shortcuts": unlocked_shortcuts,
        "collected_resources": collected_resources,
        "cleared_encounters": cleared_encounters,
        "current_zone_id": current_zone_id,
        "previous_zone_id": previous_zone_id,
        "campfires_used_this_run": campfires_used_this_run
    }

func deserialize(data: Dictionary) -> void:
    discovered_zones = data.get("discovered_zones", {}).duplicate(true)
    unlocked_shortcuts = data.get("unlocked_shortcuts", {}).duplicate(true)
    collected_resources = data.get("collected_resources", {}).duplicate(true)
    cleared_encounters = data.get("cleared_encounters", {}).duplicate(true)
    current_zone_id = str(data.get("current_zone_id", ""))
    previous_zone_id = str(data.get("previous_zone_id", ""))
    campfires_used_this_run = data.get("campfires_used_this_run", {}).duplicate(true)
