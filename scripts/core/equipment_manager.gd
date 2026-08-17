extends Node

signal inventory_changed(items: Array)
signal item_generated(item: Dictionary)
signal item_equipped(hero_id: String, item: Dictionary)

const DEFAULT_SEED := 0x4C495444
const LEVELS_PER_SCALING_STEP: int = 3
const LEVEL_SCALING_STEP: float = 0.25
const MAX_WEAPON_LEVEL_MULTIPLIER: float = 3.0

var items: Array[Dictionary] = []
var equipped_by_hero: Dictionary = {}
var drop_counter: int = 0
var generation_seed: int = DEFAULT_SEED
var last_rewards: Array[Dictionary] = []

func _ready() -> void:
    reset_new_game()

func reset_new_game(seed_value: int = 0) -> void:
    items.clear()
    equipped_by_hero.clear()
    last_rewards.clear()
    drop_counter = 0
    if seed_value != 0:
        generation_seed = seed_value
    else:
        generation_seed = int(Time.get_unix_time_from_system() * 1000.0) + Time.get_ticks_msec()
    inventory_changed.emit(items.duplicate(true))

func generate_item(base_id: String, rarity_id: String = "common", context: String = "drop") -> Dictionary:
    var definition: Dictionary = DataLoader.find_by_id(DataLoader.equipment, base_id)
    var rarity: Dictionary = DataLoader.find_by_id(DataLoader.equipment_rarities, rarity_id)
    if definition.is_empty() or rarity.is_empty():
        push_error("EquipmentManager: unknown equipment or rarity: %s / %s" % [base_id, rarity_id])
        return {}

    var item_seed: int = _next_seed(base_id, rarity_id, context)
    var rng := RandomNumberGenerator.new()
    rng.seed = item_seed
    var item: Dictionary = {
        "instance_id": _instance_id(base_id, item_seed, drop_counter),
        "base_id": base_id,
        "name": str(definition.get("name", base_id)),
        "slot": str(definition.get("slot", "")),
        "class_id": str(definition.get("class_id", "")),
        "rarity": rarity_id,
        "rarity_rank": int(rarity.get("rank", 1)),
        "seed": item_seed,
        "drop_index": drop_counter,
        "context": context,
        "base_bonuses": _scaled_bonuses(definition.get("base_bonuses", {}), float(rarity.get("base_multiplier", 1.0))),
        "affixes": []
    }
    if item["slot"] in ["weapon", "armor", "ring", "necklace"]:
        item["affixes"] = _roll_weapon_affixes(definition, rarity, rng)
    return item

func add_generated_item(base_id: String, rarity_id: String = "common", context: String = "drop") -> Dictionary:
    var item: Dictionary = generate_item(base_id, rarity_id, context)
    return add_item(item)

func add_item(item: Dictionary) -> Dictionary:
    if item.is_empty() or str(item.get("instance_id", "")) == "":
        return {}
    if has_instance(str(item["instance_id"])):
        return get_instance(str(item["instance_id"]))
    items.append(item.duplicate(true))
    last_rewards.clear()
    last_rewards.append(item.duplicate(true))
    inventory_changed.emit(items.duplicate(true))
    item_generated.emit(item.duplicate(true))
    return item.duplicate(true)

func grant_test_level_bundle(hero_index: int, rarity_id: String = "common") -> Array[Dictionary]:
    var rewards: Array[Dictionary] = []
    if hero_index < 0 or hero_index >= DataLoader.heroes.size():
        return rewards
    var hero: Dictionary = DataLoader.heroes[hero_index]
    var hero_id: String = str(hero.get("id", ""))
    var class_id: String = str(hero.get("class_id", ""))
    for definition_value in DataLoader.equipment:
        var definition: Dictionary = definition_value
        if not bool(definition.get("test_level", false)) or str(definition.get("class_id", "")) != class_id:
            continue
        var item: Dictionary = generate_item(str(definition.get("id", "")), rarity_id, "test_room_%d" % (hero_index + 1))
        if item.is_empty():
            continue
        items.append(item.duplicate(true))
        rewards.append(item.duplicate(true))
        item_generated.emit(item.duplicate(true))
        var slots: Dictionary = equipped_by_hero.get(hero_id, {})
        var slot: String = str(item.get("slot", ""))
        if not slots.has(slot):
            equip(hero_id, str(item.get("instance_id", "")))
    last_rewards = rewards.duplicate(true)
    if not rewards.is_empty():
        inventory_changed.emit(items.duplicate(true))
    return rewards

func generate_random_weapon(class_id: String, rarity_id: String, context: String) -> Dictionary:
    var candidates: Array[Dictionary] = []
    for definition_value in DataLoader.equipment:
        var definition: Dictionary = definition_value
        if str(definition.get("slot", "")) == "weapon" and str(definition.get("class_id", "")) == class_id and bool(definition.get("test_level", false)):
            candidates.append(definition)
    if candidates.is_empty():
        return {}
    var selection_seed: int = _preview_seed(class_id, rarity_id, context, drop_counter + 1)
    var rng := RandomNumberGenerator.new()
    rng.seed = selection_seed
    var selected: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
    return generate_item(str(selected.get("id", "")), rarity_id, context)

func grant_random_party_weapon(rarity_id: String, context: String) -> Dictionary:
    if GameState.party.is_empty():
        return {}
    var selection_seed: int = _preview_seed("party", rarity_id, context, drop_counter + 1)
    var rng := RandomNumberGenerator.new()
    rng.seed = selection_seed
    var hero: Dictionary = GameState.party[rng.randi_range(0, GameState.party.size() - 1)]
    var item: Dictionary = generate_random_weapon(str(hero.get("class_id", "")), rarity_id, context)
    return add_item(item)

func equip(hero_id: String, instance_id: String) -> bool:
    var item: Dictionary = get_instance(instance_id)
    if item.is_empty():
        return false
    var hero: Dictionary = DataLoader.find_by_id(DataLoader.heroes, hero_id)
    var item_class_id: String = str(item.get("class_id", ""))
    if hero.is_empty() or (item_class_id != "" and item_class_id != str(hero.get("class_id", ""))):
        return false
    var slots: Dictionary = equipped_by_hero.get(hero_id, {})
    if slots.values().has(instance_id):
        return true
    var slot: String = _resolve_equipment_slot(slots, str(item.get("slot", "")))
    var old_item: Dictionary = get_instance(str(slots.get(slot, "")))
    var old_hp_bonus: int = int(effective_bonuses(old_item).get("hp_bonus", 0)) if not old_item.is_empty() else 0
    var new_hp_bonus: int = int(effective_bonuses(item).get("hp_bonus", 0))
    slots[slot] = instance_id
    equipped_by_hero[hero_id] = slots
    for party_hero_value in GameState.party:
        var party_hero: Dictionary = party_hero_value
        if str(party_hero.get("id", "")) == hero_id:
            var hp_delta: int = new_hp_bonus - old_hp_bonus
            party_hero["max_hp"] = maxi(1, int(party_hero.get("max_hp", 1)) + hp_delta)
            party_hero["hp"] = clampi(int(party_hero.get("hp", 0)) + maxi(0, hp_delta), 0, int(party_hero["max_hp"]))
            break
    item_equipped.emit(hero_id, item.duplicate(true))
    return true

func _resolve_equipment_slot(slots: Dictionary, item_slot: String) -> String:
    if item_slot != "ring":
        return item_slot
    if not slots.has("ring_1"):
        return "ring_1"
    if not slots.has("ring_2"):
        return "ring_2"
    return "ring_1"

func get_instance(instance_id: String) -> Dictionary:
    for item in items:
        if str(item.get("instance_id", "")) == instance_id:
            return item.duplicate(true)
    return {}

func has_instance(instance_id: String) -> bool:
    return not get_instance(instance_id).is_empty()

func effective_bonuses(item: Dictionary) -> Dictionary:
    var result: Dictionary = item.get("base_bonuses", {}).duplicate(true)
    for affix_value in item.get("affixes", []):
        var affix: Dictionary = affix_value
        var stat: String = str(affix.get("stat", ""))
        if stat == "" or str(affix.get("unit", "")) == "effect":
            continue
        result[stat] = int(result.get(stat, 0)) + int(affix.get("value", 0))
    return result

func weapon_level_multiplier(level: int) -> float:
    var safe_level: int = maxi(1, level)
    var completed_steps: int = floori(float(safe_level - 1) / float(LEVELS_PER_SCALING_STEP))
    return minf(MAX_WEAPON_LEVEL_MULTIPLIER, 1.0 + float(completed_steps) * LEVEL_SCALING_STEP)

func effective_bonuses_for_level(item: Dictionary, level: int) -> Dictionary:
    var result: Dictionary = effective_bonuses(item)
    var slot: String = str(item.get("slot", ""))
    if slot not in ["weapon", "armor", "ring", "necklace"]:
        return result
    var multiplier: float = weapon_level_multiplier(level)
    for key_value in result.keys():
        var key: String = str(key_value)
        if slot != "weapon" and key == "hp_bonus":
            continue
        result[key] = maxi(1, int(round(float(result.get(key, 0)) * multiplier)))
    return result

func level_for_class(class_id: String) -> int:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("class_id", "")) == class_id:
            return maxi(1, int(hero.get("level", 1)))
    return 1

func bonuses_for_hero(hero_id: String) -> Dictionary:
    var result: Dictionary = {}
    var hero_level: int = 1
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            hero_level = maxi(1, int(hero.get("level", 1)))
            break
    var slots: Dictionary = equipped_by_hero.get(hero_id, {})
    for instance_value in slots.values():
        var item: Dictionary = get_instance(str(instance_value))
        var item_bonuses: Dictionary = effective_bonuses_for_level(item, hero_level)
        for key_value in item_bonuses.keys():
            var key: String = str(key_value)
            result[key] = int(result.get(key, 0)) + int(item_bonuses.get(key, 0))
    return result

func has_effect(hero_id: String, effect_id: String) -> bool:
    var slots: Dictionary = equipped_by_hero.get(hero_id, {})
    for instance_value in slots.values():
        var item: Dictionary = get_instance(str(instance_value))
        for affix_value in item.get("affixes", []):
            var affix: Dictionary = affix_value
            if bool(affix.get("special", false)) and str(affix.get("stat", "")) == effect_id:
                return true
    return false

func describe_item(item: Dictionary, hero_level: int = 0) -> String:
    var rarity: Dictionary = DataLoader.find_by_id(DataLoader.equipment_rarities, str(item.get("rarity", "common")))
    var parts: Array[String] = []
    var displayed_bonuses: Dictionary = effective_bonuses(item)
    var level_suffix: String = ""
    var slot: String = str(item.get("slot", ""))
    if hero_level > 0 and slot in ["weapon", "armor", "ring", "necklace"]:
        displayed_bonuses = effective_bonuses_for_level(item, hero_level)
        level_suffix = " · niv. %d ×%.2f" % [hero_level, weapon_level_multiplier(hero_level)]
    for key_value in displayed_bonuses.keys():
        var key: String = str(key_value)
        var suffix: String = "%" if _is_percentage_stat(key) else ""
        parts.append("+%d%s %s" % [int(displayed_bonuses.get(key, 0)), suffix, _stat_label(key)])
    for affix_value in item.get("affixes", []):
        var affix: Dictionary = affix_value
        if str(affix.get("unit", "")) == "effect":
            parts.append(str(affix.get("name", "Effet spécial")))
    return "%s [%s%s] — %s" % [str(item.get("name", "Objet")), str(rarity.get("name", "Commun")), level_suffix, ", ".join(parts)]

func serialize() -> Dictionary:
    return {
        "items": items,
        "equipped_by_hero": equipped_by_hero,
        "drop_counter": drop_counter,
        "generation_seed": generation_seed,
        "last_rewards": last_rewards
    }

func deserialize(data: Dictionary) -> void:
    items.clear()
    var seen: Dictionary = {}
    for item_value in data.get("items", []):
        var item: Dictionary = item_value
        var instance_id: String = str(item.get("instance_id", ""))
        if instance_id == "" or seen.has(instance_id):
            continue
        seen[instance_id] = true
        items.append(item.duplicate(true))
    equipped_by_hero = data.get("equipped_by_hero", {}).duplicate(true)
    for hero_key_value in equipped_by_hero.keys():
        var hero_key: String = str(hero_key_value)
        var slots: Dictionary = equipped_by_hero.get(hero_key, {})
        if slots.has("ring"):
            if not slots.has("ring_1"):
                slots["ring_1"] = slots["ring"]
            slots.erase("ring")
            equipped_by_hero[hero_key] = slots
    drop_counter = maxi(0, int(data.get("drop_counter", items.size())))
    generation_seed = int(data.get("generation_seed", DEFAULT_SEED))
    last_rewards.clear()
    for reward_value in data.get("last_rewards", []):
        var reward: Dictionary = reward_value
        last_rewards.append(reward.duplicate(true))
    inventory_changed.emit(items.duplicate(true))

func _roll_weapon_affixes(definition: Dictionary, rarity: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var candidates: Array[Dictionary] = []
    var allowed: Array = definition.get("allowed_affixes", [])
    for affix_value in DataLoader.equipment_affixes:
        var affix: Dictionary = affix_value
        if not bool(affix.get("special", false)) and allowed.has(str(affix.get("id", ""))):
            candidates.append(affix)
    var regular_count: int = mini(int(rarity.get("affix_count", 0)), candidates.size())
    for _index in regular_count:
        var chosen_index: int = rng.randi_range(0, candidates.size() - 1)
        var chosen: Dictionary = candidates.pop_at(chosen_index)
        result.append(_roll_affix(chosen, float(rarity.get("affix_multiplier", 1.0)), rng))

    var special_count: int = int(rarity.get("special_affix_count", 0))
    var class_id: String = str(definition.get("class_id", ""))
    var specials: Array[Dictionary] = []
    for affix_value in DataLoader.equipment_affixes:
        var affix: Dictionary = affix_value
        var classes: Array = affix.get("classes", [])
        if bool(affix.get("special", false)) and classes.has(class_id):
            specials.append(affix)
    for _index in mini(special_count, specials.size()):
        var chosen_index: int = rng.randi_range(0, specials.size() - 1)
        var chosen: Dictionary = specials.pop_at(chosen_index)
        result.append(_roll_affix(chosen, float(rarity.get("affix_multiplier", 1.0)), rng))
    return result

func _roll_affix(definition: Dictionary, multiplier: float, rng: RandomNumberGenerator) -> Dictionary:
    var value_range: Array = definition.get("base_range", [1, 1])
    var raw_value: int = rng.randi_range(int(value_range[0]), int(value_range[1]))
    var unit: String = str(definition.get("unit", "flat"))
    var value: int = raw_value if unit == "effect" else maxi(1, int(round(raw_value * multiplier)))
    return {
        "id": str(definition.get("id", "")),
        "name": str(definition.get("name", "")),
        "stat": str(definition.get("stat", "")),
        "value": value,
        "unit": unit,
        "special": bool(definition.get("special", false))
    }

func _scaled_bonuses(source_value: Variant, multiplier: float) -> Dictionary:
    var source: Dictionary = source_value
    var result: Dictionary = {}
    for key_value in source.keys():
        var key: String = str(key_value)
        result[key] = maxi(1, int(round(float(source[key]) * multiplier)))
    return result

func _next_seed(base_id: String, rarity_id: String, context: String) -> int:
    drop_counter += 1
    return _preview_seed(base_id, rarity_id, context, drop_counter)

func _preview_seed(base_id: String, rarity_id: String, context: String, index: int) -> int:
    var mixed: int = generation_seed
    mixed ^= int(base_id.hash()) * 73856093
    mixed ^= int(rarity_id.hash()) * 19349663
    mixed ^= int(context.hash()) * 83492791
    mixed ^= index * 2654435761
    return mixed

func _instance_id(base_id: String, item_seed: int, index: int) -> String:
    return "%s-%08x-%06d" % [base_id, item_seed & 0x7fffffff, index]

func _is_percentage_stat(stat: String) -> bool:
    return stat in [
        "critical_chance", "break_chance", "stun_chance", "guard_power",
        "riposte_chance", "healing_power", "bleed_chance", "precision",
        "physical_resistance", "madness_resistance", "fear_resistance"
    ]

func _stat_label(stat: String) -> String:
    var labels: Dictionary = {
        "damage_bonus": "dégâts", "hp_bonus": "PV", "critical_chance": "critique",
        "break_chance": "rupture", "stun_chance": "étourdissement", "guard_power": "garde",
        "riposte_chance": "riposte", "healing_power": "soins", "max_hope": "espoir max",
        "max_madness": "folie max", "bleed_chance": "saignement", "precision": "précision",
        "physical_resistance": "résistance physique", "madness_resistance": "résistance à la folie",
        "fear_resistance": "résistance à la peur"
    }
    return str(labels.get(stat, stat))
