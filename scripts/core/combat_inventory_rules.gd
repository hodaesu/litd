extends RefCounted

# Inventaire personnel en combat. L'inventaire d'expédition reste la source de
# vérité pour les quantités du groupe ; `carried_items` indique seulement qui
# porte chaque ressource. Un transfert change le porteur, jamais la quantité.

const CARRIED_ITEMS_KEY := "carried_items"
const ENEMY_INITIALIZED_KEY := "_combat_inventory_initialized"

static func ensure_actor_inventory(actor: Dictionary) -> Dictionary:
    var value: Variant = actor.get(CARRIED_ITEMS_KEY, {})
    var carried: Dictionary = {}
    if typeof(value) == TYPE_DICTIONARY:
        carried = value as Dictionary
    actor[CARRIED_ITEMS_KEY] = carried
    return carried

static func initialize_enemy_inventory(enemy: Dictionary) -> Dictionary:
    if bool(enemy.get(ENEMY_INITIALIZED_KEY, false)):
        return ensure_actor_inventory(enemy)
    var source_value: Variant = enemy.get("combat_inventory", enemy.get("inventory", {}))
    var carried: Dictionary = {}
    if typeof(source_value) == TYPE_DICTIONARY:
        carried = (source_value as Dictionary).duplicate(true)
    enemy[CARRIED_ITEMS_KEY] = carried
    enemy[ENEMY_INITIALIZED_KEY] = true
    return carried

static func quantity(actor: Dictionary, resource_id: String) -> int:
    return maxi(0, int(ensure_actor_inventory(actor).get(resource_id, 0)))

static func add(actor: Dictionary, resource_id: String, amount: int = 1) -> void:
    if resource_id == "" or amount <= 0:
        return
    var carried := ensure_actor_inventory(actor)
    carried[resource_id] = quantity(actor, resource_id) + amount

static func consume(actor: Dictionary, resource_id: String, amount: int = 1) -> bool:
    if resource_id == "" or amount <= 0 or quantity(actor, resource_id) < amount:
        return false
    var carried := ensure_actor_inventory(actor)
    var remaining := quantity(actor, resource_id) - amount
    if remaining > 0:
        carried[resource_id] = remaining
    else:
        carried.erase(resource_id)
    return true

static func transfer(giver: Dictionary, receiver: Dictionary, resource_id: String, amount: int = 1) -> bool:
    if giver.is_empty() or receiver.is_empty() or giver == receiver:
        return false
    if not consume(giver, resource_id, amount):
        return false
    add(receiver, resource_id, amount)
    return true

static func reconcile_party_aggregate(actors: Array, aggregate: Dictionary) -> void:
    if actors.is_empty():
        return
    for actor_value in actors:
        var actor: Dictionary = actor_value
        ensure_actor_inventory(actor)

    for resource_value in aggregate.keys():
        var resource_id := str(resource_value)
        var aggregate_total := maxi(0, int(aggregate.get(resource_id, 0)))
        var assigned_total := 0
        for actor_value in actors:
            var actor: Dictionary = actor_value
            assigned_total += quantity(actor, resource_id)

        if assigned_total > aggregate_total:
            var excess := assigned_total - aggregate_total
            for index in range(actors.size() - 1, -1, -1):
                if excess <= 0:
                    break
                var actor: Dictionary = actors[index]
                var held := quantity(actor, resource_id)
                var removed := mini(held, excess)
                if removed > 0:
                    consume(actor, resource_id, removed)
                    excess -= removed
        elif assigned_total < aggregate_total:
            var missing := aggregate_total - assigned_total
            for offset in range(missing):
                var actor: Dictionary = actors[offset % actors.size()]
                add(actor, resource_id, 1)

static func most_wounded(actors: Array) -> Dictionary:
    var result: Dictionary = {}
    var best_ratio := 2.0
    for actor_value in actors:
        var actor: Dictionary = actor_value
        if int(actor.get("hp", 0)) <= 0:
            continue
        var ratio := float(actor.get("hp", 0)) / maxf(1.0, float(actor.get("max_hp", 1)))
        if result.is_empty() or ratio < best_ratio:
            result = actor
            best_ratio = ratio
    return result

static func strongest_healing_item(actor: Dictionary, item_rules: Dictionary) -> String:
    var best_id := ""
    var best_heal := -1
    for resource_value in item_rules.keys():
        var resource_id := str(resource_value)
        var rule_value: Variant = item_rules.get(resource_id, {})
        if typeof(rule_value) != TYPE_DICTIONARY:
            continue
        var rule: Dictionary = rule_value
        if str(rule.get("effect", "")) != "heal" or quantity(actor, resource_id) <= 0:
            continue
        var heal := int(rule.get("heal", 0))
        if heal > best_heal:
            best_heal = heal
            best_id = resource_id
    return best_id
