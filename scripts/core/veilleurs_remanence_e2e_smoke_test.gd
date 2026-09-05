extends Node

const HybridDungeonGenerator := preload("res://scripts/core/hybrid_dungeon_generator.gd")
const RoomPersistenceAssembler := preload("res://scripts/core/veilleurs_room_persistence_assembler.gd")

const DUNGEON_ID := "first_veil_crypts"
const REGION_ID := "act_i"
const OTHER_REGION_ID := "act_ii"
const SEED := 26090517
const SPECIES_ID := "hungry_ghoul"
const RELIC_ID := "relic:nayra_serment_001"

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    SaveManager.delete_qa_snapshot()
    GameState.reset_new_game()
    await get_tree().process_frame
    await get_tree().process_frame

    var generator: RefCounted = HybridDungeonGenerator.new()
    var first_run: Dictionary = generator.call("generate", SEED, DUNGEON_ID, {
        "visit_kind":"revisit",
        "device_profile":"mobile",
        "zone_id":DUNGEON_ID,
        "region_id":REGION_ID
    })
    _check(bool(first_run.get("success", false)), "E2E Rémanence : l'expédition initiale doit produire un donjon hybride valide")
    var first_room: Dictionary = _room_by_graph_key(first_run.get("layout", []), "approach")
    _check(not first_room.is_empty(), "E2E Rémanence : la salle approach doit exister lors de l'expédition initiale")
    if first_room.is_empty():
        _finish()
        return

    var target_enemy := {
        "id":"e2e_hungry_ghoul_target",
        "species_id":SPECIES_ID,
        "name":"La Gueule Fendue",
        "hp":31,
        "max_hp":52,
        "damage":[6, 10],
        "persistent_injuries":[{"id":"fracture_forearm","severity":"critical","functional_effect":"grip_impaired"}],
        "body_state":{"left_arm":"fractured"},
        "dismembered_parts":[]
    }
    var target_id: String = _promote_to_nemesis(target_enemy, REGION_ID, 0)
    _check(target_id != "", "E2E Rémanence : le Némésis cible doit posséder une identité persistante")
    _check(str(RemanenceRuntime.entity_state(target_id).get("stage", "")) == "nemesis", "E2E Rémanence : le Némésis cible doit atteindre le stade Némésis par des événements réels")
    RemanenceRuntime.sync_body_snapshot(target_enemy)

    # Un second Némésis de la même espèce est volontairement beaucoup plus haut en score.
    # Sans verrou d'identité, le directeur générique le choisirait avant la cible demandée.
    var decoy_enemy := {
        "id":"e2e_hungry_ghoul_decoy",
        "species_id":SPECIES_ID,
        "name":"Le Mange-Sceaux",
        "hp":49,
        "max_hp":49,
        "damage":[7, 11],
        "persistent_injuries":[],
        "body_state":{},
        "dismembered_parts":[]
    }
    var decoy_id: String = _promote_to_nemesis(decoy_enemy, OTHER_REGION_ID, 48)
    _check(decoy_id != "" and decoy_id != target_id, "E2E Rémanence : le leurre doit être un second individu distinct")
    _check(str(RemanenceRuntime.entity_state(decoy_id).get("stage", "")) == "nemesis", "E2E Rémanence : le leurre doit lui aussi être un Némésis valide")
    _check(int(RemanenceRuntime.entity_state(decoy_id).get("score", 0)) > int(RemanenceRuntime.entity_state(target_id).get("score", 0)) + 100, "E2E Rémanence : le leurre doit dominer volontairement le classement générique")

    var world_director: Node = RemanenceCombatBridge.world_director
    _check(world_director != null, "E2E Rémanence : le directeur mondial réel doit être disponible")
    if world_director == null:
        _finish()
        return

    var target_mark_id: String = _nemesis_mark_for(target_id)
    if target_mark_id == "":
        target_mark_id = str(world_director.call("create_nemesis_mark", target_id, {"region_id":REGION_ID,"zone_id":DUNGEON_ID}))
    _check(target_mark_id != "", "E2E Rémanence : le Némésis cible doit laisser une marque persistante")

    var fallen_watcher := {
        "id":"nayra_orun",
        "name":"Nayra Orun",
        "hp":0,
        "max_hp":100,
        "persistent_injuries":[{"id":"fatal_thoracic_wound","severity":"critical"}],
        "body_state":{"thorax":"fatal"},
        "dismembered_parts":[]
    }
    var corpse_scar_id: String = str(world_director.call("create_corpse_scar", fallen_watcher, false, {
        "region_id":REGION_ID,
        "zone_id":DUNGEON_ID,
        "combat_id":"e2e_first_encounter",
        "summary":"Nayra Orun tombe face à La Gueule Fendue."
    }))
    _check(corpse_scar_id != "", "E2E Rémanence : la mort de Nayra doit créer un cadavre mémoriel réel")

    RemanenceRuntime.record_event(target_id, "killed_watcher", {
        "region_id":REGION_ID,
        "zone_id":DUNGEON_ID,
        "hero_id":"nayra_orun",
        "summary":"La Gueule Fendue abat Nayra Orun."
    })
    RemanenceRuntime.record_event(target_id, "relic_taken", {
        "region_id":REGION_ID,
        "zone_id":DUNGEON_ID,
        "hero_id":"nayra_orun",
        "object_id":RELIC_ID,
        "summary":"La Gueule Fendue emporte la relique de Nayra."
    })
    RemanenceRuntime.link_archive_nodes(target_id, "hero:nayra_orun", "killed", {"room_key":"approach"})
    RemanenceRuntime.link_archive_nodes(target_id, RELIC_ID, "relic_taken", {"owner":"nayra_orun","room_key":"approach"})

    var item_scar_id: String = RemanenceRuntime.create_world_scar("e2e.nayra.relic", "major_item_removed", "regional", {
        "region_id":REGION_ID,
        "zone_id":DUNGEON_ID,
        "object_id":RELIC_ID,
        "origin_entity_id":target_id,
        "origin_hero_id":"nayra_orun",
        "summary":"La relique de Nayra n'est plus sur le lieu de sa mort."
    })
    var burn_scar_id: String = RemanenceRuntime.create_world_scar("e2e.approach.burn", "burned_area", "local", {
        "region_id":REGION_ID,
        "zone_id":DUNGEON_ID,
        "origin_entity_id":target_id,
        "summary":"Le combat a noirci une partie de la salle."
    })

    var binder: RefCounted = RoomPersistenceAssembler.new()
    for scar_id: String in [target_mark_id, corpse_scar_id, item_scar_id, burn_scar_id]:
        _check(bool(binder.call("bind_scar_to_room", scar_id, first_room)), "E2E Rémanence : chaque conséquence doit être liée à la salle approach")

    _check(_link_exists(target_id, "hero:nayra_orun", "killed"), "E2E Rémanence : les Archives doivent relier le meurtrier à Nayra")
    _check(_link_exists(target_id, RELIC_ID, "relic_taken"), "E2E Rémanence : les Archives doivent relier le Némésis à la relique emportée")
    _check(_event_with_object_exists(target_id, RELIC_ID), "E2E Rémanence : la chronologie doit conserver l'identité de la relique")

    # Fin réelle d'expédition : les traces vieillissent, puis l'état complet est sauvegardé.
    RemanenceRuntime.advance_expedition_cycle()
    _check(RemanenceRuntime.run_index == 1, "E2E Rémanence : la fin d'expédition doit avancer le cycle de Rémanence")
    _check(SaveManager.save_qa_snapshot(), "E2E Rémanence : la sauvegarde disque réelle doit réussir")

    var expected_target_state: Dictionary = RemanenceRuntime.entity_state(target_id)
    var expected_decoy_state: Dictionary = RemanenceRuntime.entity_state(decoy_id)
    var expected_links: int = RemanenceRuntime.archive_links.size()
    var expected_events: int = RemanenceRuntime.event_timeline.size()

    # Simulation d'une fermeture/reprise : on détruit les états de session avant de relire le disque.
    GameState.reset_new_game()
    await get_tree().process_frame
    await get_tree().process_frame
    _check(RemanenceRuntime.entity_state(target_id).is_empty(), "E2E Rémanence : le reset doit réellement effacer le Némésis avant reload")
    _check(not RemanenceRuntime.world_scars.has(corpse_scar_id), "E2E Rémanence : le reset doit réellement effacer le cadavre avant reload")

    _check(SaveManager.load_qa_snapshot(), "E2E Rémanence : la sauvegarde doit se recharger depuis le disque")
    _check(RemanenceRuntime.run_index == 1, "E2E Rémanence : le numéro d'expédition doit survivre au reload")
    _check(RemanenceRuntime.entity_state(target_id) == expected_target_state, "E2E Rémanence : l'individu cible doit revenir avec exactement le même état mémoriel")
    _check(RemanenceRuntime.entity_state(decoy_id) == expected_decoy_state, "E2E Rémanence : le second Némésis doit lui aussi survivre au reload")
    _check(RemanenceRuntime.archive_links.size() == expected_links, "E2E Rémanence : les liens des Archives doivent survivre au reload")
    _check(RemanenceRuntime.event_timeline.size() == expected_events, "E2E Rémanence : la chronologie doit survivre au reload")
    _check(RemanenceRuntime.world_scars.has(corpse_scar_id), "E2E Rémanence : le cadavre de Nayra doit survivre au reload")
    _check(RemanenceRuntime.world_scars.has(target_mark_id), "E2E Rémanence : la marque du Némésis cible doit survivre au reload")

    var revisit_generator: RefCounted = HybridDungeonGenerator.new()
    var revisit: Dictionary = revisit_generator.call("generate", SEED, DUNGEON_ID, {
        "visit_kind":"revisit",
        "device_profile":"mobile",
        "zone_id":DUNGEON_ID,
        "region_id":REGION_ID
    })
    _check(bool(revisit.get("success", false)), "E2E Rémanence : la nouvelle expédition doit reconstruire un donjon valide")
    var revisit_room: Dictionary = _room_by_graph_key(revisit.get("layout", []), "approach")
    _check(not revisit_room.is_empty(), "E2E Rémanence : la même salle logique approach doit être reconstruite")
    _check((revisit_room.get("environment_tags", []) as Array).has("corpse_memory"), "E2E Rémanence : la salle revisitée doit matérialiser le souvenir du cadavre")
    _check((revisit_room.get("environment_tags", []) as Array).has("nemesis_trace"), "E2E Rémanence : la salle revisitée doit matérialiser la marque du Némésis")
    _check((revisit_room.get("environment_tags", []) as Array).has("burned_area"), "E2E Rémanence : la salle revisitée doit conserver la brûlure du premier combat")
    _check(str(revisit_room.get("remanence_resource_state", "")) == "removed", "E2E Rémanence : l'absence de la relique doit rester visible comme état de ressource")
    _check(str(revisit_room.get("nemesis_entity_id", "")) == target_id, "E2E Rémanence : la marque de salle doit exiger l'ID exact du Némésis cible")
    _check((revisit_room.get("persistent_corpses", []) as Array).size() >= 1, "E2E Rémanence : le corps de Nayra doit être reconstructible sans resimuler son ragdoll")

    var encounter := {
        "template_id":"e2e_revisit_encounter",
        "act_id":REGION_ID,
        "actors":[
            {"id":"ghoul_shell_target","species_id":SPECIES_ID,"name":"Goule affamée","hp":52,"max_hp":52,"damage":[6,10]},
            {"id":"ghoul_shell_other","species_id":SPECIES_ID,"name":"Goule affamée","hp":52,"max_hp":52,"damage":[6,10]}
        ]
    }
    var assembler: RefCounted = RoomPersistenceAssembler.new()
    var projected: Dictionary = assembler.call("assemble_room", revisit_room, encounter, {
        "device_profile":"mobile",
        "dungeon_id":DUNGEON_ID,
        "zone_id":DUNGEON_ID,
        "region_id":REGION_ID,
        "combat_id":"e2e_revisit_encounter"
    })
    _check(bool(projected.get("ok", false)), "E2E Rémanence : la salle revisitée doit accepter une rencontre réelle")
    var projected_encounter: Dictionary = projected.get("encounter", {})
    var actors: Array = projected_encounter.get("actors", [])
    _check(actors.size() == 2, "E2E Rémanence : la rencontre revisitée doit conserver ses deux emplacements")
    if actors.size() >= 2:
        var exact_actor: Dictionary = actors[0]
        var generic_actor: Dictionary = actors[1]
        _check(str(exact_actor.get("remanence_id", "")) == target_id, "E2E Rémanence : l'emplacement verrouillé doit restaurer La Gueule Fendue, même face à un meilleur candidat générique")
        _check(bool(exact_actor.get("remanence_identity_locked", false)), "E2E Rémanence : l'identité exacte doit être explicitement verrouillée")
        _check(str(exact_actor.get("memory_stage", exact_actor.get("remanence_stage", ""))) == "nemesis", "E2E Rémanence : l'individu restauré doit conserver son stade Némésis")
        _check(_has_injury(exact_actor, "fracture_forearm"), "E2E Rémanence : le Némésis restauré doit conserver sa fracture du premier combat")
        _check(str(generic_actor.get("remanence_id", "")) != target_id, "E2E Rémanence : le Némésis exact ne doit pas être dupliqué dans un second emplacement générique")
        _check(str(generic_actor.get("remanence_id", "")) == decoy_id, "E2E Rémanence : le meilleur candidat générique peut occuper l'autre emplacement sans remplacer l'identité requise")
    _check(str(projected_encounter.get("required_nemesis_entity_id", "")) == target_id, "E2E Rémanence : la rencontre doit exposer l'identité Némésis requise")
    _check(bool(projected_encounter.get("required_nemesis_resolved", false)), "E2E Rémanence : la contrainte d'identité Némésis doit être résolue")

    # Les Veilleurs reviennent sur les traces : le corps est reconnu et la relique est récupérée.
    var corpse_visit: Dictionary = world_director.call("visit_scar", corpse_scar_id)
    var relic_visit: Dictionary = world_director.call("visit_scar", item_scar_id)
    _check(bool(corpse_visit.get("ok", false)), "E2E Rémanence : le corps de Nayra doit pouvoir être revisité")
    _check(bool(relic_visit.get("ok", false)), "E2E Rémanence : la trace de la relique doit pouvoir être revisitée")
    RemanenceRuntime.link_archive_nodes("hero:tarek_senn", RELIC_ID, "relic_recovered", {
        "room_key":"approach",
        "from_entity_id":target_id,
        "run_index":RemanenceRuntime.run_index
    })
    RemanenceRuntime.link_archive_nodes("hero:tarek_senn", "hero:nayra_orun", "corpse_found", {
        "scar_id":corpse_scar_id,
        "run_index":RemanenceRuntime.run_index
    })
    _check(_link_exists("hero:tarek_senn", RELIC_ID, "relic_recovered"), "E2E Rémanence : les Archives doivent enregistrer la récupération de la relique")
    _check(_link_exists("hero:tarek_senn", "hero:nayra_orun", "corpse_found"), "E2E Rémanence : les Archives doivent enregistrer la redécouverte du corps de Nayra")
    _check(RemanenceRuntime.linked_entries(target_id).size() >= 2, "E2E Rémanence : la fiche du Némésis doit rester reliée à son histoire")
    _check(RemanenceRuntime.linked_entries("hero:nayra_orun").size() >= 2, "E2E Rémanence : la fiche de Nayra doit rester reliée au meurtre et au corps retrouvé")

    _finish()

func _promote_to_nemesis(enemy: Dictionary, region_id: String, extra_relic_events: int) -> String:
    for encounter_index in range(4):
        RemanenceRuntime.note_encounter(enemy, region_id, {
            "zone_id":DUNGEON_ID,
            "combat_id":"e2e_%s_%d" % [str(enemy.get("id", "enemy")), encounter_index],
            "summary":"Rencontre persistante %d avec %s." % [encounter_index + 1, str(enemy.get("name", "l'adversaire"))]
        })
    var entity_id: String = str(enemy.get("remanence_id", ""))
    RemanenceRuntime.record_event(entity_id, "survived_combat", {"region_id":region_id,"zone_id":DUNGEON_ID})
    RemanenceRuntime.record_event(entity_id, "major_mutilation", {"region_id":region_id,"zone_id":DUNGEON_ID,"object_id":"forearm"})
    RemanenceRuntime.record_event(entity_id, "capture_escaped", {"region_id":region_id,"zone_id":DUNGEON_ID})
    RemanenceRuntime.record_event(entity_id, "forced_retreat", {"region_id":region_id,"zone_id":DUNGEON_ID})
    RemanenceRuntime.record_event(entity_id, "killed_watcher", {"region_id":region_id,"zone_id":DUNGEON_ID,"hero_id":"test_watcher"})
    RemanenceRuntime.record_event(entity_id, "relic_taken", {"region_id":region_id,"zone_id":DUNGEON_ID,"object_id":"relic:test"})
    RemanenceRuntime.record_event(entity_id, "great_remanence", {"region_id":region_id,"zone_id":DUNGEON_ID})
    for extra_index in range(extra_relic_events):
        RemanenceRuntime.record_event(entity_id, "relic_taken", {
            "region_id":region_id,
            "zone_id":DUNGEON_ID,
            "object_id":"relic:decoy_%02d" % extra_index
        })
    return entity_id

func _room_by_graph_key(layout: Array, graph_key: String) -> Dictionary:
    for value: Variant in layout:
        if value is Dictionary and str((value as Dictionary).get("graph_key", "")) == graph_key:
            return (value as Dictionary).duplicate(true)
    return {}

func _nemesis_mark_for(entity_id: String) -> String:
    for key_value: Variant in RemanenceRuntime.world_scars.keys():
        var scar_id := str(key_value)
        var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
        if str(scar.get("type", "")) != "nemesis_mark":
            continue
        if str(scar.get("origin_entity_id", "")) == entity_id:
            return scar_id
        var payload: Dictionary = scar.get("payload", {})
        if str(payload.get("origin_entity_id", "")) == entity_id:
            return scar_id
    return ""

func _link_exists(source_id: String, target_id: String, relation: String) -> bool:
    for value: Variant in RemanenceRuntime.archive_links:
        if not (value is Dictionary):
            continue
        var link: Dictionary = value
        if str(link.get("source_id", "")) == source_id and str(link.get("target_id", "")) == target_id and str(link.get("relation", "")) == relation:
            return true
    return false

func _event_with_object_exists(entity_id: String, object_id: String) -> bool:
    for event: Dictionary in RemanenceRuntime.recent_events(entity_id, 220):
        if str(event.get("object_id", "")) == object_id:
            return true
    return false

func _has_injury(character: Dictionary, injury_id: String) -> bool:
    for value: Variant in character.get("persistent_injuries", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == injury_id:
            return true
    return false

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    SaveManager.delete_qa_snapshot()
    if failures.is_empty():
        print("VEILLEURS_REMANENCE_E2E_SMOKE_OK target_exact=true save_reload=true room_revisit=true archives=true")
        get_tree().quit(0)
        return
    for failure: String in failures.slice(0, mini(60, failures.size())):
        push_error("VEILLEURS_REMANENCE_E2E_SMOKE: " + failure)
    print("VEILLEURS_REMANENCE_E2E_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
