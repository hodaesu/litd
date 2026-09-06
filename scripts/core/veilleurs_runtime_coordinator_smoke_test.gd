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

    var observed := coordinator.note_enemy_observed("enemy:delie_affame:01", {"species_id": "delie_affame"})
    assert(str(observed.get("knowledge_state", "")) == "OBSERVED")
    var analyzed := coordinator.note_enemy_analyzed("enemy:delie_affame:01", {"source": "corpse_analysis"})
    assert(str(analyzed.get("knowledge_state", "")) == "CONFIRMED")

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
