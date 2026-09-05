extends Node

const CONTRACT_PATH := "res://data/veilleurs/skills/resolver_contract.json"
const OVERRIDES_PATH := "res://data/veilleurs/skills/canonical_overrides.json"
const CLINICAL_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_clinical_combat_runtime.gd")
const HEMOCORDE_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_hemocorde_runtime.gd")

var contract: Dictionary = {}
var overrides: Dictionary = {}
var load_errors: Array[String] = []
var clinical_runtime: Node = null
var hemocorde_runtime: Node = null

func _ready() -> void:
    clinical_runtime = CLINICAL_RUNTIME_SCRIPT.new()
    clinical_runtime.name = "ClinicalRuntime"
    add_child(clinical_runtime)
    hemocorde_runtime = HEMOCORDE_RUNTIME_SCRIPT.new()
    hemocorde_runtime.name = "HemocordeRuntime"
    add_child(hemocorde_runtime)
    reload()

func reload() -> void:
    load_errors.clear()
    contract = _load_dictionary(CONTRACT_PATH)
    overrides = _load_dictionary(OVERRIDES_PATH)
    if contract.is_empty():
        load_errors.append("resolver_contract_missing")
    if overrides.is_empty():
        load_errors.append("canonical_overrides_missing")

func normalize_node(node: Dictionary) -> Dictionary:
    var result := node.duplicate(true)
    var skill_id := str(result.get("id", ""))
    var tags: Array = (result.get("canonical_tags", []) as Array).duplicate()
    for index in range(tags.size()):
        if str(tags[index]) == "MEMRE_BLESSÉ":
            tags[index] = "MEMBRE_BLESSÉ"
    var skill_overrides: Dictionary = overrides.get("skill_overrides", {})
    if skill_overrides.has(skill_id):
        var override: Dictionary = skill_overrides[skill_id]
        if override.has("Tags"):
            tags.clear()
            for part: String in str(override.get("Tags", "")).split(";", false):
                var clean := part.strip_edges()
                if clean != "" and not tags.has(clean):
                    tags.append(clean)
    result["canonical_tags"] = tags
    var resolver := contract_for(result)
    result["resolver_id"] = str(resolver.get("resolver_id", ""))
    result["resolver_status"] = str(resolver.get("status", "required"))
    result["activation_mode"] = str(resolver.get("activation_mode", activation_mode_for(result)))
    result["runtime_entrypoint"] = str(resolver.get("entrypoint", ""))
    result["resolver_coverage"] = (resolver.get("coverage", {}) as Dictionary).duplicate(true)
    return result

func contract_for(node: Dictionary) -> Dictionary:
    var skill_id := str(node.get("id", ""))
    var skill_overrides: Dictionary = contract.get("skill_overrides", {})
    if skill_overrides.has(skill_id):
        return (skill_overrides[skill_id] as Dictionary).duplicate(true)
    var branch := str(node.get("branch_name", node.get("branch", "")))
    var families: Dictionary = contract.get("tree_families", {})
    if families.has(branch):
        var result: Dictionary = (families[branch] as Dictionary).duplicate(true)
        result["activation_mode"] = activation_mode_for(node)
        return result
    return {"resolver_id":"unknown","status":"required","activation_mode":activation_mode_for(node)}

func activation_mode_for(node: Dictionary) -> String:
    var by_type: Dictionary = contract.get("activation_by_type", {})
    return str(by_type.get(str(node.get("canonical_type", "")), "action"))

func can_manual_equip(node: Dictionary) -> bool:
    var normalized := normalize_node(node)
    if str(normalized.get("resolver_status", "")) not in ["implemented", "prototype_bridge"]:
        return false
    return str(normalized.get("activation_mode", "")) in ["action", "mastery_action", "posture_state"]

func can_execute_context(node: Dictionary) -> bool:
    var normalized := normalize_node(node)
    return str(normalized.get("resolver_status", "")) == "implemented" and str(normalized.get("activation_mode", "")) == "context_action"

func combat_profile(hero: Dictionary, node: Dictionary) -> Dictionary:
    if node.is_empty():
        return {}
    var normalized := normalize_node(node)
    var result := {
        "id": str(normalized.get("id", "")),
        "name": str(normalized.get("name", "Technique")),
        "description": str(normalized.get("description", "")),
        "branch": str(normalized.get("branch", "")),
        "branch_name": str(normalized.get("branch_name", "")),
        "canonical_type": str(normalized.get("canonical_type", "")),
        "canonical_function": str(normalized.get("canonical_function", "")),
        "canonical_positions": str(normalized.get("canonical_positions", "")),
        "canonical_target": str(normalized.get("canonical_target", "")),
        "canonical_impacts": str(normalized.get("canonical_impacts", "")),
        "canonical_tags": (normalized.get("canonical_tags", []) as Array).duplicate(),
        "canonical_conditions": str(normalized.get("canonical_conditions", "")),
        "base_accuracy_pct": int(normalized.get("base_accuracy_pct", 100)),
        "power_0_5": float(normalized.get("power_0_5", 0.0)),
        "resolver_id": str(normalized.get("resolver_id", "")),
        "resolver_status": str(normalized.get("resolver_status", "required")),
        "resolver_coverage": (normalized.get("resolver_coverage", {}) as Dictionary).duplicate(true),
        "activation_mode": str(normalized.get("activation_mode", "action")),
        "runtime_entrypoint": str(normalized.get("runtime_entrypoint", "")),
        "manual_combat_usable": can_manual_equip(normalized)
    }
    if not bool(result.get("manual_combat_usable", false)):
        result["effect"] = "resolver_required"
        result["target"] = "none"
        return result

    var runtime := _runtime_for(result)
    if runtime != null and runtime.has_method("profile_for"):
        var runtime_profile: Dictionary = runtime.call("profile_for", hero, result)
        for key_value: Variant in runtime_profile.keys():
            result[str(key_value)] = runtime_profile.get(key_value)
        return result

    result["effect"] = "resolver_required"
    result["target"] = "none"
    result["manual_combat_usable"] = false
    return result

func resolve_combat(hero: Dictionary, target: Dictionary, skill: Dictionary, damage: int = 0, party: Array = []) -> Dictionary:
    var runtime := _runtime_for(skill)
    if runtime == null or not runtime.has_method("resolve"):
        return {"ok": false, "reason": "specialized_runtime_unavailable", "skill_id": str(skill.get("id", ""))}
    return runtime.call("resolve", hero, target, skill, damage, party)

func select_medical_target(party: Array) -> Dictionary:
    var runtime := _clinical_runtime()
    if runtime == null or not runtime.has_method("select_medical_target"):
        return {}
    return runtime.call("select_medical_target", party)

func refresh_specialized_passives(party: Array, enemies: Array) -> void:
    var runtime := _hemocorde_runtime()
    if runtime == null or not runtime.has_method("refresh_passive_state"):
        return
    for hero_value: Variant in party:
        if hero_value is Dictionary and str((hero_value as Dictionary).get("id", "")) == "aisha_maren":
            runtime.call("refresh_passive_state", hero_value, enemies)
            break

func advance_specialized_round_states(party: Array) -> void:
    var runtime := _hemocorde_runtime()
    if runtime == null or not runtime.has_method("advance_round_state"):
        return
    for hero_value: Variant in party:
        if hero_value is Dictionary and str((hero_value as Dictionary).get("id", "")) == "aisha_maren":
            runtime.call("advance_round_state", hero_value)
            break

func ultimate_contract(hero: Dictionary, branch: String) -> Dictionary:
    var ultimate := VeilleursSkillCatalog.ultimate_for(hero, branch)
    if ultimate.is_empty():
        return {}
    var family: Dictionary = (contract.get("ultimate_family", {}) as Dictionary).duplicate(true)
    family["ultimate"] = ultimate
    family["resolver_id"] = str(family.get("resolver_id", "ultimate_sequence"))
    family["status"] = str(family.get("status", "required"))
    return family

func summary() -> Dictionary:
    return {
        "tree_families": (contract.get("tree_families", {}) as Dictionary).size(),
        "skill_overrides": (contract.get("skill_overrides", {}) as Dictionary).size(),
        "clinical_runtime": clinical_runtime != null,
        "hemocorde_runtime": hemocorde_runtime != null,
        "load_errors": load_errors.duplicate()
    }

func _runtime_for(skill: Dictionary) -> Node:
    var clinical := _clinical_runtime()
    if clinical != null and clinical.has_method("handles") and bool(clinical.call("handles", skill)):
        return clinical
    var hemocorde := _hemocorde_runtime()
    if hemocorde != null and hemocorde.has_method("handles") and bool(hemocorde.call("handles", skill)):
        return hemocorde
    return null

func _clinical_runtime() -> Node:
    if clinical_runtime == null:
        clinical_runtime = get_node_or_null("ClinicalRuntime")
    return clinical_runtime

func _hemocorde_runtime() -> Node:
    if hemocorde_runtime == null:
        hemocorde_runtime = get_node_or_null("HemocordeRuntime")
    return hemocorde_runtime

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
