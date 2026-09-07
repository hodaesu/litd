extends Node

const EncounterGenerator := preload("res://scripts/core/veilleurs_encounter_generator.gd")

var failures: Array[String] = []
var generator: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    generator = EncounterGenerator.new()
    _test_t26_threat_budget()
    _test_t27_max_standard_actors()
    _test_t28_no_immediate_template_repeat()
    _test_t29_only_one_memorial_injection()
    _test_t30_nemesis_requires_shared_history()
    _test_t31_n20_reuses_base_rig_and_scene()
    _test_t32_n40_adds_advanced_reactions_without_mobile_intent_breakage()
    _finish()

func _test_t26_threat_budget() -> void:
    _check(generator.call("template_count") == 64, "Tests_48/T26 : les 64 compositions canoniques doivent être chargées")
    for act_id in ["I", "II", "III", "IV", "V"]:
        for depth in range(1, 6):
            var rule: Dictionary = generator.call("depth_rule", act_id, depth)
            _check(not rule.is_empty(), "Tests_48/T26 : chaque acte/profondeur doit posséder un budget de menace")
            var budget := int(rule.get("threat_budget", -1))
            for template_value: Variant in generator.call("eligible_templates", act_id, depth):
                var template: Dictionary = template_value
                _check(int(template.get("threat", 999)) <= budget or bool(template.get("scripted", false)), "Tests_48/T26 : aucun template générable ne doit dépasser le budget sans marque scriptée")
    var illegal := {"act_id":"I","depth_min":1,"depth_max":5,"actor_count":1,"threat":99,"scripted":false}
    var rejected: Dictionary = generator.call("validate_template", illegal, "I", 1)
    _check(not bool(rejected.get("valid", true)) and str(rejected.get("reason", "")) == "over_budget", "Tests_48/T26 : un template hors budget non scripté doit être refusé")
    illegal["scripted"] = true
    var exception: Dictionary = generator.call("validate_template", illegal, "I", 1)
    _check(bool(exception.get("valid", false)) and str(exception.get("reason", "")) == "scripted_exception", "Tests_48/T26 : seule une rencontre explicitement scriptée peut dépasser le budget")

func _test_t27_max_standard_actors() -> void:
    for template_value: Variant in generator.get("templates"):
        if not (template_value is Dictionary):
            continue
        var template: Dictionary = template_value
        if str(template.get("type", "")) == "standard":
            _check(int(template.get("actor_count", 99)) <= 4, "Tests_48/T27 : aucun template standard canonique ne doit dépasser 4 acteurs")
    generator.call("reset_history")
    for seed in range(20):
        var encounter: Dictionary = generator.call("generate", "V", 5, 27000 + seed, [])
        _check(bool(encounter.get("ok", false)), "Tests_48/T27 : une rencontre valide doit être générable")
        if bool(encounter.get("ok", false)):
            _check(int(encounter.get("actor_count", 99)) <= 4, "Tests_48/T27 : le runtime ne doit jamais produire plus de 4 acteurs ennemis")

func _test_t28_no_immediate_template_repeat() -> void:
    generator.call("reset_history")
    var first: Dictionary = generator.call("generate", "II", 3, 28001, [])
    var second: Dictionary = generator.call("generate", "II", 3, 28001, [])
    _check(bool(first.get("ok", false)) and bool(second.get("ok", false)), "Tests_48/T28 : deux générations consécutives doivent être possibles")
    _check(str(first.get("template_id", "")) != str(second.get("template_id", "")), "Tests_48/T28 : le même template ne doit jamais apparaître deux fois de suite")
    var first_id := str(first.get("template_id", ""))
    generator.call("restore_history", ["x", first_id, "y", first_id, "z"])
    _check(int(generator.call("anti_repetition_weight", first_id)) == 40, "Tests_48/T28 : deux apparitions dans les cinq dernières salles doivent appliquer le malus canonique de 60 %")

func _test_t29_only_one_memorial_injection() -> void:
    var actors := [
        {"actor_id":"a","species":"Traque-Suie"},
        {"actor_id":"b","species":"Traque-Suie"},
        {"actor_id":"c","species":"Brise-Os de Suie"}
    ]
    var memories := [
        {"id":"mem_1","species":"Traque-Suie","stage":"elite","score":20,"status":"active"},
        {"id":"mem_2","species":"Traque-Suie","stage":"veteran","score":12,"status":"active"}
    ]
    var result: Dictionary = generator.call("inject_memory", actors, memories)
    _check(int(result.get("injected", 0)) == 1, "Tests_48/T29 : la génération standard doit injecter au maximum un ennemi mémoriel")
    var marked := 0
    for value: Variant in result.get("actors", []):
        if value is Dictionary and str((value as Dictionary).get("memory_entity_id", "")) != "":
            marked += 1
    _check(marked == 1, "Tests_48/T29 : un seul acteur de la composition doit porter l'identité mémorielle")

func _test_t30_nemesis_requires_shared_history() -> void:
    var actors := [{"actor_id":"nemesis_slot","species":"Traque-Suie"}]
    var artificial := [{"id":"nemesis_false","species":"Traque-Suie","stage":"nemesis","score":100,"status":"active","shared_history":false,"history_events":0}]
    var rejected: Dictionary = generator.call("inject_memory", actors, artificial)
    _check(int(rejected.get("nemesis_injected", 0)) == 0, "Tests_48/T30 : un score ou label Némésis ne doit pas suffire sans histoire partagée")
    var legitimate := [{"id":"nemesis_true","species":"Traque-Suie","stage":"nemesis","score":20,"status":"active","shared_history":true,"history_events":3}]
    var accepted: Dictionary = generator.call("inject_memory", actors, legitimate)
    _check(int(accepted.get("nemesis_injected", 0)) == 1, "Tests_48/T30 : une Némésis issue d'une histoire partagée peut réapparaître")
    _check(int(accepted.get("injected", 0)) == 1, "Tests_48/T30 : une Némésis compte dans l'unique injection mémorielle de la rencontre")

func _test_t31_n20_reuses_base_rig_and_scene() -> void:
    var n1: Dictionary = generator.call("variant_profile", "Écouteur Creux", "N1")
    var n20: Dictionary = generator.call("variant_profile", "Écouteur Creux", "N20")
    _check(str(n20.get("variant_tier", "")) == "N20", "Tests_48/T31 : le profil N20 doit être chargé comme spécialisation visible")
    _check(str(n20.get("base_rig_id", "")) == str(n1.get("base_rig_id", "")), "Tests_48/T31 : N20 doit réutiliser le rig de base de l'espèce")
    _check(str(n20.get("family_scene_id", "")) == str(n1.get("family_scene_id", "")), "Tests_48/T31 : N20 ne doit pas exiger une scène spécifique")
    _check(not bool(n20.get("scene_specific", true)), "Tests_48/T31 : la spécialisation visuelle N20 doit rester data-driven")
    _check(bool(n20.get("specialized_profile", false)) and str(n20.get("ai_profile", "")) == "specialized", "Tests_48/T31 : N20 doit charger stats/IA/visuel spécialisés sans nouveau rig")

func _test_t32_n40_adds_advanced_reactions_without_mobile_intent_breakage() -> void:
    var n1: Dictionary = generator.call("variant_profile", "Archiviste de Version", "N1")
    var n40: Dictionary = generator.call("variant_profile", "Archiviste de Version", "N40")
    _check(str(n40.get("variant_tier", "")) == "N40", "Tests_48/T32 : le profil expert N40 doit être identifiable")
    _check(str(n40.get("base_rig_id", "")) == str(n1.get("base_rig_id", "")), "Tests_48/T32 : la forme experte doit conserver le rig de famille")
    _check(bool(n40.get("advanced_reactions", false)), "Tests_48/T32 : N40 doit activer les réactions avancées")
    _check(str(n40.get("ai_profile", "")) == "advanced_reactions", "Tests_48/T32 : l'IA N40 doit charger son profil expert")
    _check(int(n40.get("mobile_intent_complexity_cap", 99)) <= 3, "Tests_48/T32 : la forme experte ne doit pas casser la limite de lisibilité des intentions mobiles")
    _check(str(n40.get("intent_contract", "")) == "bounded_mobile", "Tests_48/T32 : les intentions N40 restent soumises au contrat mobile")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_ENCOUNTER_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_ENCOUNTER_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_ENCOUNTER_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
