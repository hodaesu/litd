extends Node

const EncounterGenerator := preload("res://scripts/core/veilleurs_encounter_generator.gd")
const ProductionRegistry := preload("res://scripts/core/veilleurs_enemy_production_registry.gd")

const ACTS := ["I", "II", "III", "IV", "V"]
const EXPECTED_FAMILIES := [
    "Bêtes de Suie",
    "Déliés",
    "Gardiens de Pierre",
    "Gardiens de Version",
    "Porte-Cendres",
    "Pèlerins Fendus",
    "Silencieux",
    "Veines"
]
const ACT_I_SPECIES := [
    "Délié Affamé", "Délié Boursouflé", "Censeur Fendu", "Flagellant Fendu",
    "Sentinelle du Seuil", "Exécuteur de Pierre", "Traque-Suie", "Brise-Os de Suie"
]
const LOCKED_EVOLUTIONS := {
    "Écouteur Creux": ["Écouteur Creux", "Écouteur du Vide", "Écouteur Sans Écho"],
    "Porte-Signe": ["Porte-Signe", "Porte-Signe Scellé", "Porte-Signe Muet"],
    "Marcheur Aphone": ["Marcheur Aphone", "Marcheur de Silence", "Marcheur Sans Nom"],
    "Reteneur de Souffle": ["Reteneur de Souffle", "Reteneur Profond", "Souffle Absent"],
    "Veine Rampante": ["Veine Rampante", "Veine Noueuse", "Veine Profonde"],
    "Nœud-Écorché": ["Nœud-Écorché", "Nœud Charnel", "Nœud Profond"],
    "Porte-Sang": ["Porte-Sang", "Porte-Sang Gorgé", "Porte-Sang Noir"],
    "Germe Artériel": ["Germe Artériel", "Germe Pulsant", "Germe du Dessous"],
    "Marche-Pâle": ["Marche-Pâle", "Marche-Cendre", "Marche-Blanc"],
    "Porte-Linceul": ["Porte-Linceul", "Porte-Linceul Pâle", "Porte-Linceul Blanc"],
    "Effaceur de Traces": ["Effaceur de Traces", "Effaceur de Noms", "Effaceur Blanc"],
    "Dormeur de Cendre": ["Dormeur de Cendre", "Dormeur Compact", "Dormeur Blanc"],
    "Copie Lacunaire": ["Copie Lacunaire", "Copie Révisée", "Copie Stable"],
    "Rature Vivante": ["Rature Vivante", "Rature Dense", "Rature Souveraine"],
    "Archiviste de Version": ["Archiviste de Version", "Archiviste Double", "Archiviste Intégral"],
    "Double du Seuil": ["Double du Seuil", "Double Convergent", "Double Exact"]
}

var failures: Array[String] = []
var generator: RefCounted
var registry: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    generator = EncounterGenerator.new()
    registry = ProductionRegistry.new()
    _test_registry_shape()
    _test_all_templates_reference_production_species()
    _test_all_24_variant_rules_are_explicit()
    _test_locked_evolution_names()
    _test_act_i_does_not_invent_evolution_names()
    _test_generated_encounters_are_production_enriched()
    _finish()

func _test_registry_shape() -> void:
    var contract: Dictionary = registry.call("validate_contract")
    _check(bool(contract.get("valid", false)), "Production/Bestiaire : le registre 24 espèces / 8 familles doit satisfaire son contrat")
    _check(int(contract.get("species_count", 0)) == 24, "Production/Bestiaire : exactement 24 espèces ordinaires sont attendues")
    _check(int(contract.get("family_count", 0)) == 8, "Production/Bestiaire : exactement 8 familles de combat sont attendues")
    var families: Array[String] = registry.call("known_families")
    _check(families == EXPECTED_FAMILIES, "Production/Bestiaire : les huit familles doivent correspondre au référentiel maître actuel")
    for family: String in EXPECTED_FAMILIES:
        _check(not (registry.call("family_species", family) as Array).is_empty(), "Production/Bestiaire : chaque famille doit contenir au moins une espèce")

func _test_all_templates_reference_production_species() -> void:
    var referenced: Dictionary = {}
    for value: Variant in generator.get("templates"):
        if not (value is Dictionary):
            continue
        var template: Dictionary = value
        for species_value: Variant in template.get("species", []):
            var species := str(species_value)
            referenced[species] = true
            _check(bool(registry.call("has_species", species)), "Production/Rencontres : espèce inconnue dans une composition canonique : %s" % species)
    _check(referenced.size() == 24, "Production/Rencontres : les 64 compositions doivent référencer les 24 espèces ordinaires de production")

func _test_all_24_variant_rules_are_explicit() -> void:
    for species_value: Variant in registry.get("profiles_by_species").keys():
        var species := str(species_value)
        var n1: Dictionary = generator.call("variant_profile", species, "N1")
        var n20: Dictionary = generator.call("variant_profile", species, "N20")
        var n40: Dictionary = generator.call("variant_profile", species, "N40")
        _check(bool(n1.get("variant_rule_known", false)), "Production/Variantes : règle rig/scène absente pour %s" % species)
        _check(str(n1.get("base_rig_id", "")) != "", "Production/Variantes : rig vide pour %s" % species)
        _check(str(n1.get("family_scene_id", "")) != "", "Production/Variantes : scène de famille vide pour %s" % species)
        _check(str(n20.get("base_rig_id", "")) == str(n1.get("base_rig_id", "")), "Production/Variantes : N20 doit réutiliser le rig de %s" % species)
        _check(str(n40.get("base_rig_id", "")) == str(n1.get("base_rig_id", "")), "Production/Variantes : N40 doit réutiliser le rig de %s" % species)
        _check(str(n20.get("family_scene_id", "")) == str(n1.get("family_scene_id", "")), "Production/Variantes : N20 doit rester dans la scène de famille de %s" % species)
        _check(str(n40.get("family_scene_id", "")) == str(n1.get("family_scene_id", "")), "Production/Variantes : N40 doit rester dans la scène de famille de %s" % species)
        _check(int(n40.get("mobile_intent_complexity_cap", 99)) <= 3, "Production/Variantes : N40 ne doit pas casser la lisibilité mobile de %s" % species)

func _test_locked_evolution_names() -> void:
    _check(LOCKED_EVOLUTIONS.size() == 16, "Production/Variantes : 16 espèces des actes II-V doivent posséder des formes nommées verrouillées")
    for species_value: Variant in LOCKED_EVOLUTIONS.keys():
        var species := str(species_value)
        var expected: Array = LOCKED_EVOLUTIONS[species]
        for index in range(3):
            var tier := ["N1", "N20", "N40"][index]
            var form: Dictionary = registry.call("variant_form", species, tier)
            _check(bool(form.get("named_form_locked", false)), "Production/Variantes : la forme %s de %s doit être verrouillée par le référentiel" % [tier, species])
            _check(str(form.get("form", "")) == str(expected[index]), "Production/Variantes : nom %s incorrect pour %s" % [tier, species])
            _check(not bool(form.get("unnamed_canonical_variant", true)), "Production/Variantes : %s %s possède bien un nom canonique" % [species, tier])

func _test_act_i_does_not_invent_evolution_names() -> void:
    _check(ACT_I_SPECIES.size() == 8, "Production/Acte I : huit espèces ordinaires sont attendues")
    for species: String in ACT_I_SPECIES:
        var n1: Dictionary = registry.call("variant_form", species, "N1")
        var n20: Dictionary = registry.call("variant_form", species, "N20")
        var n40: Dictionary = registry.call("variant_form", species, "N40")
        _check(str(n1.get("form", "")) == species, "Production/Acte I : N1 conserve le nom de l'espèce %s" % species)
        _check(not bool(n20.get("named_form_locked", true)) and str(n20.get("form", "")) == "", "Production/Acte I : aucun faux nom N20 ne doit être créé pour %s" % species)
        _check(not bool(n40.get("named_form_locked", true)) and str(n40.get("form", "")) == "", "Production/Acte I : aucun faux nom N40 ne doit être créé pour %s" % species)
        _check(bool(n20.get("unnamed_canonical_variant", false)) and bool(n40.get("unnamed_canonical_variant", false)), "Production/Acte I : les paliers N20/N40 restent mécaniquement utilisables mais non nommés pour %s" % species)

func _test_generated_encounters_are_production_enriched() -> void:
    generator.call("reset_history")
    for act_index in range(ACTS.size()):
        var act_id: String = ACTS[act_index]
        for depth in range(1, 6):
            var result: Dictionary = generator.call("generate", act_id, depth, 91000 + act_index * 100 + depth, [])
            _check(bool(result.get("ok", false)), "Production/Générateur : génération impossible acte %s profondeur %d" % [act_id, depth])
            if not bool(result.get("ok", false)):
                continue
            _check(int(result.get("actor_count", 99)) <= 4, "Production/Générateur : la limite mobile de quatre ennemis doit rester active")
            for actor_value: Variant in result.get("actors", []):
                if not (actor_value is Dictionary):
                    _check(false, "Production/Générateur : un acteur généré doit être un dictionnaire data-driven")
                    continue
                var actor: Dictionary = actor_value
                _check(not bool(actor.get("production_profile_missing", true)), "Production/Générateur : chaque acteur doit recevoir son profil de production")
                _check(str(actor.get("family", "")) != "", "Production/Générateur : chaque acteur doit porter sa famille")
                _check(str(actor.get("role", "")) != "", "Production/Générateur : chaque acteur doit porter son rôle")
                _check(str(actor.get("anatomy", "")) != "", "Production/Générateur : chaque acteur doit porter son anatomie")
                _check((actor.get("skill_trees", []) as Array).size() == 3, "Production/Générateur : chaque acteur doit exposer ses trois arbres")
                _check(bool(actor.get("recruitable", false)), "Production/Générateur : les espèces ordinaires doivent rester potentiellement recrutables")
                _check(bool(actor.get("main_party_replacement_forbidden", false)), "Production/Générateur : aucune recrue ennemie ne remplace le quatuor permanent")
                _check(str(actor.get("intent_contract", "")) == "bounded_mobile", "Production/Générateur : toutes les variantes restent sous le contrat de lisibilité mobile")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_PRODUCTION_BESTIARY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_PRODUCTION_BESTIARY_SMOKE: " + failure)
    print("VEILLEURS_PRODUCTION_BESTIARY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
