extends RefCounted
class_name VeilleursEnemyDecisionMatrix

const SAFE_CONTEXT_KEYS := [
    "body_functions",
    "current_position",
    "observed_target_id",
    "later_encounter",
    "seed"
]
const RANK_BIAS := {
    "normal": 0.0,
    "memorial": 0.0,
    "veteran": 18.0,
    "elite": 28.0,
    "nemesis": 36.0
}
const THREAT_RESPONSES := {
    "assaut": ["defense", "controle", "repositionnement"],
    "controle": ["repositionnement", "defense", "chasse_embuscade"],
    "repositionnement": ["controle", "chasse_embuscade", "assaut"],
    "defense": ["controle", "environnement", "chasse_embuscade"],
    "soutien": ["assaut", "controle", "chasse_embuscade"],
    "environnement": ["repositionnement", "chasse_embuscade", "defense"],
    "chasse_embuscade": ["defense", "environnement", "repositionnement"],
    "fuite_cession_recrutement": ["chasse_embuscade", "repositionnement", "controle"]
}

var intent_resolver := VeilleursIntentResolver.new()

func rank_owned_skills(memory_state: Dictionary, owned_skills: Array, context: Dictionary = {}) -> Dictionary:
    var ignored_context_keys: Array[String] = []
    for key_value: Variant in context.keys():
        var key := str(key_value)
        if not key in SAFE_CONTEXT_KEYS:
            ignored_context_keys.append(key)

    var body_functions: Dictionary = context.get("body_functions", {})
    var species_id := str(memory_state.get("species_id", ""))
    var memory_rank := str(memory_state.get("memory_rank", "normal"))
    var bias := float(RANK_BIAS.get(memory_rank, 0.0))
    var channels: Dictionary = memory_state.get("memory_channels", {})
    var threat_memory: Dictionary = channels.get("threat_family", {})
    var positioning_memory: Dictionary = channels.get("positioning", {})
    var capture_memory: Dictionary = channels.get("capture", {})
    var relationship_memory: Dictionary = channels.get("relationship", {})

    var ranked: Array[Dictionary] = []
    var rejected: Array[Dictionary] = []
    var source_ids: Array[String] = []
    for index: int in range(owned_skills.size()):
        var value: Variant = owned_skills[index]
        if not (value is Dictionary):
            continue
        var skill: Dictionary = (value as Dictionary).duplicate(true)
        var skill_id := _skill_id(skill)
        if skill_id.is_empty():
            rejected.append({"reason": "missing_owned_skill_id", "index": index})
            continue
        if source_ids.has(skill_id):
            rejected.append({"reason": "duplicate_owned_skill_id", "skill_id": skill_id, "index": index})
            continue
        source_ids.append(skill_id)
        var usability := _body_usability(skill, body_functions)
        if not bool(usability.get("usable", true)):
            rejected.append({"reason": usability.get("reason", "body_requirement_failed"), "skill_id": skill_id, "index": index})
            continue

        var intent_family := str(skill.get("intent_family", ""))
        if intent_family.is_empty():
            var resolver_entity := str(skill.get("entity_id", species_id))
            var resolved := intent_resolver.resolve_skill_intent(resolver_entity, skill)
            if bool(resolved.get("ok", false)):
                intent_family = str(resolved.get("intent_family", ""))
        if intent_family.is_empty():
            rejected.append({"reason": "unresolved_intent_family", "skill_id": skill_id, "index": index})
            continue

        var base_score := 100.0 + float(skill.get("base_priority", skill.get("weight", 0.0)))
        var score := base_score
        var reasons: Array[String] = []
        var used_channels: Array[String] = []
        if bias > 0.0:
            var threat_value := str(threat_memory.get("value", ""))
            var responses: Array = THREAT_RESPONSES.get(threat_value, [])
            if not threat_value.is_empty() and intent_family in responses:
                score += bias
                reasons.append("lived_threat_response:%s" % threat_value)
                used_channels.append("threat_family")
            if not positioning_memory.is_empty() and intent_family in ["repositionnement", "defense", "chasse_embuscade"]:
                score += bias * 0.45
                reasons.append("lived_positioning_response")
                used_channels.append("positioning")
            if not capture_memory.is_empty() and intent_family in ["defense", "repositionnement", "controle"]:
                score += bias * 0.55
                reasons.append("lived_capture_response")
                used_channels.append("capture")

        ranked.append({
            "skill_id": skill_id,
            "source_index": index,
            "intent_family": intent_family,
            "score": score,
            "base_score": base_score,
            "memory_changed_score": not is_equal_approx(score, base_score),
            "used_memory_channels": _unique_strings(used_channels),
            "reasons": reasons,
            "skill": skill
        })

    ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_score := float(left.get("score", 0.0))
        var right_score := float(right.get("score", 0.0))
        if is_equal_approx(left_score, right_score):
            return int(left.get("source_index", 0)) < int(right.get("source_index", 0))
        return left_score > right_score
    )

    var baseline := _baseline_choice(owned_skills, body_functions, species_id)
    var selected: Dictionary = {} if ranked.is_empty() else ranked[0].duplicate(true)
    var selected_id := str(selected.get("skill_id", ""))
    var baseline_id := str(baseline.get("skill_id", ""))
    var changed_by_memory := not selected_id.is_empty() and not baseline_id.is_empty() and selected_id != baseline_id and bool(selected.get("memory_changed_score", false))
    var target_hint := ""
    if bias > 0.0 and not relationship_memory.is_empty():
        target_hint = str(relationship_memory.get("value", ""))

    return {
        "ok": not selected.is_empty(),
        "memory_rank": memory_rank,
        "owned_skill_count": source_ids.size(),
        "eligible_skill_count": ranked.size(),
        "ranked": ranked,
        "rejected": rejected,
        "selected": selected,
        "baseline_selected": baseline,
        "changed_by_memory": changed_by_memory,
        "target_hint_from_lived_relationship": target_hint,
        "ignored_context_keys": ignored_context_keys,
        "guardrails": {
            "selection_is_subset_of_owned_skills": true,
            "new_skill_creation_forbidden": true,
            "player_build_read": false,
            "memory_can_only_reorder_or_filter_declared_candidates": true
        }
    }

func _baseline_choice(owned_skills: Array, body_functions: Dictionary, species_id: String) -> Dictionary:
    var best: Dictionary = {}
    var best_score := -INF
    for index: int in range(owned_skills.size()):
        var value: Variant = owned_skills[index]
        if not (value is Dictionary):
            continue
        var skill: Dictionary = value
        var skill_id := _skill_id(skill)
        if skill_id.is_empty() or not bool(_body_usability(skill, body_functions).get("usable", true)):
            continue
        var intent_family := str(skill.get("intent_family", ""))
        if intent_family.is_empty():
            var resolved := intent_resolver.resolve_skill_intent(str(skill.get("entity_id", species_id)), skill)
            if not bool(resolved.get("ok", false)):
                continue
            intent_family = str(resolved.get("intent_family", ""))
        var score := 100.0 + float(skill.get("base_priority", skill.get("weight", 0.0)))
        if score > best_score:
            best_score = score
            best = {"skill_id": skill_id, "source_index": index, "intent_family": intent_family, "score": score}
    return best

func _body_usability(skill: Dictionary, body_functions: Dictionary) -> Dictionary:
    if bool(skill.get("disabled", false)) or not bool(skill.get("usable", true)):
        return {"usable": false, "reason": "skill_declared_unusable"}
    var required: Array = skill.get("required_body_functions", [])
    for function_value: Variant in required:
        var function_id := str(function_value)
        if body_functions.has(function_id) and not bool(body_functions.get(function_id, false)):
            return {"usable": false, "reason": "required_body_function_lost:%s" % function_id}
    var forbidden: Array = skill.get("forbidden_body_functions", [])
    for function_value: Variant in forbidden:
        var function_id := str(function_value)
        if bool(body_functions.get(function_id, false)):
            return {"usable": false, "reason": "forbidden_body_function_present:%s" % function_id}
    return {"usable": true}

func _skill_id(skill: Dictionary) -> String:
    for key: String in ["runtime_skill_id", "id", "source_skill_id", "ID"]:
        var value := str(skill.get(key, ""))
        if not value.is_empty():
            return value
    return ""

func _unique_strings(values: Array[String]) -> Array[String]:
    var result: Array[String] = []
    for value: String in values:
        if not result.has(value):
            result.append(value)
    return result
