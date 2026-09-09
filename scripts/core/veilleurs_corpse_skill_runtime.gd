extends RefCounted
class_name VeilleursCorpseSkillRuntime

const CORPSE_TACTICS := preload("res://scripts/core/veilleurs_corpse_tactical_runtime.gd")
var corpses: RefCounted = CORPSE_TACTICS.new()

func available_actions(scar_ids: Array, side: String = "hero") -> Array[String]:
    var context: Dictionary = corpses.call("skill_context", scar_ids, side)
    if not bool(context.get("corpse_skill_available", false)):
        return []
    return ["push", "barricade", "project"]

func push(scar_id: String, destination: int, side: String = "hero") -> Dictionary:
    var result: Dictionary = corpses.call("place", scar_id, destination, false, side)
    if bool(result.get("ok", false)):
        corpses.call("consume_for_skill", scar_id, "CORPSE_PUSH", "move")
    return result

func barricade(scar_id: String, destination: int, side: String = "hero", cover_quality: int = 35) -> Dictionary:
    var result: Dictionary = corpses.call("place", scar_id, destination, true, side)
    if not bool(result.get("ok", false)):
        return result
    var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    payload["prepared_as_cover"] = true
    payload["cover_quality"] = clampi(cover_quality, 15, 45)
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    corpses.call("consume_for_skill", scar_id, "CORPSE_BARRICADE", "prepare")
    result["cover_quality"] = payload["cover_quality"]
    return result

func project(scar_id: String, enemy: Dictionary, enemy_allies: Array, destination: int) -> Dictionary:
    if enemy.is_empty() or int(enemy.get("hp", 0)) <= 0:
        return {"ok": false, "reason": "invalid_target"}
    var result: Dictionary = corpses.call("place", scar_id, destination, true, "enemy")
    if not bool(result.get("ok", false)):
        return result
    var origin := CombatPositionRuntime.position_of(enemy)
    var forced := destination + 1 if destination < 3 else destination - 1
    if CombatPositionRuntime.can_move(enemy, forced, enemy_allies, "enemy"):
        CombatPositionRuntime.move(enemy, forced, enemy_allies, "enemy", "corpse_project")
    corpses.call("consume_for_skill", scar_id, "CORPSE_PROJECT", "project")
    result["enemy_from"] = origin
    result["enemy_to"] = CombatPositionRuntime.position_of(enemy)
    result["displaced"] = origin != int(result["enemy_to"])
    return result

func attack_context(attacker: Dictionary, target: Dictionary, scar_ids: Array) -> Dictionary:
    var attacker_slot := CombatPositionRuntime.position_of(attacker)
    var target_slot := CombatPositionRuntime.position_of(target)
    var hero_cover := int(corpses.call("cover_for_slot", attacker_slot, scar_ids, "hero"))
    var enemy_cover := int(corpses.call("cover_for_slot", target_slot, scar_ids, "enemy"))
    return {
        "attacker_slot": attacker_slot,
        "target_slot": target_slot,
        "attacker_cover": hero_cover,
        "target_cover": enemy_cover,
        "can_attack_over_cover": hero_cover > 0,
        "corpse_between": _corpse_between(attacker_slot, target_slot, scar_ids)
    }

func anatomy_bonus(target: Dictionary, body_zone: String, context: Dictionary) -> Dictionary:
    var known := body_zone != "" and body_zone != "unknown"
    var bonus := 0
    if known and bool(context.get("corpse_between", false)):
        bonus = 10
    return {"zone": body_zone, "known": known, "precision_bonus": bonus}

func _corpse_between(attacker_slot: int, target_slot: int, scar_ids: Array) -> bool:
    var state: Dictionary = corpses.call("snapshot", scar_ids, "")
    for corpse_value: Variant in state.get("corpses", []):
        var corpse: Dictionary = corpse_value
        var slot := int(corpse.get("slot", -1))
        if slot >= mini(attacker_slot, target_slot) and slot <= maxi(attacker_slot, target_slot):
            return true
    return false
