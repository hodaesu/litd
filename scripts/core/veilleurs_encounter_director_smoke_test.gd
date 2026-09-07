extends Node

const DIRECTOR_SCRIPT := preload("res://scripts/core/veilleurs_encounter_director.gd")

func _ready() -> void:
    var director := DIRECTOR_SCRIPT.new() as VeilleursEncounterDirector
    add_child(director)

    var report := director.validation_report()
    assert(bool(report.get("ok", false)), "64 canonical encounters must bind to species and narrative/reward source")
    assert(int(report.get("encounters", 0)) == 64)
    assert(int(report.get("synergies", 0)) == 21)
    assert(int(report.get("narrative_reward_records", 0)) == 64)
    assert(int(report.get("max_standard_enemies", 0)) == 4)

    var bound_ids: Dictionary = {}
    for source: Dictionary in director.encounter_records:
        var runtime_entry := director.runtime_for_named_encounter(str(source.get("name", "")))
        assert(bool(runtime_entry.get("success", false)))
        var encounter_id := str(runtime_entry.get("id", ""))
        assert(not encounter_id.is_empty())
        assert(not bound_ids.has(encounter_id))
        bound_ids[encounter_id] = true
        assert(bool(runtime_entry.get("generated_binding_verified", false)))
        var narrative: Dictionary = runtime_entry.get("narrative", {})
        var reward: Dictionary = runtime_entry.get("reward", {})
        for key: String in ["intro", "combat_beat", "victory", "retreat", "remanence_hint"]:
            assert(not str(narrative.get(key, "")).is_empty())
        assert(int(reward.get("threat", -1)) >= 0)
        assert(int(reward.get("gold_target", -1)) >= 0)
        assert(int(reward.get("essence_target", -1)) >= 0)
        assert(int(reward.get("remanence_target", -1)) >= 0)
        assert(not str(reward.get("loot", "")).is_empty())
        assert(not str(reward.get("capture_rule", "")).is_empty())
        assert(not str(reward.get("knowledge_bonus", "")).is_empty())
        assert(str(runtime_entry.get("capture_rule", "")) == str(reward.get("capture_rule", "")))
        assert(str(runtime_entry.get("knowledge_bonus", "")) == str(reward.get("knowledge_bonus", "")))
    assert(bound_ids.size() == 64)

    var charognards := director.runtime_for_named_encounter("Charognards du bord")
    assert(bool(charognards.get("success", false)))
    assert(str(charognards.get("id", "")) == "enc_a1_01")
    assert(str((charognards.get("narrative", {}) as Dictionary).get("intro", "")).contains("Délié Affamé"))
    assert(int((charognards.get("reward", {}) as Dictionary).get("gold_target", 0)) == 22)
    assert(int((charognards.get("reward", {}) as Dictionary).get("essence_target", 0)) == 2)

    var first := director.select_encounter(4242, "I")
    assert(bool(first.get("success", false)))
    assert(int(first.get("runtime_actor_count", 0)) <= 4)
    assert(not bool(first.get("party_counterpick_used", true)))
    assert(bool(first.get("generated_binding_verified", false)))
    for spawn_value: Variant in first.get("spawn_entries", []):
        assert(spawn_value is Dictionary)
        assert(not str((spawn_value as Dictionary).get("species_id", "")).is_empty())

    var second := director.select_encounter(4242, "I")
    assert(bool(second.get("success", false)))
    assert(str(second.get("name", "")) != str(first.get("name", "")), "same template twice in a row is forbidden")

    var synergy_encounter := director.runtime_for_named_encounter("Faim derrière la masse")
    assert(bool(synergy_encounter.get("success", false)))
    assert((synergy_encounter.get("synergies", []) as Array).size() >= 1)
    var feedback: Array = synergy_encounter.get("synergy_feedback", [])
    assert(not feedback.is_empty())
    assert(bool((feedback[0] as Dictionary).get("visible", false)))
    assert(bool((feedback[0] as Dictionary).get("breakable", false)))
    assert(not str((feedback[0] as Dictionary).get("counterplay", "")).is_empty())

    var memorial := {
        "entity_id": "enemy:delie_affame:remembered",
        "species_id": "delie_affame",
        "name": "Délié Affamé — le Balafré",
        "memory_rank": "memorial"
    }
    var memorial_encounter := director.runtime_for_named_encounter("Gardien isolé", {"memorial_candidate": memorial})
    assert(bool(memorial_encounter.get("success", false)))
    assert(int(memorial_encounter.get("source_actor_count", 0)) == 1)
    assert(int(memorial_encounter.get("runtime_actor_count", 0)) == 2)
    assert(bool((memorial_encounter.get("memorial_overlay", {}) as Dictionary).get("insert", false)))

    var artificial_nemesis := memorial.duplicate(true)
    artificial_nemesis["memory_rank"] = "nemesis"
    artificial_nemesis["shared_history"] = false
    var nemesis_encounter := director.runtime_for_named_encounter("Gardien isolé", {"memorial_candidate": artificial_nemesis})
    assert(not bool((nemesis_encounter.get("memorial_overlay", {}) as Dictionary).get("insert", true)))
    assert(str((nemesis_encounter.get("memorial_overlay", {}) as Dictionary).get("reason", "")) == "artificial_nemesis_forbidden")

    artificial_nemesis["shared_history"] = true
    var lived_nemesis := director.runtime_for_named_encounter("Gardien isolé", {"memorial_candidate": artificial_nemesis})
    assert(bool((lived_nemesis.get("memorial_overlay", {}) as Dictionary).get("insert", false)))

    var full_encounter := director.runtime_for_named_encounter("Avant l’Orateur", {"memorial_candidate": memorial})
    assert(int(full_encounter.get("runtime_actor_count", 0)) == 4)
    assert(str((full_encounter.get("memorial_overlay", {}) as Dictionary).get("reason", "")) == "actor_cap_full")

    var state := director.serialize()
    var restored := DIRECTOR_SCRIPT.new() as VeilleursEncounterDirector
    add_child(restored)
    restored.deserialize(state)
    assert(restored.recent_history == director.recent_history)
    assert(restored.selection_count == director.selection_count)

    var deterministic_a := DIRECTOR_SCRIPT.new() as VeilleursEncounterDirector
    var deterministic_b := DIRECTOR_SCRIPT.new() as VeilleursEncounterDirector
    add_child(deterministic_a)
    add_child(deterministic_b)
    var choice_a := deterministic_a.select_encounter(777, "III")
    var choice_b := deterministic_b.select_encounter(777, "III")
    assert(str(choice_a.get("name", "")) == str(choice_b.get("name", "")), "same seed and state must select same encounter")

    print("VEILLEURS_ENCOUNTER_DIRECTOR_SMOKE_OK")
    get_tree().quit(0)
