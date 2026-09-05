extends Node

const BossRouter := preload("res://scripts/core/veilleurs_boss_production_router.gd")
const ProductionRegistry := preload("res://scripts/core/veilleurs_enemy_production_registry.gd")
const EncounterGenerator := preload("res://scripts/core/veilleurs_encounter_generator.gd")

const ACTS: Array[String] = ["I", "II", "III", "IV", "V"]
const EXPECTED_NAMES := {
    "I": "Ishar, Gardien du Passage",
    "II": "Orateur Sans Voix",
    "III": "Mère des Veines",
    "IV": "Porte-Cendres Blanc",
    "V": "Le Copiste"
}
const EXPECTED_PHASES := {"I":3,"II":3,"III":3,"IV":3,"V":4}

var failures: Array[String] = []
var router: RefCounted
var registry: RefCounted
var generator: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    router = BossRouter.new()
    registry = ProductionRegistry.new()
    generator = EncounterGenerator.new()
    _test_manifest_contract()
    _test_one_boss_per_act()
    _test_bosses_never_enter_ordinary_registry_or_templates()
    _test_every_act_has_real_preboss_template()
    _test_route_requires_completed_preboss()
    _finish()

func _test_manifest_contract() -> void:
    var result: Dictionary = router.call("validate_contract")
    _check(bool(result.get("valid", false)), "Production/Boss : le manifeste doit lier les cinq boss à leurs contrats runtime")
    _check(int(result.get("boss_count", 0)) == 5, "Production/Boss : exactement cinq boss sont attendus")

func _test_one_boss_per_act() -> void:
    var seen_ids: Dictionary = {}
    for act_id: String in ACTS:
        var boss: Dictionary = router.call("boss_for_act", act_id)
        _check(not boss.is_empty(), "Production/Boss : boss absent pour l'acte %s" % act_id)
        _check(str(boss.get("name", "")) == str(EXPECTED_NAMES[act_id]), "Production/Boss : identité incorrecte pour l'acte %s" % act_id)
        _check(int(boss.get("phase_count", 0)) == int(EXPECTED_PHASES[act_id]), "Production/Boss : nombre de phases incorrect pour l'acte %s" % act_id)
        _check(not bool(boss.get("recruitable", true)), "Production/Boss : un boss majeur ne doit jamais être recruté")
        _check(not bool(boss.get("standard_generator_injection", true)), "Production/Boss : un boss ne doit jamais être injecté dans une rencontre standard")
        var boss_id := str(boss.get("boss_id", ""))
        _check(boss_id != "" and not seen_ids.has(boss_id), "Production/Boss : chaque acte doit pointer vers un boss unique")
        seen_ids[boss_id] = true

func _test_bosses_never_enter_ordinary_registry_or_templates() -> void:
    var boss_names: Array[String] = []
    for act_id: String in ACTS:
        boss_names.append(str((router.call("boss_for_act", act_id) as Dictionary).get("name", "")))
    for boss_name: String in boss_names:
        _check(not bool(registry.call("has_species", boss_name)), "Production/Boss : %s ne doit pas être compté parmi les 24 espèces ordinaires" % boss_name)
    for template_value: Variant in generator.get("templates"):
        if not (template_value is Dictionary):
            continue
        var template: Dictionary = template_value
        for species_value: Variant in template.get("species", []):
            _check(not boss_names.has(str(species_value)), "Production/Boss : une composition standard/pré-boss ne doit jamais contenir directement un boss")

func _test_every_act_has_real_preboss_template() -> void:
    for act_id: String in ACTS:
        var found := false
        for template_value: Variant in generator.get("templates"):
            if not (template_value is Dictionary):
                continue
            var template: Dictionary = template_value
            if str(template.get("act_id", "")) != act_id:
                continue
            if str(template.get("type", "")).to_lower() == "pré-boss" or str(template.get("type", "")).to_lower() == "pre-boss" or str(template.get("type", "")).to_lower() == "preboss":
                if int(template.get("depth_min", 0)) <= 5 and int(template.get("depth_max", 0)) >= 5:
                    found = true
                    break
        _check(found, "Production/Boss : l'acte %s doit avoir une vraie composition pré-boss de profondeur 5 avant son boss" % act_id)

func _test_route_requires_completed_preboss() -> void:
    for act_id: String in ACTS:
        var wrong_depth: Dictionary = router.call("route_after_preboss", act_id, 4, true)
        _check(not bool(wrong_depth.get("spawn_boss", true)) and str(wrong_depth.get("reason", "")) == "not_preboss_depth", "Production/Boss : le boss %s ne doit pas apparaître avant la profondeur pré-boss" % act_id)
        var not_done: Dictionary = router.call("route_after_preboss", act_id, 5, false)
        _check(not bool(not_done.get("spawn_boss", true)) and str(not_done.get("reason", "")) == "preboss_not_completed", "Production/Boss : le boss %s doit attendre la résolution du pré-boss" % act_id)
        var ready: Dictionary = router.call("route_after_preboss", act_id, 5, true)
        _check(bool(ready.get("spawn_boss", false)), "Production/Boss : le boss %s doit être routé après le pré-boss" % act_id)
        _check(str(ready.get("name", "")) == str(EXPECTED_NAMES[act_id]), "Production/Boss : le routeur doit fournir le bon boss pour l'acte %s" % act_id)
        _check(str(ready.get("source", "")) == "boss_production_router", "Production/Boss : l'apparition doit provenir du routeur dédié, pas du générateur standard")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_BOSS_PRODUCTION_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_BOSS_PRODUCTION_SMOKE: " + failure)
    print("VEILLEURS_BOSS_PRODUCTION_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
