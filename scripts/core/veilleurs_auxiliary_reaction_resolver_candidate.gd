extends RefCounted
class_name VeilleursAuxiliaryReactionResolverCandidate

const CONTRACT_PATH := "res://data/veilleurs/parallel_content/auxiliary_individual_reaction_contract_v1.json"
const RESPONSE_MODES := ["acknowledge", "question", "disagree", "refuse", "assist", "observe", "remain_silent"]

var contract: Dictionary = {}
var valid_dimensions: Array[String] = []

func _init() -> void:
    contract = _load_dictionary(CONTRACT_PATH)
    for value: Variant in contract.get("reaction_dimensions", []):
        if value is Dictionary:
            valid_dimensions.append(str((value as Dictionary).get("id", "")))

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    if bool(contract.get("enabled_by_default", true)):
        errors.append("contract_must_remain_inactive")
    if valid_dimensions.size() != 9:
        errors.append("reaction_dimensions:%d" % valid_dimensions.size())
    return {"ok": errors.is_empty(), "errors": errors, "dimension_count": valid_dimensions.size()}

func resolve(auxiliary: Dictionary, event_context: Dictionary, memory_context: Dictionary = {}) -> Dictionary:
    var entity_id := str(auxiliary.get("entity_id", ""))
    if entity_id.is_empty():
        return {"eligible": false, "reason": "stable_entity_id_required"}
    if not auxiliary.has("identity_seed"):
        return {"eligible": false, "reason": "identity_seed_required", "entity_id": entity_id}

    var direct_participation := _entity_flag(entity_id, event_context, "direct_participation", "direct_participants")
    var direct_observation := _entity_flag(entity_id, event_context, "direct_observation", "direct_observers")
    var shared_history := _entity_flag(entity_id, event_context, "shared_history", "shared_history_entities") or _has_shared_history(auxiliary, memory_context)
    var materially_affected := _entity_flag(entity_id, event_context, "materially_affected", "materially_affected_entities")
    if not (direct_participation or direct_observation or shared_history or materially_affected):
        return {"eligible": false, "reason": "individual_evidence_required", "entity_id": entity_id}

    var evidence_refs: Array[String] = []
    for value: Variant in event_context.get("evidence_refs", []):
        var ref := str(value)
        if not ref.is_empty() and not ref in evidence_refs:
            evidence_refs.append(ref)
    for value: Variant in memory_context.get("history_refs", []):
        var ref := str(value)
        if not ref.is_empty() and not ref in evidence_refs:
            evidence_refs.append(ref)

    var requested_dimensions: Array[String] = []
    for value: Variant in event_context.get("reaction_dimensions", []):
        var dimension := str(value)
        if dimension in valid_dimensions and not dimension in requested_dimensions:
            requested_dimensions.append(dimension)
    if requested_dimensions.is_empty():
        requested_dimensions = _infer_dimensions(auxiliary, event_context)

    var response_mode := str(event_context.get("preferred_response_mode", "observe"))
    if not response_mode in RESPONSE_MODES:
        response_mode = "observe"
    if bool(event_context.get("consent_required", false)) and not bool((auxiliary.get("consent_flags", {}) as Dictionary).get(str(event_context.get("consent_key", "social_reaction")), false)):
        response_mode = "remain_silent"

    return {
        "eligible": true,
        "entity_id": entity_id,
        "identity_seed": int(auxiliary.get("identity_seed", 0)),
        "species_id": str(auxiliary.get("species_id", "")),
        "evidence_refs": evidence_refs,
        "reaction_dimensions": requested_dimensions,
        "allowed_response_mode": response_mode,
        "archive_write_candidate": (event_context.get("archive_write_candidate", {}) as Dictionary).duplicate(true),
        "relationship_write_candidate": (event_context.get("relationship_write_candidate", {}) as Dictionary).duplicate(true),
        "canonical_dialogue_key": str(event_context.get("canonical_dialogue_key", "")),
        "species_personality_used": false,
        "generated_dialogue": false,
        "direct_participation": direct_participation,
        "direct_observation": direct_observation,
        "shared_history": shared_history,
        "materially_affected": materially_affected,
        "score": _score(entity_id, event_context, memory_context, direct_participation, direct_observation, shared_history, materially_affected)
    }

func rank_candidates(auxiliaries: Array[Dictionary], event_context: Dictionary, memory_contexts: Dictionary = {}, limit: int = -1) -> Array[Dictionary]:
    var resolved: Array[Dictionary] = []
    for auxiliary: Dictionary in auxiliaries:
        var entity_id := str(auxiliary.get("entity_id", ""))
        var memory_context: Dictionary = (memory_contexts.get(entity_id, {}) as Dictionary).duplicate(true)
        var result := resolve(auxiliary, event_context, memory_context)
        if bool(result.get("eligible", false)):
            resolved.append(result)
    resolved.sort_custom(Callable(self, "_candidate_before"))
    var effective_limit := resolved.size() if limit <= 0 else mini(limit, resolved.size())
    var output: Array[Dictionary] = []
    for index: int in range(effective_limit):
        output.append(resolved[index].duplicate(true))
    return output

func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
    var a_score := int(a.get("score", 0))
    var b_score := int(b.get("score", 0))
    if a_score != b_score:
        return a_score > b_score
    return str(a.get("entity_id", "")) < str(b.get("entity_id", ""))

func _score(entity_id: String, event_context: Dictionary, memory_context: Dictionary, direct_participation: bool, direct_observation: bool, shared_history: bool, materially_affected: bool) -> int:
    var score := 0
    if materially_affected:
        score += 4000
    if direct_participation:
        score += 3000
    if direct_observation:
        score += 2000
    if shared_history:
        score += 1000
    score += mini(99, int(memory_context.get("shared_history_strength", 0)))
    var recency_by_entity: Dictionary = event_context.get("recency_by_entity", {})
    score += mini(99, int(recency_by_entity.get(entity_id, event_context.get("recency", 0))))
    return score

func _entity_flag(entity_id: String, context: Dictionary, legacy_bool_key: String, entity_list_key: String) -> bool:
    for value: Variant in context.get(entity_list_key, []):
        if str(value) == entity_id:
            return true
    return bool(context.get(legacy_bool_key, false)) and bool(context.get("legacy_boolean_applies_to_all_candidates", false))

func _has_shared_history(auxiliary: Dictionary, memory_context: Dictionary) -> bool:
    if bool(memory_context.get("shared_history", false)):
        return true
    var entity_id := str(auxiliary.get("entity_id", ""))
    for value: Variant in memory_context.get("participants", []):
        if str(value) == entity_id:
            return true
    return false

func _infer_dimensions(auxiliary: Dictionary, event_context: Dictionary) -> Array[String]:
    var dimensions: Array[String] = []
    var requested_family := str(event_context.get("family", ""))
    if not (auxiliary.get("persistent_injuries", []) as Array).is_empty() and requested_family in ["BESOIN_BIOLOGIQUE", "TRANSFORMATION", "TRAVAIL", "CRISE"]:
        dimensions.append("body")
    if not (auxiliary.get("capture_history", []) as Array).is_empty() and requested_family in ["CONFLIT", "DEPART", "POLITIQUE"]:
        dimensions.append("capture_rallying")
    if not (auxiliary.get("work_history", []) as Array).is_empty() and requested_family in ["TRAVAIL", "COHABITATION"]:
        dimensions.append("work")
    if not (auxiliary.get("remanence_history", []) as Array).is_empty() and requested_family in ["TRANSFORMATION", "CRISE", "SOUVENIR"]:
        dimensions.append("remanence")
    if not (auxiliary.get("relationship_history", []) as Array).is_empty():
        dimensions.append("trust")
    if dimensions.is_empty():
        dimensions.append("responsibility")
    return dimensions

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
