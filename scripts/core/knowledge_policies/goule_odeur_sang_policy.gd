extends RefCounted

const ENTITY_ID := "ENT_ENEMY_GOULE_AFFAMEE"
const FACT_ID := "FACT_GOULE_AFFAMEE_ODEUR_SANG"
const HYPOTHESIS_ID := "HYP_GOULE_AFFAMEE_01"
const POLICY_ID := "POLICY_GOULE_AFFAMEE_ODEUR_SANG"

const DISTANCE_RANK := {"CONTACT":0, "NEAR":1, "MID":2, "FAR":3}

static func descriptor() -> Dictionary:
    return {
        "entity_id": ENTITY_ID,
        "fact_id": FACT_ID,
        "hypothesis_id": HYPOTHESIS_ID,
        "policy_id": POLICY_ID,
        "claim_scope": "TENDENCY",
        "claim_fr": "Le sang ou une plaie visible augmente probablement la priorité d'une cible.",
        "unlock_id": "UNLOCK_GOULE_AFFAMEE_TARGET_VULNERABLE_HINT"
    }

static func evaluate(observation: Dictionary) -> Array[Dictionary]:
    if str(observation.get("subject_entity_id", "")) != ENTITY_ID:
        return []
    if str(observation.get("event_type", "")) != "combat.target_selected":
        return []
    var features: Dictionary = observation.get("perceived_features", {}) as Dictionary
    var chosen_id := str(features.get("chosen_target_id", ""))
    var candidates: Array = features.get("candidate_targets", []) if features.get("candidate_targets", []) is Array else []
    var chosen: Dictionary = {}
    var accessible: Array[Dictionary] = []
    for value: Variant in candidates:
        if not (value is Dictionary):
            continue
        var row: Dictionary = value
        if bool(row.get("accessible", false)):
            accessible.append(row)
        if str(row.get("target_id", "")) == chosen_id:
            chosen = row
    if chosen.is_empty() or not bool(chosen.get("accessible", false)):
        return []
    var chosen_bleeding := bool(chosen.get("bleeding_visible", false))
    var bleeding: Array[Dictionary] = []
    var healthy: Array[Dictionary] = []
    for row: Dictionary in accessible:
        if str(row.get("target_id", "")) == chosen_id:
            continue
        if bool(row.get("bleeding_visible", false)):
            bleeding.append(row)
        else:
            healthy.append(row)

    if accessible.size() == 1 and chosen_bleeding:
        return [_assessment(observation, "RULE_ONLY_ACCESSIBLE", "SUPPORT", "TRACE", ["CONF_GOULE_ONLY_ACCESSIBLE"])]
    if chosen_bleeding and not healthy.is_empty():
        if _closer_than_all(chosen, healthy):
            return [_assessment(observation, "RULE_BLEEDING_CLOSEST", "SUPPORT", "WEAK", ["CONF_GOULE_CLOSEST"])]
        return [_assessment(observation, "RULE_BLEEDING_COMPARABLE", "SUPPORT", "STRONG", [])]
    if not chosen_bleeding and not bleeding.is_empty():
        if _closer_than_all(chosen, bleeding):
            return [_assessment(observation, "RULE_HEALTHY_CLOSER", "NEUTRAL", "TRACE", ["CONF_GOULE_CLOSEST"])]
        return [_assessment(observation, "RULE_HEALTHY_COMPARABLE", "CONTRADICT", "MODERATE", [])]
    return [_assessment(observation, "RULE_NO_CONTRAST", "NEUTRAL", "TRACE", [])]

static func _assessment(observation: Dictionary, rule_id: String, direction: String, strength: String, confounders: Array[String]) -> Dictionary:
    return {
        "fact_id": FACT_ID,
        "hypothesis_id": HYPOTHESIS_ID,
        "policy_id": POLICY_ID,
        "policy_rule_id": rule_id,
        "direction": direction,
        "strength": strength,
        "independence_group": str(observation.get("independence_group", "")),
        "source_observation_ids": [str(observation.get("observation_id", ""))],
        "source_event_id": str(observation.get("event_id", "")),
        "logical_time": (observation.get("logical_time", {}) as Dictionary).duplicate(true),
        "confounder_ids": confounders
    }

static func _closer_than_all(chosen: Dictionary, alternatives: Array[Dictionary]) -> bool:
    var chosen_rank := int(DISTANCE_RANK.get(str(chosen.get("distance_band", "FAR")), 99))
    for row: Dictionary in alternatives:
        if chosen_rank >= int(DISTANCE_RANK.get(str(row.get("distance_band", "FAR")), 99)):
            return false
    return not alternatives.is_empty()
