extends RefCounted
class_name VeilleursGE01SkillBridge

const CORPSE_SKILLS := preload("res://scripts/core/veilleurs_corpse_skill_runtime.gd")
var corpse_skills: RefCounted = CORPSE_SKILLS.new()

func is_supported_skill(skill_id: String) -> bool:
    return skill_id in ["AÏ-ANA-12", "TA-TRA-06"]

func preview(hero: Dictionary, skill: Dictionary, target: Dictionary, corpse_ids: Array) -> Dictionary:
    var skill_id := str(skill.get("id", ""))
    if skill_id == "AÏ-ANA-12":
        return {
            "supported": true,
            "target_kind": "corpse",
            "requires_corpse": true,
            "corpse_count": corpse_ids.size(),
            "summary": "Analyse un cadavre : faiblesse, cause de mort et indice anatomique.",
            "positions": str(skill.get("canonical_positions", "P1-P3"))
        }
    if skill_id == "TA-TRA-06":
        var context: Dictionary = corpse_skills.call("attack_context", hero, target, corpse_ids)
        return {
            "supported": true,
            "target_kind": "enemy_anatomy",
            "requires_known_zone": true,
            "corpse_between": bool(context.get("corpse_between", false)),
            "summary": "Tir précis sur une zone révélée; le terrain peut améliorer la lecture de trajectoire.",
            "positions": str(skill.get("canonical_positions", "P2-P4"))
        }
    return {"supported": false}

func resolve_read_the_dead(hero: Dictionary, scar_id: String) -> Dictionary:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return {"ok": false, "reason": "corpse_missing"}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    var body: Dictionary = payload.get("body_snapshot", {})
    var clue := str(payload.get("cause_of_death", payload.get("summary", "Cause de mort indéterminée.")))
    payload["examined_by_aisha"] = true
    payload["last_anatomy_reader"] = str(hero.get("id", "aisha_maren"))
    payload["anatomy_read_run"] = RemanenceRuntime.run_index
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    return {
        "ok": true,
        "scar_id": scar_id,
        "cause_or_clue": clue,
        "body_known": not body.is_empty(),
        "anatomy_hint": _anatomy_hint(body),
        "knowledge_gain": 1
    }

func resolve_weakness_shot(hero: Dictionary, target: Dictionary, corpse_ids: Array, body_zone: String) -> Dictionary:
    var context: Dictionary = corpse_skills.call("attack_context", hero, target, corpse_ids)
    var anatomy: Dictionary = corpse_skills.call("anatomy_bonus", target, body_zone, context)
    var bonus := int(anatomy.get("precision_bonus", 0))
    target["ge01_weakness_shot_zone"] = body_zone
    target["ge01_weakness_shot_precision_bonus"] = bonus
    return {
        "ok": body_zone != "" and body_zone != "unknown",
        "zone": body_zone,
        "precision_bonus": bonus,
        "corpse_between": bool(context.get("corpse_between", false)),
        "summary": "+%d précision sur %s" % [bonus, body_zone] if bonus > 0 else "Zone anatomique ciblée : %s" % body_zone
    }

func _anatomy_hint(body: Dictionary) -> String:
    if body.is_empty():
        return "Le corps ne fournit pas encore de carte anatomique complète."
    for key in ["dismembered_parts", "anatomy_injuries", "persistent_injuries"]:
        var value: Variant = body.get(key, null)
        if value is Array and not (value as Array).is_empty():
            return "%s révèle une atteinte exploitable." % key.replace("_", " ")
        if value is Dictionary and not (value as Dictionary).is_empty():
            return "%s révèle une atteinte exploitable." % key.replace("_", " ")
    return "Aucune lésion majeure n'est confirmée."
