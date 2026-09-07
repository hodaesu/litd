extends Node

const LightInformationRuntime := preload("res://scripts/core/veilleurs_light_information_runtime.gd")
const SpeciesKnowledgeRuntime := preload("res://scripts/core/species_knowledge_runtime.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _test_t18_destroyed_light_reduces_precision_without_false_certainty()
    _test_t19_two_stable_light_zones_are_recognized()
    _test_t20_fear_100_is_distinct_from_madness_and_persists()
    _test_t21_unknown_species_starts_qualitative_and_learns_by_evidence()
    _test_t22_mastered_species_information_returns_next_expedition()
    _finish()

func _test_t18_destroyed_light_reduces_precision_without_false_certainty() -> void:
    var light_state := LightInformationRuntime.create_state([
        {"id": "torch_a", "zone_id": "left", "stable": true},
        {"id": "torch_b", "zone_id": "right", "stable": true}
    ])
    var observation := {
        "confirmed_facts": {"species": "Traque-Suie", "has_claws": true},
        "exact_values": {"distance_m": 6, "visible_wounds": 2},
        "qualitative": "Une silhouette blessée progresse dans la cendre."
    }
    var before := LightInformationRuntime.information_view(light_state, observation)
    _check(str(before.get("precision", "")) == "confirmed", "Tests_48/T18 : deux zones stables doivent permettre une lecture précise avant destruction")
    _check(not (before.get("exact_values", {}) as Dictionary).is_empty(), "Tests_48/T18 : l'information exacte peut être visible quand la lumière la confirme")

    var destroyed := LightInformationRuntime.destroy_source(light_state, "torch_b")
    _check(bool(destroyed.get("ok", false)), "Tests_48/T18 : une source lumineuse doit pouvoir être détruite")
    var after := LightInformationRuntime.information_view(light_state, observation)
    _check(float(after.get("confidence", 1.0)) < float(before.get("confidence", 0.0)), "Tests_48/T18 : détruire une source doit réduire la confiance de lecture")
    _check(str(after.get("precision", "")) != "confirmed", "Tests_48/T18 : la précision doit réellement diminuer après perte de lumière")
    _check((after.get("exact_values", {}) as Dictionary).is_empty(), "Tests_48/T18 : les valeurs exactes non confirmées ne doivent pas survivre comme fausse certitude")
    _check((after.get("confirmed_facts", {}) as Dictionary) == (before.get("confirmed_facts", {}) as Dictionary), "Tests_48/T18 : perdre de la lumière ne doit pas transformer un fait déjà confirmé en information fausse")
    _check(str(after.get("qualitative", "")) != "", "Tests_48/T18 : une lecture qualitative doit rester disponible plutôt qu'inventer un chiffre")

func _test_t19_two_stable_light_zones_are_recognized() -> void:
    var light_state := LightInformationRuntime.create_state([
        {"id": "stable_1", "zone_id": "sanctuary_left", "stable": true},
        {"id": "stable_2", "zone_id": "sanctuary_right", "stable": true},
        {"id": "flicker", "zone_id": "center", "stable": false}
    ])
    var condition := LightInformationRuntime.porte_cendres_phase1_condition(light_state)
    _check(bool(condition.get("recognized", false)), "Tests_48/T19 : Porte-Cendres phase 1 doit reconnaître deux zones lumineuses stables")
    _check(int(condition.get("stable_zone_count", 0)) == 2, "Tests_48/T19 : seules les zones stables actives doivent compter")
    LightInformationRuntime.destroy_source(light_state, "stable_2")
    var reduced := LightInformationRuntime.porte_cendres_phase1_condition(light_state)
    _check(not bool(reduced.get("recognized", true)), "Tests_48/T19 : la condition doit cesser d'être vraie si une des deux zones stables disparaît")

func _test_t20_fear_100_is_distinct_from_madness_and_persists() -> void:
    SaveManager.delete_slot(2)
    GameState.reset_new_game()
    _check(not GameState.party.is_empty(), "Tests_48/T20 : un Veilleur est requis pour le contrat psychologique")
    if GameState.party.is_empty():
        return
    var hero: Dictionary = GameState.party[0]
    var hero_id := str(hero.get("id", ""))
    hero["fear"] = 90
    hero["madness"] = 17
    var psychology := PsychologyRuntime.ensure_hero(hero)
    psychology["resolve_charges"] = 0
    hero["psychology"] = psychology

    hero["fear"] = 100
    PsychologyRuntime.record_external_fear(hero, 90, "tests_48_t20", {"extreme": true})
    var after_crossing: Dictionary = hero.get("psychology", {})
    _check(int(after_crossing.get("panic_count", 0)) >= 1, "Tests_48/T20 : atteindre Peur 100 doit laisser une rupture/panique mémorisée")
    var panic := PsychologyRuntime.resolve_panic_action(hero, 20)
    _check(not panic.is_empty(), "Tests_48/T20 : Peur 100 doit déclencher une résolution de rupture psychologique")
    _check(str(panic.get("kind", "")) in ["freeze", "retreat"], "Tests_48/T20 : sans charge d'Espoir, la rupture doit produire une réaction de panique identifiable")
    _check(bool(panic.get("consume_action", false)), "Tests_48/T20 : la rupture de Peur doit avoir une conséquence de combat cohérente")
    _check(int(hero.get("madness", -1)) == 17, "Tests_48/T20 : une rupture de Peur ne doit pas être confondue avec une hausse arbitraire de Folie")

    _check(SaveManager.save_game(2), "Tests_48/T20 : l'état psychologique doit pouvoir être sauvegardé")
    hero["fear"] = 0
    hero["madness"] = 0
    hero["psychology"] = {}
    _check(SaveManager.load_game(2), "Tests_48/T20 : l'état psychologique doit pouvoir être rechargé")
    var restored := _hero_by_id(hero_id)
    _check(not restored.is_empty(), "Tests_48/T20 : le même Veilleur doit réapparaître après recharge")
    if not restored.is_empty():
        _check(int((restored.get("psychology", {}) as Dictionary).get("panic_count", 0)) >= 1, "Tests_48/T20 : la mémoire de rupture doit persister")
        _check(int(restored.get("madness", -1)) == 17, "Tests_48/T20 : la Folie sauvegardée doit rester son axe distinct")
    SaveManager.delete_slot(2)

func _test_t21_unknown_species_starts_qualitative_and_learns_by_evidence() -> void:
    RemanenceRuntime.reset_new_game()
    var enemy := {
        "species_id": "ecouteur_creux_t21",
        "name": "Écouteur Creux",
        "intent_family": "attack",
        "knowledge_exact_values": {"damage_min": 5, "damage_max": 8}
    }
    var first := SpeciesKnowledgeRuntime.intent_preview(enemy)
    _check(int(first.get("knowledge_level", -1)) == 0, "Tests_48/T21 : une espèce inconnue doit commencer au niveau de connaissance 0")
    _check(str(first.get("detail", "")) == "qualitative", "Tests_48/T21 : l'intention d'une espèce inconnue doit rester qualitative")
    _check(str(first.get("text", "")) != "", "Tests_48/T21 : même inconnue, une intention observable doit être décrite qualitativement")
    _check((first.get("exact_values", {}) as Dictionary).is_empty(), "Tests_48/T21 : aucune valeur exacte ne doit fuir pour une espèce inconnue")

    var learned := SpeciesKnowledgeRuntime.record_evidence(
        "ecouteur_creux_t21",
        "observed_attack",
        {"evidence_key": "first_attack", "species_name": "Écouteur Creux", "intent_family": "attack", "summary": "Une attaque a été observée directement."}
    )
    _check(bool(learned.get("ok", false)) and bool(learned.get("new_evidence", false)), "Tests_48/T21 : une preuve observée doit être enregistrée")
    _check(int(learned.get("knowledge_level", 0)) >= 1, "Tests_48/T21 : la connaissance doit progresser grâce à une preuve, pas à un nombre arbitraire de morts")
    var second := SpeciesKnowledgeRuntime.intent_preview(enemy)
    _check(str(second.get("detail", "")) == "observed", "Tests_48/T21 : après preuve, l'intention peut devenir une information observée")

func _test_t22_mastered_species_information_returns_next_expedition() -> void:
    RemanenceRuntime.reset_new_game()
    var species_id := "traque_suie_t22"
    var evidence_types := ["encounter", "injury", "corpse_exam", "document", "capture", "survival", "environment", "behavior"]
    for index in range(evidence_types.size()):
        SpeciesKnowledgeRuntime.record_evidence(
            species_id,
            str(evidence_types[index]),
            {
                "evidence_key": "proof_%d" % index,
                "species_name": "Traque-Suie",
                "intent_family": "attack",
                "confirmed_facts": {"tracks_wounded_targets": true, "mobility_is_critical": true}
            }
        )
    var mastered := SpeciesKnowledgeRuntime.confirmed_information(species_id)
    _check(bool(mastered.get("mastered", false)), "Tests_48/T22 : huit preuves variées doivent atteindre le niveau Maîtrisé")
    _check(bool((mastered.get("confirmed_facts", {}) as Dictionary).get("tracks_wounded_targets", false)), "Tests_48/T22 : les faits confirmés doivent être conservés dans les Archives")

    var saved := RemanenceRuntime.serialize()
    RemanenceRuntime.reset_new_game()
    RemanenceRuntime.deserialize(saved)
    RemanenceRuntime.advance_expedition_cycle()

    var returned_enemy := {
        "species_id": species_id,
        "name": "Traque-Suie rencontrée plus tard",
        "intent_family": "attack",
        "knowledge_exact_values": {"damage_min": 6, "damage_max": 9}
    }
    var preview := SpeciesKnowledgeRuntime.intent_preview(returned_enemy)
    _check(str(preview.get("detail", "")) == "mastered", "Tests_48/T22 : une espèce maîtrisée doit rester maîtrisée lors d'une nouvelle expédition")
    _check(bool((preview.get("confirmed_facts", {}) as Dictionary).get("mobility_is_critical", false)), "Tests_48/T22 : l'information confirmée doit réapparaître sur une nouvelle instance de l'espèce")
    _check(not (preview.get("exact_values", {}) as Dictionary).is_empty(), "Tests_48/T22 : le niveau Maîtrisé peut réafficher les valeurs que le système autorise à connaître")

func _hero_by_id(hero_id: String) -> Dictionary:
    for value: Variant in GameState.party:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == hero_id:
            return value as Dictionary
    return {}

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    SaveManager.delete_slot(2)
    if failures.is_empty():
        print("VEILLEURS_INFORMATION_PSYCHOLOGY_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_INFORMATION_PSYCHOLOGY_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_INFORMATION_PSYCHOLOGY_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
