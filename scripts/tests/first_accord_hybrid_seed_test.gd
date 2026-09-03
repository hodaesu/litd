extends SceneTree

const RUNTIME_PLAN := preload("res://scripts/world/first_accord_hybrid_runtime_plan.gd")

const CAMPAIGN_SEEDS := [1, 7, 42, 1337, 9001, 17011, 65537, 123456789]
const VISIT_INDICES := [0, 1, 2, 5, 12]
const DIFFICULTY_BANDS := ["normal", "hard"]

func _init() -> void:
    var failures: Array[String] = []
    var signatures := {}
    var tested := 0

    for campaign_seed in CAMPAIGN_SEEDS:
        for visit_index in VISIT_INDICES:
            for difficulty_band in DIFFICULTY_BANDS:
                var state := {
                    "campaign_seed": campaign_seed,
                    "visit_index": visit_index,
                    "difficulty_band": difficulty_band,
                    "story_epoch": 0
                }
                var first := RUNTIME_PLAN.build(state)
                var second := RUNTIME_PLAN.build(state)
                tested += 1

                if not bool(first.get("ok", false)):
                    failures.append("plan_not_ok:%s" % str(state))
                    continue
                if bool(first.get("fallback", false)):
                    failures.append("unexpected_fallback:%s:%s" % [str(state), str(first.get("fallback_reason", ""))])
                    continue
                if not bool(first.get("all_nodes_have_modules", false)):
                    failures.append("unresolved_modules:%s" % str(state))

                var validation: Dictionary = first.get("validation", {})
                if not bool(validation.get("ok", false)):
                    failures.append("validation_failed:%s:%s" % [str(state), str(validation.get("errors", []))])

                var sig_a := _signature(first)
                var sig_b := _signature(second)
                if sig_a != sig_b:
                    failures.append("non_deterministic:%s" % str(state))

                signatures[sig_a] = true

    if signatures.size() < 4:
        failures.append("insufficient_layout_variety:%d" % signatures.size())

    if failures.is_empty():
        print("FIRST_ACCORD_HYBRID_SEEDS_OK tested=%d unique=%d" % [tested, signatures.size()])
        quit(0)
        return

    for failure in failures:
        push_error(failure)
    print("FIRST_ACCORD_HYBRID_SEEDS_FAILED tested=%d failures=%d unique=%d" % [tested, failures.size(), signatures.size()])
    quit(1)

func _signature(plan: Dictionary) -> String:
    var parts: Array[String] = []
    for node in plan.get("nodes", []):
        parts.append("%s:%s:%s:%s" % [
            str(node.get("id", "")),
            str(node.get("module_id", "")),
            str(node.get("role", "")),
            str(node.get("variation_seed", 0))
        ])
    for edge in plan.get("edges", []):
        parts.append("%s>%s:%s" % [str(edge.get("from", "")), str(edge.get("to", "")), str(edge.get("kind", ""))])
    parts.sort()
    return "|".join(parts)
