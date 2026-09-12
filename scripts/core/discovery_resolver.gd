extends RefCounted

const STRENGTH_RANK := {"TRACE":1, "WEAK":2, "MODERATE":3, "STRONG":4}

static func resolve_observation(observation: Dictionary, assessments: Array, current_hypothesis: Dictionary, evidence_lookup: Dictionary) -> Dictionary:
    var hypothesis := current_hypothesis.duplicate(true)
    var lookup := evidence_lookup.duplicate(true)
    var new_evidence: Array[Dictionary] = []
    for value: Variant in assessments:
        if not (value is Dictionary):
            continue
        var assessment: Dictionary = value
        var evidence := _build_evidence(observation, assessment)
        var evidence_id := str(evidence.get("evidence_id", ""))
        if lookup.has(evidence_id):
            continue
        lookup[evidence_id] = evidence
        new_evidence.append(evidence)
        hypothesis = _apply(hypothesis, evidence, lookup)
    return {
        "accepted": true,
        "new_evidence_records": new_evidence,
        "hypothesis_after": hypothesis,
        "knowledge_projection": _projection(hypothesis)
    }

static func _build_evidence(observation: Dictionary, assessment: Dictionary) -> Dictionary:
    var key := "%s|%s|%s|%s" % [
        str(assessment.get("hypothesis_id", "")),
        str(assessment.get("independence_group", "")),
        str(assessment.get("policy_rule_id", "")),
        str(assessment.get("direction", ""))
    ]
    return {
        "schema_version": 1,
        "evidence_id": "EVID_%s" % key.sha256_text().substr(0, 20).to_upper(),
        "subject_entity_id": str(observation.get("subject_entity_id", "")),
        "fact_id": str(assessment.get("fact_id", "")),
        "hypothesis_id": str(assessment.get("hypothesis_id", "")),
        "policy_id": str(assessment.get("policy_id", "")),
        "policy_rule_id": str(assessment.get("policy_rule_id", "")),
        "direction": str(assessment.get("direction", "")),
        "strength": str(assessment.get("strength", "")),
        "independence_group": str(assessment.get("independence_group", "")),
        "source_observation_ids": (assessment.get("source_observation_ids", []) as Array).duplicate(),
        "source_event_id": str(assessment.get("source_event_id", "")),
        "logical_time": (assessment.get("logical_time", {}) as Dictionary).duplicate(true),
        "confounder_ids": (assessment.get("confounder_ids", []) as Array).duplicate()
    }

static func _apply(hypothesis: Dictionary, evidence: Dictionary, lookup: Dictionary) -> Dictionary:
    var h := hypothesis.duplicate(true)
    if h.is_empty():
        h = {
            "schema_version": 1,
            "hypothesis_id": str(evidence.get("hypothesis_id", "")),
            "subject_entity_id": str(evidence.get("subject_entity_id", "")),
            "fact_id": str(evidence.get("fact_id", "")),
            "policy_id": str(evidence.get("policy_id", "")),
            "status": "SUSPICION",
            "supporting_evidence_ids": [],
            "contradicting_evidence_ids": [],
            "neutral_evidence_ids": [],
            "status_history": []
        }
    var direction := str(evidence.get("direction", ""))
    var key := "neutral_evidence_ids"
    if direction == "SUPPORT":
        key = "supporting_evidence_ids"
    elif direction == "CONTRADICT":
        key = "contradicting_evidence_ids"
    var ids: Array = h.get(key, []) if h.get(key, []) is Array else []
    var evidence_id := str(evidence.get("evidence_id", ""))
    if not ids.has(evidence_id):
        ids.append(evidence_id)
    h[key] = ids
    var old_status := str(h.get("status", "SUSPICION"))
    var new_status := _status(h, lookup)
    h["status"] = new_status
    if old_status != new_status:
        var history: Array = h.get("status_history", []) if h.get("status_history", []) is Array else []
        history.append({"from":old_status, "to":new_status, "evidence_id":evidence_id})
        h["status_history"] = history
    return h

static func _status(h: Dictionary, lookup: Dictionary) -> String:
    var support := _group_stats(h.get("supporting_evidence_ids", []), lookup)
    var contradict := _group_stats(h.get("contradicting_evidence_ids", []), lookup)
    if int(contradict["moderate_plus"]) >= 4 and int(contradict["combats"]) >= 2 and int(support["strong_plus"]) <= 1:
        return "REFUTED"
    if int(support["groups"]) >= 5 and int(support["combats"]) >= 3 and int(support["strong_plus"]) >= 2 and int(contradict["strong_plus"]) == 0:
        return "VERIFIED"
    if int(support["groups"]) >= 3 and int(support["combats"]) >= 2 and int(support["strong_plus"]) >= 1 and int(contradict["moderate_plus"]) <= 1:
        return "PROBABLE"
    if int(support["weak_plus"]) >= 2 and int(contradict["moderate_plus"]) >= 2:
        return "UNCERTAIN"
    if int(support["groups"]) >= 2 and int(support["weak_plus"]) >= 1:
        return "HYPOTHESIS"
    return "SUSPICION"

static func _group_stats(ids_value: Variant, lookup: Dictionary) -> Dictionary:
    var ids: Array = ids_value if ids_value is Array else []
    var rank_by_group: Dictionary = {}
    var combat_by_group: Dictionary = {}
    for value: Variant in ids:
        var evidence_id := str(value)
        if not lookup.has(evidence_id):
            continue
        var evidence: Dictionary = lookup[evidence_id]
        var group := str(evidence.get("independence_group", evidence_id))
        var rank := int(STRENGTH_RANK.get(str(evidence.get("strength", "TRACE")), 1))
        if not rank_by_group.has(group) or rank > int(rank_by_group[group]):
            rank_by_group[group] = rank
            combat_by_group[group] = str((evidence.get("logical_time", {}) as Dictionary).get("combat_id", ""))
    var combats: Dictionary = {}
    var weak_plus := 0
    var moderate_plus := 0
    var strong_plus := 0
    for group_value: Variant in rank_by_group.keys():
        var group := str(group_value)
        var rank := int(rank_by_group[group])
        if rank >= 2:
            weak_plus += 1
        if rank >= 3:
            moderate_plus += 1
        if rank >= 4:
            strong_plus += 1
        var combat_id := str(combat_by_group[group])
        if combat_id != "":
            combats[combat_id] = true
    return {"groups":rank_by_group.size(),"weak_plus":weak_plus,"moderate_plus":moderate_plus,"strong_plus":strong_plus,"combats":combats.size()}

static func _projection(h: Dictionary) -> Dictionary:
    var status := str(h.get("status", ""))
    var level := 0 if h.is_empty() else 1
    var unlocks: Array[String] = []
    if status in ["PROBABLE", "VERIFIED"]:
        level = 2
        unlocks.append("UNLOCK_GOULE_AFFAMEE_TARGET_VULNERABLE_HINT")
    return {"archive_level":level,"unlock_ids":unlocks,"hud_text_fr":"Cible vulnérable probable" if not unlocks.is_empty() else ""}
