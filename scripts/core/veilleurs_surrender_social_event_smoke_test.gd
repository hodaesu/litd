extends Node

const SocialEvent := preload("res://scripts/core/veilleurs_surrender_social_event_runtime.gd")
const SpeciesKnowledge := preload("res://scripts/core/species_knowledge_runtime.gd")
const EncounterGenerator := preload("res://scripts/core/veilleurs_encounter_generator.gd")

const REGION_ID := "act_i"

var failures: Array[String] = []
var former_id := ""

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    _prepare()
    _test_informant_information_and_double_resolution()
    _test_service_debt_and_redemption()
    _test_deferred_refuge_recruitment()
    _test_family_return_invalid_choice_and_persistence()
    _test_resentful_combat_handoff_and_generator_surface()
    _finish()

func _prepare() -> void:
    GameState.reset_new_game()
    RemanenceRuntime.reset_new_game()
    CreatureManager.reset_new_game(26090710)
    var former_enemy := {
        "id": 9100,
        "species_id": "hungry_ghoul",
        "family_id": "ghouls",
        "name": "La Gueule Fendue",
        "hp": 24,
        "max_hp": 24
    }
    former_id = RemanenceRuntime.prepare_enemy(former_enemy, REGION_ID)
    var former := RemanenceRuntime.entity_state(former_id)
    former["stage"] = "former_nemesis"
    former["historical_stage"] = "nemesis"
    former["status"] = "recruited"
    former["protected"] = true
    RemanenceRuntime.entities[former_id] = former
    CreatureManager.captured_creatures = [{
        "instance_id": "former-ghoul-social-001",
        "species_id": "hungry_ghoul",
        "family_id": "ghouls",
        "name": "La Gueule Fendue",
        "former_nemesis": true,
        "source_remanence_id": former_id,
        "player_owned": true
    }]
    CreatureManager.active_instance_id = "former-ghoul-social-001"
    RemanenceRuntime.run_index = 3

func _test_informant_information_and_double_resolution() -> void:
    var informant_id := _seed_survivor(9201, "Le Témoin revenu", "hungry_ghoul", "ghouls")
    var projection := _projection(informant_id, "Le Témoin revenu", "informant", "hungry_ghoul", "ghouls", {"trust": 30, "respect": 70, "resentment": 0})
    var event := SocialEvent.build_event(projection, {"region_id": REGION_ID})
    _check(bool(event.get("can_resolve", false)), "Social : un informateur doit produire une rencontre résoluble")
    _check(int(event.get("choice_count", 0)) == 3, "Social : un informateur doit proposer information, service et retour à la famille")
    _check(_has_choice(event, SocialEvent.CHOICE_RECEIVE_INFORMATION), "Social : le choix d'information doit être exposé")
    _check(_has_choice(event, SocialEvent.CHOICE_REQUEST_SERVICE), "Social : le choix de dette/service doit être exposé")
    var reaction: Dictionary = event.get("former_nemesis_reaction", {})
    _check(bool(reaction.get("present", false)), "Social : l'ancien Némésis actif doit pouvoir réagir à la rencontre")
    _check(str(reaction.get("reaction", "")) == "recognition_open", "Social : la réaction de l'ancien Némésis doit être déterministe depuis la relation")
    _check(not bool(reaction.get("random_betrayal", true)), "Social : la réaction ne doit jamais réintroduire une trahison aléatoire")

    var resolved := SocialEvent.resolve_choice(event, SocialEvent.CHOICE_RECEIVE_INFORMATION, {"region_id": REGION_ID})
    _check(bool(resolved.get("resolved", false)), "Social : prendre l'information doit résoudre réellement le choix")
    var knowledge := SpeciesKnowledge.state("hungry_ghoul")
    _check((knowledge.get("evidence", []) as Array).size() == 1, "Social : l'information doit alimenter la vraie connaissance d'espèce")
    var record := RemanenceRuntime.entity_state(informant_id)
    _check(int(record.get("information_shared_count", 0)) == 1, "Social : le partage d'information doit persister sur le même EntityID")
    _check((record.get("surrender_social_history", []) as Array).size() == 1, "Social : le choix doit entrer dans l'historique individuel")

    var duplicate := SocialEvent.resolve_choice(event, SocialEvent.CHOICE_RECEIVE_INFORMATION, {"region_id": REGION_ID})
    _check(not bool(duplicate.get("resolved", true)) and str(duplicate.get("reason", "")) == "already_resolved", "Social : une même rencontre ne doit jamais être encaissée deux fois")
    knowledge = SpeciesKnowledge.state("hungry_ghoul")
    _check((knowledge.get("evidence", []) as Array).size() == 1, "Social : le verrou anti-double-résolution doit aussi protéger les Archives")

func _test_service_debt_and_redemption() -> void:
    var service_id := _seed_survivor(9202, "La Dette de Suie", "hungry_ghoul", "ghouls")
    var event := SocialEvent.build_event(_projection(service_id, "La Dette de Suie", "informant", "hungry_ghoul", "ghouls", {"trust": 10, "respect": 55, "resentment": 0}), {"region_id": REGION_ID})
    var resolved := SocialEvent.resolve_choice(event, SocialEvent.CHOICE_REQUEST_SERVICE, {"region_id": REGION_ID})
    _check(bool(resolved.get("resolved", false)), "Service : demander un service doit créer une conséquence persistante")
    var state := SocialEvent.service_state(service_id)
    _check(bool(state.get("owed", false)) and not bool(state.get("ready", true)), "Service : la dette doit exister sans être consommable dans le même run")
    _check(int(state.get("debt_count", 0)) == 1, "Service : le nombre de services dus doit être explicite")
    var too_early := SocialEvent.redeem_service(service_id, {"region_id": REGION_ID})
    _check(not bool(too_early.get("redeemed", true)) and str(too_early.get("reason", "")) == "service_not_ready", "Service : un service différé ne doit pas pouvoir être utilisé immédiatement")
    RemanenceRuntime.run_index += 1
    var redeemed := SocialEvent.redeem_service(service_id, {"region_id": REGION_ID, "service_kind": "safe_route"})
    _check(bool(redeemed.get("redeemed", false)), "Service : la dette doit être réellement consommable lors d'un run ultérieur")
    _check(int(redeemed.get("remaining_debt", -1)) == 0, "Service : consommer le service doit décrémenter la dette")

func _test_deferred_refuge_recruitment() -> void:
    RemanenceRuntime.run_index = 5
    var recruit_id := _seed_survivor(9203, "Celle qui hésite", "hungry_ghoul", "ghouls")
    var event := SocialEvent.build_event(_projection(recruit_id, "Celle qui hésite", "potential_recruit", "hungry_ghoul", "ghouls", {"trust": 28, "respect": 68, "resentment": 0}), {"region_id": REGION_ID})
    _check(bool(event.get("deferred_recruitment_only", false)), "Recrutement : la candidature doit être explicitement différée")
    var captured_before := CreatureManager.captured_creatures.size()
    var resolved := SocialEvent.resolve_choice(event, SocialEvent.CHOICE_INVITE_REFUGE, {"region_id": REGION_ID})
    _check(bool(resolved.get("resolved", false)), "Recrutement : inviter au Refuge doit résoudre le choix social")
    var record := RemanenceRuntime.entity_state(recruit_id)
    _check(bool(record.get("pending_refuge_recruitment", false)), "Recrutement : l'invitation doit persister sur l'individu")
    _check(str(record.get("status", "active")) != "recruited", "Recrutement : l'invitation ne doit pas recruter instantanément")
    _check(CreatureManager.captured_creatures.size() == captured_before, "Recrutement : la rencontre sociale ne doit ajouter aucun compagnon ni cinquième Veilleur")
    _check(not SocialEvent.is_deferred_recruit_ready(recruit_id, 5), "Recrutement : la candidature ne doit pas être disponible dans le run d'invitation")
    _check(SocialEvent.is_deferred_recruit_ready(recruit_id, 6), "Recrutement : la candidature doit devenir disponible au run suivant")

func _test_family_return_invalid_choice_and_persistence() -> void:
    RemanenceRuntime.run_index = 6
    var family_id := _seed_survivor(9204, "Le Porte-Parole", "ash_hound", "hounds")
    var event := SocialEvent.build_event(_projection(family_id, "Le Porte-Parole", "survivor", "ash_hound", "hounds", {}), {"region_id": REGION_ID})
    var before := RemanenceRuntime.entity_state(family_id)
    var invalid := SocialEvent.resolve_choice(event, "impossible_choice", {"region_id": REGION_ID})
    _check(not bool(invalid.get("resolved", true)) and str(invalid.get("reason", "")) == "choice_not_available", "Social : un choix absent de l'événement doit être refusé")
    var after_invalid := RemanenceRuntime.entity_state(family_id)
    _check((before.get("surrender_social_history", []) as Array).size() == (after_invalid.get("surrender_social_history", []) as Array).size(), "Social : un choix invalide ne doit produire aucune mutation")

    var resolved := SocialEvent.resolve_choice(event, SocialEvent.CHOICE_RETURN_TO_FAMILY, {"region_id": REGION_ID})
    _check(bool(resolved.get("resolved", false)), "Famille : laisser repartir le survivant doit être un vrai choix")
    var record := RemanenceRuntime.entity_state(family_id)
    _check(bool(record.get("social_returned_to_family", false)), "Famille : le retour aux siens doit persister")
    _check(int(record.get("family_return_run", -1)) == 6, "Famille : le run du retour doit être mémorisé")

    var snapshot := RemanenceRuntime.serialize()
    RemanenceRuntime.reset_new_game()
    RemanenceRuntime.deserialize(snapshot)
    record = RemanenceRuntime.entity_state(family_id)
    _check(bool(record.get("social_returned_to_family", false)), "Sauvegarde : le choix de retour à la famille doit survivre au round-trip")
    _check((record.get("surrender_social_history", []) as Array).size() == 1, "Sauvegarde : l'historique de rencontre sociale doit survivre au round-trip")

func _test_resentful_combat_handoff_and_generator_surface() -> void:
    RemanenceRuntime.run_index = 7
    var hostile_id := _seed_survivor(9205, "Le Refusé", "ash_hound", "hounds")
    var projection := _projection(hostile_id, "Le Refusé", "resentful_adversary", "ash_hound", "hounds", {"resentment": 70})
    var event := SocialEvent.build_event(projection, {"region_id": REGION_ID})
    _check(bool(event.get("combat_handoff", false)), "Rancune : un adversaire revenu hostile doit basculer explicitement vers le combat")
    _check(not bool(event.get("can_resolve", true)) and int(event.get("choice_count", -1)) == 0, "Rancune : un retour hostile ne doit pas afficher de faux choix sociaux")

    var generator := EncounterGenerator.new()
    var surfaced := generator.build_surrender_social_event(_projection(hostile_id, "Le Refusé", "family_returnee", "ash_hound", "hounds", {}), {"region_id": REGION_ID})
    _check(not surfaced.is_empty(), "Générateur : la couche de rencontre doit savoir matérialiser l'événement social projeté")
    _check(int(surfaced.get("choice_count", 0)) == 3, "Générateur : l'événement social doit conserver ses choix jouables")

func _seed_survivor(id_value: int, name_value: String, species_id: String, family_id: String) -> String:
    var enemy := {
        "id": id_value,
        "species_id": species_id,
        "family_id": family_id,
        "name": name_value,
        "hp": 8,
        "max_hp": 24
    }
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, REGION_ID)
    var record := RemanenceRuntime.entity_state(entity_id)
    record["family_id"] = family_id
    record["species_id"] = species_id
    record["status"] = "active"
    record["surrender_outcome"] = "surrender_negotiated"
    record["surrender_resolution_run"] = 0
    record["return_eligible_run"] = 2
    record["former_nemesis_id"] = former_id
    record["former_kin_relationship"] = {"trust": 25, "respect": 60, "fear": 10, "resentment": 0}
    RemanenceRuntime.entities[entity_id] = record
    return entity_id

func _projection(entity_id: String, name_value: String, role: String, species_id: String, family_id: String, relationship: Dictionary) -> Dictionary:
    return {
        "entity_id": entity_id,
        "name": name_value,
        "role": role,
        "species_id": species_id,
        "family_id": family_id,
        "former_nemesis_id": former_id,
        "relationship": relationship.duplicate(true),
        "summary": "Une conséquence de reddition revient dans le monde."
    }

func _has_choice(event: Dictionary, choice_id: String) -> bool:
    for value: Variant in event.get("choices", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
            return true
    return false

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_SURRENDER_SOCIAL_EVENT_SMOKE_OK choices=true information=true species_knowledge=true service_debt=true deferred_recruit=true family_return=true former_nemesis_reaction=true no_random_betrayal=true anti_double_resolution=true combat_handoff=true save_reload=true generator_surface=true")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_SURRENDER_SOCIAL_EVENT_SMOKE: " + failure)
    print("VEILLEURS_SURRENDER_SOCIAL_EVENT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
