extends RefCounted
class_name VeilleursProgressionRuntime

var config: Dictionary = {}

func configure(value: Dictionary) -> void:
    config = value.duplicate(true)

func new_state(entity_id: String, level: int = 1) -> Dictionary:
    var clamped_level := clampi(level, 1, int(config.get("level_cap", 50)))
    return {
        "entity_id": entity_id,
        "level": clamped_level,
        "xp": 0,
        "skill_points": clamped_level,
        "chosen_tree": "",
        "unlocked_skills": [],
        "ultimate_charges": ultimate_charges_for_level(clamped_level)
    }

func xp_to_next(level: int) -> int:
    var curve: Dictionary = config.get("xp_curve", {})
    var base := int(curve.get("base", 80))
    var linear := int(curve.get("linear", 24))
    var quadratic := int(curve.get("quadratic", 2))
    return base + linear * level + quadratic * level * level

func gain_xp(state: Dictionary, amount: int) -> Dictionary:
    var result := state.duplicate(true)
    if amount <= 0:
        return result
    var cap := int(config.get("level_cap", 50))
    result["xp"] = int(result.get("xp", 0)) + amount
    while int(result.get("level", 1)) < cap:
        var needed := xp_to_next(int(result.get("level", 1)))
        if int(result.get("xp", 0)) < needed:
            break
        result["xp"] = int(result.get("xp", 0)) - needed
        result["level"] = int(result.get("level", 1)) + 1
        result["skill_points"] = int(result.get("skill_points", 0)) + 1
    if int(result.get("level", 1)) >= cap:
        result["xp"] = 0
    result["ultimate_charges"] = ultimate_charges_for_level(int(result.get("level", 1)))
    return result

func choose_tree(state: Dictionary, tree_id: String) -> Dictionary:
    var result := state.duplicate(true)
    var current := str(result.get("chosen_tree", ""))
    if tree_id == "":
        result["last_error"] = "empty_tree"
        return result
    if current != "" and current != tree_id:
        result["last_error"] = "tree_locked"
        return result
    result["chosen_tree"] = tree_id
    result.erase("last_error")
    return result

func unlock_skill(state: Dictionary, skill: Dictionary) -> Dictionary:
    var result := state.duplicate(true)
    var tree_id := str(skill.get("tree_id", ""))
    var skill_id := str(skill.get("skill_id", ""))
    if tree_id == "" or skill_id == "":
        result["last_error"] = "invalid_skill"
        return result
    result = choose_tree(result, tree_id)
    if result.has("last_error"):
        return result
    if int(result.get("level", 1)) < int(skill.get("unlock_level", 99)):
        result["last_error"] = "level_too_low"
        return result
    if int(result.get("skill_points", 0)) <= 0:
        result["last_error"] = "no_skill_points"
        return result
    var unlocked: Array = (result.get("unlocked_skills", []) as Array).duplicate()
    if unlocked.has(skill_id):
        result["last_error"] = "already_unlocked"
        return result
    unlocked.append(skill_id)
    result["unlocked_skills"] = unlocked
    result["skill_points"] = int(result.get("skill_points", 0)) - 1
    result.erase("last_error")
    return result

func ultimate_charges_for_level(level: int) -> int:
    if level >= 48:
        return 3
    if level >= 32:
        return 2
    if level >= 16:
        return 1
    return 0

func can_use_ultimate(state: Dictionary) -> bool:
    return int(state.get("level", 1)) >= 16 and int(state.get("ultimate_charges", 0)) > 0 and str(state.get("chosen_tree", "")) != ""

func spend_ultimate_charge(state: Dictionary) -> Dictionary:
    var result := state.duplicate(true)
    if not can_use_ultimate(result):
        result["last_error"] = "ultimate_unavailable"
        return result
    result["ultimate_charges"] = int(result.get("ultimate_charges", 0)) - 1
    result.erase("last_error")
    return result

func reset_dungeon_charges(state: Dictionary) -> Dictionary:
    var result := state.duplicate(true)
    result["ultimate_charges"] = ultimate_charges_for_level(int(result.get("level", 1)))
    return result
