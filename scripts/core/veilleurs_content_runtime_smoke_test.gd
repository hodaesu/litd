extends Node

const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_content_runtime.gd")

func _ready() -> void:
    var runtime := RUNTIME_SCRIPT.new() as VeilleursContentRuntime
    runtime.name = "VeilleursContentRuntimeUnderTest"
    add_child(runtime)

    var report := runtime.validation_report()
    assert(bool(report.get("ok", false)), "canonical content must validate")
    assert(int(report.get("ordinary_species", 0)) == 24, "24 ordinary species required")
    assert(int(report.get("encounters", 0)) == 64, "64 encounters required")
    assert(int(report.get("synergies", 0)) == 21, "21 synergies required")
    assert(int(report.get("boss_phases", 0)) == 16, "16 boss phases required")
    assert(int(report.get("bosses", 0)) == 5, "5 bosses required")
    assert(str(report.get("source_sha256", "")) == "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919")

    assert(runtime.encounter_by_name("Avant Ishar").get("actors", 0) == 3)
    assert(runtime.encounters_for_act("I").size() == 16)
    assert(runtime.encounters_for_act("II").size() == 12)
    assert(runtime.encounters_for_act("III").size() == 12)
    assert(runtime.encounters_for_act("IV").size() == 12)
    assert(runtime.encounters_for_act("V").size() == 12)
    assert(runtime.synergies_for_species("Délié Affamé").size() >= 1)

    var boss_candidate := runtime.create_rally_candidate({
        "id": "boss.ishar_gardien_du_passage",
        "species_id": "ishar_gardien_du_passage",
        "boss": true
    }, "I")
    assert(not bool(boss_candidate.get("ok", true)), "boss recruitment must be forbidden")
    assert(str(boss_candidate.get("reason", "")) == "boss_non_recruitable")

    var wounded_enemy := {
        "species_id": "delie_affame",
        "name": "Délié Affamé",
        "persistent_injuries": [{"id": "fracture_leg", "severity": "serious"}],
        "dismembered_parts": ["hand_left"],
        "anatomy_injuries": {"leg_left": "critical"},
        "anatomy_part_states": {"leg_left": "critical"},
        "anatomy_part_trauma": {"leg_left": 82.0}
    }
    var act_i_candidate := runtime.create_rally_candidate(wounded_enemy, "I")
    assert(bool(act_i_candidate.get("ok", false)))
    assert(not bool(act_i_candidate.get("capture_is_recruitment", true)))
    assert(str(act_i_candidate.get("condition_mode", "")) == "story_resolution_required")
    var rally_id := str(act_i_candidate.get("rally_id", ""))
    var premature := runtime.resolve_rally_candidate(rally_id, true, {})
    assert(not bool(premature.get("ok", true)), "Act I must never invent an automatic numeric condition")
    assert(runtime.refuge_roster.is_empty())

    var rallied := runtime.resolve_rally_candidate(rally_id, true, {"story_eligible": true})
    assert(bool(rallied.get("ok", false)))
    assert(bool(rallied.get("recruited", false)))
    assert(runtime.refuge_roster.size() == 1)
    var recruit: Dictionary = runtime.refuge_roster[0]
    assert((recruit.get("persistent_injuries", []) as Array).size() == 1, "injuries must persist through rallying")
    assert((recruit.get("body_state", {}) as Dictionary).get("dismembered_parts", []).size() == 1)
    assert(runtime.capacity_for_act("I") == 4)
    assert(runtime.refuge_slots_remaining("I") == 3)

    var act_ii_candidate := runtime.create_rally_candidate({"species_id": "ecouteur_creux", "name": "Écouteur Creux"}, "II")
    assert(bool(act_ii_candidate.get("ok", false)))
    assert(str(act_ii_candidate.get("condition_text", "")).contains("30 %"))
    var act_ii_id := str(act_ii_candidate.get("rally_id", ""))
    var unresolved := runtime.resolve_rally_candidate(act_ii_id, true, {"condition_satisfied": false})
    assert(not bool(unresolved.get("ok", true)))
    var resolved := runtime.resolve_rally_candidate(act_ii_id, true, {"condition_satisfied": true})
    assert(bool(resolved.get("recruited", false)))

    assert(runtime.record_boss_phase_observed("le_copiste", 4))
    assert(runtime.boss_phase_is_known("le_copiste", 4))
    assert(not runtime.boss_phase_is_known("le_copiste", 3), "unseen boss phases must remain unknown")
    assert(not runtime.record_boss_phase_observed("le_copiste", 5), "Copiste has only four canonical phases")

    var archive := runtime.record_archive_hook("enemy:test", "knowledge_observed", {"source": "combat"})
    assert(str(archive.get("knowledge_state", "")) == "OBSERVED")
    archive = runtime.record_archive_hook("enemy:test", "knowledge_confirmed", {"source": "analysis"})
    assert(str(archive.get("knowledge_state", "")) == "CONFIRMED")
    archive = runtime.record_archive_hook("enemy:test", "knowledge_contradicted", {"note": "observation revised"})
    assert(str(archive.get("knowledge_state", "")) == "CONFIRMED", "contradiction must preserve history instead of fabricating certainty")

    var payload := runtime.serialize()
    var restored := RUNTIME_SCRIPT.new() as VeilleursContentRuntime
    add_child(restored)
    restored.deserialize(payload)
    assert(restored.refuge_roster.size() == runtime.refuge_roster.size())
    assert(restored.boss_phase_is_known("le_copiste", 4))
    assert(str(restored.archive_entry("enemy:test").get("knowledge_state", "")) == "CONFIRMED")

    print("VEILLEURS_CONTENT_RUNTIME_SMOKE_OK")
    get_tree().quit(0)
