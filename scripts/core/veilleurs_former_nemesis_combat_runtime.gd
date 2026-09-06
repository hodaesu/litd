extends RefCounted

const MemorialRecruit := preload("res://scripts/core/veilleurs_memorial_recruit_runtime.gd")

static func prepare_family_encounter(enemies: Array, context: Dictionary = {}) -> Dictionary:
    var recruit := CreatureManager.active_creature()
    if recruit.is_empty() or not bool(recruit.get("former_nemesis", false)):
        return {
            "applied": false,
            "recognized": 0,
            "hesitating": 0,
            "surrender_available": 0,
            "successor": regional_successor_state("")
        }

    var source_id := str(recruit.get("source_remanence_id", ""))
    var region_id := str(context.get("region_id", recruit.get("historical_region_id", AshlandsRuntime.current_zone_id)))
    var recognized := 0
    var hesitating := 0
    var surrender_available := 0
    var dialogue_lines: Array[String] = []

    for enemy_value: Variant in enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0 or bool(enemy.get("captured", false)):
            continue
        var reaction: Dictionary = MemorialRecruit.family_reaction(recruit, enemy)
        if not bool(reaction.get("applies", false)):
            continue

        recognized += 1
        var fear_before := int(enemy.get("enemy_fear", enemy.get("fear_gauge", 0)))
        var fear_delta := 28 if bool(recruit.get("former_nemesis", false)) else 12
        var historical_score := int(recruit.get("historical_score", 0))
        fear_delta += mini(12, int(historical_score / 4))
        var fear_after := clampi(fear_before + fear_delta, 0, 100)
        enemy["enemy_fear"] = fear_after
        enemy["former_kin_recognition"] = str(reaction.get("reaction", "recognition"))
        enemy["former_kin_source_id"] = source_id
        enemy["former_kin_source_name"] = str(recruit.get("name", "Ancien Némésis"))
        enemy["former_kin_telegraphed"] = bool(reaction.get("telegraphed", true))
        enemy["former_kin_betrayal_allowed"] = false
        enemy["former_kin_player_control_preserved"] = true
        enemy["former_kin_respect"] = clampi(35 + historical_score * 2, 0, 100)
        enemy["former_kin_hesitate_first_turn"] = int(reaction.get("enemy_hesitation_window", 0)) > 0
        enemy["former_kin_hesitation_consumed"] = false
        if bool(enemy.get("former_kin_hesitate_first_turn", false)):
            hesitating += 1

        var hp_ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", enemy.get("hp", 1))))
        var surrender_ready := bool(reaction.get("surrender_dialogue_available", false)) and fear_after >= 65 and hp_ratio <= 0.35
        enemy["former_kin_surrender_available"] = surrender_ready
        enemy["former_kin_social_state"] = _social_state(fear_after, int(enemy.get("former_kin_respect", 0)), surrender_ready)
        if surrender_ready:
            surrender_available += 1

        var dialogue := _dialogue_for(recruit, enemy, str(enemy.get("former_kin_social_state", "recognition_shock")))
        enemy["former_kin_dialogue"] = dialogue
        dialogue_lines.append(dialogue)

        var enemy_entity_id := str(enemy.get("remanence_id", ""))
        if enemy_entity_id == "":
            enemy_entity_id = RemanenceRuntime.prepare_enemy(enemy, region_id)
        if source_id != "" and RemanenceRuntime.entities.has(source_id):
            RemanenceRuntime.record_event(source_id, "former_kin_recognition", {
                "region_id": region_id,
                "object_id": enemy_entity_id,
                "summary": dialogue,
                "reaction": str(enemy.get("former_kin_social_state", "")),
                "fear_delta": fear_after - fear_before,
                "surrender_available": surrender_ready
            })
            if enemy_entity_id != "":
                RemanenceRuntime.link_archive_nodes(source_id, enemy_entity_id, "recognized_by_former_kin", {
                    "run_index": RemanenceRuntime.run_index,
                    "region_id": region_id,
                    "social_state": str(enemy.get("former_kin_social_state", ""))
                })

    if recognized > 0 and not bool(context.get("silent", false)):
        GameState.add_log(dialogue_lines[0])

    var successor := regional_successor_state(region_id)
    _link_successor_if_needed(source_id, successor, region_id)
    return {
        "applied": recognized > 0,
        "recruit_id": source_id,
        "recognized": recognized,
        "hesitating": hesitating,
        "surrender_available": surrender_available,
        "dialogue_lines": dialogue_lines,
        "successor": successor,
        "random_betrayal_allowed": false,
        "player_control_preserved": true
    }

static func regional_successor_state(region_id: String) -> Dictionary:
    var former: Array[Dictionary] = []
    var hostile: Array[Dictionary] = []
    for value: Variant in RemanenceRuntime.entities.values():
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        var record_region := str(record.get("region_id", ""))
        if region_id != "" and record_region != region_id:
            continue
        var status := str(record.get("status", "active"))
        var stage := str(record.get("stage", "normal"))
        var historical_stage := str(record.get("historical_stage", ""))
        if status == "recruited" and (stage == "former_nemesis" or historical_stage == "nemesis"):
            former.append(record.duplicate(true))
        elif status == "active" and stage == "nemesis":
            hostile.append(record.duplicate(true))

    hostile.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left.get("score", 0)) > int(right.get("score", 0))
    )
    former.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left.get("recruited_run", 0)) > int(right.get("recruited_run", 0))
    )
    return {
        "region_id": region_id,
        "former_nemeses": former,
        "hostile_nemeses": hostile,
        "former_count": former.size(),
        "hostile_count": hostile.size(),
        "cap_respected": hostile.size() <= 1,
        "successor_entity_id": str(hostile[0].get("id", "")) if not hostile.is_empty() else "",
        "predecessor_entity_id": str(former[0].get("id", "")) if not former.is_empty() else ""
    }

static func apply_first_cycle_hesitation(timeline: Node, enemies: Array) -> Dictionary:
    var applied := 0
    for enemy_value: Variant in enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        if not bool(enemy.get("former_kin_hesitate_first_turn", false)) or bool(enemy.get("former_kin_hesitation_consumed", false)):
            continue
        var actor_id := str(enemy.get("id", ""))
        if actor_id == "":
            continue
        timeline.set_cycle_status(actor_id, "former_kin_hesitation_turns", 1)
        enemy["former_kin_hesitation_consumed"] = true
        applied += 1
    return {"applied": applied, "first_turn_only": true}

static func _social_state(fear: int, respect: int, surrender_ready: bool) -> String:
    if surrender_ready:
        return "surrender_offer"
    if fear >= 65 and respect >= 45:
        return "fearful_respect"
    if respect >= 55:
        return "hostile_respect"
    return "recognition_shock"

static func _dialogue_for(recruit: Dictionary, enemy: Dictionary, state: String) -> String:
    var recruit_name := str(recruit.get("name", "L'ancien Némésis"))
    var enemy_name := str(enemy.get("name", "L'adversaire"))
    match state:
        "surrender_offer":
            return "%s reconnaît %s et baisse son arme : la reddition devient possible." % [enemy_name, recruit_name]
        "fearful_respect":
            return "%s reconnaît %s ; la peur se mêle au respect et brise son élan." % [enemy_name, recruit_name]
        "hostile_respect":
            return "%s reconnaît %s et répond par un défi hostile, sans pouvoir ignorer son ancien rang." % [enemy_name, recruit_name]
        _:
            return "%s reconnaît %s : un instant d'hésitation traverse les anciens rangs." % [enemy_name, recruit_name]

static func _link_successor_if_needed(former_id: String, successor: Dictionary, region_id: String) -> void:
    if former_id == "":
        return
    var successor_id := str(successor.get("successor_entity_id", ""))
    if successor_id == "" or successor_id == former_id:
        return
    RemanenceRuntime.link_archive_nodes(former_id, successor_id, "nemesis_succeeded_by", {
        "run_index": RemanenceRuntime.run_index,
        "region_id": region_id
    })
