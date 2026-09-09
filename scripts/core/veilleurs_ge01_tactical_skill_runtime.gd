extends RefCounted
class_name VeilleursGE01TacticalSkillRuntime

const EXPOSED_ROUNDS := 2

func expose_articulation(target: Dictionary, zone: String) -> Dictionary:
    if target.is_empty() or int(target.get("hp", 0)) <= 0:
        return {"ok": false, "reason": "invalid_target"}
    var normalized := _normalize_zone(zone)
    target["ge01_exposed_zone"] = normalized
    target["ge01_exposed_rounds"] = EXPOSED_ROUNDS
    target["exposed"] = true
    return {
        "ok": true,
        "zone": normalized,
        "rounds": EXPOSED_ROUNDS,
        "summary": "%s exposé · %d rounds" % [_zone_label(normalized), EXPOSED_ROUNDS]
    }

func pas_sanglant_options(hero: Dictionary, target: Dictionary, allies: Array) -> Dictionary:
    if hero.is_empty() or target.is_empty():
        return {"ok": false, "reason": "invalid_context", "destinations": []}
    var wounded := _target_is_wounded(target)
    var destinations: Array[int] = []
    if wounded:
        destinations = CombatPositionRuntime.available_moves(hero, allies, "hero")
    return {
        "ok": true,
        "target_wounded": wounded,
        "destinations": destinations,
        "from": CombatPositionRuntime.position_of(hero),
        "summary": "Repositionnement disponible après l'entaille." if wounded and not destinations.is_empty() else ("Cible blessée, mais aucun rang adjacent n'est libre." if wounded else "Repositionnement verrouillé : la cible doit déjà être blessée.")
    }

func pas_sanglant_move(hero: Dictionary, destination: int, allies: Array) -> Dictionary:
    return CombatPositionRuntime.move(hero, destination, allies, "hero", "TA-ENT-05")

func movement_reaction_preview(enemy: Dictionary, from_slot: int, to_slot: int, heroes: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if from_slot == to_slot:
        return result
    for hero_value: Variant in heroes:
        if not hero_value is Dictionary:
            continue
        var hero: Dictionary = hero_value
        var unlocked: Array = hero.get("unlocked_skills", [])
        if str(hero.get("id", "")) == "tarek_senn" and unlocked.has("TA-ENT-13"):
            result.append({"skill_id": "TA-ENT-13", "name": "Fauchage réflexe", "hero": str(hero.get("name", "Tarek")), "summary": "Le changement de rang traverse l'espace rapproché : réaction possible."})
        if str(hero.get("id", "")) == "aisha_maren" and unlocked.has("AÏ-ANA-13"):
            result.append({"skill_id": "AÏ-ANA-13", "name": "Réflexe musculaire", "hero": str(hero.get("name", "Aïsha")), "summary": "Le déplacement sollicite un groupe musculaire prévisible : réaction possible."})
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

func _target_is_wounded(target: Dictionary) -> bool:
    if int(target.get("hp", 0)) < int(target.get("max_hp", target.get("hp", 0))):
        return true
    for key in ["persistent_injuries", "anatomy_injuries", "dismembered_parts"]:
        var value: Variant = target.get(key, null)
        if value is Array and not (value as Array).is_empty(): return true
        if value is Dictionary and not (value as Dictionary).is_empty(): return true
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
