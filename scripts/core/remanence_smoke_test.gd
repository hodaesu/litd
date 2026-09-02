extends Node

var failures: Array[String] = []

func run() -> void:
    RemanenceRuntime.reset_new_game()
    _test_entity_identity_and_promotion()
    _test_world_scar_aging()
    _test_archive_links_and_serialization()
    if failures.is_empty():
        print("REMANENCE_SMOKE_OK")
        get_tree().quit(0)
    else:
        for failure: String in failures:
            push_error("REMANENCE_SMOKE: %s" % failure)
        print("REMANENCE_SMOKE_FAILED: %d" % failures.size())
        get_tree().quit(1)

func _test_entity_identity_and_promotion() -> void:
    var enemy := {"id": 8, "species_id": "traque_suie", "name": "Traque-Suie", "hp": 20, "max_hp": 20}
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, "premier_voile")
    _expect(entity_id != "", "Un ennemi doit recevoir un EntityID de Rémanence")
    _expect(str(enemy.get("remanence_id", "")) == entity_id, "L'EntityID doit rester porté par l'instance")
    _expect(RemanenceRuntime.prepare_enemy(enemy, "premier_voile") == entity_id, "Préparer deux fois la même instance ne doit pas reroll son ID")

    RemanenceRuntime.note_encounter(enemy, "premier_voile")
    RemanenceRuntime.record_enemy_event(enemy, "survived_combat", {"region_id": "premier_voile"})
    RemanenceRuntime.record_enemy_event(enemy, "major_mutilation", {"region_id": "premier_voile", "summary": "Œil droit détruit"})
    var memorial := RemanenceRuntime.entity_state(entity_id)
    _expect(int(memorial.get("score", 0)) == 3, "Survie + mutilation majeure doivent produire 3 points mémoriels")
    _expect(str(memorial.get("stage", "")) == "memorial", "Le seuil 3 doit promouvoir l'ennemi au stade mémoriel")

    RemanenceRuntime.note_encounter(enemy, "premier_voile")
    RemanenceRuntime.record_enemy_event(enemy, "killed_watcher", {"region_id": "premier_voile", "hero_id": "smoke_hero"})
    var veteran := RemanenceRuntime.entity_state(entity_id)
    _expect(int(veteran.get("encounters", 0)) == 2, "Une seconde rencontre doit être comptée")
    _expect(str(veteran.get("stage", "")) == "veteran", "Score suffisant + deux rencontres doivent permettre le stade vétéran")
    _expect(RemanenceRuntime.add_adaptation(entity_id, "fear_fire"), "Un vétéran doit pouvoir mémoriser une adaptation")
    _expect((RemanenceRuntime.entity_state(entity_id).get("adaptations", []) as Array).size() == 1, "Un vétéran doit rester limité à une adaptation")

func _test_world_scar_aging() -> void:
    var scar_id := RemanenceRuntime.create_world_scar("room_08", "watcher_corpse", "local", {"summary": "Un Veilleur est tombé ici."})
    _expect(scar_id != "", "Une cicatrice doit recevoir un identifiant")
    RemanenceRuntime.advance_expedition_cycle()
    RemanenceRuntime.advance_expedition_cycle()
    var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    _expect(str(scar.get("age_stage", "")) == "weathered", "Après deux expéditions, une trace doit être vieillie")
    for _index in range(8):
        RemanenceRuntime.advance_expedition_cycle()
    _expect(not RemanenceRuntime.world_scars.has(scar_id), "Une cicatrice locale ancienne doit être compressée hors de l'état actif")
    _expect(not RemanenceRuntime.archived_scars.is_empty(), "La compression ne doit pas effacer la mémoire de la cicatrice")

func _test_archive_links_and_serialization() -> void:
    var enemy := {"id": 10, "species_id": "executeur_pierre", "name": "Exécuteur de Pierre"}
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, "premier_voile")
    _expect(RemanenceRuntime.link_archive_nodes(entity_id, "hero:narem", "killed"), "Deux fiches des Archives doivent pouvoir être reliées")
    _expect(RemanenceRuntime.linked_entries(entity_id).size() == 1, "La fiche d'un ennemi doit retrouver ses liens d'Archive")
    var snapshot := RemanenceRuntime.serialize()
    RemanenceRuntime.reset_new_game()
    _expect(RemanenceRuntime.entities.is_empty(), "Le reset doit vider l'état actif")
    RemanenceRuntime.deserialize(snapshot)
    _expect(RemanenceRuntime.entities.has(entity_id), "La désérialisation doit restaurer les EntityID")
    _expect(RemanenceRuntime.linked_entries(entity_id).size() == 1, "Les liens d'Archive doivent survivre à la sauvegarde")

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
