extends Node

const KIT_SCRIPT := preload("res://scripts/core/veilleurs_boss_kit_runtime.gd")

func _ready() -> void:
    var runtime := KIT_SCRIPT.new() as VeilleursBossKitRuntime
    var report := runtime.validation_report()
    assert(bool(report.get("ok", false)))
    assert(int(report.get("bosses", 0)) == 5)
    assert(int(report.get("trees", 0)) == 15)
    assert(int(report.get("ultimates", 0)) == 15)
    assert(int(report.get("boss_skill_rows_source", 0)) == 225)

    var ishar_one := runtime.phase_kit("ishar_gardien_du_passage", 1)
    assert(bool(ishar_one.get("success", false)))
    assert(str(ishar_one.get("mode", "")) == "single_tree")
    assert(str(ishar_one.get("doctrine", "")) == "Loi du Passage")
    assert(str((ishar_one.get("ultimate", {}) as Dictionary).get("name", "")) == "Nul ne passe")

    var orateur_two := runtime.phase_kit("orateur_sans_voix", 2)
    assert(str(orateur_two.get("doctrine", "")) == "Écho muet")
    assert(str((orateur_two.get("ultimate", {}) as Dictionary).get("name", "")) == "Ce qui revient sans voix")

    var mere_three := runtime.phase_kit("mere_des_veines", 3)
    assert(str(mere_three.get("doctrine", "")) == "Nourrir la masse")

    var cendres_three := runtime.phase_kit("porte_cendres_blanc", 3)
    assert(str((cendres_three.get("ultimate", {}) as Dictionary).get("name", "")) == "Effacer jusqu’au nom")

    var copiste_three := runtime.phase_kit("le_copiste", 3)
    assert(str(copiste_three.get("doctrine", "")) == "Palimpseste")
    var copiste_four := runtime.phase_kit("le_copiste", 4)
    assert(bool(copiste_four.get("success", false)))
    assert(str(copiste_four.get("mode", "")) == "synthesis")
    assert((copiste_four.get("trees", []) as Array).size() == 3)
    assert(runtime.ultimate_for_phase("le_copiste", 4).is_empty(), "phase 4 must synthesize three doctrines instead of inventing a fourth ultimate")

    print("VEILLEURS_BOSS_KIT_RUNTIME_SMOKE_OK")
    get_tree().quit(0)
