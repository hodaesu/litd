extends Node

var data: Dictionary = {}

func _ready() -> void:
    _load_data()

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

func apply_to_latest_capture(enemy: Dictionary) -> Dictionary:
    _load_data()
    if CreatureManager.captured_creatures.is_empty():
        return {}
    var index := CreatureManager.captured_creatures.size() - 1
    var creature: Dictionary = CreatureManager.captured_creatures[index]
    var lost: Array = enemy.get("dismembered_parts", []).duplicate(true)
    var injuries: Dictionary = enemy.get("anatomy_injuries", {}).duplicate(true)
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
    creature["capture_wounds"] = {"lost_parts": lost, "injuries": injuries}
    creature["care_required"] = care_required
    creature["care_progress"] = 0
    creature["anatomy_recovery_locked"] = bool(data.get("disable_combat_until_care_complete", true)) and care_required > 0
    creature["disabled_anatomy_parts"] = lost.duplicate(true)
    creature["capture_condition"] = "mutilated" if not lost.is_empty() else ("injured" if not injuries.is_empty() else "stable")
    CreatureManager.captured_creatures[index] = creature
    CreatureManager.creatures_changed.emit()
    return creature.duplicate(true)

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
            creature["disabled_anatomy_parts"] = []
            creature["capture_condition"] = "recovered"
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
