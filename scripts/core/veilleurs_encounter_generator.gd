extends RefCounted

const TEMPLATES_PATH := "res://data/veilleurs/encounter_templates_64.json"
const DEPTH_RULES_PATH := "res://data/veilleurs/encounter_depth_rules.json"
const VARIANTS_PATH := "res://data/veilleurs/enemy_variant_rules.json"

var templates: Array = []
var depth_rules: Array = []
var variant_data: Dictionary = {}
var recent_template_ids: Array[String] = []

func _init() -> void:
    _load_data()

func reset_history() -> void:
    recent_template_ids.clear()

func template_count() -> int:
    return templates.size()

func depth_rule(act_id: String, depth: int) -> Dictionary:
    for value: Variant in depth_rules:
        if not (value is Dictionary):
            continue
        var rule: Dictionary = value
        if str(rule.get("act_id", "")) == act_id and int(rule.get("depth", 0)) == depth:
            return rule.duplicate(true)
    return {}

func validate_template(template: Dictionary, act_id: String, depth: int) -> Dictionary:
    var rule := depth_rule(act_id, depth)
    if rule.is_empty():
        return {"valid": false, "reason": "depth_rule_missing"}
    if str(template.get("act_id", "")) != act_id:
        return {"valid": false, "reason": "wrong_act"}
    if depth < int(template.get("depth_min", 1)) or depth > int(template.get("depth_max", 5)):
        return {"valid": false, "reason": "wrong_depth"}
    var max_actors := int(rule.get("max_standard_actors", 4))
    if int(template.get("actor_count", 0)) > max_actors:
        return {"valid": false, "reason": "actor_cap", "max_actors": max_actors}
    var budget := int(rule.get("threat_budget", 0))
    var threat := int(template.get("threat", 0))
    if threat > budget and not bool(template.get("scripted", false)):
        return {"valid": false, "reason": "over_budget", "budget": budget, "threat": threat}
    return {
        "valid": true,
        "reason": "scripted_exception" if threat > budget else "within_budget",
        "budget": budget,
        "threat": threat,
        "actor_count": int(template.get("actor_count", 0))
    }

func eligible_templates(act_id: String, depth: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in templates:
        if not (value is Dictionary):
            continue
        var template: Dictionary = value
        if bool(validate_template(template, act_id, depth).get("valid", false)):
            result.append(template.duplicate(true))
    result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return str(left.get("template_id", "")) < str(right.get("template_id", ""))
    )
    return result

func generate(act_id: String, depth: int, seed: int, memory_candidates: Array = []) -> Dictionary:
    var candidates := eligible_templates(act_id, depth)
    if candidates.is_empty():
        return {"ok": false, "reason": "no_valid_template", "act_id": act_id, "depth": depth}
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var weighted_candidates: Array[Dictionary] = []
    var weights: Array[int] = []
    for template: Dictionary in candidates:
        var template_id := str(template.get("template_id", ""))
        var weight := anti_repetition_weight(template_id)
        if weight <= 0:
            continue
        weighted_candidates.append(template)
        weights.append(weight)
    if weighted_candidates.is_empty():
        return {"ok": false, "reason": "anti_repeat_exhausted"}
    var selected := _weighted_template(weighted_candidates, weights, rng)
    if selected.is_empty():
        return {"ok": false, "reason": "selection_failed"}

    var rule := depth_rule(act_id, depth)
    var actors: Array[Dictionary] = []
    var actor_index := 0
    for species_value: Variant in selected.get("species", []):
        var species := str(species_value)
        var tier := _choose_variant_tier((rule.get("variant_weights", {}) as Dictionary), rng)
        var actor := variant_profile(species, tier)
        actor["actor_id"] = "%s:%d" % [str(selected.get("template_id", "encounter")), actor_index]
        actor["species"] = species
        actors.append(actor)
        actor_index += 1

    var memory_result := inject_memory(actors, memory_candidates)
    actors = memory_result.get("actors", actors)
    _register_template(str(selected.get("template_id", "")))
    return {
        "ok": true,
        "template": selected.duplicate(true),
        "template_id": str(selected.get("template_id", "")),
        "act_id": act_id,
        "depth": depth,
        "threat_budget": int(rule.get("threat_budget", 0)),
        "threat": int(selected.get("threat", 0)),
        "actors": actors,
        "actor_count": actors.size(),
        "memory_injected": int(memory_result.get("injected", 0)),
        "nemesis_injected": int(memory_result.get("nemesis_injected", 0)),
        "recent_template_ids": recent_template_ids.duplicate()
    }

func anti_repetition_weight(template_id: String) -> int:
    if template_id == "":
        return 0
    if not recent_template_ids.is_empty() and recent_template_ids[-1] == template_id:
        return 0
    var seen := 0
    for value: String in recent_template_ids:
        if value == template_id:
            seen += 1
    return 40 if seen >= 2 else 100

func inject_memory(actors: Array, candidates: Array) -> Dictionary:
    var output: Array = actors.duplicate(true)
    var ranked: Array[Dictionary] = []
    for value: Variant in candidates:
        if value is Dictionary:
            ranked.append((value as Dictionary).duplicate(true))
    ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_priority := _stage_rank(str(left.get("stage", "normal"))) * 1000 + int(left.get("score", 0))
        var right_priority := _stage_rank(str(right.get("stage", "normal"))) * 1000 + int(right.get("score", 0))
        return left_priority > right_priority
    )

    for candidate: Dictionary in ranked:
        if str(candidate.get("status", "active")) != "active":
            continue
        var stage := str(candidate.get("stage", "normal"))
        if stage == "normal":
            continue
        if stage == "nemesis" and not _has_shared_history(candidate):
            continue
        var species := str(candidate.get("species", candidate.get("species_id", "")))
        for index in range(output.size()):
            if not (output[index] is Dictionary):
                continue
            var actor: Dictionary = output[index]
            if str(actor.get("species", "")) != species:
                continue
            actor["memory_entity_id"] = str(candidate.get("id", ""))
            actor["memory_stage"] = stage
            actor["memory_score"] = int(candidate.get("score", 0))
            actor["memorial_injected"] = stage != "nemesis"
            actor["nemesis_injected"] = stage == "nemesis"
            output[index] = actor
            return {
                "actors": output,
                "injected": 1,
                "nemesis_injected": 1 if stage == "nemesis" else 0,
                "entity_id": str(candidate.get("id", ""))
            }
    return {"actors": output, "injected": 0, "nemesis_injected": 0}

func variant_profile(species: String, tier: String) -> Dictionary:
    var tier_profiles: Dictionary = variant_data.get("tier_profiles", {})
    var profile: Dictionary = (tier_profiles.get(tier, tier_profiles.get("N1", {})) as Dictionary).duplicate(true)
    var species_rule := _species_variant_rule(species)
    var base_rig_id := str(species_rule.get("base_rig_id", "rig_%s" % species.to_snake_case()))
    var family_scene_id := str(species_rule.get("family_scene_id", "family_scene_%s" % species.to_snake_case()))
    profile["variant_tier"] = tier if tier_profiles.has(tier) else "N1"
    profile["base_rig_id"] = base_rig_id
    profile["family_scene_id"] = family_scene_id
    profile["scene_specific"] = false
    profile["shared_base_rig"] = true
    profile["specialized_profile"] = profile["variant_tier"] in ["N20", "N40"]
    profile["intent_contract"] = "bounded_mobile"
    return profile

func _load_data() -> void:
    var template_payload := _load_json(TEMPLATES_PATH)
    templates = template_payload.get("templates", [])
    var depth_payload := _load_json(DEPTH_RULES_PATH)
    depth_rules = depth_payload.get("depth_rules", [])
    variant_data = _load_json(VARIANTS_PATH)

func _load_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _weighted_template(candidates: Array[Dictionary], weights: Array[int], rng: RandomNumberGenerator) -> Dictionary:
    var total := 0
    for weight: int in weights:
        total += maxi(0, weight)
    if total <= 0:
        return {}
    var roll := rng.randi_range(1, total)
    var running := 0
    for index in range(candidates.size()):
        running += maxi(0, weights[index])
        if roll <= running:
            return candidates[index].duplicate(true)
    return candidates[-1].duplicate(true)

func _choose_variant_tier(weights: Dictionary, rng: RandomNumberGenerator) -> String:
    var n1 := maxi(0, int(weights.get("N1", 100)))
    var n20 := maxi(0, int(weights.get("N20", 0)))
    var n40 := maxi(0, int(weights.get("N40", 0)))
    var total := n1 + n20 + n40
    if total <= 0:
        return "N1"
    var roll := rng.randi_range(1, total)
    if roll <= n1:
        return "N1"
    if roll <= n1 + n20:
        return "N20"
    return "N40"

func _species_variant_rule(species: String) -> Dictionary:
    for value: Variant in variant_data.get("species", []):
        if value is Dictionary and str((value as Dictionary).get("species", "")) == species:
            return (value as Dictionary).duplicate(true)
    return {}

func _register_template(template_id: String) -> void:
    if template_id == "":
        return
    recent_template_ids.append(template_id)
    while recent_template_ids.size() > 5:
        recent_template_ids.pop_front()

func _has_shared_history(candidate: Dictionary) -> bool:
    if bool(candidate.get("shared_history", false)) or int(candidate.get("history_events", 0)) > 0:
        return true
    var entity_id := str(candidate.get("id", ""))
    if entity_id != "" and RemanenceRuntime.entities.has(entity_id):
        return not RemanenceRuntime.recent_events(entity_id, 1).is_empty()
    return false

func _stage_rank(stage: String) -> int:
    return int({"normal": 0, "memorial": 1, "veteran": 2, "elite": 3, "nemesis": 4}.get(stage, 0))
