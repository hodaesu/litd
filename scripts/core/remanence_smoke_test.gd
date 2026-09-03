extends Node

const PROXY_ROOM_SCRIPT := preload("res://scripts/world/dungeon_proxy_room.gd")

var failures: Array[String] = []

func run() -> void:
    RemanenceRuntime.reset_new_game()
    _test_entity_identity_and_promotion()
    _test_world_scar_aging()
    _test_archive_links_and_serialization()
    _test_live_combat_bridge_and_persistent_corpse()
    _test_great_remanence_and_plan_decoration()
    _test_remembered_enemy_reappearance_and_adaptations()
    _test_proxy_room_materializes_scars()
    _test_archives_ui()
    if failures.is_empty():
        print("REMANENCE_SMOKE_OK")
        get_tree().quit(0)
    else:
        for failure: String in failures:
            push_error("REMANENCE_SMOKE: %s" % failure)
        print("REMANENCE_SMOKE_FAILED: %d" % failures.size())
        get_tree().quit(1)

func _world_director() -> Node:
    return RemanenceCombatBridge.world_director

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

func _test_live_combat_bridge_and_persistent_corpse() -> void:
    RemanenceRuntime.reset_new_game()
    RemanenceCombatBridge._on_new_game_reset()
    var enemy := {
        "id": 8,
        "species_id": "traque_suie",
        "name": "Traque-Suie témoin",
        "hp": 20,
        "max_hp": 20,
        "damage": [3, 5],
        "dismembered_parts": [],
        "anatomy_injuries": {},
        "anatomy_part_states": {},
        "anatomy_part_trauma": {}
    }
    GameState.battle_enemies = [enemy]
    RemanenceCombatBridge._begin_current_combat()
    var entity_id := str(enemy.get("remanence_id", ""))
    _expect(entity_id != "", "Le bridge doit préparer un EntityID au début du combat")
    _expect(_has_event(entity_id, "encountered"), "Le début réel du combat doit créer l'événement de rencontre")

    enemy["dismembered_parts"] = ["arm_right"]
    enemy["anatomy_injuries"] = {"arm_right": "critical"}
    RemanenceCombatBridge._scan_enemy_changes()
    _expect(_has_event(entity_id, "major_mutilation"), "Une perte de membre en combat doit remonter en mutilation majeure")

    RemanenceCombatBridge._finish_current_combat(false, "forced_retreat")
    _expect(_has_event(entity_id, "survived_combat"), "Un ennemi encore vivant doit mémoriser sa survie")
    _expect(_has_event(entity_id, "forced_retreat"), "Un ennemi encore vivant doit mémoriser une retraite imposée")

    enemy["hp"] = 20
    GameState.battle_enemies = [enemy]
    RemanenceCombatBridge._begin_current_combat()
    enemy["hp"] = 0
    RemanenceCombatBridge._scan_enemy_changes()
    var corpse_id := _corpse_for_origin(entity_id)
    _expect(corpse_id != "", "Un adversaire mémoriel tué doit laisser un cadavre persistant")
    if corpse_id != "":
        var corpse: Dictionary = RemanenceRuntime.world_scars.get(corpse_id, {})
        _expect(str(corpse.get("type", "")) == "persistent_corpse", "Le cadavre doit être stocké comme WorldScar persistant")
        _expect(str(corpse.get("payload", {}).get("owner_id", "")) == entity_id, "Le cadavre doit conserver l'identité de l'adversaire")
    RemanenceCombatBridge._finish_current_combat(true, "victory")

func _test_great_remanence_and_plan_decoration() -> void:
    var director := _world_director()
    _expect(director != null, "Le directeur mondial de Rémanence doit exister")
    if director == null:
        return
    var scar_id := ""
    for value: Variant in RemanenceRuntime.world_scars.values():
        if value is Dictionary and str((value as Dictionary).get("type", "")) == "persistent_corpse":
            scar_id = str((value as Dictionary).get("id", ""))
            break
    _expect(scar_id != "", "Le test de Grande Rémanence nécessite un cadavre persistant")
    if scar_id == "":
        return
    RemanenceRuntime.advance_expedition_cycle()
    RemanenceRuntime.advance_expedition_cycle()
    var first_visit: Dictionary = director.call("visit_scar", scar_id)
    var second_visit: Dictionary = director.call("visit_scar", scar_id)
    _expect(bool(first_visit.get("ok", false)) and bool(second_visit.get("ok", false)), "Une cicatrice active doit pouvoir être revisitée")
    _expect(bool(second_visit.get("great_remanence", false)), "Deux visites d'une trace vieillie doivent pouvoir créer une Grande Rémanence")
    var upgraded: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    _expect(bool(upgraded.get("protected", false)), "Une Grande Rémanence doit être protégée contre la compression ordinaire")
    _expect(str(upgraded.get("severity", "")) == "historical", "Une Grande Rémanence doit devenir historique")

    var anchor_id := str(upgraded.get("anchor_id", ""))
    var plan := {
        "seed": 77,
        "nodes": [{"id": "memory_room", "role": "combat", "depth": 3, "scar_anchors": [anchor_id], "nemesis_eligible": true}],
        "remanence": {"applied": [upgraded.duplicate(true)], "deferred": []}
    }
    var decorated: Dictionary = director.call("decorate_plan", plan)
    var nodes: Array = decorated.get("nodes", [])
    _expect(not nodes.is_empty() and not ((nodes[0] as Dictionary).get("remanence_scars", []) as Array).is_empty(), "Une cicatrice compatible doit être attachée à la salle hybride qui porte son ancre")

func _test_remembered_enemy_reappearance_and_adaptations() -> void:
    RemanenceRuntime.reset_new_game()
    var director := _world_director()
    if director == null:
        _expect(false, "Le directeur mondial est requis pour la réapparition")
        return
    director.call("reset_new_game")
    var remembered := {"id": 8, "species_id": "traque_suie", "name": "Traque-Suie ancien", "hp": 20, "max_hp": 20, "damage": [3, 5]}
    var entity_id := RemanenceRuntime.prepare_enemy(remembered, "premier_voile")
    RemanenceRuntime.note_encounter(remembered, "premier_voile")
    RemanenceRuntime.record_enemy_event(remembered, "major_mutilation", {"object_id": "arm_right", "summary": "Bras droit perdu"})
    var record: Dictionary = RemanenceRuntime.entities[entity_id]
    record["stage"] = "nemesis"
    record["status"] = "active"
    record["protected"] = true
    record["score"] = 24
    record["body_snapshot"] = {
        "dismembered_parts": ["arm_right"],
        "anatomy_injuries": {"arm_right": "critical"},
        "anatomy_part_states": {"arm_right": "lost"},
        "anatomy_part_trauma": {"arm_right": 100},
        "persistent_injuries": [],
        "body_state": {}
    }
    RemanenceRuntime.entities[entity_id] = record
    _expect(RemanenceRuntime.add_adaptation(entity_id, "guard_old_wound"), "Un Némésis doit pouvoir protéger une ancienne mutilation")
    _expect(RemanenceRuntime.add_adaptation(entity_id, "seal_resistance"), "Un Némésis doit pouvoir mémoriser le sceau de capture")

    var fresh := {"id": 8, "species_id": "traque_suie", "name": "Traque-Suie", "hp": 20, "max_hp": 20, "damage": [3, 5]}
    var baseline_chance := CreatureManager.capture_chance(fresh)
    var enemies: Array = [fresh]
    var assigned: Array = director.call("prepare_battle", enemies, {"region_id": "premier_voile", "zone_id": "premier_voile", "combat_id": "smoke_reappearance"})
    _expect(assigned.has(entity_id), "Un Némésis compatible doit réapparaître avec son EntityID")
    _expect(str(fresh.get("remanence_id", "")) == entity_id, "La nouvelle instance physique doit reprendre l'identité mémorielle")
    _expect((fresh.get("dismembered_parts", []) as Array).has("arm_right"), "Une mutilation mémorisée doit survivre entre deux rencontres")
    _expect(str(fresh.get("protected_anatomy_part", "")) == "arm_right", "L'adaptation doit protéger l'ancienne plaie")
    _expect(CreatureManager.capture_chance(fresh) < baseline_chance, "La mémoire d'un sceau raté doit réduire la chance de capture")

    fresh["remanence_target_mode"] = "weakest"
    fresh["remanence_damage_multiplier"] = 1.10
    var heroes: Array = [
        {"id": "strong", "hp": 20, "max_hp": 20},
        {"id": "weak", "hp": 4, "max_hp": 20}
    ]
    var action := EnemyCombatDirector.choose_action(fresh, heroes)
    _expect(int(action.get("target_index", -1)) == 1, "Un adversaire adapté doit pouvoir cibler le Veilleur le plus vulnérable")
    _expect(float(action.get("power", 1.0)) > 0.0, "La modification mémorielle ne doit jamais produire une action invalide")

    fresh["enemy_fear"] = 30
    fresh["remanence_fear_resistance"] = 15
    _expect(str(EnemyFearDirector.combat_modifiers(fresh).get("state", "")) == "calm", "L'endurcissement mémoriel doit réduire la Peur effective")

func _test_proxy_room_materializes_scars() -> void:
    var scar: Dictionary = {
        "id": "scar:smoke:000001",
        "anchor_id": "accord.gallery.memorial_floor",
        "type": "persistent_corpse",
        "severity": "local",
        "summary": "Un corps demeure ici.",
        "payload": {"owner_name": "Témoin de fumée", "owner_kind": "enemy"}
    }
    var room := PROXY_ROOM_SCRIPT.new() as Node3D
    add_child(room)
    room.configure({
        "id": "smoke_room",
        "dimensions_m": Vector3(12.0, 5.0, 10.0),
        "proxy": {"role": "combat"},
        "ports": [],
        "anchors": {"hero_spawn": Vector3.ZERO},
        "interaction_points": [],
        "remanence_scars": [scar],
        "global_geometry": {"wall": 0.4, "floor": 0.25, "door": [2.4, 3.2]}
    }, [], false)
    var scars_root := room.get_node_or_null("RemanenceScars")
    _expect(scars_root != null and scars_root.get_child_count() >= 2, "Une salle proxy doit matérialiser la cicatrice sans asset PC définitif")
    var nearest: Dictionary = room.nearest_interaction_for(room.global_position, 20.0)
    _expect(str(nearest.get("id", "")) == "scar:smoke:000001", "Le proxy de cadavre doit être examinable par l'explorateur")
    room.queue_free()

func _test_archives_ui() -> void:
    _expect(RemanenceArchivesUI.panel != null, "L'interface des Archives doit être construite")
    if RemanenceArchivesUI.panel == null:
        return
    RemanenceArchivesUI.open_archives()
    _expect(RemanenceArchivesUI.panel.visible, "Les Archives doivent pouvoir être ouvertes")
    _expect(RemanenceArchivesUI.search != null and RemanenceArchivesUI.stage_filter != null and RemanenceArchivesUI.status_filter != null, "Les Archives doivent proposer recherche et filtres tactiles")
    RemanenceArchivesUI._switch_mode("entities")
    RemanenceArchivesUI._on_search_changed("traque")
    _expect(RemanenceArchivesUI.list != null, "La recherche des Archives doit rester disponible après filtrage")
    RemanenceArchivesUI._on_search_changed("")
    RemanenceArchivesUI.close_archives()
    _expect(not RemanenceArchivesUI.panel.visible, "Les Archives doivent pouvoir être refermées")

func _corpse_for_origin(origin_id: String) -> String:
    for value: Variant in RemanenceRuntime.world_scars.values():
        if not (value is Dictionary):
            continue
        var scar: Dictionary = value
        if str(scar.get("type", "")) == "persistent_corpse" and str(scar.get("payload", {}).get("owner_id", "")) == origin_id:
            return str(scar.get("id", ""))
    return ""

func _has_event(entity_id: String, event_type: String) -> bool:
    for event: Dictionary in RemanenceRuntime.recent_events(entity_id, 32):
        if str(event.get("type", "")) == event_type:
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
