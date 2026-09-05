extends Node

const RoomPersistenceAssembler := preload("res://scripts/core/veilleurs_room_persistence_assembler.gd")
const HybridDungeonGenerator := preload("res://scripts/core/hybrid_dungeon_generator.gd")
const SpeciesKnowledge := preload("res://scripts/core/species_knowledge_runtime.gd")

var failures: Array[String] = []
var assembler: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    RemanenceRuntime.reset_new_game()
    assembler = RoomPersistenceAssembler.new()
    _seed_archived_trace()
    _test_room_projection_with_corpse_nemesis_and_knowledge()
    _test_hybrid_generator_projects_graph_bound_scar()
    _finish()

func _seed_archived_trace() -> void:
    RemanenceRuntime.create_world_scar("test.room.anchor", "old_blood", "trace", {
        "room_id": "room_memory",
        "summary": "Une ancienne lutte n'est plus qu'une trace sèche."
    })
    for _index in range(10):
        RemanenceRuntime.advance_expedition_cycle()
    _check(RemanenceRuntime.archived_scars.size() >= 1, "RoomPersistence : une Rémanence mineure ancienne doit pouvoir être compressée en trace archivée")

func _test_room_projection_with_corpse_nemesis_and_knowledge() -> void:
    var room := {
        "id": "room_memory",
        "template_id": "template_memory",
        "graph_key": "approach",
        "scar_anchors": ["test.room.anchor"],
        "environment_tags": [],
        "hand_authored_geometry": true,
        "geometry_policy": "immutable_authored"
    }

    var corpse_id := RemanenceRuntime.create_world_scar("test.room.anchor", "persistent_corpse", "regional", {
        "room_id": "room_memory",
        "owner_kind": "watcher",
        "owner_name": "Veilleur tombé",
        "body_snapshot": {"persistent_injuries": [{"id":"leg_fracture","severity":"critical"}]},
        "summary": "Le corps d'un Veilleur demeure dans la salle."
    })
    _check(corpse_id != "", "RoomPersistence : le cadavre persistant de test doit être créé")
    RemanenceRuntime.create_world_scar("test.room.anchor", "opened_shortcut", "local", {"room_id":"room_memory","summary":"Un ancien passage reste ouvert."})
    RemanenceRuntime.create_world_scar("test.room.anchor", "burned_area", "local", {"room_id":"room_memory","summary":"Le sol porte encore une brûlure."})
    RemanenceRuntime.create_world_scar("test.room.anchor", "old_blood", "trace", {"room_id":"room_memory","summary":"Du sang ancien marque les dalles."})
    RemanenceRuntime.create_world_scar("test.room.anchor", "old_blood", "trace", {"room_id":"room_memory","summary":"Une seconde traînée subsiste."})
    RemanenceRuntime.create_world_scar("test.room.anchor", "old_blood", "trace", {"room_id":"room_memory","summary":"Une troisième traînée subsiste."})

    var memory_enemy := {
        "species_id": "Délié Affamé",
        "name": "Délié Affamé",
        "hp": 24,
        "max_hp": 24,
        "damage": [4, 7],
        "persistent_injuries": [{"id":"eye_loss","severity":"critical","permanent":true}],
        "body_state": {"right_eye":"lost"}
    }
    var entity_id := RemanenceRuntime.prepare_enemy(memory_enemy, "act_i")
    RemanenceRuntime.record_event(entity_id, "encountered", {"region_id":"act_i"})
    RemanenceRuntime.record_event(entity_id, "reencountered", {"region_id":"act_i"})
    RemanenceRuntime.record_event(entity_id, "killed_watcher", {"region_id":"act_i"})
    RemanenceRuntime.record_event(entity_id, "reencountered", {"region_id":"act_i"})
    RemanenceRuntime.record_event(entity_id, "killed_watcher", {"region_id":"act_i"})
    RemanenceRuntime.record_event(entity_id, "reencountered", {"region_id":"act_i"})
    RemanenceRuntime.record_event(entity_id, "relic_taken", {"region_id":"act_i"})
    RemanenceRuntime.record_event(entity_id, "killed_watcher", {"region_id":"act_i"})
    RemanenceRuntime.sync_body_snapshot(memory_enemy)
    var entity_state: Dictionary = RemanenceRuntime.entity_state(entity_id)
    _check(str(entity_state.get("stage", "")) == "nemesis", "RoomPersistence : un ennemi ayant assez d'histoire partagée doit atteindre le stade Némésis")

    SpeciesKnowledge.record_evidence("Délié Affamé", "observation", {"evidence_key":"delie_obs_1","source":"field","summary":"Sa vitesse a été observée."})
    SpeciesKnowledge.record_evidence("Délié Affamé", "injury", {"evidence_key":"delie_obs_2","source":"corpse","summary":"Une blessure oculaire réduit sa lecture du terrain.","confirmed_facts":{"sensor_vulnerability":"eyes"}})
    SpeciesKnowledge.record_evidence("Délié Affamé", "behavior", {"evidence_key":"delie_obs_3","source":"field","summary":"Il privilégie les cibles blessées.","intent_family":"attack"})

    var encounter := {
        "template_id": "test_memory_encounter",
        "act_id": "I",
        "actors": [{
            "actor_id": "memory_actor_0",
            "species": "Délié Affamé",
            "hp": 20,
            "max_hp": 20,
            "damage": [3, 5]
        }]
    }
    var assembled: Dictionary = assembler.call("assemble_room", room, encounter, {
        "device_profile":"mobile",
        "combat_id":"room_memory_combat",
        "zone_id":"first_veil_crypts",
        "region_id":"act_i"
    })
    _check(bool(assembled.get("ok", false)), "RoomPersistence : la projection d'une salle valide doit réussir")
    var projected: Dictionary = assembled.get("room", {})
    var summary: Dictionary = assembled.get("summary", {})
    _check(bool(projected.get("hand_authored_geometry", false)) and str(projected.get("geometry_policy", "")) == "immutable_authored", "RoomPersistence : la Rémanence ne doit jamais remplacer la géométrie authored")
    _check(int(summary.get("active_scars", 99)) <= 4, "RoomPersistence : le budget mobile doit limiter les cicatrices visibles à quatre")
    _check(int(summary.get("interactive_scars", 99)) <= 2, "RoomPersistence : le budget mobile doit limiter les cicatrices interactives à deux")
    _check((projected.get("persistent_corpses", []) as Array).size() == 1, "RoomPersistence : le cadavre persistant doit être reconstruit depuis son snapshot")
    _check((projected.get("remanence_archived_traces", []) as Array).size() >= 1, "RoomPersistence : une ancienne conséquence compressée doit revenir sous forme de trace")
    _check((projected.get("environment_tags", []) as Array).has("corpse_memory"), "RoomPersistence : le cadavre doit modifier les tags environnementaux de la salle")
    _check(str(projected.get("remanence_route_state", "")) == "opened_shortcut", "RoomPersistence : une cicatrice de route doit conserver son état fonctionnel")

    var projected_encounter: Dictionary = assembled.get("encounter", {})
    var actors: Array = projected_encounter.get("actors", [])
    _check(actors.size() == 1, "RoomPersistence : la rencontre doit conserver son acteur")
    if actors.size() == 1 and actors[0] is Dictionary:
        var actor: Dictionary = actors[0]
        _check(str(actor.get("memory_stage", "")) == "nemesis", "RoomPersistence : le Némésis doit remplacer l'occurrence ordinaire de la même espèce")
        _check(str(actor.get("memory_entity_id", "")) == entity_id, "RoomPersistence : l'identité persistante du Némésis doit être conservée")
        _check((actor.get("persistent_injuries", []) as Array).size() == 1, "RoomPersistence : les blessures persistantes du Némésis doivent revenir avec lui")
        _check(int(actor.get("knowledge_level", 0)) == 2, "RoomPersistence : trois preuves doivent projeter le savoir collectif au niveau 2")
        _check(str((actor.get("knowledge_confirmed_facts", {}) as Dictionary).get("sensor_vulnerability", "")) == "eyes", "RoomPersistence : les faits confirmés du bestiaire doivent accompagner la rencontre")

func _test_hybrid_generator_projects_graph_bound_scar() -> void:
    RemanenceRuntime.create_world_scar("hybrid.approach.trace", "old_blood", "local", {
        "graph_key":"approach",
        "summary":"La salle d'approche conserve la trace d'une expédition précédente."
    })
    var generator: RefCounted = HybridDungeonGenerator.new()
    var result: Dictionary = generator.call("generate", 424242, "first_veil_crypts", {
        "visit_kind":"revisit",
        "device_profile":"mobile",
        "zone_id":"first_veil_crypts",
        "region_id":"act_i"
    })
    _check(bool(result.get("success", false)), "RoomPersistence : le générateur hybride doit rester valide après raccord Rémanence")
    _check(bool(result.get("room_persistence_projection", false)), "RoomPersistence : le générateur doit déclarer la projection salle par salle")
    var found_approach := false
    for room_value: Variant in result.get("layout", []):
        if not (room_value is Dictionary):
            continue
        var room: Dictionary = room_value
        if str(room.get("graph_key", "")) != "approach":
            continue
        found_approach = true
        _check(bool(room.get("persistence_projection_ready", false)), "RoomPersistence : la salle d'approche doit être passée par l'assembleur")
        _check((room.get("environment_tags", []) as Array).has("danger_memory"), "RoomPersistence : une cicatrice liée au graph_key doit modifier la salle générée")
        _check((room.get("remanence_scars", []) as Array).size() >= 1, "RoomPersistence : la cicatrice liée à la salle doit être visible dans sa projection")
        break
    _check(found_approach, "RoomPersistence : le graphe hybride doit toujours contenir sa salle d'approche")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_ROOM_PERSISTENCE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_ROOM_PERSISTENCE_SMOKE: " + failure)
    print("VEILLEURS_ROOM_PERSISTENCE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
