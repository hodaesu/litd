extends Node

const CONTENT_SCRIPT := preload("res://scripts/core/veilleurs_content_runtime.gd")
const ENCOUNTER_SCRIPT := preload("res://scripts/core/veilleurs_encounter_director.gd")
const BOSS_SCRIPT := preload("res://scripts/core/veilleurs_boss_director.gd")
const COORDINATOR_SCRIPT := preload("res://scripts/core/veilleurs_runtime_coordinator.gd")

func _ready() -> void:
    var content := CONTENT_SCRIPT.new() as VeilleursContentRuntime
    var encounters := ENCOUNTER_SCRIPT.new() as VeilleursEncounterDirector
    var bosses := BOSS_SCRIPT.new() as VeilleursBossDirector
    var coordinator := COORDINATOR_SCRIPT.new() as VeilleursRuntimeCoordinator
    add_child(content)
    add_child(encounters)
    add_child(bosses)
    add_child(coordinator)
    coordinator.bind(content, encounters, bosses)

    var selected := coordinator.select_encounter(991, "I")
    assert(bool(selected.get("success", false)))
    assert(content.archive_entries.is_empty(), "encounter selection must not reveal knowledge before perception")

    var intent_result := coordinator.resolve_enemy_intent("delie_affame", {
        "Arbre": "Fuite des cendres",
        "Compétence": "Repli bas",
        "Type": "Active",
        "Rôle du nœud": "Fondation",
        "Positions": "P1-P3",
        "Puissance 0-5": 1.0,
        "Précision %": 96,
        "Tags": "FUITE;POSITION",
        "Effet": "Change de rang sans quitter le combat."
    }, 5, "low_light")
    assert(bool(intent_result.get("ok", false)))
    assert(str((intent_result.get("resolved", {}) as Dictionary).get("intent_family", "")) == "repositionnement")
    assert(int((intent_result.get("telegraph", {}) as Dictionary).get("detail_level", -1)) == 4)
    assert(int((intent_result.get("telegraph", {}) as Dictionary).get("stored_detail", -1)) == 5)

    var observed := coordinator.note_enemy_observed("enemy:delie_affame:01", {"species_id": "delie_affame"})
    assert(str(observed.get("knowledge_state", "")) == "OBSERVED")
    var analyzed := coordinator.note_enemy_analyzed("enemy:delie_affame:01", {"source": "corpse_analysis"})
    assert(str(analyzed.get("knowledge_state", "")) == "CONFIRMED")

    var memory_id := "enemy:delie_affame:memory"
    var memorial := coordinator.note_enemy_memory_event(memory_id, "survival", {
        "species_id": "delie_affame",
        "shared_history": true,
        "direct_exchange": true,
        "intent_family": "assaut",
        "exit_axis": "left_cover"
    })
    assert(str((memorial.get("state", {}) as Dictionary).get("memory_rank", "")) == "memorial")
    var veteran := coordinator.apply_enemy_lesson(memory_id, "threat_family", {
        "later_encounter": true,
        "changed_decision": true
    })
    assert(str((veteran.get("state", {}) as Dictionary).get("memory_rank", "")) == "veteran")
    var elite := coordinator.note_enemy_group_influence(memory_id, "threat_family", {
        "later_encounter": true,
        "used_existing_skill": true,
        "influenced_group": true
    })
    assert(str((elite.get("state", {}) as Dictionary).get("memory_rank", "")) == "elite")
    coordinator.note_enemy_memory_event(memory_id, "failed_capture", {
        "shared_history": true,
        "direct_exchange": true,
        "capture_method": "binding_chain",
        "initiator": "tarek_senn"
    })
    var nemesis := coordinator.note_enemy_memory_event(memory_id, "repeated_encounter", {
        "direct_confrontation": true,
        "recognized_watchers": ["tarek_senn"]
    })
    assert(str((nemesis.get("state", {}) as Dictionary).get("memory_rank", "")) == "nemesis")
    assert(str(coordinator.enemy_memory_state(memory_id).get("memory_rank", "")) == "nemesis")
    assert(not content.archive_entry(memory_id).is_empty())

    var boss_start := coordinator.start_boss("Le Copiste", "boss:copiste:live", {"anatomy_part_states": {"arm_left": "injured"}})
    assert(bool(boss_start.get("success", false)))
    assert(content.boss_phase_is_known("le_copiste", 1))
    assert(not content.boss_phase_is_known("le_copiste", 2))
    var boss_archive := content.archive_entry("boss:copiste:live")
    assert(str(boss_archive.get("knowledge_state", "")) == "OBSERVED")

    var phase_two := coordinator.advance_boss_phase(true, {"anatomy_part_states": {"arm_right": "critical"}})
    assert(bool(phase_two.get("success", false)))
    assert(content.boss_phase_is_known("le_copiste", 2))
    assert(not content.boss_phase_is_known("le_copiste", 3))
    assert(str((bosses.active_state.get("body_snapshot", {}) as Dictionary).get("anatomy_part_states", {}).get("arm_left", "")) == "injured")

    var candidate := coordinator.create_rally_candidate({
        "species_id": "delie_affame",
        "name": "Délié Affamé",
        "persistent_injuries": [{"id": "fracture_leg", "severity": "serious"}]
    }, "I")
    assert(bool(candidate.get("ok", false)))
    var rallied := coordinator.resolve_rally(str(candidate.get("rally_id", "")), true, {"story_eligible": true})
    assert(bool(rallied.get("recruited", false)))
    assert((content.refuge_roster[0].get("persistent_injuries", []) as Array).size() == 1)

    print("VEILLEURS_RUNTIME_COORDINATOR_SMOKE_OK")
    get_tree().quit(0)
