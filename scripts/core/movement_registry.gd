extends Node

const PATH := "res://data/movement_registry.json"

var data: Dictionary = {}
var by_id: Dictionary = {}
var by_trigger: Dictionary = {}
var by_owner: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> bool:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    data = parsed if parsed is Dictionary else {}
    by_id.clear()
    by_trigger.clear()
    by_owner.clear()
    for value: Variant in data.get("entries", []):
        if not value is Dictionary:
            continue
        var movement: Dictionary = value
        var movement_id: String = str(movement.get("id", ""))
        var trigger: String = str(movement.get("trigger", ""))
        var owner: String = str(movement.get("owner", "global"))
        by_id[movement_id] = movement
        if trigger != "":
            by_trigger[trigger] = movement
        if not by_owner.has(owner):
            by_owner[owner] = []
        (by_owner[owner] as Array).append(movement)
    return not by_id.is_empty()

func movement(movement_id: String) -> Dictionary:
    return (by_id.get(movement_id, {}) as Dictionary).duplicate(true)

func for_trigger(trigger: String) -> Dictionary:
    return (by_trigger.get(trigger, {}) as Dictionary).duplicate(true)

func for_owner(owner: String, category: String = "") -> Array:
    var result: Array = []
    for value: Variant in by_owner.get(owner, []):
        var item: Dictionary = value
        if category == "" or str(item.get("category", "")) == category:
            result.append(item.duplicate(true))
    return result

func skill_movements(hero_id: String, branch: String = "") -> Array:
    var result: Array = []
    for value: Variant in for_owner(hero_id, "hero_skill"):
        var item: Dictionary = value
        if branch == "" or "_%s_" % branch in str(item.get("id", "")):
            result.append(item)
    return result

func blender_queue(rig: String = "") -> Array:
    var result: Array = []
    for value: Variant in data.get("entries", []):
        var item: Dictionary = value
        if str(item.get("status", "")) not in ["prepared","proxy","planned_blender"]:
            continue
        if rig == "" or str(item.get("rig", "")) == rig:
            result.append(item.duplicate(true))
    return result

func summary() -> Dictionary:
    return (data.get("summary", {}) as Dictionary).duplicate(true)
