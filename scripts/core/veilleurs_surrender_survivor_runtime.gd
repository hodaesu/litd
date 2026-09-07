extends RefCounted

const ROLE_DORMANT := "dormant"
const ROLE_SURVIVOR := "survivor"
const ROLE_NEUTRAL := "neutral"
const ROLE_INFORMANT := "informant"
const ROLE_RECRUIT_CANDIDATE := "recruit_candidate"
const ROLE_FORMER_FAMILY := "former_family_member"
const ROLE_RESENTFUL_ENEMY := "resentful_enemy"
const ROLE_RECRUIT := "recruit"

static func register_decision_survivor(enemy: Dictionary, entity_id: String, former_id: String, outcome: String, reputation_delta: int, context: Dictionary = {}) -> Dictionary:
    if entity_id == "" or not RemanenceRuntime.entities.has(entity_id):
        return {}
    var record := RemanenceRuntime.entity_state(entity_id)
    var family_id := str(enemy.get("family_id", enemy.get("family", record.get("family_id", record.get("species_id", "unknown")))))
    var region_id := str(context.get("region_id", record.get("region_id", AshlandsRuntime.current_zone_id)))
    record["family_id"] = family_id
    record["surrender_witness"] = true
    record["surrender_former_nemesis_id"] = former_id
    record["surrender_family_id"] = family_id
    record["surrender_origin_outcome"] = outcome
    record["surrender_origin_run"] = RemanenceRuntime.run_index
    record["surrender_reputation_delta"] = reputation_delta
    record["surrender_relationship"] = (enemy.get("former_kin_relationship", {}) as Dictionary).duplicate(true)
    record["surrender_projection_count"] = int(record.get("surrender_projection_count", 0))
    record["surrender_last_projection_run"] = int(record.get("surrender_last_projection_run", -1))
    record["surrender_future_role"] = future_role_for_record(record, RemanenceRuntime.run_index)
    RemanenceRuntime.entities[entity_id] = record
    var family_state := refresh_family_reputation(former_id, family_id, region_id)
    RemanenceRuntime.remanence_changed.emit()
    return {
        "entity_id": entity_id,
        "family_id": family_id,
        "region_id": region_id,
        "future_role": str(record.get("surrender_future_role", ROLE_DORMANT)),
        "family_state": family_state
    }

static func future_role_for_record(record: Dictionary, current_run: int = -1) -> String:
    if not bool(record.get("surrender_witness", false)):
        return ROLE_DORMANT
    var run_now := RemanenceRuntime.run_index if current_run < 0 else current_run
    var origin_run := int(record.get("surrender_origin_run", run_now))
    var age := maxi(0, run_now - origin_run)
    var outcome := str(record.get("surrender_origin_outcome", record.get("last_surrender_outcome", "")))
    var status := str(record.get("status", "active"))
    var relation: Dictionary = (record.get("surrender_relationship", record.get("former_kin_relationship", {})) as Dictionary)
    var respect := int(relation.get("respect", 0))
    var resentment := int(relation.get("resentment", 0))

    if status == "recruited" or outcome == "rallied":
        return ROLE_RECRUIT
    if age < 2:
        return ROLE_DORMANT
    if outcome in ["surrender_refused", "negotiation_failed"]:
        return ROLE_RESENTFUL_ENEMY if resentment >= 35 else ROLE_FORMER_FAMILY
    if age == 2:
        return ROLE_SURVIVOR
    if outcome == "surrender_negotiated":
        if age >= 5 and respect >= 50 and resentment <= 35:
            return ROLE_RECRUIT_CANDIDATE
        if respect >= 50 and resentment <= 45:
            return ROLE_INFORMANT
        return ROLE_NEUTRAL
    if outcome == "surrender_accepted":
        if age >= 5 and respect >= 50 and resentment <= 35:
            return ROLE_INFORMANT
        return ROLE_NEUTRAL
    if status == "surrendered":
        return ROLE_FORMER_FAMILY
    return ROLE_DORMANT

static func witnesses_for_former(former_id: String, region_id: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in RemanenceRuntime.entities.values():
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        if not bool(record.get("surrender_witness", false)):
            continue
        if str(record.get("surrender_former_nemesis_id", "")) != former_id:
            continue
        if region_id != "" and str(record.get("region_id", "")) != region_id:
            continue
        var copy := record.duplicate(true)
        copy["surrender_future_role"] = future_role_for_record(record)
        copy["surrender_age_runs"] = maxi(0, RemanenceRuntime.run_index - int(record.get("surrender_origin_run", RemanenceRuntime.run_index)))
        result.append(copy)
    result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_rank := _role_rank(str(left.get("surrender_future_role", ROLE_DORMANT))) * 10000 + int(left.get("surrender_age_runs", 0)) * 100 + int(left.get("score", 0))
        var right_rank := _role_rank(str(right.get("surrender_future_role", ROLE_DORMANT))) * 10000 + int(right.get("surrender_age_runs", 0)) * 100 + int(right.get("score", 0))
        return left_rank > right_rank
    )
    return result

static func projected_survivors(region_id: String, max_count: int = 1) -> Array[Dictionary]:
    var ranked: Array[Dictionary] = []
    for value: Variant in RemanenceRuntime.entities.values():
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        if not bool(record.get("surrender_witness", false)):
            continue
        if region_id != "" and str(record.get("region_id", "")) != region_id:
            continue
        if int(record.get("surrender_last_projection_run", -1)) == RemanenceRuntime.run_index:
            continue
        var role := future_role_for_record(record)
        if role in [ROLE_DORMANT, ROLE_RECRUIT]:
            continue
        var projection := _projection_from_record(record, role)
        ranked.append(projection)
    ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_priority := _role_rank(str(left.get("role", ROLE_DORMANT))) * 10000 + int(left.get("age_runs", 0)) * 100 + int(left.get("score", 0))
        var right_priority := _role_rank(str(right.get("role", ROLE_DORMANT))) * 10000 + int(right.get("age_runs", 0)) * 100 + int(right.get("score", 0))
        if left_priority == right_priority:
            return str(left.get("entity_id", "")) < str(right.get("entity_id", ""))
        return left_priority > right_priority
    )
    while ranked.size() > maxi(0, max_count):
        ranked.pop_back()
    return ranked

static func inject_into_encounter(actors: Array, region_id: String, allow_actor_injection: bool = true) -> Dictionary:
    var output := actors.duplicate(true)
    var projections := projected_survivors(region_id, 1)
    if projections.is_empty():
        return {"actors": output, "events": [], "injected": 0, "actor_injected": 0}
    var projection: Dictionary = projections[0]
    var role := str(projection.get("role", ROLE_DORMANT))
    var actor_injected := 0
    if allow_actor_injection and role == ROLE_RESENTFUL_ENEMY:
        var species_id := str(projection.get("species_id", ""))
        for index in range(output.size()):
            if not (output[index] is Dictionary):
                continue
            var actor: Dictionary = output[index]
            var actor_species := str(actor.get("species", actor.get("species_id", "")))
            if actor_species != species_id:
                continue
            actor["memory_entity_id"] = str(projection.get("entity_id", ""))
            actor["memory_stage"] = "surrender_survivor"
            actor["surrender_survivor_injected"] = true
            actor["surrender_survivor_role"] = role
            actor["surrender_survivor_relationship"] = (projection.get("relationship", {}) as Dictionary).duplicate(true)
            actor["name"] = str(projection.get("name", actor.get("name", "Survivant rancunier")))
            actor["remanence_id"] = str(projection.get("entity_id", ""))
            output[index] = actor
            actor_injected = 1
            break
    mark_projected(str(projection.get("entity_id", "")), role)
    return {
        "actors": output,
        "events": [projection.duplicate(true)],
        "injected": 1,
        "actor_injected": actor_injected,
        "role": role,
        "entity_id": str(projection.get("entity_id", ""))
    }

static func mark_projected(entity_id: String, role: String) -> bool:
    if entity_id == "" or not RemanenceRuntime.entities.has(entity_id):
        return false
    var record := RemanenceRuntime.entity_state(entity_id)
    record["surrender_last_projection_run"] = RemanenceRuntime.run_index
    record["surrender_projection_count"] = int(record.get("surrender_projection_count", 0)) + 1
    record["surrender_future_role"] = role
    RemanenceRuntime.entities[entity_id] = record
    var former_id := str(record.get("surrender_former_nemesis_id", ""))
    var family_id := str(record.get("surrender_family_id", record.get("family_id", "")))
    var region_id := str(record.get("region_id", ""))
    if former_id != "" and family_id != "":
        refresh_family_reputation(former_id, family_id, region_id)
    RemanenceRuntime.record_event(entity_id, "surrender_survivor_returned", {
        "region_id": region_id,
        "object_id": former_id,
        "role": role,
        "summary": _role_summary(str(record.get("name", "Un survivant")), role)
    })
    return true

static func refresh_family_reputation(former_id: String, family_id: String, region_id: String = "") -> Dictionary:
    if former_id == "" or family_id == "" or not RemanenceRuntime.entities.has(former_id):
        return _family_state(50, 0, 0)
    var reputation_delta := 0
    var testimony_count := 0
    var spread_count := 0
    for value: Variant in RemanenceRuntime.entities.values():
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        if not bool(record.get("surrender_witness", false)):
            continue
        if str(record.get("surrender_former_nemesis_id", "")) != former_id:
            continue
        if str(record.get("surrender_family_id", record.get("family_id", ""))) != family_id:
            continue
        if region_id != "" and str(record.get("region_id", "")) != region_id:
            continue
        testimony_count += 1
        reputation_delta += int(record.get("surrender_reputation_delta", 0))
        spread_count += int(record.get("surrender_projection_count", 0))
    var score := clampi(50 + reputation_delta, 0, 100)
    var state := _family_state(score, testimony_count, spread_count)
    var former := RemanenceRuntime.entity_state(former_id)
    var reputations: Dictionary = (former.get("family_reputation", {}) as Dictionary).duplicate(true)
    var key := _family_key(region_id, family_id)
    var stored := state.duplicate(true)
    stored["family_id"] = family_id
    stored["region_id"] = region_id
    stored["updated_run"] = RemanenceRuntime.run_index
    reputations[key] = stored
    former["family_reputation"] = reputations
    former["last_family_reputation_key"] = key
    RemanenceRuntime.entities[former_id] = former
    return stored

static func family_attitude(former_id: String, family_id: String, region_id: String = "") -> Dictionary:
    if former_id == "" or family_id == "":
        return _family_state(50, 0, 0)
    return refresh_family_reputation(former_id, family_id, region_id)

static func _projection_from_record(record: Dictionary, role: String) -> Dictionary:
    var age := maxi(0, RemanenceRuntime.run_index - int(record.get("surrender_origin_run", RemanenceRuntime.run_index)))
    var relation: Dictionary = (record.get("surrender_relationship", record.get("former_kin_relationship", {})) as Dictionary).duplicate(true)
    return {
        "entity_id": str(record.get("id", "")),
        "name": str(record.get("name", "Survivant")),
        "species_id": str(record.get("species_id", "")),
        "family_id": str(record.get("surrender_family_id", record.get("family_id", ""))),
        "former_nemesis_id": str(record.get("surrender_former_nemesis_id", "")),
        "role": role,
        "age_runs": age,
        "score": int(record.get("score", 0)),
        "relationship": relation,
        "origin_outcome": str(record.get("surrender_origin_outcome", "")),
        "combat_hostile": role == ROLE_RESENTFUL_ENEMY,
        "recruit_candidate": role == ROLE_RECRUIT_CANDIDATE,
        "provides_information": role == ROLE_INFORMANT,
        "neutral_presence": role in [ROLE_SURVIVOR, ROLE_NEUTRAL, ROLE_FORMER_FAMILY],
        "summary": _role_summary(str(record.get("name", "Un survivant")), role)
    }

static func _family_state(score: int, testimony_count: int, spread_count: int) -> Dictionary:
    var attitude := "divided_memory"
    var fear_delta := 0
    var respect_delta := 0
    var surrender_threshold_bonus := 0
    if score >= 75:
        attitude = "legacy_loyalty"
        fear_delta = -6
        respect_delta = 20
        surrender_threshold_bonus = 12
    elif score >= 60:
        attitude = "respectful_memory"
        fear_delta = -2
        respect_delta = 10
        surrender_threshold_bonus = 6
    elif score >= 45:
        attitude = "divided_memory"
        respect_delta = 4
        surrender_threshold_bonus = 2
    elif score >= 30:
        attitude = "distrustful_memory"
        fear_delta = 6
        respect_delta = -6
        surrender_threshold_bonus = -4
    else:
        attitude = "hostile_memory"
        fear_delta = 10
        respect_delta = -14
        surrender_threshold_bonus = -8
    return {
        "score": score,
        "attitude": attitude,
        "testimony_count": testimony_count,
        "spread_count": spread_count,
        "fear_delta": fear_delta,
        "respect_delta": respect_delta,
        "surrender_threshold_bonus": surrender_threshold_bonus
    }

static func _family_key(region_id: String, family_id: String) -> String:
    return "%s|%s" % [region_id if region_id != "" else "*", family_id]

static func _role_rank(role: String) -> int:
    return int({
        ROLE_DORMANT: 0,
        ROLE_SURVIVOR: 1,
        ROLE_NEUTRAL: 2,
        ROLE_FORMER_FAMILY: 3,
        ROLE_INFORMANT: 4,
        ROLE_RECRUIT_CANDIDATE: 5,
        ROLE_RESENTFUL_ENEMY: 6,
        ROLE_RECRUIT: 7
    }.get(role, 0))

static func _role_summary(name: String, role: String) -> String:
    match role:
        ROLE_SURVIVOR:
            return "%s réapparaît comme survivant de la reddition passée." % name
        ROLE_NEUTRAL:
            return "%s croise de nouveau les Veilleurs sans reprendre les armes." % name
        ROLE_INFORMANT:
            return "%s transmet une information en mémoire de la décision passée." % name
        ROLE_RECRUIT_CANDIDATE:
            return "%s revient volontairement et peut désormais envisager un ralliement." % name
        ROLE_FORMER_FAMILY:
            return "%s revient auprès de son ancienne famille et porte le témoignage de la reddition." % name
        ROLE_RESENTFUL_ENEMY:
            return "%s revient armé, nourri par le ressentiment laissé par la décision passée." % name
        ROLE_RECRUIT:
            return "%s appartient désormais aux auxiliaires des Veilleurs." % name
        _:
            return "%s reste hors de la scène pour le moment." % name
