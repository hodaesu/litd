extends Node

const SKILL_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_enemy_skill_runtime.gd")

func _ready() -> void:
    var runtime := SKILL_RUNTIME_SCRIPT.new() as VeilleursEnemySkillRuntime
    var report := runtime.validation_report()
    assert(bool(report.get("ok", false)))
    assert(int(report.get("entities", 0)) == 29)
    assert(int(report.get("trees", 0)) == 87)
    assert(int(report.get("skills", 0)) == 1305)
    assert(int(report.get("runtime_id_collisions", -1)) == 0)
    assert(str(report.get("decision_source", "")) == "canonical_prepc_pack_exact_cache")
    var exact_report: Dictionary = report.get("exact_catalog", {})
    assert(bool(exact_report.get("ok", false)))
    assert(int(exact_report.get("records", 0)) == 1305)
    assert(int(exact_report.get("entities", 0)) == 29)

    var entity_count := 0
    var all_runtime_ids: Dictionary = {}
    for entity_id_value: Variant in runtime.trees_by_entity.keys():
        var entity_id := str(entity_id_value)
        entity_count += 1
        var skills := runtime.skills_for_entity(entity_id)
        assert(skills.size() == 45)
        var tree_counts: Dictionary = {}
        for skill_value: Variant in skills:
            assert(skill_value is Dictionary)
            var skill: Dictionary = skill_value
            var runtime_id := str(skill.get("runtime_skill_id", ""))
            assert(not runtime_id.is_empty())
            assert(runtime_id.begins_with("%s:" % entity_id))
            assert(not all_runtime_ids.has(runtime_id))
            all_runtime_ids[runtime_id] = true
            var tree := str(skill.get("tree", ""))
            tree_counts[tree] = int(tree_counts.get(tree, 0)) + 1
        assert(tree_counts.size() == 3)
        for tree_value: Variant in tree_counts.keys():
            assert(int(tree_counts[tree_value]) == 15)
    assert(entity_count == 29)
    assert(all_runtime_ids.size() == 1305)

    var delie_skills := runtime.skills_for_entity("delie_affame")
    assert(delie_skills.size() == 45)
    var delie_tree_counts: Dictionary = {}
    for skill: Dictionary in delie_skills:
        var tree := str(skill.get("tree", ""))
        delie_tree_counts[tree] = int(delie_tree_counts.get(tree, 0)) + 1
    assert(delie_tree_counts.size() == 3)
    assert(int(delie_tree_counts.get("Chair ouverte", 0)) == 15)
    assert(int(delie_tree_counts.get("Faim basse", 0)) == 15)
    assert(int(delie_tree_counts.get("Fuite des cendres", 0)) == 15)

    var enemy := {
        "species_id": "delie_affame",
        "name": "Délié Affamé",
        "hp": 18,
        "max_hp": 24,
        "identity_seed": 74031,
        "seed": 74031
    }
    runtime.prepare_enemy(enemy, 74031)
    assert(str(enemy.get("veilleurs_entity_id", "")) == "delie_affame")
    assert(int(enemy.get("veilleurs_canonical_skill_count", 0)) == 45)
    var active_tree := str(enemy.get("veilleurs_active_tree", ""))
    assert(active_tree in ["Chair ouverte", "Faim basse", "Fuite des cendres"])

    var heroes: Array = [
        {"id": "nayra_orun", "hp": 20, "max_hp": 20},
        {"id": "tarek_senn", "hp": 9, "max_hp": 20}
    ]
    var full_context := {
        "seed": 74031,
        "turn_index": 2,
        "actor_rank": 1,
        "reaction_window": true,
        "environment_interaction_available": true,
        "posture_window": true,
        "synergy_active": true,
        "major_action_window": true,
        "transformation_window": true
    }
    var action := runtime.choose_action(enemy, heroes, full_context)
    _assert_canonical_action(action, all_runtime_ids, active_tree)

    # Production path: the autoload used by live combat must resolve the same exact catalog,
    # and must never fall through to the generic archetype attack for a recognized Veilleurs entity.
    var production_enemy := enemy.duplicate(true)
    EnemyCombatDirector.prepare_veilleurs_enemy(production_enemy, 74031)
    var production_action := EnemyCombatDirector.choose_action(production_enemy, heroes, full_context)
    _assert_canonical_action(production_action, all_runtime_ids, str(production_enemy.get("veilleurs_active_tree", "")))
    assert(str(production_action.get("id", "")) != "basic_attack")

    # Also exercise the normal combat context where only Active skills are immediately eligible.
    var active_only_action := EnemyCombatDirector.choose_action(production_enemy, heroes, {
        "seed": 74031,
        "turn_index": 3,
        "actor_rank": 1
    })
    _assert_canonical_action(active_only_action, all_runtime_ids, str(production_enemy.get("veilleurs_active_tree", "")))
    assert(str(active_only_action.get("skill_type", "")) == "Active")

    print("VEILLEURS_CANONICAL_SKILL_CATALOG_SMOKE_OK")
    get_tree().quit(0)

func _assert_canonical_action(action: Dictionary, all_runtime_ids: Dictionary, active_tree: String) -> void:
    assert(not action.is_empty())
    assert(not bool(action.get("blocked", false)))
    assert(bool(action.get("veilleurs_skill", false)))
    assert(str(action.get("canonical_skill_source", "")) == "prepc_pack_exact_cache")
    var chosen_id := str(action.get("runtime_skill_id", ""))
    assert(all_runtime_ids.has(chosen_id))
    assert(chosen_id.begins_with("delie_affame:"))
    assert(str(action.get("tree", "")) == active_tree)
    assert(bool(action.get("generic_damage_fallback_forbidden", false)))
    assert(not bool(action.get("party_counterpick_used", true)))
