extends Node

const EncounterGenerator := preload("res://scripts/core/veilleurs_encounter_generator.gd")
const SynergyRuntime := preload("res://scripts/core/veilleurs_enemy_synergy_runtime.gd")
const ProductionRegistry := preload("res://scripts/core/veilleurs_enemy_production_registry.gd")

var failures: Array[String] = []
var generator: RefCounted
var synergies: RefCounted
var registry: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    generator = EncounterGenerator.new()
    synergies = SynergyRuntime.new()
    registry = ProductionRegistry.new()
    _test_synergy_data_contract()
    _test_every_synergy_uses_known_species_and_exists_in_encounters()
    _test_synergy_is_visible_and_breakable()
    _test_cross_family_act_i_relation()
    _test_generator_exposes_synergy_without_hidden_stats()
    _finish()

func _test_synergy_data_contract() -> void:
    var contract: Dictionary = synergies.call("validate_contract")
    _check(bool(contract.get("valid", false)), "Production/Synergies : la matrice canonique doit être structurellement valide")
    _check(int(contract.get("synergy_count", 0)) == 21, "Production/Synergies : exactement 21 paires canoniques sont attendues")

func _test_every_synergy_uses_known_species_and_exists_in_encounters() -> void:
    var pair_keys_in_templates: Dictionary = {}
    for template_value: Variant in generator.get("templates"):
        if not (template_value is Dictionary):
            continue
        var species: Array = (template_value as Dictionary).get("species", [])
        var unique: Array[String] = []
        for value: Variant in species:
            var name := str(value)
            if not unique.has(name):
                unique.append(name)
        for i in range(unique.size()):
            for j in range(i + 1, unique.size()):
                pair_keys_in_templates[_pair_key(unique[i], unique[j])] = true

    for synergy_value: Variant in synergies.get("synergies"):
        if not (synergy_value is Dictionary):
            continue
        var synergy: Dictionary = synergy_value
        var pair: Array = synergy.get("species", [])
        _check(pair.size() == 2, "Production/Synergies : chaque synergie doit être une paire")
        if pair.size() != 2:
            continue
        var a := str(pair[0])
        var b := str(pair[1])
        _check(bool(registry.call("has_species", a)) and bool(registry.call("has_species", b)), "Production/Synergies : une paire ne peut référencer une espèce hors bestiaire : %s + %s" % [a, b])
        _check(pair_keys_in_templates.has(_pair_key(a, b)), "Production/Synergies : chaque paire canonique doit être réellement rencontrable dans les 64 compositions : %s + %s" % [a, b])

func _test_synergy_is_visible_and_breakable() -> void:
    var actors := [
        {"species":"Porte-Signe","hp":20,"status":"active"},
        {"species":"Marcheur Aphone","hp":30,"status":"active"}
    ]
    var active: Dictionary = synergies.call("evaluate", actors, "II")
    _check(int(active.get("active_count", 0)) == 1, "Production/Synergies : Porte-Signe + Marcheur Aphone doit activer sa relation tactique")
    _check(not bool(active.get("hidden_stat_bonus", true)), "Production/Synergies : aucune relation ne doit injecter un bonus de stats caché")
    var relation: Dictionary = (active.get("active", []) as Array)[0] if int(active.get("active_count", 0)) > 0 else {}
    _check(bool(relation.get("telegraphed", false)), "Production/Synergies : une synergie active doit être télégraphiable")
    _check(bool(relation.get("counterplay_visible", false)) and str(relation.get("counterplay", "")) != "", "Production/Synergies : le contre-jeu doit être exposable au joueur par observation/connaissance")
    var broken: Dictionary = synergies.call("break_by_species_loss", actors, "Porte-Signe", "II")
    _check(int(broken.get("active_count", 99)) == 0, "Production/Synergies : perdre un maillon fonctionnel doit casser la relation, pas laisser un buff fantôme")

func _test_cross_family_act_i_relation() -> void:
    var actors := [
        {"species":"Censeur Fendu","hp":25,"status":"active"},
        {"species":"Sentinelle du Seuil","hp":40,"status":"active"}
    ]
    var result: Dictionary = synergies.call("evaluate", actors, "I")
    _check(int(result.get("active_count", 0)) == 1, "Production/Synergies : les relations peuvent traverser deux familles quand le référentiel le prévoit")
    var relation: Dictionary = (result.get("active", []) as Array)[0] if int(result.get("active_count", 0)) > 0 else {}
    _check(str(relation.get("id", "")) == "syn_i_censor_threshold", "Production/Synergies : Censeur + Sentinelle doit activer la relation canonique de contrôle du passage")

func _test_generator_exposes_synergy_without_hidden_stats() -> void:
    var candidates: Array = generator.call("eligible_templates", "I", 2)
    var target_template: Dictionary = {}
    for value: Variant in candidates:
        if not (value is Dictionary):
            continue
        var template: Dictionary = value
        var species: Array = template.get("species", [])
        if species.has("Traque-Suie") and species.has("Brise-Os de Suie"):
            target_template = template
            break
    _check(not target_template.is_empty(), "Production/Synergies : une composition Traque-Suie + Brise-Os doit rester éligible en Acte I")

    var actor_pair := [
        _actor("Traque-Suie", "N1"),
        _actor("Brise-Os de Suie", "N1")
    ]
    var evaluated: Dictionary = generator.call("evaluate_synergies", actor_pair, "I")
    _check(int(evaluated.get("active_count", 0)) == 1, "Production/Synergies : le générateur doit exposer la relation marquage → collision")
    _check(not bool(evaluated.get("hidden_stat_bonus", true)), "Production/Synergies : le générateur ne doit jamais convertir la relation en bonus invisible")

func _actor(species: String, tier: String) -> Dictionary:
    var base: Dictionary = generator.call("variant_profile", species, tier)
    var profile: Dictionary = registry.call("species_profile", species)
    base["species"] = species
    base["family"] = str(profile.get("family", ""))
    base["hp"] = 10
    base["status"] = "active"
    return base

func _pair_key(a: String, b: String) -> String:
    var values := [a, b]
    values.sort()
    return "%s||%s" % [values[0], values[1]]

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_PRODUCTION_SYNERGY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_PRODUCTION_SYNERGY_SMOKE: " + failure)
    print("VEILLEURS_PRODUCTION_SYNERGY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
