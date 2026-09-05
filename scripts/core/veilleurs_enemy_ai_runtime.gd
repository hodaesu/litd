extends RefCounted

const PROFILE_PATH := "res://data/veilleurs/enemy_ai_contract_profiles.json"
const PhysicalRules := preload("res://scripts/core/combat_physical_rules.gd")

var profiles: Dictionary = {}

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    if parsed is Dictionary:
        profiles = (parsed as Dictionary).get("profiles", {})

func select_target(enemy: Dictionary, heroes: Array) -> Dictionary:
    var enemy_name := str(enemy.get("name", enemy.get("species", "")))
    var profile: Dictionary = (profiles.get(enemy_name, {}) as Dictionary).duplicate(true)
    var mode := str(profile.get("target_priority", enemy.get("target_priority", "nearest_accessible")))
    var accessible_positions: Array = enemy.get("accessible_positions", profile.get("default_accessible_positions", [0, 1, 2, 3]))
    var best: Dictionary = {}
    var best_score := -INF
    for index in range(heroes.size()):
        if not (heroes[index] is Dictionary):
            continue
        var hero: Dictionary = heroes[index]
        if int(hero.get("hp", 0)) <= 0:
            continue
        var position := int(hero.get("combat_position", index))
        if not accessible_positions.has(position):
            continue
        var score := _target_score(hero, mode)
        if score > best_score:
            best_score = score
            best = {"index": index, "hero": hero, "score": score, "accessible": true, "mode": mode}
    if best.is_empty():
        return {"index": -1, "hero": {}, "accessible": false, "mode": mode, "reason": "no_accessible_target"}
    best["reason"] = "selected_accessible_target"
    return best

func available_actions(enemy: Dictionary, actions: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in actions:
        if not (value is Dictionary):
            continue
        var action: Dictionary = value
        var availability := PhysicalRules.skill_availability(enemy, action)
        if bool(availability.get("usable", false)):
            result.append(action.duplicate(true))
    return result

func plan_porte_signe(enemy: Dictionary, actions: Array) -> Dictionary:
    var profile: Dictionary = (profiles.get("Porte-Signe", {}) as Dictionary).duplicate(true)
    var available := available_actions(enemy, actions)
    if available.is_empty():
        return {"ok": false, "reason": "no_functional_action", "plan": "retreat_or_guard"}
    var gesture_function := str(profile.get("coordination_function", "gesture"))
    var gesture_available := false
    for value: Variant in actions:
        if not (value is Dictionary):
            continue
        var action: Dictionary = value
        var requires: Array = action.get("required_functions", action.get("requires_functions", []))
        if requires.has(gesture_function) and bool(PhysicalRules.skill_availability(enemy, action).get("usable", false)):
            gesture_available = true
            break
    if gesture_available:
        for action: Dictionary in available:
            var requires: Array = action.get("required_functions", action.get("requires_functions", []))
            if requires.has(gesture_function):
                return {"ok": true, "action": action, "replanned": false, "reason": "coordination_available"}
    for action: Dictionary in available:
        var requires: Array = action.get("required_functions", action.get("requires_functions", []))
        if not requires.has(gesture_function):
            return {
                "ok": true,
                "action": action,
                "replanned": true,
                "reason": "hands_unavailable_replan",
                "plan": str(profile.get("fallback_plan", "self_preservation"))
            }
    return {"ok": false, "reason": "gesture_actions_only", "plan": "retreat_or_guard"}

func observe_action_family(archivist: Dictionary, family: String) -> Dictionary:
    var observed: Array = archivist.get("observed_action_families", [])
    if family != "" and not observed.has(family):
        observed.append(family)
    archivist["observed_action_families"] = observed
    return archivist_counter_profile(archivist)

func archivist_counter_profile(archivist: Dictionary) -> Dictionary:
    var profile: Dictionary = (profiles.get("Archiviste de Version", {}) as Dictionary).duplicate(true)
    var observed: Array = archivist.get("observed_action_families", [])
    var saturation_count := int(profile.get("saturation_family_count", 4))
    var saturated := observed.size() >= saturation_count
    if saturated:
        return {
            "saturated": true,
            "perfect_counter": false,
            "observed_family_count": observed.size(),
            "counter_confidence": float(profile.get("saturated_counter_confidence", 0.55)),
            "response_family": str(profile.get("saturated_response", "mixed_partial")),
            "reason": "too_many_distinct_families"
        }
    return {
        "saturated": false,
        "perfect_counter": observed.size() <= int(profile.get("perfect_counter_family_limit", 3)),
        "observed_family_count": observed.size(),
        "counter_confidence": 1.0 if observed.size() <= 1 else maxf(0.65, 1.0 - 0.12 * float(observed.size() - 1)),
        "response_family": str(observed[-1]) if not observed.is_empty() else "none",
        "reason": "focused_archive"
    }

func _target_score(hero: Dictionary, mode: String) -> float:
    var hp_ratio := float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("max_hp", 1)))
    match mode:
        "wounded_accessible":
            var injury_bonus := 0.0
            if not (hero.get("persistent_injuries", []) as Array).is_empty():
                injury_bonus += 0.35
            if bool(hero.get("bleeding", false)) or int(hero.get("bleed", 0)) > 0:
                injury_bonus += 0.25
            return (1.0 - hp_ratio) + injury_bonus
        "nearest_accessible":
            return -float(hero.get("combat_position", 0))
        _:
            return 1.0 - hp_ratio
