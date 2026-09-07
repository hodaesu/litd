extends RefCounted

static func on_recruited(enemy: Dictionary, creature: Dictionary) -> Dictionary:
    var output := creature.duplicate(true)
    var entity_id := str(enemy.get("remanence_id", ""))
    if entity_id == "" or not RemanenceRuntime.entities.has(entity_id):
        return {"creature": output, "memory_preserved": false}

    var record := RemanenceRuntime.entity_state(entity_id)
    var hostile_stage := str(record.get("stage", "normal"))
    var recent := RemanenceRuntime.recent_events(entity_id, 24)
    var killed_watchers: Array[String] = []
    var relic_ids: Array[String] = []
    var escaped_captures := 0
    for event: Dictionary in recent:
        match str(event.get("type", "")):
            "killed_watcher":
                var hero_id := str(event.get("hero_id", ""))
                if hero_id != "" and not killed_watchers.has(hero_id):
                    killed_watchers.append(hero_id)
            "relic_taken":
                var object_id := str(event.get("object_id", ""))
                if object_id != "" and not relic_ids.has(object_id):
                    relic_ids.append(object_id)
            "capture_escaped":
                escaped_captures += 1

    var compact_history: Array[Dictionary] = []
    for event: Dictionary in recent.slice(0, mini(12, recent.size())):
        compact_history.append({
            "seq": int(event.get("seq", 0)),
            "type": str(event.get("type", "")),
            "run_index": int(event.get("run_index", 0)),
            "hero_id": str(event.get("hero_id", "")),
            "object_id": str(event.get("object_id", "")),
            "summary": str(event.get("summary", ""))
        })

    var body_snapshot: Dictionary = record.get("body_snapshot", {})
    output["source_remanence_id"] = entity_id
    output["historical_hostile_stage"] = hostile_stage
    output["historical_score"] = int(record.get("score", 0))
    output["historical_encounters"] = int(record.get("encounters", 0))
    output["historical_major_events"] = int(record.get("major_events", 0))
    output["historical_region_id"] = str(record.get("region_id", ""))
    output["hostile_history_preserved"] = true
    output["former_nemesis"] = hostile_stage == "nemesis"
    output["allied_status"] = "former_nemesis" if hostile_stage == "nemesis" else "memorial_recruit"
    output["remanence_adaptations"] = (record.get("adaptations", []) as Array).duplicate(true)
    output["killed_watcher_ids"] = killed_watchers.duplicate()
    output["historical_relic_ids"] = relic_ids.duplicate()
    output["escaped_capture_count"] = escaped_captures
    output["hostile_history"] = compact_history
    output["remanence_relationships"] = _build_watcher_relationships(record, killed_watchers, relic_ids, escaped_captures)
    output["family_memory"] = {
        "origin_species_id": str(record.get("species_id", output.get("species_id", ""))),
        "origin_family_id": str(enemy.get("family_id", enemy.get("enemy_family_id", enemy.get("origin_family_id", "")))),
        "origin_region_id": str(record.get("region_id", "")),
        "former_nemesis": hostile_stage == "nemesis",
        "recognition_enabled": true,
        "betrayal_randomized": false
    }
    output["origin_family_id"] = str((output.get("family_memory", {}) as Dictionary).get("origin_family_id", ""))

    for key in ["persistent_injuries", "body_state", "dismembered_parts", "anatomy_injuries", "anatomy_part_states", "anatomy_part_trauma"]:
        var value: Variant = body_snapshot.get(key)
        if value is Array:
            output[key] = (value as Array).duplicate(true)
        elif value is Dictionary:
            output[key] = (value as Dictionary).duplicate(true)

    _preserve_hostile_skill_state(enemy, output)

    RemanenceRuntime.set_entity_status(entity_id, "recruited")
    var allied_record := RemanenceRuntime.entity_state(entity_id)
    allied_record["historical_stage"] = hostile_stage
    allied_record["allied_status"] = str(output.get("allied_status", "memorial_recruit"))
    allied_record["recruited_run"] = RemanenceRuntime.run_index
    allied_record["recruited_instance_id"] = str(output.get("instance_id", ""))
    allied_record["hostile_history_preserved"] = true
    allied_record["hostile_skill_state"] = (output.get("hostile_skill_state", {}) as Dictionary).duplicate(true)
    allied_record["three_tree_continuity"] = bool(output.get("three_tree_continuity", false))
    if hostile_stage == "nemesis":
        allied_record["stage"] = "former_nemesis"
    RemanenceRuntime.entities[entity_id] = allied_record
    RemanenceRuntime.link_archive_nodes(entity_id, "creature:%s" % str(output.get("instance_id", "")), "recruited_as", {
        "historical_stage": hostile_stage,
        "run_index": RemanenceRuntime.run_index,
        "killed_watchers": killed_watchers.duplicate(),
        "relic_ids": relic_ids.duplicate(),
        "specialization": str(output.get("specialization", "")),
        "unlocked_skills": (output.get("unlocked_skills", []) as Array).duplicate(true)
    })
    RemanenceRuntime.remanence_changed.emit()
    return {
        "creature": output,
        "memory_preserved": true,
        "entity_id": entity_id,
        "historical_stage": hostile_stage,
        "allied_status": str(output.get("allied_status", "")),
        "skill_state_preserved": bool(output.get("three_tree_continuity", false))
    }

static func family_reaction(creature: Dictionary, encountered_enemy: Dictionary) -> Dictionary:
    var family_memory: Dictionary = creature.get("family_memory", {})
    var origin_species := str(family_memory.get("origin_species_id", creature.get("species_id", "")))
    var encountered_species := str(encountered_enemy.get("species_id", encountered_enemy.get("species", "")))
    var same_species := origin_species != "" and origin_species == encountered_species
    var origin_family := str(creature.get("origin_family_id", family_memory.get("origin_family_id", "")))
    var encountered_family := str(encountered_enemy.get("family_id", encountered_enemy.get("enemy_family_id", "")))
    var same_family := origin_family != "" and origin_family == encountered_family
    if not same_species and not same_family:
        return {"applies": false, "reaction": "none", "telegraphed": false, "betrayal": false}

    var former_nemesis := bool(creature.get("former_nemesis", false))
    var killed_count := (creature.get("killed_watcher_ids", []) as Array).size()
    var reaction := "recognition"
    if former_nemesis:
        reaction = "recognition_shock"
    elif killed_count > 0:
        reaction = "hostile_recognition"
    return {
        "applies": true,
        "reaction": reaction,
        "telegraphed": true,
        "betrayal": false,
        "random_betrayal_allowed": false,
        "ally_keeps_player_control": true,
        "enemy_hesitation_window": 1 if former_nemesis else 0,
        "surrender_dialogue_available": former_nemesis,
        "shared_history": true,
        "former_nemesis": former_nemesis,
        "summary": "%s est reconnu par ceux qu'il combattait autrefois." % str(creature.get("name", "L'ancien adversaire"))
    }

static func create_memorial_death_scar(creature: Dictionary, world_director: Node, context: Dictionary = {}) -> String:
    if world_director == null:
        return ""
    var entity_id := str(creature.get("source_remanence_id", ""))
    if entity_id == "" or not RemanenceRuntime.entities.has(entity_id):
        return ""
    var body := {
        "id": str(creature.get("instance_id", entity_id)),
        "name": str(creature.get("name", "Ancien adversaire")),
        "remanence_id": entity_id,
        "species_id": str(creature.get("species_id", "")),
        "hp": 0,
        "max_hp": int(creature.get("max_hp", 1)),
        "elite": true,
        "persistent_injuries": (creature.get("persistent_injuries", []) as Array).duplicate(true),
        "body_state": (creature.get("body_state", {}) as Dictionary).duplicate(true),
        "dismembered_parts": (creature.get("dismembered_parts", []) as Array).duplicate(true),
        "anatomy_injuries": (creature.get("anatomy_injuries", {}) as Dictionary).duplicate(true),
        "anatomy_part_states": (creature.get("anatomy_part_states", {}) as Dictionary).duplicate(true),
        "anatomy_part_trauma": (creature.get("anatomy_part_trauma", {}) as Dictionary).duplicate(true)
    }
    var scar_id := str(world_director.call("create_corpse_scar", body, true, context))
    if scar_id == "":
        return ""
    var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    var payload: Dictionary = (scar.get("payload", {}) as Dictionary).duplicate(true)
    payload["former_ally"] = true
    payload["former_nemesis"] = bool(creature.get("former_nemesis", false))
    payload["allied_instance_id"] = str(creature.get("instance_id", ""))
    payload["historical_hostile_stage"] = str(creature.get("historical_hostile_stage", ""))
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload, "severity": "historical" if bool(creature.get("former_nemesis", false)) else "regional", "protected": true})
    RemanenceRuntime.set_entity_status(entity_id, "dead")
    RemanenceRuntime.link_archive_nodes("creature:%s" % str(creature.get("instance_id", "")), scar_id, "ally_corpse_left", {
        "run_index": RemanenceRuntime.run_index,
        "former_nemesis": bool(creature.get("former_nemesis", false))
    })
    return scar_id

static func _preserve_hostile_skill_state(enemy: Dictionary, output: Dictionary) -> void:
    var original_level := maxi(1, int(enemy.get("level", output.get("level", 1))))
    var original_xp := maxi(0, int(enemy.get("xp", 0)))
    var original_points := maxi(0, int(enemy.get("skill_points", output.get("skill_points", original_level))))
    var original_unlocked: Array = []
    var unlocked_value: Variant = enemy.get("unlocked_skills", [])
    if unlocked_value is Array:
        original_unlocked = (unlocked_value as Array).duplicate(true)
    var original_specialization := str(enemy.get("specialization", enemy.get("active_doctrine", "")))
    if original_specialization not in ["offense", "defense", "special"]:
        original_specialization = str(output.get("specialization", ""))
    var tree_progress: Dictionary = {}
    var progress_value: Variant = enemy.get("skill_tree_progress", enemy.get("tree_progress", {}))
    if progress_value is Dictionary:
        tree_progress = (progress_value as Dictionary).duplicate(true)

    output["level"] = original_level
    output["xp"] = original_xp
    output["skill_points"] = original_points
    if not original_unlocked.is_empty():
        output["unlocked_skills"] = original_unlocked
    output["specialization"] = original_specialization
    output["skill_tree_progress"] = tree_progress
    output["hostile_skill_state"] = {
        "level": original_level,
        "xp": original_xp,
        "skill_points": original_points,
        "unlocked_skills": original_unlocked.duplicate(true),
        "specialization": original_specialization,
        "tree_progress": tree_progress.duplicate(true),
        "active_doctrine": str(enemy.get("active_doctrine", original_specialization))
    }
    output["three_tree_continuity"] = true
    output["tree_lock_preserved"] = original_specialization != ""

static func _build_watcher_relationships(record: Dictionary, killed_watchers: Array[String], relic_ids: Array[String], escaped_captures: int) -> Dictionary:
    var relationships := {}
    var stage_rank := int({"normal": 0, "memorial": 1, "veteran": 2, "elite": 3, "nemesis": 4}.get(str(record.get("stage", "normal")), 0))
    var respect_base := mini(60, stage_rank * 12 + int(record.get("encounters", 0)) * 2)
    var fear_base := mini(80, stage_rank * 12 + killed_watchers.size() * 8 + escaped_captures * 3)
    for hero_value: Variant in GameState.party:
        if not (hero_value is Dictionary):
            continue
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        if hero_id == "":
            continue
        var trust := 0
        var respect := respect_base
        var fear := fear_base
        var resentment := 0
        if killed_watchers.has(hero_id):
            resentment = 100
            fear = 100
        else:
            for fallen_id: String in killed_watchers:
                var bond: Dictionary = (hero.get("relationships", {}) as Dictionary).get(fallen_id, {})
                resentment += 8 + int(float(bond.get("trust", 0)) / 8.0) + int(float(bond.get("admiration", 0)) / 10.0)
            resentment = mini(85, resentment)
        if not relic_ids.is_empty():
            resentment = mini(100, resentment + 5)
        relationships[hero_id] = {
            "trust": trust,
            "respect": respect,
            "fear": fear,
            "resentment": resentment,
            "state": _relationship_state(trust, respect, fear, resentment)
        }
    return relationships

static func _relationship_state(trust: int, respect: int, fear: int, resentment: int) -> String:
    if resentment >= 70:
        return "hostile_memory"
    if fear >= 60 and respect >= 40:
        return "fearful_respect"
    if respect >= 45:
        return "guarded_respect"
    if trust >= 30:
        return "emerging_trust"
    return "watchful_distance"
