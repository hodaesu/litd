extends "res://scripts/core/veilleurs_tactical_combat_runtime_v2.gd"
class_name VeilleursTacticalCombatRuntimeV062

const HEMOCORDE_SCRIPT := preload("res://scripts/core/veilleurs_hemocorde_ultimate_runtime_v2.gd")

var hemocorde: VeilleursHemocordeUltimateRuntimeV2

func _init() -> void:
    super()
    hemocorde = HEMOCORDE_SCRIPT.new() as VeilleursHemocordeUltimateRuntimeV2

func resolve_skill(attacker_id: String, target_id: String, skill_id: String, zone: String = "torso", forced_roll: int = -1) -> Dictionary:
    var result: Dictionary = super.resolve_skill(attacker_id, target_id, skill_id, zone, forced_roll)
    if not bool(result.get("ok", false)):
        return result
    var skill: Dictionary = content_db.skill(skill_id)
    if skill.is_empty():
        return result
    result = hemocorde.post_skill_result(self, attacker_id, target_id, skill, result)
    if not action_log.is_empty() and str((action_log[action_log.size() - 1] as Dictionary).get("skill_id", "")) == skill_id:
        action_log[action_log.size() - 1] = result.duplicate(true)
    return result

func configure_watcher_progression(watcher_id: String, level: int, specialization: String, reset_charges: bool = true) -> Dictionary:
    if watcher_id != "ENT_WATCHER_AISHA":
        return {"ok": false, "reason": "ultimate_progression_not_implemented_for_watcher"}
    return hemocorde.configure_aisha(self, level, specialization, reset_charges)

func note_vascular_knowledge(target_id: String, zone: String, certainty: int = 2) -> Dictionary:
    return hemocorde.note_vascular_knowledge(self, target_id, zone, certainty)

func apply_bleeding(target_id: String, amount: int, wound_delta: int = 1) -> Dictionary:
    return hemocorde.apply_bleeding(self, target_id, amount, wound_delta)

func ultimate_status(attacker_id: String, target_id: String, branch: String, encounter_id: String) -> Dictionary:
    if attacker_id == "ENT_WATCHER_AISHA" and branch == "hemocorde":
        return hemocorde.status(self, attacker_id, target_id, encounter_id)
    return {"available": false, "reason": "ultimate_resolver_required", "attacker": attacker_id, "target": target_id, "branch": branch, "encounter_id": encounter_id}

func resolve_ultimate(attacker_id: String, target_id: String, branch: String, encounter_id: String) -> Dictionary:
    if attacker_id == "ENT_WATCHER_AISHA" and branch == "hemocorde":
        return hemocorde.resolve(self, attacker_id, target_id, encounter_id)
    return {"ok": false, "reason": "ultimate_resolver_required", "attacker": attacker_id, "target": target_id, "branch": branch, "encounter_id": encounter_id}
