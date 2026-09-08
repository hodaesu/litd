extends RefCounted
class_name VeilleursMarketService

const RULES_PATH := "res://data/economy/sanctuary_economy_rules.json"

var rules: Dictionary = {}

func _init() -> void:
    _load_rules()

func _load_rules() -> void:
    if not FileAccess.file_exists(RULES_PATH):
        push_error("VeilleursMarketService: missing economy rules")
        rules = {}
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        rules = (parsed as Dictionary).get("market", {}).duplicate(true)

func quote_item(item: Dictionary, buying: bool = true) -> int:
    if item.is_empty():
        return 0
    var rarity := str(item.get("rarity", "common"))
    var base_prices: Dictionary = rules.get("rarity_buy_price", {})
    var base := int(base_prices.get(rarity, base_prices.get("common", 0)))
    var affix_value := int(rules.get("affix_value", 0))
    var affix_count := (item.get("affixes", []) as Array).size()
    var price := maxi(0, base + affix_count * affix_value)
    if buying:
        return price
    return maxi(0, int(round(float(price) * float(rules.get("sell_ratio", 0.45)))))

func generate_offers(seed_value: int, count: int = -1) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if DataLoader.equipment.is_empty():
        return result
    var offer_count := count if count > 0 else int(rules.get("offer_count", 6))
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var rarities := ["common", "uncommon", "rare", "epic", "legendary"]
    for index in range(offer_count):
        var definition: Dictionary = DataLoader.equipment[rng.randi_range(0, DataLoader.equipment.size() - 1)]
        var rarity_roll := rng.randf()
        var rarity := "common"
        if rarity_roll >= 0.985:
            rarity = "legendary"
        elif rarity_roll >= 0.93:
            rarity = "epic"
        elif rarity_roll >= 0.78:
            rarity = "rare"
        elif rarity_roll >= 0.48:
            rarity = "uncommon"
        var preview := EquipmentManager.generate_item(str(definition.get("id", "")), rarity, "market_preview_%d_%d" % [seed_value, index])
        if preview.is_empty():
            continue
        result.append({
            "offer_id": "market_%d_%d" % [seed_value, index],
            "base_id": str(definition.get("id", "")),
            "rarity": rarity,
            "class_id": str(definition.get("class_id", "")),
            "slot": str(definition.get("slot", "")),
            "name": str(definition.get("name", definition.get("id", "Objet"))),
            "price": quote_item(preview, true)
        })
    return result

func buy_offer(offer: Dictionary, context: String = "sanctuary_market") -> Dictionary:
    var base_id := str(offer.get("base_id", ""))
    var rarity := str(offer.get("rarity", "common"))
    if base_id == "":
        return {"ok": false, "reason": "invalid_offer"}
    var preview := EquipmentManager.generate_item(base_id, rarity, context + "_quote")
    if preview.is_empty():
        return {"ok": false, "reason": "invalid_equipment"}
    var price := quote_item(preview, true)
    if GameState.gold < price:
        return {"ok": false, "reason": "insufficient_gold", "price": price, "gold": GameState.gold}
    var item := EquipmentManager.add_generated_item(base_id, rarity, context)
    if item.is_empty():
        return {"ok": false, "reason": "generation_failed"}
    GameState.gold -= price
    GameState.add_log("Marché noir : %s acheté pour %d or." % [str(item.get("name", "objet")), price])
    return {"ok": true, "item": item, "price": price, "gold": GameState.gold}

func sell(instance_id: String) -> Dictionary:
    if instance_id == "":
        return {"ok": false, "reason": "invalid_instance"}
    for slots_value in EquipmentManager.equipped_by_hero.values():
        var slots: Dictionary = slots_value
        if slots.values().has(instance_id):
            return {"ok": false, "reason": "equipped"}
    var source := "items"
    var item := EquipmentManager.get_instance(instance_id)
    if item.is_empty():
        item = EquipmentManager.get_stashed_instance(instance_id)
        source = "stash"
    if item.is_empty():
        return {"ok": false, "reason": "not_found"}
    var price := quote_item(item, false)
    var removed := false
    if source == "items":
        for index in range(EquipmentManager.items.size()):
            if str(EquipmentManager.items[index].get("instance_id", "")) == instance_id:
                EquipmentManager.items.remove_at(index)
                removed = true
                break
    else:
        for index in range(EquipmentManager.guild_stash.size()):
            if str(EquipmentManager.guild_stash[index].get("instance_id", "")) == instance_id:
                EquipmentManager.guild_stash.remove_at(index)
                removed = true
                break
    if not removed:
        return {"ok": false, "reason": "remove_failed"}
    GameState.gold += price
    EquipmentManager.inventory_changed.emit(EquipmentManager.items.duplicate(true))
    GameState.add_log("Marché noir : %s vendu pour %d or." % [str(item.get("name", "objet")), price])
    return {"ok": true, "item": item, "price": price, "gold": GameState.gold}
