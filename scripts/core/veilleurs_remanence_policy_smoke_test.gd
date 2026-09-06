extends Node

const POLICY_SCRIPT := preload("res://scripts/core/veilleurs_remanence_policy.gd")

func _ready() -> void:
    var policy := POLICY_SCRIPT.new() as VeilleursRemanencePolicy
    var entity_id := "enemy:delie_affame:policy-smoke"
    policy.ensure_entity(entity_id, "delie_affame")
    assert(policy.rank(entity_id) == "normal")

    var survived := policy.note_event(entity_id, "survival", {
        "shared_history": true,
        "direct_exchange": true,
        "intent_family": "assaut",
        "exit_axis": "left_cover",
        "salience": 2
    })
    assert(bool(survived.get("ok", false)))
    assert(policy.rank(entity_id) == "memorial")
    var memorial := policy.state(entity_id)
    assert(str((memorial["memory_channels"]["threat_family"] as Dictionary).get("value", "")) == "assaut")
    assert(str((memorial["memory_channels"]["positioning"] as Dictionary).get("value", "")) == "left_cover")

    var early_influence := policy.note_group_influence(entity_id, "threat_family", {
        "later_encounter": true,
        "used_existing_skill": true,
        "influenced_group": true
    })
    assert(not bool(early_influence.get("ok", true)))
    assert(policy.rank(entity_id) == "memorial")

    var applied := policy.apply_lesson(entity_id, "threat_family", {
        "later_encounter": true,
        "changed_decision": true,
        "decision": "avoid_assaut_axis"
    })
    assert(bool(applied.get("ok", false)))
    assert(policy.rank(entity_id) == "veteran")

    var influence := policy.note_group_influence(entity_id, "threat_family", {
        "later_encounter": true,
        "used_existing_skill": true,
        "influenced_group": true,
        "skill_id": "existing-tree-skill"
    })
    assert(bool(influence.get("ok", false)))
    assert(policy.rank(entity_id) == "elite")

    var no_anchor_reencounter := policy.note_event(entity_id, "repeated_encounter", {
        "direct_confrontation": true,
        "recognized_watchers": ["nayra_orun"]
    })
    assert(bool(no_anchor_reencounter.get("ok", false)))
    assert(policy.rank(entity_id) == "elite", "repeated encounter alone must not manufacture a Nemesis")

    var capture := policy.note_event(entity_id, "failed_capture", {
        "shared_history": true,
        "direct_exchange": true,
        "capture_method": "binding_chain",
        "initiator": "tarek_senn",
        "salience": 3
    })
    assert(bool(capture.get("ok", false)))
    assert(policy.rank(entity_id) == "elite", "major anchor still requires a later direct confrontation")

    var return_event := policy.note_event(entity_id, "repeated_encounter", {
        "direct_confrontation": true,
        "recognized_watchers": ["tarek_senn"]
    })
    assert(bool(return_event.get("ok", false)))
    assert(policy.rank(entity_id) == "nemesis")
    var nemesis := policy.state(entity_id)
    assert((nemesis.get("major_anchors", []) as Array).size() >= 1)
    assert(str((nemesis["memory_channels"]["capture"] as Dictionary).get("value", "")) == "binding_chain")

    print("VEILLEURS_REMANENCE_POLICY_SMOKE_OK")
    get_tree().quit(0)
