extends RefCounted

const RULES_PATH := "res://data/remanence_world_rules.json"
const WorldDirectorScript := preload("res://scripts/core/remanence_world_director.gd")
const CorpseState := preload("res://scripts/core/corpse_state_runtime.gd")
const SpeciesKnowledge := preload("res://scripts/core/species_knowledge_runtime.gd")

var rules: Dictionary = {}
var world_director: Node

func _init() -> void:
    rules = _load_dictionary(RULES_PATH)
    world_director = WorldDirectorScript.new()
    world_director.call("_load_data")

func assemble_room(room: Dictionary, encounter: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
    if room.is_empty():
        return {"ok": false, "reason": "room_missing"}

    var output_room: Dictionary = room.duplicate(true)
    var output_encounter: Dictionary = encounter.duplicate(true)
    var budget: Dictionary = _proxy_budget(str(context.get("device_profile", "mobile")))
    var max_visible: int = int(budget.get("max_visible_scars_per_room", 4))
    var max_interactive: int = int(budget.get("max_interactive_scars_per_room", 2))

    var active_candidates: Array[Dictionary] = _matching_active_scars(output_room)
    var visible_scars: Array[Dictionary] = []
    var persistent_corpses: Array[Dictionary] = []
    var interactive_count: int = 0

    for scar: Dictionary in active_candidates:
        if visible_scars.size() >= max_visible:
            break
        var scar_type: String = str(scar.get("type", ""))
        if scar_type == "species_knowledge":
            continue
        var effect: Dictionary = (rules.get("scar_effects", {}) as Dictionary).get(scar_type, {})
        var interactive: bool = bool(effect.get("interaction", false))
        if interactive and interactive_count >= max_interactive:
            continue
        visible_scars.append(scar.duplicate(true))
        if interactive:
            interactive_count += 1
        _apply_scar_effect(output_room, scar, effect)
        if scar_type == "persistent_corpse":
            var reconstruction: Dictionary = CorpseState.reconstruct(str(scar.get("id", "")))
            if bool(reconstruction.get("ok", false)):
                persistent_corpses.append(reconstruction)

    var archived_traces: Array[Dictionary] = _matching_archived_traces(output_room, 4 if _is_pc_profile(str(context.get("device_profile", "mobile"))) else 2)
    var actor_result: Dictionary = _assemble_encounter_actors(output_room, output_encounter, context)
    output_encounter = actor_result.get("encounter", output_encounter)

    output_room["remanence_scars"] = visible_scars
    output_room["persistent_corpses"] = persistent_corpses
    output_room["remanence_archived_traces"] = archived_traces
    output_room["persistence_projection_ready"] = true
    output_room["persistence_projection"] = {
        "active_scars": visible_scars.size(),
        "interactive_scars": interactive_count,
        "persistent_corpses": persistent_corpses.size(),
        "archived_traces": archived_traces.size(),
        "remembered_enemies": int(actor_result.get("remembered_enemies", 0)),
        "nemesis_enemies": int(actor_result.get("nemesis_enemies", 0)),
        "knowledge_profiles": int(actor_result.get("knowledge_profiles", 0)),
        "required_nemesis_entity_id": str(actor_result.get("required_nemesis_entity_id", output_room.get("nemesis_entity_id", ""))),
        "required_nemesis_resolved": bool(actor_result.get("required_nemesis_resolved", str(output_room.get("nemesis_entity_id", "")) == "")),
        "device_profile": str(context.get("device_profile", "mobile")),
        "consequence_over_mesh": true
    }

    return {
        "ok": true,
        "room": output_room,
        "encounter": output_encounter,
        "summary": (output_room.get("persistence_projection", {}) as Dictionary).duplicate(true)
    }

func assemble_layout(layout: Array, encounters_by_room: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
    var output: Array = []
    var total_scars: int = 0
    var total_corpses: int = 0
    var total_memorials: int = 0
    var total_nemeses: int = 0
    var total_knowledge: int = 0

    for room_value: Variant in layout:
        if not (room_value is Dictionary):
            continue
        var room: Dictionary = room_value
        var room_id: String = str(room.get("id", ""))
        var encounter_value: Variant = encounters_by_room.get(room_id, {})
        var encounter: Dictionary = encounter_value if encounter_value is Dictionary else {}
        var room_context: Dictionary = context.duplicate(true)
        room_context["room_id"] = room_id
        var assembled: Dictionary = assemble_room(room, encounter, room_context)
        if not bool(assembled.get("ok", false)):
            output.append(room.duplicate(true))
            continue
        var assembled_room: Dictionary = assembled.get("room", room)
        var summary: Dictionary = assembled.get("summary", {})
        output.append(assembled_room)
        total_scars += int(summary.get("active_scars", 0))
        total_corpses += int(summary.get("persistent_corpses", 0))
        total_memorials += int(summary.get("remembered_enemies", 0))
        total_nemeses += int(summary.get("nemesis_enemies", 0))
        total_knowledge += int(summary.get("knowledge_profiles", 0))
        if not encounter.is_empty():
            encounters_by_room[room_id] = (assembled.get("encounter", encounter) as Dictionary).duplicate(true)

    return {
        "ok": not output.is_empty(),
        "layout": output,
        "encounters_by_room": encounters_by_room.duplicate(true),
        "summary": {
            "rooms": output.size(),
            "active_scars": total_scars,
            "persistent_corpses": total_corpses,
            "remembered_enemies": total_memorials,
            "nemesis_enemies": total_nemeses,
            "knowledge_profiles": total_knowledge,
            "mobile_archive_compression_supported": true
        }
    }

func bind_scar_to_room(scar_id: String, room: Dictionary) -> bool:
    if scar_id == "" or not RemanenceRuntime.world_scars.has(scar_id) or room.is_empty():
        return false
    var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    var payload: Dictionary = (scar.get("payload", {}) as Dictionary).duplicate(true)
    payload["room_id"] = str(room.get("id", ""))
    payload["template_id"] = str(room.get("template_id", ""))
    payload["graph_key"] = str(room.get("graph_key", ""))
    payload["room_bound"] = true
    return RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})

func _assemble_encounter_actors(room: Dictionary, encounter: Dictionary, context: Dictionary) -> Dictionary:
    if encounter.is_empty():
        return {
            "encounter": encounter,
            "remembered_enemies": 0,
            "nemesis_enemies": 0,
            "knowledge_profiles": 0,
            "required_nemesis_entity_id": str(room.get("nemesis_entity_id", "")),
            "required_nemesis_resolved": str(room.get("nemesis_entity_id", "")) == ""
        }
    var actors_value: Variant = encounter.get("actors", [])
    if not (actors_value is Array):
        return {
            "encounter": encounter,
            "remembered_enemies": 0,
            "nemesis_enemies": 0,
            "knowledge_profiles": 0,
            "required_nemesis_entity_id": str(room.get("nemesis_entity_id", "")),
            "required_nemesis_resolved": str(room.get("nemesis_entity_id", "")) == ""
        }

    var actors: Array = (actors_value as Array).duplicate(true)
    for index in range(actors.size()):
        if not (actors[index] is Dictionary):
            continue
        var actor: Dictionary = actors[index]
        if str(actor.get("species_id", "")) == "":
            actor["species_id"] = str(actor.get("species", actor.get("id", "unknown")))
        actors[index] = actor

    var forced_nemesis_id: String = str(room.get("nemesis_entity_id", ""))
    var forced_result: Dictionary = {"resolved": forced_nemesis_id == "", "index": -1, "species_id": ""}
    if forced_nemesis_id != "":
        forced_result = _inject_specific_entity(actors, forced_nemesis_id)
        if not bool(forced_result.get("resolved", false)):
            var required_species_id: String = str(room.get("nemesis_species_id", forced_result.get("species_id", "")))
            _lock_required_species_slot(actors, required_species_id, forced_nemesis_id)

    var battle_context: Dictionary = {
        "combat_id": str(context.get("combat_id", encounter.get("template_id", room.get("id", "")))),
        "zone_id": str(context.get("zone_id", context.get("dungeon_id", ""))),
        "region_id": str(context.get("region_id", context.get("act_id", encounter.get("act_id", ""))))
    }

    # Une identité explicitement imposée par une Rémanence de salle ne doit jamais être
    # remplacée par le candidat générique le mieux classé de la même espèce. On ne passe
    # au directeur générique que les emplacements qui ne sont pas verrouillés.
    var generic_actors: Array = []
    var generic_indices: Array[int] = []
    for index in range(actors.size()):
        if not (actors[index] is Dictionary):
            continue
        var actor: Dictionary = actors[index]
        if bool(actor.get("remanence_identity_locked", false)):
            continue
        generic_indices.append(index)
        generic_actors.append(actor)
    if not generic_actors.is_empty():
        world_director.call("prepare_battle", generic_actors, battle_context)
        for generic_index in range(generic_indices.size()):
            actors[generic_indices[generic_index]] = generic_actors[generic_index]

    var remembered_count: int = 0
    var nemesis_count: int = 0
    var knowledge_count: int = 0
    for index in range(actors.size()):
        if not (actors[index] is Dictionary):
            continue
        var actor: Dictionary = actors[index]
        var remanence_id: String = str(actor.get("remanence_id", actor.get("memory_entity_id", "")))
        if remanence_id != "":
            remembered_count += 1
            actor["memory_entity_id"] = remanence_id
            actor["memory_stage"] = str(actor.get("remanence_stage", actor.get("memory_stage", "normal")))
            actor["memory_score"] = int(actor.get("remanence_score", actor.get("memory_score", 0)))
            if str(actor.get("memory_stage", "")) == "nemesis":
                nemesis_count += 1
                actor["nemesis_injected"] = true
        var species_id: String = str(actor.get("species_id", actor.get("species", "")))
        var knowledge: Dictionary = SpeciesKnowledge.confirmed_information(species_id)
        actor["knowledge_level"] = int(knowledge.get("knowledge_level", 0))
        actor["knowledge_confirmed_facts"] = (knowledge.get("confirmed_facts", {}) as Dictionary).duplicate(true)
        actor["knowledge_observed_intent_families"] = (knowledge.get("observed_intent_families", []) as Array).duplicate(true)
        actor["knowledge_mastered"] = bool(knowledge.get("mastered", false))
        knowledge_count += 1
        actors[index] = actor

    var forced_resolved: bool = bool(forced_result.get("resolved", forced_nemesis_id == ""))
    encounter["actors"] = actors
    encounter["room_persistence_applied"] = true
    encounter["remembered_enemy_count"] = remembered_count
    encounter["nemesis_enemy_count"] = nemesis_count
    encounter["knowledge_profile_count"] = knowledge_count
    encounter["required_nemesis_entity_id"] = forced_nemesis_id
    encounter["required_nemesis_resolved"] = forced_resolved
    if forced_nemesis_id != "" and not forced_resolved:
        encounter["persistence_blocked_reason"] = "required_nemesis_identity_unresolved"
    return {
        "encounter": encounter,
        "remembered_enemies": remembered_count,
        "nemesis_enemies": nemesis_count,
        "knowledge_profiles": knowledge_count,
        "required_nemesis_entity_id": forced_nemesis_id,
        "required_nemesis_resolved": forced_resolved
    }

func _inject_specific_entity(actors: Array, entity_id: String) -> Dictionary:
    var record: Dictionary = RemanenceRuntime.entity_state(entity_id)
    if record.is_empty() or str(record.get("status", "active")) != "active":
        return {"resolved": false, "index": -1, "species_id": str(record.get("species_id", ""))}
    var species_id: String = str(record.get("species_id", ""))
    for index in range(actors.size()):
        if not (actors[index] is Dictionary):
            continue
        var actor: Dictionary = actors[index]
        if str(actor.get("species_id", actor.get("species", ""))) != species_id:
            continue
        world_director.call("apply_entity_memory_to_enemy", actor, entity_id)
        actor["remanence_identity_locked"] = true
        actor["required_remanence_id"] = entity_id
        actor["required_remanence_resolved"] = true
        actors[index] = actor
        return {"resolved": true, "index": index, "species_id": species_id}
    return {"resolved": false, "index": -1, "species_id": species_id}

func _lock_required_species_slot(actors: Array, species_id: String, entity_id: String) -> void:
    if species_id == "":
        return
    for index in range(actors.size()):
        if not (actors[index] is Dictionary):
            continue
        var actor: Dictionary = actors[index]
        if str(actor.get("species_id", actor.get("species", ""))) != species_id:
            continue
        actor["remanence_identity_locked"] = true
        actor["required_remanence_id"] = entity_id
        actor["required_remanence_resolved"] = false
        actors[index] = actor
        return

func _matching_active_scars(room: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in RemanenceRuntime.world_scars.values():
        if not (value is Dictionary):
            continue
        var scar: Dictionary = value
        if _scar_matches_room(scar, room):
            result.append(scar.duplicate(true))
    result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return _scar_priority(left) > _scar_priority(right)
    )
    return result

func _matching_archived_traces(room: Dictionary, maximum: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var anchors_value: Variant = room.get("scar_anchors", [])
    var anchors: Array = anchors_value if anchors_value is Array else []
    if anchors.is_empty() or maximum <= 0:
        return result
    for value: Variant in RemanenceRuntime.archived_scars:
        if not (value is Dictionary):
            continue
        var trace: Dictionary = value
        if anchors.has(str(trace.get("anchor_id", ""))):
            result.append(trace.duplicate(true))
    result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left.get("age_runs", 0)) > int(right.get("age_runs", 0))
    )
    while result.size() > maximum:
        result.pop_back()
    return result

func _scar_matches_room(scar: Dictionary, room: Dictionary) -> bool:
    var scar_type: String = str(scar.get("type", ""))
    if scar_type == "species_knowledge":
        return false
    var anchor_id: String = str(scar.get("anchor_id", ""))
    var anchors_value: Variant = room.get("scar_anchors", [])
    var anchors: Array = anchors_value if anchors_value is Array else []
    if anchor_id != "" and anchors.has(anchor_id):
        return true

    var payload: Dictionary = scar.get("payload", {})
    var room_id: String = str(room.get("id", ""))
    var template_id: String = str(room.get("template_id", ""))
    var graph_key: String = str(room.get("graph_key", ""))
    if room_id != "" and str(payload.get("room_id", payload.get("generated_room_id", ""))) == room_id:
        return true
    if template_id != "" and str(payload.get("template_id", "")) == template_id:
        return true
    if graph_key != "" and str(payload.get("graph_key", payload.get("room_key", ""))) == graph_key:
        return true
    return false

func _apply_scar_effect(room: Dictionary, scar: Dictionary, effect: Dictionary) -> void:
    var tags_value: Variant = room.get("environment_tags", [])
    var tags: Array = tags_value if tags_value is Array else []
    for tag_value: Variant in effect.get("environment_tags", []):
        if not tags.has(tag_value):
            tags.append(tag_value)
    room["environment_tags"] = tags

    var route_state: String = str(effect.get("route_state", ""))
    if route_state != "":
        room["remanence_route_state"] = route_state
    var resource_state: String = str(effect.get("resource_state", ""))
    if resource_state != "":
        room["remanence_resource_state"] = resource_state
    if bool(effect.get("boost_nemesis_eligibility", false)):
        room["nemesis_eligible"] = true
        room["nemesis_trace"] = true
    if bool(effect.get("may_change_navigation", false)):
        room["remanence_navigation_change"] = true
    var scar_type: String = str(scar.get("type", ""))
    if scar_type == "persistent_corpse":
        room["corpse_interaction_available"] = true
    elif scar_type == "nemesis_mark":
        var payload: Dictionary = scar.get("payload", {})
        var entity_id: String = str(payload.get("nemesis_entity_id", scar.get("origin_entity_id", payload.get("origin_entity_id", ""))))
        if entity_id != "":
            room["nemesis_entity_id"] = entity_id
            room["nemesis_required"] = true
            room["nemesis_scar_id"] = str(scar.get("id", ""))
            var entity: Dictionary = RemanenceRuntime.entity_state(entity_id)
            var species_id: String = str(entity.get("species_id", payload.get("species_id", "")))
            if species_id != "":
                room["nemesis_species_id"] = species_id

func _proxy_budget(device_profile: String) -> Dictionary:
    var key: String = "pc_proxy_budget" if _is_pc_profile(device_profile) else "mobile_proxy_budget"
    var value: Variant = rules.get(key, {})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _is_pc_profile(device_profile: String) -> bool:
    return device_profile.to_lower() in ["pc", "desktop", "keyboard_mouse", "gamepad_pc"]

func _scar_priority(scar: Dictionary) -> int:
    var ranks: Dictionary = {"trace": 0, "local": 10, "regional": 20, "historical": 30}
    var priority: int = int(ranks.get(str(scar.get("severity", "trace")), 0))
    if bool(scar.get("protected", false)):
        priority += 100
    match str(scar.get("type", "")):
        "nemesis_mark": priority += 80
        "persistent_corpse": priority += 60
        "opened_shortcut", "destroyed_door": priority += 50
    return priority

func _load_dictionary(path: String) -> Dictionary:
    if path == "" or not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
