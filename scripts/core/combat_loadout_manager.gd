extends Node

signal loadout_changed(hero_id: String)

const HEAL_SLOT := "healing"
const GRENADE_SLOT := "grenade"
const DEFINITIONS: Array[Dictionary] = [
    {"id":"field_dressing","name":"Pansement de campagne","category":HEAL_SLOT,"description":"Stabilise une plaie et restaure 12 PV.","heal":12},
    {"id":"restorative_balm","name":"Baume réparateur","category":HEAL_SLOT,"description":"Restaure 20 PV et réduit un affaiblissement.","heal":20},
    {"id":"fire_grenade","name":"Grenade incendiaire","category":GRENADE_SLOT,"description":"Inflige des dégâts de zone et applique Brûlure.","damage":14,"status":"burn"},
    {"id":"ash_grenade","name":"Grenade de cendres","category":GRENADE_SLOT,"description":"Aveugle temporairement les ennemis et réduit leur précision.","damage":6,"status":"accuracy_down"}
]

var inventory: Dictionary = {}
var loadouts_by_hero: Dictionary = {}

func _ready() -> void:
    reset_new_game()

func reset_new_game() -> void:
    inventory = {"field_dressing":4,"restorative_balm":2,"fire_grenade":2,"ash_grenade":2}
    loadouts_by_hero.clear()

func definition(item_id: String) -> Dictionary:
    for value: Variant in DEFINITIONS:
        var item: Dictionary = value
        if String(item.get("id", "")) == item_id:
            return item.duplicate(true)
    return {}

func definitions_for(category: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in DEFINITIONS:
        var item: Dictionary = value
        if String(item.get("category", "")) == category:
            result.append(item.duplicate(true))
    return result

func loadout(hero_id: String) -> Dictionary:
    return loadouts_by_hero.get(hero_id, {HEAL_SLOT:"",GRENADE_SLOT:""}).duplicate(true)

func equipped(hero_id: String, category: String) -> Dictionary:
    return definition(String(loadout(hero_id).get(category, "")))

func equip(hero_id: String, item_id: String) -> bool:
    var item := definition(item_id)
    if hero_id == "" or item.is_empty() or int(inventory.get(item_id, 0)) <= 0:
        return false
    var slots := loadout(hero_id)
    slots[String(item.get("category", ""))] = item_id
    loadouts_by_hero[hero_id] = slots
    loadout_changed.emit(hero_id)
    return true

func consume(hero_id: String, category: String) -> Dictionary:
    var slots := loadout(hero_id)
    var item_id := String(slots.get(category, ""))
    var item := definition(item_id)
    if item.is_empty() or int(inventory.get(item_id, 0)) <= 0:
        return {}
    inventory[item_id] = int(inventory.get(item_id, 0)) - 1
    if int(inventory[item_id]) <= 0:
        slots[category] = ""
        loadouts_by_hero[hero_id] = slots
    loadout_changed.emit(hero_id)
    return item

func serialize() -> Dictionary:
    return {"inventory":inventory.duplicate(true),"loadouts_by_hero":loadouts_by_hero.duplicate(true)}

func deserialize(data: Dictionary) -> void:
    reset_new_game()
    var saved_inventory: Variant = data.get("inventory", {})
    if saved_inventory is Dictionary:
        for key_value: Variant in saved_inventory.keys():
            var item_id := String(key_value)
            if not definition(item_id).is_empty():
                inventory[item_id] = maxi(0, int(saved_inventory[item_id]))
    var saved_loadouts: Variant = data.get("loadouts_by_hero", {})
    if saved_loadouts is Dictionary:
        for hero_value: Variant in saved_loadouts.keys():
            var hero_id := String(hero_value)
            var slots_value: Variant = saved_loadouts[hero_value]
            if slots_value is not Dictionary:
                continue
            for category in [HEAL_SLOT, GRENADE_SLOT]:
                var item_id := String(slots_value.get(category, ""))
                var item := definition(item_id)
                if not item.is_empty() and String(item.get("category", "")) == category:
                    var slots := loadout(hero_id)
                    slots[category] = item_id
                    loadouts_by_hero[hero_id] = slots
