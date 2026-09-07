extends Node

const DIRECTOR_SCRIPT := preload("res://scripts/core/veilleurs_boss_director.gd")

func _ready() -> void:
    var director := DIRECTOR_SCRIPT.new() as VeilleursBossDirector
    add_child(director)

    var report := director.validation_report()
    assert(bool(report.get("ok", false)))
    assert(int(report.get("bosses", 0)) == 5)
    assert(int(report.get("boss_phases", 0)) == 16)
    assert(director.phase_count("ishar_gardien_du_passage") == 3)
    assert(director.phase_count("orateur_sans_voix") == 3)
    assert(director.phase_count("mere_des_veines") == 3)
    assert(director.phase_count("porte_cendres_blanc") == 3)
    assert(director.phase_count("le_copiste") == 4)
    assert(not director.can_recruit_boss("le_copiste"))

    var initial_body := {
        "persistent_injuries": [{"id": "arm_break", "severity": "serious"}],
        "dismembered_parts": ["finger_left"],
        "anatomy_part_states": {"arm_left": "critical"}
    }
    var started := director.start_boss("Ishar, Gardien du Passage", "boss:ishar:001", initial_body)
    assert(bool(started.get("success", false)))
    assert(int(started.get("current_phase", 0)) == 1)
    assert(not str(director.current_phase_definition().get("mechanics", "")).is_empty())
    assert(not str(director.current_transition_contract()).is_empty())

    var refused := director.advance_phase(false, {"anatomy_part_states": {"arm_right": "injured"}})
    assert(not bool(refused.get("success", true)))
    assert(int(director.active_state.get("current_phase", 0)) == 1)

    var phase_two := director.advance_phase(true, {"anatomy_part_states": {"arm_right": "injured"}})
    assert(bool(phase_two.get("success", false)))
    assert(int(director.active_state.get("current_phase", 0)) == 2)
    var body_after_two: Dictionary = director.active_state.get("body_snapshot", {})
    assert((body_after_two.get("persistent_injuries", []) as Array).size() == 1, "phase transition cannot heal previous injuries")
    assert((body_after_two.get("dismembered_parts", []) as Array).has("finger_left"), "dismemberment must persist")
    assert(str((body_after_two.get("anatomy_part_states", {}) as Dictionary).get("arm_left", "")) == "critical")
    assert(str((body_after_two.get("anatomy_part_states", {}) as Dictionary).get("arm_right", "")) == "injured")

    var phase_three := director.advance_phase(true)
    assert(bool(phase_three.get("success", false)))
    assert(int(director.active_state.get("current_phase", 0)) == 3)
    assert(director.observed_phases("ishar_gardien_du_passage") == [1, 2, 3])
    var no_fourth := director.advance_phase(true)
    assert(not bool(no_fourth.get("success", true)))
    assert(str(no_fourth.get("reason", "")) == "final_phase_requires_finish")

    var finish := director.finish_boss(true)
    assert(bool(finish.get("success", false)))
    assert(bool((finish.get("state", {}) as Dictionary).get("victory", false)))
    assert(not director.is_active())

    var copiste := director.start_boss("Le Copiste", "boss:copiste:001")
    assert(int(copiste.get("max_phase", 0)) == 4)
    assert(director.advance_phase(true).get("success", false))
    assert(director.advance_phase(true).get("success", false))
    assert(director.advance_phase(true).get("success", false))
    assert(int(director.active_state.get("current_phase", 0)) == 4)
    assert(director.observed_phases("le_copiste") == [1, 2, 3, 4])

    var payload := director.serialize()
    var restored := DIRECTOR_SCRIPT.new() as VeilleursBossDirector
    add_child(restored)
    restored.deserialize(payload)
    assert(int(restored.active_state.get("current_phase", 0)) == 4)
    assert(not bool(restored.active_state.get("recruitable", true)))
    assert(restored.observed_phases("le_copiste") == [1, 2, 3, 4])

    print("VEILLEURS_BOSS_DIRECTOR_SMOKE_OK")
    get_tree().quit(0)
