extends Node

const COORDINATOR_SCRIPT := preload("res://scripts/core/veilleurs_runtime_coordinator.gd")

var previous_party: Array = []

func _ready() -> void:
    previous_party = GameState.party.duplicate(true)
    GameState.party = [
        {"id": "nayra_orun", "name": "Nayra Orun", "hp": 10, "max_hp": 10},
        {"id": "tarek_senn", "name": "Tarek Senn", "hp": 10, "max_hp": 10},
        {"id": "aisha_maren", "name": "Aïsha Maren", "hp": 10, "max_hp": 10},
        {"id": "idris_vael", "name": "Idris Vael", "hp": 10, "max_hp": 10}
    ]

    var coordinator := COORDINATOR_SCRIPT.new() as VeilleursRuntimeCoordinator
    add_child(coordinator)

    var enemy := {
        "id": "delie_affame",
        "species_id": "delie_affame",
        "name": "Délié Affamé",
        "hp": 18,
        "max_hp": 24,
        "persistent_injuries": [],
        "body_state": {}
    }
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, "vs001")
    RemanenceRuntime.note_encounter(enemy, "vs001", {"summary": "Combat smoke Les Veilleurs"})

    RemanenceRuntime.record_event(entity_id, "major_mutilation", {
        "object_id": "arm_right",
        "injury_state": "critical",
        "source_intent_family": "assaut",
        "hero_id": "nayra_orun"
    })
    var memorial := coordinator.enemy_memory_state(entity_id)
    assert(str(memorial.get("memory_rank", "")) == "memorial")
    assert(str((memorial.get("memory_channels", {}) as Dictionary).get("threat_family", {}).get("value", "")) == "assaut")
    assert(str((memorial.get("memory_channels", {}) as Dictionary).get("relationship", {}).get("value", "")) == "nayra_orun")

    var owned_skills: Array = [
        {
            "runtime_skill_id": "delie_affame:OWN-ATTACK",
            "intent_family": "assaut",
            "base_priority": 10.0,
            "effect": "Attaque directe"
        },
        {
            "runtime_skill_id": "delie_affame:OWN-GUARD",
            "intent_family": "defense",
            "base_priority": 5.0,
            "required_body_functions": ["arm_right"],
            "effect": "Garde avec le membre droit"
        },
        {
            "runtime_skill_id": "delie_affame:OWN-STEP",
            "intent_family": "repositionnement",
            "base_priority": 4.0,
            "effect": "Change d'axe"
        }
    ]
    var ranked := coordinator.rank_enemy_skill_choices(entity_id, owned_skills, {
        "body_functions": {"arm_right": true},
        "later_encounter": true,
        "player_build": {"forbidden_omniscient_data": true},
        "all_unlocked_player_skills": ["must_be_ignored"]
    })
    assert(bool(ranked.get("ok", false)))
    assert(str((ranked.get("baseline_selected", {}) as Dictionary).get("skill_id", "")) == "delie_affame:OWN-ATTACK")
    assert(str((ranked.get("selected", {}) as Dictionary).get("skill_id", "")) == "delie_affame:OWN-GUARD")
    assert(bool(ranked.get("changed_by_memory", false)))
    assert((ranked.get("ignored_context_keys", []) as Array).has("player_build"))
    assert((ranked.get("ignored_context_keys", []) as Array).has("all_unlocked_player_skills"))
    var selected_id := str((ranked.get("selected", {}) as Dictionary).get("skill_id", ""))
    assert(selected_id in ["delie_affame:OWN-ATTACK", "delie_affame:OWN-GUARD", "delie_affame:OWN-STEP"])

    var committed := coordinator.commit_enemy_skill_choice(entity_id, ranked, {"later_encounter": true})
    assert(bool(committed.get("ok", false)))
    assert(str(coordinator.enemy_memory_state(entity_id).get("memory_rank", "")) == "veteran")

    var injured_ranked := coordinator.rank_enemy_skill_choices(entity_id, owned_skills, {
        "body_functions": {"arm_right": false},
        "later_encounter": true,
        "player_build": {"still_ignored": true}
    })
    assert(bool(injured_ranked.get("ok", false)))
    assert(str((injured_ranked.get("selected", {}) as Dictionary).get("skill_id", "")) != "delie_affame:OWN-GUARD")
    var rejected_ids: Array[String] = []
    for rejected_value: Variant in injured_ranked.get("rejected", []):
        if rejected_value is Dictionary:
            rejected_ids.append(str((rejected_value as Dictionary).get("skill_id", "")))
    assert(rejected_ids.has("delie_affame:OWN-GUARD"))
    for ranked_value: Variant in injured_ranked.get("ranked", []):
        var ranked_skill: Dictionary = ranked_value
        assert(str(ranked_skill.get("skill_id", "")) in ["delie_affame:OWN-ATTACK", "delie_affame:OWN-GUARD", "delie_affame:OWN-STEP"])

    RemanenceRuntime.record_event(entity_id, "capture_escaped", {
        "capture_method": "capture_seal",
        "hero_id": "tarek_senn"
    })
    var after_capture := coordinator.enemy_memory_state(entity_id)
    assert(str((after_capture.get("memory_channels", {}) as Dictionary).get("capture", {}).get("value", "")) == "capture_seal")

    RemanenceRuntime.record_event(entity_id, "killed_watcher", {
        "hero_id": "tarek_senn",
        "intent_family": "assaut"
    })
    var after_kill := coordinator.enemy_memory_state(entity_id)
    assert(str((after_kill.get("memory_channels", {}) as Dictionary).get("relationship", {}).get("value", "")) == "tarek_senn")

    var escaped := coordinator.note_actual_enemy_escape(entity_id, {
        "entity_alive": true,
        "exit_axis": "north_cover",
        "cover_type": "stone_column",
        "pursuer": "nayra_orun",
        "last_player_intent_family": "controle",
        "direct_exchange": true
    })
    assert(bool(escaped.get("ok", false)))
    assert(str((coordinator.enemy_memory_state(entity_id).get("memory_channels", {}) as Dictionary).get("positioning", {}).get("value", "")) == "north_cover")

    RemanenceRuntime.record_event(entity_id, "forced_retreat", {
        "intent_family": "controle",
        "terrain_factor": "narrow_passage"
    })
    assert(not coordinator.enemy_memory_state(entity_id).is_empty())

    var item_event := coordinator.note_actual_important_item_event(entity_id, {
        "entity_alive": true,
        "shared_history": true,
        "direct_exchange": true,
        "item_id": "relic:smoke",
        "action": "recovered",
        "opposing_actor": "idris_vael",
        "location_anchor": "threshold_room"
    })
    assert(bool(item_event.get("ok", false)))

    var global_state: Dictionary = RemanenceRuntime.entity_state(entity_id)
    assert(not (global_state.get("veilleurs_memory_state", {}) as Dictionary).is_empty())
    assert(str(global_state.get("veilleurs_memory_rank", "")) == str(coordinator.enemy_memory_state(entity_id).get("memory_rank", "")))

    var serialized := coordinator.remanence_policy.serialize()
    coordinator.remanence_policy.reset()
    assert(coordinator.enemy_memory_state(entity_id).is_empty())
    coordinator.remanence_policy.deserialize(serialized)
    assert(not coordinator.enemy_memory_state(entity_id).is_empty())
    assert(str(coordinator.enemy_memory_state(entity_id).get("memory_rank", "")) == str(global_state.get("veilleurs_memory_rank", "")))

    GameState.party = previous_party
    print("VEILLEURS_COMBAT_MEMORY_AI_SMOKE_OK")
    get_tree().quit(0)
