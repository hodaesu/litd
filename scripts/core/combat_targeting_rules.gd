extends RefCounted

# Rangs ennemis : position 0 = E1 (première ligne), position 3 = E4 (arrière).
# Les règles de ciblage restent indépendantes de l'UI : elles déterminent la portée,
# la protection de la ligne arrière et les déplacements forcés après une attaque.

const ENEMY_FRONT: Array[int] = [0, 1]
const ENEMY_FRONT_MID: Array[int] = [0, 1, 2]
const ENEMY_ALL: Array[int] = [0, 1, 2, 3]
const RANGED_CLASSES: Array[String] = ["ranger", "scout"]

static func ensure_enemy_positions(enemies: Array) -> void:
    var used: Array[int] = []
    for index in range(enemies.size()):
        var enemy: Dictionary = enemies[index]
        if not enemy.has("combat_uid"):
            enemy["combat_uid"] = "%s_%d_%d" % [str(enemy.get("id", "enemy")), index, enemies.size()]
        var desired := int(enemy.get("combat_position", -1))
        if desired < 0 or desired > 3 or used.has(desired):
            desired = 0
            while used.has(desired) and desired < 3:
                desired += 1
        enemy["combat_position"] = clampi(desired, 0, 3)
        used.append(int(enemy["combat_position"]))

static func target_positions(hero: Dictionary, skill: Dictionary) -> Array[int]:
    if str(skill.get("effect", "")) != "attack":
        return []
    var skill_id := str(skill.get("id", ""))
    if skill_id == "heavy_blow":
        return ENEMY_FRONT.duplicate()
    if skill_id == "basic_strike":
        return ENEMY_FRONT.duplicate()

    var source_stat := str(skill.get("source_stat", ""))
    var status := str(skill.get("status", ""))
    var class_id := str(hero.get("class_id", ""))
    var branch := str(skill.get("branch", ""))

    if RANGED_CLASSES.has(class_id) or source_stat in ["precision", "critical_chance"]:
        return ENEMY_ALL.duplicate()
    if class_id == "occultist" and branch == "special":
        return ENEMY_ALL.duplicate()
    if status in ["break", "stun"] or source_stat in ["break_chance", "stun_chance", "execute_percent"]:
        return ENEMY_FRONT.duplicate()
    if status == "bleed" or source_stat == "bleed_chance":
        return ENEMY_FRONT_MID.duplicate()
    return ENEMY_FRONT_MID.duplicate()

static func ignores_frontline(hero: Dictionary, skill: Dictionary) -> bool:
    var class_id := str(hero.get("class_id", ""))
    var source_stat := str(skill.get("source_stat", ""))
    var branch := str(skill.get("branch", ""))
    return RANGED_CLASSES.has(class_id) or source_stat in ["precision", "critical_chance"] or (class_id == "occultist" and branch == "special")

static func can_target(hero: Dictionary, skill: Dictionary, enemy: Dictionary, enemies: Array) -> bool:
    if enemy.is_empty() or int(enemy.get("hp", 0)) <= 0:
        return false
    var position := clampi(int(enemy.get("combat_position", 0)), 0, 3)
    if not target_positions(hero, skill).has(position):
        return false
    if ignores_frontline(hero, skill):
        return true
    # La ligne avant E1/E2 protège les rangs profonds E3/E4 contre les techniques
    # de mêlée et de portée courte tant qu'un adversaire vivant y tient encore.
    if position >= 2:
        for enemy_value in enemies:
            var blocker: Dictionary = enemy_value
            if int(blocker.get("hp", 0)) > 0 and int(blocker.get("combat_position", 0)) <= 1:
                return false
    return true

static func targetable_indices(hero: Dictionary, skill: Dictionary, enemies: Array) -> Array[int]:
    var result: Array[int] = []
    for index in range(enemies.size()):
        var enemy: Dictionary = enemies[index]
        if can_target(hero, skill, enemy, enemies):
            result.append(index)
    return result

static func forced_movement_delta(hero: Dictionary, skill: Dictionary) -> int:
    var skill_id := str(skill.get("id", ""))
    var source_stat := str(skill.get("source_stat", ""))
    var status := str(skill.get("status", ""))
    if skill_id == "heavy_blow" or status == "break" or source_stat == "break_chance":
        return 1 # repousse vers E4
    if str(hero.get("class_id", "")) == "occultist" and str(skill.get("branch", "")) == "special" and str(skill.get("effect", "")) == "attack":
        return -1 # attire vers E1
    return 0

static func move_enemy(enemies: Array, enemy: Dictionary, delta: int) -> Dictionary:
    if enemy.is_empty() or delta == 0:
        return {"moved": false}
    var current := clampi(int(enemy.get("combat_position", 0)), 0, 3)
    var destination := clampi(current + delta, 0, 3)
    if destination == current:
        return {"moved": false, "from": current, "to": current}
    var swapped: Dictionary = {}
    for enemy_value in enemies:
        var other: Dictionary = enemy_value
        if other == enemy:
            continue
        if int(other.get("combat_position", -1)) == destination:
            other["combat_position"] = current
            swapped = other
            break
    enemy["combat_position"] = destination
    return {"moved": true, "from": current, "to": destination, "swapped": swapped}

static func target_range_label(hero: Dictionary, skill: Dictionary) -> String:
    var positions := target_positions(hero, skill)
    if positions == ENEMY_ALL:
        return "E1–E4"
    if positions == ENEMY_FRONT_MID:
        return "E1–E3"
    if positions == ENEMY_FRONT:
        return "E1–E2"
    var labels: Array[String] = []
    for position in positions:
        labels.append("E%d" % (int(position) + 1))
    return " / ".join(labels)

static func movement_label(hero: Dictionary, skill: Dictionary) -> String:
    var delta := forced_movement_delta(hero, skill)
    if delta > 0:
        return "POUSSÉE +1"
    if delta < 0:
        return "TRACTION -1"
    return ""
