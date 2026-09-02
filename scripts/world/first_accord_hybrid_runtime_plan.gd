extends RefCounted
class_name FirstAccordHybridRuntimePlan

const PLANNER := preload("res://scripts/world/first_accord_hybrid_planner.gd")

const ROLE_FALLBACKS := {
    "transit": "accord_guardroom_v1",
    "combat": "accord_guardroom_v1",
    "resource": "accord_memory_vault_v1",
    "narrative": "accord_memory_vault_v1",
    "hazard": "accord_collapsed_passage_v1",
    "choice": "accord_debate_chamber_v1",
    "elite": "accord_three_pillars_v1",
    "secret": "accord_sealed_archive_v1",
    "entry": "accord_entry_vestibule_v1",
    "boss": "accord_warden_sanctum_boss_v1"
}

static func build(run_state: Dictionary = {}) -> Dictionary:
    var plan := PLANNER.build_plan(run_state)
    if not bool(plan.get("ok", false)) or bool(plan.get("fallback", false)):
        return plan

    var unresolved: Array[String] = []
    for node in plan.get("nodes", []):
        if str(node.get("module_id", "")) != "":
            continue
        var role := str(node.get("role", "transit"))
        var fallback_id := str(ROLE_FALLBACKS.get(role, "accord_guardroom_v1"))
        node["module_id"] = fallback_id
        node["module_fallback"] = true
        unresolved.append(str(node.get("id", "")))

    plan["module_fallback_nodes"] = unresolved
    plan["production_warning"] = "temporary_role_fallback_modules" if not unresolved.is_empty() else ""
    plan["all_nodes_have_modules"] = _all_nodes_have_modules(plan.get("nodes", []))
    if not bool(plan["all_nodes_have_modules"]):
        return {
            "ok": true,
            "fallback": true,
            "fallback_reason": "unresolved_module_after_runtime_resolution",
            "fallback_authored_map": plan.get("fallback_authored_map", "")
        }
    return plan

static func _all_nodes_have_modules(nodes: Array) -> bool:
    for node in nodes:
        if str(node.get("module_id", "")) == "":
            return false
    return true
