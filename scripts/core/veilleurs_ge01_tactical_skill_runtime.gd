extends RefCounted
class_name VeilleursGE01TacticalSkillRuntime

# Generic GE01 tactical primitives. They intentionally carry no hero/skill identity.
# Canonical skills may opt into these effects later through data-driven metadata.

const EXPOSED_ROUNDS := 2

func expose_zone(target: Dictionary, zone: String, rounds: int = EXPOSED_ROUNDS) -> Dictionary:
    if target.is_empty() or int(target.get("hp", 0)) <= 0:
        return {"ok": false, "reason": "invalid_target"}
    var normalized := _normalize_zone(zone)
    var duration := maxi(1, rounds)
    target["ge01_exposed_zone"] = normalized
    target["ge01_exposed_rounds"] = duration
    target["exposed"] = true
    return {
        "ok": true,
        "zone": normalized,
        "rounds": duration,
        "summary": "%s exposé · %d rounds" % [_zone_label(normalized), duration]
    }

func reposition_options(actor: Dictionary, condition_met: bool, allies: Array) -> Dictionary:
    if actor.is_empty():
        return {"ok": false, "reason": "invalid_context", "destinations": []}
    var destinations: Array[int] = []
    if condition_met:
        destinations = CombatPositionRuntime.available_moves(actor, allies, "hero")
    return {
        "ok": true,
        "condition_met": condition_met,
        "destinations": destinations,
        "from": CombatPositionRuntime.position_of(actor),
        "summary": "Repositionnement tactique disponible." if condition_met and not destinations.is_empty() else ("Condition remplie, mais aucun rang adjacent n'est libre." if condition_met else "Repositionnement verrouillé : condition de compétence non remplie.")
    }

func reposition_move(actor: Dictionary, destination: int, allies: Array, source_id: String = "GE01_TACTICAL_REPOSITION") -> Dictionary:
    return CombatPositionRuntime.move(actor, destination, allies, "hero", source_id)

func movement_reaction_preview(from_slot: int, to_slot: int, reactors: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if from_slot == to_slot:
        return result
    for value: Variant in reactors:
        if not value is Dictionary:
            continue
        var reactor: Dictionary = value
        var reactions: Array = reactor.get("movement_reactions", [])
        for reaction_value: Variant in reactions:
            if not reaction_value is Dictionary:
                continue
            var reaction: Dictionary = reaction_value
            if not bool(reaction.get("enabled", true)):
                continue
            result.append({
                "reaction_id": str(reaction.get("id", "")),
                "name": str(reaction.get("name", "Réaction")),
                "actor": str(reactor.get("name", "Veilleur")),
                "summary": str(reaction.get("summary", "Un changement de rang peut déclencher cette réaction."))
            })
    return result

func exposed_bonus(target: Dictionary, zone: String) -> Dictionary:
    var exposed_zone := str(target.get("ge01_exposed_zone", ""))
    var rounds := int(target.get("ge01_exposed_rounds", 0))
    var matches := rounds > 0 and exposed_zone != "" and exposed_zone == _normalize_zone(zone)
    return {
        "active": matches,
        "zone": exposed_zone,
        "precision_bonus": 12 if matches else 0,
        "damage_bonus_percent": 10 if matches else 0,
        "rounds": rounds
    }

func advance_round(targets: Array) -> void:
    for value: Variant in targets:
        if not value is Dictionary:
            continue
        var target: Dictionary = value
        var rounds := int(target.get("ge01_exposed_rounds", 0))
        if rounds <= 0:
            continue
        rounds -= 1
        target["ge01_exposed_rounds"] = rounds
        if rounds <= 0:
            target.erase("ge01_exposed_zone")
            target.erase("exposed")

func target_is_wounded(target: Dictionary) -> bool:
    if int(target.get("hp", 0)) < int(target.get("max_hp", target.get("hp", 0))):
        return true
    for key in ["persistent_injuries", "anatomy_injuries", "dismembered_parts"]:
        var value: Variant = target.get(key, null)
        if value is Array and not (value as Array).is_empty():
            return true
        if value is Dictionary and not (value as Dictionary).is_empty():
            return true
    return false

func _normalize_zone(zone: String) -> String:
    var value := zone.to_lower().strip_edges()
    if value in ["head", "tete", "tête"]: return "head"
    if value in ["torso", "torse"]: return "torso"
    if value in ["left_arm", "bras_gauche"]: return "left_arm"
    if value in ["right_arm", "bras_droit"]: return "right_arm"
    if value in ["left_leg", "jambe_gauche"]: return "left_leg"
    if value in ["right_leg", "jambe_droite"]: return "right_leg"
    return "right_leg"

func _zone_label(zone: String) -> String:
    return str({"head":"Tête","torso":"Torse","left_arm":"Bras gauche","right_arm":"Bras droit","left_leg":"Jambe gauche","right_leg":"Jambe droite"}.get(zone, zone))
