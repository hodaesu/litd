extends Node

signal creatures_changed
signal creature_captured(creature: Dictionary)
signal creature_leveled(creature: Dictionary)

const DEFAULT_SEED: int = 0x43524541
const ADVANCED_SKILL_LEVELS: Array[int] = [25, 28, 31, 35, 39, 44, 49]
const ADVANCED_SKILL_COSTS: Array[int] = [2, 2, 3, 3, 4, 4, 5]

var captured_creatures: Array[Dictionary] = []
var active_instance_id: String = ""
var capture_seed: int = DEFAULT_SEED
var capture_attempt_counter: int = 0
var creature_instance_counter: int = 0

func _ready() -> void:
    reset_new_game()

func reset_new_game(seed_value: int = 0) -> void:
    captured_creatures.clear()
    active_instance_id = ""
    capture_attempt_counter = 0
    creature_instance_counter = 0
    if seed_value != 0:
        capture_seed = seed_value
    else:
        capture_seed = int(Time.get_unix_time_from_system() * 1000.0) + Time.get_ticks_msec()
    creatures_changed.emit()

func definition_for_enemy(enemy_id: int) -> Dictionary:
    for definition_value in DataLoader.capturable_creatures:
        var definition: Dictionary = definition_value
        if int(definition.get("enemy_id", -1)) == enemy_id:
            return definition
    return {}

func definition_for_species(species_id: String) -> Dictionary:
    for definition_value in DataLoader.capturable_creatures:
        var definition: Dictionary = definition_value
        if str(definition.get("id", "")) == species_id:
            return definition
    return {}

func is_capturable(enemy: Dictionary) -> bool:
    if bool(enemy.get("boss", false)):
        return false
    return not definition_for_enemy(int(enemy.get("id", -1))).is_empty()

func capture_chance(enemy: Dictionary) -> int:
    if not is_capturable(enemy):
        return 0
    var definition: Dictionary = definition_for_enemy(int(enemy.get("id", -1)))
    var capture: Dictionary = definition.get("capture", {})
    var max_hp: int = maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
    var hp_ratio: float = float(enemy.get("hp", max_hp)) / float(max_hp)
    var missing_hp_bonus: int = int(round((1.0 - hp_ratio) * 70.0))
    return clampi(55 - int(capture.get("resistance", 0)) + missing_hp_bonus, 5, 90)

func attempt_capture(enemy: Dictionary) -> Dictionary:
    if bool(enemy.get("boss", false)):
        return {"success": false, "consumed": false, "message": "Un boss ne peut pas être capturé."}
    var definition: Dictionary = definition_for_enemy(int(enemy.get("id", -1)))
    if definition.is_empty():
        return {"success": false, "consumed": false, "message": "Cette créature ne peut pas être liée."}
    var capture: Dictionary = definition.get("capture", {})
    var max_hp: int = maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
    var hp_ratio: float = float(enemy.get("hp", max_hp)) / float(max_hp)
    if hp_ratio > float(capture.get("max_hp_ratio", 0.30)):
        return {"success": false, "consumed": false, "message": "La créature est encore trop vigoureuse."}
    var essence_cost: int = int(capture.get("essence_cost", 3))
    if GameState.essence < essence_cost:
        return {"success": false, "consumed": false, "message": "Essence insuffisante pour tracer le sceau."}

    GameState.essence -= essence_cost
    capture_attempt_counter += 1
    var rng := RandomNumberGenerator.new()
    rng.seed = capture_seed ^ (int(enemy.get("id", 0)) * 73856093) ^ (capture_attempt_counter * 19349663)
    var chance: int = capture_chance(enemy)
    var roll: int = rng.randi_range(1, 100)
    if roll > chance:
        return {
            "success": false, "consumed": true,
            "message": "Le sceau se brise (%d %% de chance)." % chance
        }

    var creature: Dictionary = _create_creature(definition)
    captured_creatures.append(creature)
    if active_instance_id == "":
        active_instance_id = str(creature.get("instance_id", ""))
    enemy["hp"] = 0
    enemy["captured"] = true
    creatures_changed.emit()
    creature_captured.emit(creature.duplicate(true))
    return {
        "success": true, "consumed": true, "creature": creature.duplicate(true),
        "message": "%s rejoint la compagnie." % str(creature.get("name", "La créature"))
    }

func _create_creature(definition: Dictionary) -> Dictionary:
    creature_instance_counter += 1
    var instance_seed: int = capture_seed ^ (creature_instance_counter * 83492791)
    return {
        "instance_id": "%s-%08x-%04d" % [
            str(definition.get("id", "creature")),
            instance_seed & 0x7fffffff,
            creature_instance_counter
        ],
        "species_id": str(definition.get("id", "")),
        "enemy_id": int(definition.get("enemy_id", -1)),
        "name": str(definition.get("name", "Créature")),
        "level": 1,
        "xp": 0,
        "skill_points": 1,
        "unlocked_skills": [],
        "specialization": "",
        "evolution_name": _evolution_name(definition, 1),
        "seed": instance_seed
    }

func get_creature(instance_id: String) -> Dictionary:
    for creature in captured_creatures:
        if str(creature.get("instance_id", "")) == instance_id:
            return creature.duplicate(true)
    return {}

func active_creature() -> Dictionary:
    return get_creature(active_instance_id)

func set_active(instance_id: String) -> bool:
    if get_creature(instance_id).is_empty():
        return false
    active_instance_id = instance_id
    creatures_changed.emit()
    return true

func grant_active_xp(amount: int) -> void:
    if amount <= 0 or active_instance_id == "":
        return
    for index in range(captured_creatures.size()):
        var creature: Dictionary = captured_creatures[index]
        if str(creature.get("instance_id", "")) != active_instance_id:
            continue
        creature["xp"] = int(creature.get("xp", 0)) + amount
        var leveled: bool = false
        while int(creature.get("level", 1)) < GameState.MAX_CHARACTER_LEVEL:
            var required: int = xp_to_next_level(int(creature.get("level", 1)))
            if int(creature.get("xp", 0)) < required:
                break
            creature["xp"] = int(creature.get("xp", 0)) - required
            creature["level"] = int(creature.get("level", 1)) + 1
            creature["skill_points"] = int(creature.get("skill_points", 0)) + 1
            leveled = true
        var definition: Dictionary = definition_for_species(str(creature.get("species_id", "")))
        creature["evolution_name"] = _evolution_name(definition, int(creature.get("level", 1)))
        captured_creatures[index] = creature
        if leveled:
            creature_leveled.emit(creature.duplicate(true))
        creatures_changed.emit()
        return

func xp_to_next_level(level: int) -> int:
    return 50 + maxi(1, level) * 25

func skill_nodes(creature: Dictionary, branch: String) -> Array:
    var definition: Dictionary = definition_for_species(str(creature.get("species_id", "")))
    var trees: Dictionary = definition.get("skill_trees", {})
    var result: Array = trees.get(branch, []).duplicate(true)
    if result.is_empty():
        return result
    var species_id: String = str(definition.get("id", "creature"))
    var species_name: String = str(definition.get("name", "Créature"))
    var previous_id: String = str(result[-1].get("id", ""))
    var stats: Array[String] = _advanced_stats(species_id, branch)
    for index in range(ADVANCED_SKILL_LEVELS.size()):
        var stat: String = stats[index]
        var skill_id: String = "%s_%s_ascension_%d" % [species_id, branch, index + 1]
        var value: int = _advanced_value(stat, index)
        result.append({
            "id": skill_id,
            "name": "%s — %s %s" % [species_name, _branch_title(branch), _roman(index + 1)],
            "description": _advanced_description(stat, value),
            "cost": ADVANCED_SKILL_COSTS[index],
            "required_level": ADVANCED_SKILL_LEVELS[index],
            "requires": previous_id,
            "stat": stat,
            "value": value
        })
        previous_id = skill_id
    return result

func _advanced_stats(species_id: String, branch: String) -> Array[String]:
    if branch == "offense":
        return ["damage_bonus", "critical_chance", "damage_percent", "bleed_chance", "damage_bonus", "critical_chance", "damage_percent"]
    if branch == "defense":
        return ["physical_resistance", "fear_resistance", "guard_power", "physical_resistance", "fear_resistance", "guard_power", "physical_resistance"]
    match species_id:
        "hungry_ghoul":
            return ["bleed_chance", "party_heal", "execute_percent", "bleed_chance", "party_heal", "execute_percent", "damage_percent"]
        "oni":
            return ["stun_chance", "break_chance", "execute_percent", "stun_chance", "break_chance", "execute_percent", "damage_percent"]
        _:
            return ["stun_chance", "bleed_chance", "party_heal", "stun_chance", "bleed_chance", "party_heal", "critical_chance"]

func _advanced_value(stat: String, index: int) -> int:
    var base_values: Dictionary = {
        "damage_bonus": 2, "critical_chance": 4, "damage_percent": 8,
        "bleed_chance": 5, "stun_chance": 5, "break_chance": 6,
        "physical_resistance": 3, "fear_resistance": 3, "guard_power": 5,
        "party_heal": 2, "execute_percent": 10
    }
    return int(base_values.get(stat, 2)) + int(index / 2)

func _advanced_description(stat: String, value: int) -> String:
    var labels: Dictionary = {
        "damage_bonus": "dégâts", "critical_chance": "% critique", "damage_percent": "% dégâts",
        "bleed_chance": "% saignement", "stun_chance": "% étourdissement", "break_chance": "% rupture",
        "physical_resistance": "% résistance physique", "fear_resistance": "résistance à la peur",
        "guard_power": "puissance de garde", "party_heal": "PV de soin", "execute_percent": "% exécution"
    }
    return "+%d %s" % [value, str(labels.get(stat, stat))]

func _branch_title(branch: String) -> String:
    return str({"offense": "Ascendance", "defense": "Égide", "special": "Essence"}.get(branch, "Maîtrise"))

func _roman(value: int) -> String:
    return ["I", "II", "III", "IV", "V", "VI", "VII"][clampi(value - 1, 0, 6)]

func can_unlock(instance_id: String, skill_id: String) -> bool:
    var creature: Dictionary = get_creature(instance_id)
    if creature.is_empty() or creature.get("unlocked_skills", []).has(skill_id):
        return false
    var node: Dictionary = _find_skill_node(creature, skill_id)
    if node.is_empty():
        return false
    var skill_branch: String = _skill_branch(creature, skill_id)
    var specialization: String = str(creature.get("specialization", ""))
    if skill_branch == "" or (specialization != "" and specialization != skill_branch):
        return false
    if int(creature.get("skill_points", 0)) < int(node.get("cost", 1)):
        return false
    if int(creature.get("level", 1)) < int(node.get("required_level", 1)):
        return false
    var prerequisite: String = str(node.get("requires", ""))
    return prerequisite == "" or creature.get("unlocked_skills", []).has(prerequisite)

func unlock_skill(instance_id: String, skill_id: String) -> bool:
    if not can_unlock(instance_id, skill_id):
        return false
    for index in range(captured_creatures.size()):
        var creature: Dictionary = captured_creatures[index]
        if str(creature.get("instance_id", "")) != instance_id:
            continue
        var node: Dictionary = _find_skill_node(creature, skill_id)
        var skill_branch: String = _skill_branch(creature, skill_id)
        var unlocked: Array = creature.get("unlocked_skills", [])
        unlocked.append(skill_id)
        creature["unlocked_skills"] = unlocked
        if str(creature.get("specialization", "")) == "":
            creature["specialization"] = skill_branch
        creature["skill_points"] = int(creature.get("skill_points", 0)) - int(node.get("cost", 1))
        captured_creatures[index] = creature
        creatures_changed.emit()
        return true
    return false

func _find_skill_node(creature: Dictionary, skill_id: String) -> Dictionary:
    for branch_value in ["offense", "defense", "special"]:
        var branch: String = str(branch_value)
        for node_value in skill_nodes(creature, branch):
            var node: Dictionary = node_value
            if str(node.get("id", "")) == skill_id:
                return node
    return {}

func _skill_branch(creature: Dictionary, skill_id: String) -> String:
    for branch_value in ["offense", "defense", "special"]:
        var branch: String = str(branch_value)
        for node_value in skill_nodes(creature, branch):
            var node: Dictionary = node_value
            if str(node.get("id", "")) == skill_id:
                return branch
    return ""

func active_stats() -> Dictionary:
    var result: Dictionary = {}
    var creature: Dictionary = active_creature()
    if creature.is_empty():
        return result
    for skill_id_value in creature.get("unlocked_skills", []):
        var node: Dictionary = _find_skill_node(creature, str(skill_id_value))
        var stat: String = str(node.get("stat", ""))
        if stat != "":
            result[stat] = int(result.get(stat, 0)) + int(node.get("value", 0))
    return result

func companion_turn(target: Dictionary) -> Dictionary:
    var creature: Dictionary = active_creature()
    if creature.is_empty() or target.is_empty() or int(target.get("hp", 0)) <= 0:
        return {}
    var definition: Dictionary = definition_for_species(str(creature.get("species_id", "")))
    var damage_range: Array = definition.get("base_damage", [1, 2])
    var stats: Dictionary = active_stats()
    var level: int = int(creature.get("level", 1))
    var damage: int = randi_range(int(damage_range[0]), int(damage_range[1]))
    damage += int(stats.get("damage_bonus", 0))
    damage = int(round(float(damage) * (1.0 + float(level - 1) * 0.05)))
    damage = int(round(float(damage) * (1.0 + float(stats.get("damage_percent", 0)) / 100.0)))
    if int(stats.get("critical_chance", 0)) > 0 and randi_range(1, 100) <= int(stats.get("critical_chance", 0)):
        damage = int(round(float(damage) * 1.5))
    var hp_ratio: float = float(target.get("hp", 1)) / float(maxi(1, int(target.get("max_hp", 1))))
    if hp_ratio <= 0.25:
        damage = int(round(float(damage) * (1.0 + float(stats.get("execute_percent", 0)) / 100.0)))
    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    if int(stats.get("stun_chance", 0)) > 0 and randi_range(1, 100) <= int(stats.get("stun_chance", 0)):
        target["stunned"] = true
    if int(stats.get("bleed_chance", 0)) > 0 and randi_range(1, 100) <= int(stats.get("bleed_chance", 0)):
        target["bleeding"] = maxi(2, int(stats.get("bleed_chance", 0)) / 3)
    if int(stats.get("break_chance", 0)) > 0 and randi_range(1, 100) <= int(stats.get("break_chance", 0)):
        target["broken"] = 2
    var heal: int = int(stats.get("party_heal", 0))
    if heal > 0:
        var wounded: Array = GameState.alive_heroes()
        wounded.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("hp", 0)) < int(right.get("hp", 0)))
        if not wounded.is_empty():
            var hero: Dictionary = wounded[0]
            hero["hp"] = mini(int(hero.get("max_hp", 1)), int(hero.get("hp", 0)) + heal)
    return {
        "name": str(creature.get("evolution_name", creature.get("name", "Compagnon"))),
        "damage": damage,
        "heal": heal
    }

func party_bonuses() -> Dictionary:
    var stats: Dictionary = active_stats()
    return {
        "physical_resistance": int(stats.get("physical_resistance", 0)),
        "fear_resistance": int(stats.get("fear_resistance", 0)),
        "guard_power": int(stats.get("guard_power", 0))
    }

func _evolution_name(definition: Dictionary, level: int) -> String:
    var result: String = str(definition.get("name", "Créature"))
    for evolution_value in definition.get("evolutions", []):
        var evolution: Dictionary = evolution_value
        if level >= int(evolution.get("level", 1)):
            result = str(evolution.get("name", result))
    return result

func serialize() -> Dictionary:
    return {
        "captured_creatures": captured_creatures,
        "active_instance_id": active_instance_id,
        "capture_seed": capture_seed,
        "capture_attempt_counter": capture_attempt_counter,
        "creature_instance_counter": creature_instance_counter
    }

func deserialize(data: Dictionary) -> void:
    captured_creatures.clear()
    var seen: Dictionary = {}
    for creature_value in data.get("captured_creatures", []):
        var creature: Dictionary = creature_value
        var instance_id: String = str(creature.get("instance_id", ""))
        if instance_id == "" or seen.has(instance_id):
            continue
        creature["level"] = clampi(int(creature.get("level", 1)), 1, GameState.MAX_CHARACTER_LEVEL)
        creature["xp"] = maxi(0, int(creature.get("xp", 0)))
        creature["skill_points"] = maxi(0, int(creature.get("skill_points", 0)))
        var specialization: String = str(creature.get("specialization", ""))
        if specialization not in ["offense", "defense", "special"]:
            specialization = ""
        if specialization == "" and not creature.get("unlocked_skills", []).is_empty():
            specialization = _skill_branch(creature, str(creature.get("unlocked_skills", [""])[0]))
        creature["specialization"] = specialization
        seen[instance_id] = true
        captured_creatures.append(creature.duplicate(true))
    active_instance_id = str(data.get("active_instance_id", ""))
    if active_instance_id != "" and get_creature(active_instance_id).is_empty():
        active_instance_id = ""
    capture_seed = int(data.get("capture_seed", DEFAULT_SEED))
    capture_attempt_counter = maxi(0, int(data.get("capture_attempt_counter", 0)))
    creature_instance_counter = maxi(captured_creatures.size(), int(data.get("creature_instance_counter", 0)))
    creatures_changed.emit()
