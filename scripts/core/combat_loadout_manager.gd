extends Node

signal loadout_changed(hero_id: String)

const HEAL_SLOT := "healing"
const GRENADE_SLOT := "grenade"
const HERO_STACK_LIMIT := 5
const INVENTORY_STACK_LIMIT := 10
const DEFINITIONS: Array[Dictionary] = [
    {"id":"field_dressing","name":"Pansement de campagne","category":HEAL_SLOT,"description":"Stabilise une plaie et restaure 12 PV.","heal":12},
    {"id":"restorative_balm","name":"Baume réparateur","category":HEAL_SLOT,"description":"Restaure 20 PV et réduit un affaiblissement.","heal":20},
    {"id":"fire_grenade","name":"Grenade incendiaire","category":GRENADE_SLOT,"description":"Inflige des dégâts de zone et applique Brûlure.","damage":14,"status":"burn"},
    {"id":"ash_grenade","name":"Grenade de cendres","category":GRENADE_SLOT,"description":"Aveugle temporairement les ennemis et réduit leur précision.","damage":6,"status":"accuracy_down"}
]

var inventory_stacks: Array[Dictionary] = []
var loadouts_by_hero: Dictionary = {}

func _ready() -> void:
    reset_new_game()

func reset_new_game() -> void:
    inventory_stacks.clear()
    loadouts_by_hero.clear()
    add_to_inventory("field_dressing", 4)
    add_to_inventory("restorative_balm", 2)
    add_to_inventory("fire_grenade", 2)
    add_to_inventory("ash_grenade", 2)

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

func inventory_count(item_id: String) -> int:
    var total := 0
    for stack: Dictionary in inventory_stacks:
        if String(stack.get("item_id", "")) == item_id:
            total += int(stack.get("quantity", 0))
    return total

func add_to_inventory(item_id: String, quantity: int) -> int:
    if definition(item_id).is_empty():
        return quantity
    var remaining := maxi(0, quantity)
    for stack: Dictionary in inventory_stacks:
        if String(stack.get("item_id", "")) != item_id:
            continue
        var space := INVENTORY_STACK_LIMIT - int(stack.get("quantity", 0))
        var moved := mini(space, remaining)
        stack["quantity"] = int(stack.get("quantity", 0)) + moved
        remaining -= moved
        if remaining == 0:
            return 0
    while remaining > 0:
        var moved := mini(INVENTORY_STACK_LIMIT, remaining)
        inventory_stacks.append({"item_id":item_id,"quantity":moved})
        remaining -= moved
    return 0

func _remove_from_inventory(item_id: String, quantity: int) -> int:
    var remaining := maxi(0, quantity)
    for index in range(inventory_stacks.size() - 1, -1, -1):
        var stack := inventory_stacks[index]
        if String(stack.get("item_id", "")) != item_id:
            continue
        var moved := mini(int(stack.get("quantity", 0)), remaining)
        stack["quantity"] = int(stack.get("quantity", 0)) - moved
        remaining -= moved
        if int(stack["quantity"]) <= 0:
            inventory_stacks.remove_at(index)
        if remaining == 0:
            break
    return quantity - remaining

func loadout(hero_id: String) -> Dictionary:
    return loadouts_by_hero.get(hero_id, {
        HEAL_SLOT:{"item_id":"","quantity":0},
        GRENADE_SLOT:{"item_id":"","quantity":0}
    }).duplicate(true)

func equipped_stack(hero_id: String, category: String) -> Dictionary:
    return loadout(hero_id).get(category, {"item_id":"","quantity":0}).duplicate(true)

func equipped(hero_id: String, category: String) -> Dictionary:
    return definition(String(equipped_stack(hero_id, category).get("item_id", "")))

func equip(hero_id: String, item_id: String, requested_quantity: int = HERO_STACK_LIMIT) -> bool:
    var item := definition(item_id)
    if hero_id == "" or item.is_empty():
        return false
    var category := String(item.get("category", ""))
    var slots := loadout(hero_id)
    var previous: Dictionary = slots.get(category, {"item_id":"","quantity":0})
    var previous_id := String(previous.get("item_id", ""))
    var previous_quantity := int(previous.get("quantity", 0))
    if previous_id == item_id:
        add_to_inventory(previous_id, previous_quantity)
    elif previous_id != "":
        add_to_inventory(previous_id, previous_quantity)
    var quantity := mini(HERO_STACK_LIMIT, maxi(1, requested_quantity), inventory_count(item_id))
    if quantity <= 0:
        slots[category] = previous
        if previous_id != "":
            _remove_from_inventory(previous_id, previous_quantity)
        return false
    _remove_from_inventory(item_id, quantity)
    slots[category] = {"item_id":item_id,"quantity":quantity}
    loadouts_by_hero[hero_id] = slots
    loadout_changed.emit(hero_id)
    return true

func unequip(hero_id: String, category: String) -> bool:
    var slots := loadout(hero_id)
    var stack: Dictionary = slots.get(category, {"item_id":"","quantity":0})
    var item_id := String(stack.get("item_id", ""))
    if item_id == "":
        return false
    add_to_inventory(item_id, int(stack.get("quantity", 0)))
    slots[category] = {"item_id":"","quantity":0}
    loadouts_by_hero[hero_id] = slots
    loadout_changed.emit(hero_id)
    return true

func consume(hero_id: String, category: String) -> Dictionary:
    var slots := loadout(hero_id)
    var stack: Dictionary = slots.get(category, {"item_id":"","quantity":0})
    var item := definition(String(stack.get("item_id", "")))
    if item.is_empty() or int(stack.get("quantity", 0)) <= 0:
        return {}
    stack["quantity"] = int(stack.get("quantity", 0)) - 1
    if int(stack["quantity"]) <= 0:
        stack = {"item_id":"","quantity":0}
    slots[category] = stack
    loadouts_by_hero[hero_id] = slots
    loadout_changed.emit(hero_id)
    return item

func serialize() -> Dictionary:
    return {"inventory_stacks":inventory_stacks.duplicate(true),"loadouts_by_hero":loadouts_by_hero.duplicate(true)}

func deserialize(data: Dictionary) -> void:
    inventory_stacks.clear()
    loadouts_by_hero.clear()
    var saved_stacks: Variant = data.get("inventory_stacks", [])
    if saved_stacks is Array:
        for value: Variant in saved_stacks:
            if value is not Dictionary:
                continue
            var item_id := String(value.get("item_id", ""))
            add_to_inventory(item_id, maxi(0, int(value.get("quantity", 0))))
    else:
        var legacy_inventory: Variant = data.get("inventory", {})
        if legacy_inventory is Dictionary:
            for key_value: Variant in legacy_inventory.keys():
                add_to_inventory(String(key_value), maxi(0, int(legacy_inventory[key_value])))
    var saved_loadouts: Variant = data.get("loadouts_by_hero", {})
    if saved_loadouts is Dictionary:
        for hero_value: Variant in saved_loadouts.keys():
            var hero_id := String(hero_value)
            var source: Variant = saved_loadouts[hero_value]
            if source is not Dictionary:
                continue
            var slots := loadout(hero_id)
            for category in [HEAL_SLOT, GRENADE_SLOT]:
                var raw: Variant = source.get(category, "")
                var item_id := String(raw.get("item_id", "")) if raw is Dictionary else String(raw)
                var quantity := mini(HERO_STACK_LIMIT, int(raw.get("quantity", 1)) if raw is Dictionary else 1)
                var item := definition(item_id)
                if item.is_empty() or String(item.get("category", "")) != category:
                    continue
                slots[category] = {"item_id":item_id,"quantity":maxi(1, quantity)}
            loadouts_by_hero[hero_id] = slots
