extends Node

var data: Dictionary = {}

func _ready() -> void:
    _load_data()
    if not CreatureManager.creature_captured.is_connected(_on_creature_captured):
        CreatureManager.creature_captured.connect(_on_creature_captured)

func _load_data() -> void:
    if not data.is_empty():
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/capture_wound_rules.json"))
    data = parsed if parsed is Dictionary else {}

func capture_bonus(enemy: Dictionary) -> int:
    _load_data()
    var lost: Array = enemy.get("dismembered_parts", [])
    var states: Dictionary = enemy.get("anatomy_part_states", {})
    var critical := 0
    for state_value in states.values():
        if str(state_value) == "critical":
            critical += 1
    var bonus := lost.size() * int(data.get("capture_bonus_per_lost_part", 7))
    bonus += critical * int(data.get("capture_bonus_per_critical_injury", 3))
    return clampi(bonus, 0, int(data.get("capture_bonus_cap", 20)))

func _on_creature_captured(creature: Dictionary) -> void:
    var instance_id := str(creature.get("instance_id", ""))
    if instance_id == "":
        return
    var enemy := _find_untransferred_captured_enemy(creature)
    if enemy.is_empty():
        return
    apply_to_capture(instance_id, enemy)

func _find_untransferred_captured_enemy(creature: Dictionary) -> Dictionary:
    var enemy_id := int(creature.get("enemy_id", -1))
    for index in range(GameState.battle_enemies.size() - 1, -1, -1):
        var candidate_value: Variant = GameState.battle_enemies[index]
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if enemy_id >= 0 and int(candidate.get("id", -2)) != enemy_id:
            continue
        if not bool(candidate.get("captured", false)) or int(candidate.get("hp", 1)) > 0:
            continue
        if bool(candidate.get("capture_wound_transferred", false)):
            continue
        candidate["capture_wound_transferred"] = true
        GameState.battle_enemies[index] = candidate
        return candidate
    return {}

func apply_to_latest_capture(enemy: Dictionary) -> Dictionary:
    _load_data()
    if CreatureManager.captured_creatures.is_empty():
        return {}
    var creature: Dictionary = CreatureManager.captured_creatures[CreatureManager.captured_creatures.size() - 1]
    return apply_to_capture(str(creature.get("instance_id", "")), enemy)

func apply_to_capture(instance_id: String, enemy: Dictionary) -> Dictionary:
    _load_data()
    if instance_id == "" or enemy.is_empty():
        return {}
    for index in range(CreatureManager.captured_creatures.size()):
        var creature: Dictionary = CreatureManager.captured_creatures[index]
        if str(creature.get("instance_id", "")) != instance_id:
            continue

        var lost: Array = (enemy.get("dismembered_parts", []) as Array).duplicate(true)
        var injuries: Dictionary = (enemy.get("anatomy_injuries", {}) as Dictionary).duplicate(true)
        var critical := 0
        for state_value in injuries.values():
            if str(state_value) == "critical":
                critical += 1

        var bond := int(data.get("bond_base", 50))
        bond -= lost.size() * int(data.get("bond_penalty_per_lost_part", 7))
        bond -= critical * int(data.get("bond_penalty_per_critical_injury", 2))
        bond = maxi(int(data.get("bond_minimum", 15)), bond)
        var care_required := int(data.get("care_base", 1))
        care_required += lost.size() * int(data.get("care_per_lost_part", 2))
        care_required += critical * int(data.get("care_per_critical_injury", 1))

        creature["bond"] = bond
        creature["capture_wounds"] = {"lost_parts": lost.duplicate(true), "injuries": injuries.duplicate(true)}
        creature["care_required"] = care_required
        creature["care_progress"] = 0
        creature["anatomy_recovery_locked"] = bool(data.get("disable_combat_until_care_complete", true)) and care_required > 0
        creature["disabled_anatomy_parts"] = lost.duplicate(true)
        creature["capture_condition"] = "mutilated" if not lost.is_empty() else ("injured" if not injuries.is_empty() else "stable")
        creature["source_enemy_id"] = int(enemy.get("id", creature.get("enemy_id", -1)))
        var remanence_origin_id := str(enemy.get("remanence_id", ""))
        if remanence_origin_id != "":
            creature["remanence_origin_id"] = remanence_origin_id

        for key in ["persistent_injuries", "body_state", "dismembered_parts", "anatomy_injuries", "anatomy_part_states", "anatomy_part_trauma"]:
            var value: Variant = enemy.get(key)
            if value is Array:
                creature[key] = (value as Array).duplicate(true)
            elif value is Dictionary:
                creature[key] = (value as Dictionary).duplicate(true)

        CreatureManager.captured_creatures[index] = creature
        CreatureManager.creatures_changed.emit()
        return creature.duplicate(true)
    return {}

func can_fight(creature: Dictionary) -> bool:
    return not bool(creature.get("anatomy_recovery_locked", false))

func provide_sanctuary_care(instance_id: String, points: int = -1) -> Dictionary:
    _load_data()
    var care_points := int(data.get("sanctuary_care_points_per_treatment", 1)) if points < 0 else maxi(0, points)
    for index in range(CreatureManager.captured_creatures.size()):
        var creature: Dictionary = CreatureManager.captured_creatures[index]
        if str(creature.get("instance_id", "")) != instance_id:
            continue
        var required := maxi(0, int(creature.get("care_required", 0)))
        var progress := mini(required, int(creature.get("care_progress", 0)) + care_points)
        creature["care_progress"] = progress
        if progress >= required:
            creature["anatomy_recovery_locked"] = false
            var wound_state: Dictionary = creature.get("capture_wounds", {})
            var permanently_lost: Array = (wound_state.get("lost_parts", []) as Array).duplicate(true)
            creature["disabled_anatomy_parts"] = permanently_lost
            creature["capture_condition"] = "adapted" if not permanently_lost.is_empty() else "recovered"
        CreatureManager.captured_creatures[index] = creature
        CreatureManager.creatures_changed.emit()
        return creature.duplicate(true)
    return {}

func care_status(creature: Dictionary) -> String:
    var required := maxi(0, int(creature.get("care_required", 0)))
    var progress := clampi(int(creature.get("care_progress", 0)), 0, required)
    if required <= 0 or progress >= required:
        return "apte au combat"
    return "convalescence %d/%d" % [progress, required]
