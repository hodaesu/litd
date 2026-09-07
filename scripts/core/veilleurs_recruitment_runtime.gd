extends RefCounted
class_name VeilleursRecruitmentRuntime

var rules: Dictionary = {}

func configure(value: Dictionary) -> void:
    rules = value.duplicate(true)

func evaluate(candidate: Dictionary, context: Dictionary) -> Dictionary:
    var entity_id := str(candidate.get("entity_id", candidate.get("id", "")))
    var family := str(candidate.get("family", ""))
    var result := {
        "ok": true,
        "entity_id": entity_id,
        "family": family,
        "outcome": "refuse",
        "met": [],
        "missing": [],
        "blocked_by": []
    }
    if entity_id == "" or family == "":
        result["ok"] = false
        result["blocked_by"] = ["invalid_candidate"]
        return result
    if entity_id.begins_with("ENT_BOSS_") or bool(candidate.get("boss", false)):
        result["blocked_by"] = ["boss"]
        return result
    if not bool(candidate.get("alive", true)) or int(candidate.get("hp", 1)) <= 0:
        result["blocked_by"] = ["not_living"]
        return result
    var traits: Array = candidate.get("traits", [])
    if traits.has(str((rules.get("trait_manifestation_destructrice", {}) as Dictionary).get("id", "TRAIT_MANIFESTATION_DESTRUCTIVE"))):
        result["blocked_by"] = ["manifestation_destructrice"]
        return result
    if int(context.get("refuge_slots_free", 0)) <= 0:
        result["blocked_by"] = ["refuge_full"]
        return result
    if int(context.get("recruits_this_expedition", 0)) >= int(rules.get("max_recruits_per_expedition", 2)):
        result["blocked_by"] = ["expedition_cap"]
        return result

    var family_rules: Dictionary = (rules.get("families", {}) as Dictionary).get(family, {})
    if family_rules.is_empty():
        result["ok"] = false
        result["blocked_by"] = ["unknown_family"]
        return result
    var flags: Array = context.get("condition_flags", [])
    for forbidden_value: Variant in family_rules.get("forbidden_conditions", []):
        var forbidden := str(forbidden_value)
        if flags.has(forbidden):
            (result["blocked_by"] as Array).append(forbidden)
    if not (result["blocked_by"] as Array).is_empty():
        return result

    var primary_met := 0
    for condition_value: Variant in family_rules.get("primary_conditions", []):
        var condition := str(condition_value)
        if flags.has(condition):
            (result["met"] as Array).append(condition)
            primary_met += 1
        else:
            (result["missing"] as Array).append(condition)

    var knowledge_level := int(context.get("knowledge_level", 0))
    var respect := int(context.get("respect", 0))
    var shared_event := int(context.get("shared_event", 0))
    var fear := int(context.get("fear", 0))
    var relation_gate := respect >= int((rules.get("relationship_thresholds", {}) as Dictionary).get("respect", 2)) or shared_event >= int((rules.get("relationship_thresholds", {}) as Dictionary).get("shared_event", 1))
    var knowledge_gate := knowledge_level >= int((rules.get("knowledge_thresholds", {}) as Dictionary).get("family_known", 1))

    result["primary_met"] = primary_met
    result["relation_gate"] = relation_gate
    result["knowledge_gate"] = knowledge_gate
    result["fear"] = fear
    if primary_met >= 2 and relation_gate and knowledge_gate:
        result["outcome"] = "accept"
    elif primary_met >= 1 or relation_gate or knowledge_gate:
        result["outcome"] = "defer"
    else:
        result["outcome"] = "refuse"
    return result

func recruit(candidate: Dictionary, context: Dictionary, roster: Array) -> Dictionary:
    var evaluation := evaluate(candidate, context)
    if str(evaluation.get("outcome", "refuse")) != "accept":
        return {"ok":false, "evaluation":evaluation, "roster":roster.duplicate(true)}
    if roster.size() >= int(rules.get("refuge_recruit_cap", 12)):
        evaluation["outcome"] = "refuse"
        evaluation["blocked_by"] = ["refuge_cap"]
        return {"ok":false, "evaluation":evaluation, "roster":roster.duplicate(true)}
    var next_roster := roster.duplicate(true)
    var recruit_row := {
        "entity_id": str(candidate.get("entity_id", candidate.get("id", ""))),
        "definition_id": str(candidate.get("definition_id", candidate.get("entity_id", ""))),
        "family": str(candidate.get("family", "")),
        "level": clampi(int(candidate.get("level", 1)), 1, 50),
        "remanence_id": str(candidate.get("remanence_id", "")),
        "body_state": (candidate.get("body_state", {}) as Dictionary).duplicate(true),
        "chosen_tree": "",
        "relation_origin": "recruited_from_encounter"
    }
    next_roster.append(recruit_row)
    return {"ok":true, "evaluation":evaluation, "recruit":recruit_row, "roster":next_roster}
