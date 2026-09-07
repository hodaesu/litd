extends Node

const SurrenderRuntime := preload("res://scripts/core/veilleurs_surrender_runtime.gd")
const SurrenderAfterlife := preload("res://scripts/core/veilleurs_surrender_afterlife_runtime.gd")
const ArchiveChainUI := preload("res://scripts/ui/veilleurs_nemesis_archive_chain_ui.gd")

const REGION_ID := "act_i"

var failures: Array[String] = []
var former_id := ""
var accepted_id := ""
var negotiated_id := ""

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    _prepare()
    _test_future_roles_and_family_reputation()
    _test_resentful_return_in_real_encounter_projection()
    _test_persistence_and_archives()
    _finish()

func _prepare() -> void:
    GameState.reset_new_game()
    RemanenceRuntime.reset_new_game()
    CreatureManager.reset_new_game(26090709)
    var former_enemy := {
        "id": 9001,
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
    former["historical_hostile_stage"] = "nemesis"
    former["status"] = "recruited"
    former["recruited_run"] = 0
    former["allied_reputation"] = 50
    former["protected"] = true
    RemanenceRuntime.entities[former_id] = former
    CreatureManager.captured_creatures = [{
        "instance_id": "former-ghoul-001",
        "species_id": "hungry_ghoul",
        "family_id": "ghouls",
        "name": "La Gueule Fendue",
        "former_nemesis": true,
        "source_remanence_id": former_id,
        "player_owned": true,
        "level_sync": false
    }]
    CreatureManager.active_instance_id = "former-ghoul-001"
    RemanenceRuntime.run_index = 0

func _test_future_roles_and_family_reputation() -> void:
    var accepted := _surrender_enemy(10, "Le Témoin des Cendres", "ghouls", "hungry_ghoul", 72, 55)
    var accepted_result := SurrenderRuntime.resolve(accepted, SurrenderRuntime.CHOICE_ACCEPT, {"region_id": REGION_ID})
    accepted_id = str(accepted_result.get("entity_id", ""))
    _check(bool(accepted_result.get("resolved", false)), "Après-vie : accepter une reddition doit produire une résolution")
    _check(int(accepted_result.get("return_eligible_run", -1)) == 2, "Après-vie : un survivant ne doit pas réapparaître avant deux runs")
    _check(SurrenderAfterlife.role_for_entity(accepted_id, 0) == "dormant", "Après-vie : le survivant doit rester dormant immédiatement après la reddition")
    _check(SurrenderAfterlife.role_for_entity(accepted_id, 2) == "survivor", "Après-vie : l'ennemi épargné doit pouvoir revenir comme survivant")
    _check(SurrenderAfterlife.role_for_entity(accepted_id, 5) == "informant", "Après-vie : un survivant respectueux doit pouvoir devenir informateur avec le temps")

    var negotiated := _surrender_enemy(11, "La Main Basse", "ghouls", "hungry_ghoul", 78, 58)
    var negotiated_result := SurrenderRuntime.resolve(negotiated, SurrenderRuntime.CHOICE_NEGOTIATE, {"region_id": REGION_ID})
    negotiated_id = str(negotiated_result.get("entity_id", ""))
    _check(str(negotiated_result.get("outcome", "")) == "surrender_negotiated", "Après-vie : la négociation doit aboutir avec Peur et Respect suffisants")
    _check(SurrenderAfterlife.role_for_entity(negotiated_id, 3) == "informant", "Après-vie : la reddition négociée doit pouvoir produire un informateur")
    _check(SurrenderAfterlife.role_for_entity(negotiated_id, 5) == "potential_recruit", "Après-vie : une reddition négociée durable doit pouvoir devenir une candidature au ralliement")

    var positive := SurrenderAfterlife.family_reputation_state("ghouls")
    _check(bool(positive.get("known", false)), "Faction : les témoignages doivent créer une mémoire familiale persistante")
    _check(int(positive.get("score", 0)) == 66, "Faction : accepter puis négocier doit porter la réputation familiale de 50 à 66")
    _check(str(positive.get("attitude", "")) == "conciliatory", "Faction : une réputation élevée doit rendre la famille plus conciliante")
    _check(int(positive.get("testimony_count", 0)) == 2, "Faction : les deux individus doivent compter comme deux témoignages distincts")

    RemanenceRuntime.run_index = 1
    var positive_projection := SurrenderAfterlife.prepare_encounter([{
        "actor_id": "future:0",
        "species": "hungry_ghoul",
        "family": "ghouls",
        "enemy_fear": 20,
        "former_kin_respect": 35
    }], REGION_ID, 77)
    var positive_actor: Dictionary = (positive_projection.get("actors", []) as Array)[0]
    _check(str(positive_actor.get("family_attitude", "")) == "conciliatory", "Faction : la réputation doit être appliquée aux futurs membres de la famille")
    _check(int(positive_actor.get("enemy_fear", 0)) == 28, "Faction : la mémoire favorable doit modifier réellement la Peur de la rencontre")
    _check(int(positive_actor.get("former_kin_respect", 0)) == 45, "Faction : la mémoire favorable doit modifier réellement le Respect")
    _check(not bool(positive_projection.get("survivor_projected", false)), "Après-vie : aucun survivant ne doit réapparaître avant son délai minimal")

    RemanenceRuntime.run_index = 0
    for index in range(6):
        var refused := _surrender_enemy(30 + index, "Refusé %d" % index, "ghouls", "hungry_ghoul", 70, 50)
        var refused_result := SurrenderRuntime.resolve(refused, SurrenderRuntime.CHOICE_REFUSE, {"region_id": REGION_ID})
        _check(str(refused_result.get("outcome", "")) == "surrender_refused", "Faction : chaque refus doit être mémorisé comme tel")
    var negative := SurrenderAfterlife.family_reputation_state("ghouls")
    _check(int(negative.get("score", 100)) == 30, "Faction : six refus après deux témoignages favorables doivent faire tomber la réputation à 30")
    _check(str(negative.get("attitude", "")) == "resentful", "Faction : la mémoire collective doit devenir rancunière sous le seuil prévu")
    _check(int(negative.get("testimony_count", 0)) == 8, "Faction : la mémoire de famille doit agréger tous les témoins sans les réduire à un seul PNJ")

    RemanenceRuntime.run_index = 1
    var negative_projection := SurrenderAfterlife.prepare_encounter([{
        "actor_id": "future:1",
        "species": "hungry_ghoul",
        "family": "ghouls",
        "enemy_fear": 20,
        "former_kin_respect": 35,
        "remanence_capture_resistance": 0
    }], REGION_ID, 88)
    var negative_actor: Dictionary = (negative_projection.get("actors", []) as Array)[0]
    _check(str(negative_actor.get("family_attitude", "")) == "resentful", "Faction : le futur membre doit recevoir l'attitude rancunière collective")
    _check(int(negative_actor.get("enemy_fear", 0)) == 16, "Faction : la rancune familiale doit réduire la Peur sans gonfler artificiellement les PV/dégâts")
    _check(int(negative_actor.get("remanence_capture_resistance", 0)) == 5, "Faction : la rancune familiale doit augmenter la résistance au ralliement")

func _test_resentful_return_in_real_encounter_projection() -> void:
    RemanenceRuntime.run_index = 0
    var refused := _surrender_enemy(80, "Le Chien Repoussé", "hounds", "ash_hound", 68, 48)
    var result := SurrenderRuntime.resolve(refused, SurrenderRuntime.CHOICE_REFUSE, {"region_id": REGION_ID})
    var refused_id := str(result.get("entity_id", ""))
    _check(SurrenderAfterlife.role_for_entity(refused_id, 2) == "resentful_adversary", "Après-vie : une reddition refusée doit pouvoir créer un adversaire rancunier")

    RemanenceRuntime.run_index = 2
    var encounter := SurrenderAfterlife.prepare_encounter([{
        "actor_id": "hounds:0",
        "species": "ash_hound",
        "family": "hounds",
        "name": "Molasse de suie",
        "enemy_fear": 10
    }], REGION_ID, 91)
    _check(bool(encounter.get("survivor_projected", false)), "Après-vie : l'individu doit être sélectionnable dans une future rencontre compatible")
    _check(bool(encounter.get("hostile_return_injected", false)), "Après-vie : l'adversaire rancunier doit être injecté comme acteur de combat réel")
    var actor: Dictionary = (encounter.get("actors", []) as Array)[0]
    _check(str(actor.get("memory_entity_id", "")) == refused_id, "Après-vie : le retour hostile doit conserver exactement le même EntityID")
    _check(str(actor.get("surrender_return_role", "")) == "resentful_adversary", "Après-vie : l'acteur réinjecté doit exposer la cause historique de son retour")
    _check(str(actor.get("name", "")) == "Le Chien Repoussé", "Après-vie : le retour doit conserver l'identité individuelle et pas seulement l'espèce")
    var stored := RemanenceRuntime.entity_state(refused_id)
    _check(int(stored.get("last_future_return_run", -1)) == 2, "Après-vie : la réapparition doit être mémorisée avec son run")
    _check((stored.get("future_role_history", []) as Array).size() == 1, "Après-vie : la trajectoire de l'individu doit conserver l'historique de ses retours")

func _test_persistence_and_archives() -> void:
    var snapshot := RemanenceRuntime.serialize()
    RemanenceRuntime.reset_new_game()
    RemanenceRuntime.deserialize(snapshot)
    var accepted := RemanenceRuntime.entity_state(accepted_id)
    _check(str(accepted.get("family_id", "")) == "ghouls", "Sauvegarde : la famille du survivant doit persister")
    _check(int(accepted.get("return_eligible_run", -1)) == 2, "Sauvegarde : le calendrier de retour doit persister")
    _check(str(accepted.get("surrender_outcome", "")) == "surrender_accepted", "Sauvegarde : la cause de la trajectoire future doit persister")
    var family_state := SurrenderAfterlife.family_reputation_state("ghouls")
    _check(int(family_state.get("testimony_count", 0)) == 8, "Sauvegarde : les témoignages de faction doivent survivre au round-trip")

    var archive := ArchiveChainUI.new()
    var chains := archive.chain_snapshot()
    archive.free()
    var found := false
    for chain: Dictionary in chains:
        if str(chain.get("predecessor_id", "")) != former_id:
            continue
        found = true
        _check(not (chain.get("family_reputation_ledger", {}) as Dictionary).is_empty(), "Archives : la lignée Némésis doit exposer la mémoire de famille")
        _check((chain.get("family_testimonies", []) as Array).size() >= 8, "Archives : les témoignages individuels doivent être consultables depuis la lignée")
        break
    _check(found, "Archives : l'ancien Némésis doit rester présent comme source de la réputation de faction")

func _surrender_enemy(id_value: int, name_value: String, family_id: String, species_id: String, fear: int, respect: int) -> Dictionary:
    return {
        "id": id_value,
        "species_id": species_id,
        "family_id": family_id,
        "name": name_value,
        "hp": 6,
        "max_hp": 24,
        "enemy_fear": fear,
        "former_kin_respect": respect,
        "former_kin_surrender_available": true,
        "captured": false
    }

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        # This line is intentionally machine-readable in CI: it proves the complete post-surrender chain.
        print("VEILLEURS_SURRENDER_AFTERLIFE_SMOKE_OK survivor=true informant=true potential_recruit=true resentful_return=true same_entity_id=true faction_memory=true testimony_propagation=true save_reload=true archives=true")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_SURRENDER_AFTERLIFE_SMOKE: " + failure)
    print("VEILLEURS_SURRENDER_AFTERLIFE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)