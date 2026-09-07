extends Node

const RESOLVER_SCRIPT := preload("res://scripts/core/veilleurs_auxiliary_reaction_resolver_candidate.gd")

func _ready() -> void:
    var resolver := RESOLVER_SCRIPT.new() as VeilleursAuxiliaryReactionResolverCandidate
    var report := resolver.validation_report()
    assert(bool(report.get("ok", false)))
    assert(int(report.get("dimension_count", 0)) == 9)

    var aux_a := {
        "entity_id": "aux:delie_affame:101",
        "identity_seed": 101,
        "species_id": "delie_affame",
        "persistent_injuries": [{"zone":"arm_left","state":"wounded"}],
        "capture_history": [{"event":"failed_capture"}],
        "work_history": [{"event":"shared_repair"}],
        "relationship_history": [{"event":"boundary_negotiated"}],
        "remanence_history": [],
        "consent_flags": {"social_reaction": true}
    }
    var aux_b := {
        "entity_id": "aux:delie_affame:202",
        "identity_seed": 202,
        "species_id": "delie_affame",
        "persistent_injuries": [],
        "capture_history": [],
        "work_history": [],
        "relationship_history": [],
        "remanence_history": [],
        "consent_flags": {"social_reaction": true}
    }

    var no_evidence := resolver.resolve(aux_b, {"family":"CONFLIT"}, {})
    assert(not bool(no_evidence.get("eligible", true)))

    var event_context := {
        "family": "CONFLIT",
        "direct_participants": ["aux:delie_affame:101"],
        "direct_observers": [],
        "materially_affected_entities": ["aux:delie_affame:101"],
        "shared_history_entities": [],
        "reaction_dimensions": ["capture_rallying", "trust", "responsibility"],
        "evidence_refs": ["refuge:recruit_friction:1"],
        "preferred_response_mode": "disagree",
        "recency_by_entity": {"aux:delie_affame:101": 8, "aux:delie_affame:202": 2}
    }
    var resolved_a := resolver.resolve(aux_a, event_context, {})
    var resolved_b := resolver.resolve(aux_b, event_context, {})
    assert(bool(resolved_a.get("eligible", false)))
    assert(not bool(resolved_b.get("eligible", true)), "Same species must not inherit another individual's reaction evidence")
    assert(not bool(resolved_a.get("species_personality_used", true)))
    assert(not bool(resolved_a.get("generated_dialogue", true)))
    assert(str(resolved_a.get("allowed_response_mode", "")) == "disagree")

    var auxiliaries: Array[Dictionary] = [aux_b, aux_a]
    var ranked := resolver.rank_candidates(auxiliaries, event_context, {}, 2)
    assert(ranked.size() == 1)
    assert(str(ranked[0].get("entity_id", "")) == "aux:delie_affame:101")

    var shared_memory_contexts := {
        "aux:delie_affame:202": {
            "shared_history": true,
            "participants": ["aux:delie_affame:202"],
            "history_refs": ["expedition:shared:44"],
            "shared_history_strength": 5
        }
    }
    var shared_event_context := {
        "family": "SOUVENIR",
        "reaction_dimensions": ["trust"],
        "preferred_response_mode": "acknowledge"
    }
    var shared_result := resolver.resolve(aux_b, shared_event_context, shared_memory_contexts["aux:delie_affame:202"])
    assert(bool(shared_result.get("eligible", false)))
    assert(bool(shared_result.get("shared_history", false)))

    var no_id := resolver.resolve({"identity_seed":303,"species_id":"delie_affame"}, event_context, {})
    assert(not bool(no_id.get("eligible", true)))
    assert(str(no_id.get("reason", "")) == "stable_entity_id_required")

    print("VEILLEURS_AUXILIARY_REACTION_CANDIDATE_SMOKE_OK")
    get_tree().quit(0)
