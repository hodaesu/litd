extends RefCounted

const MIN_RETURN_DELAY_RUNS := 2
const RETURN_COOLDOWN_RUNS := 2
const MAX_ROLE_HISTORY := 12
const MAX_TESTIMONIES := 32

static func register_resolution(enemy: Dictionary, entity_id: String, former_id: String, outcome: String, relationship: Dictionary, reputation_delta: int, context: Dictionary = {}) -> Dictionary:
    if entity_id == "" or not RemanenceRuntime.entities.has(entity_id):
        return {}
    var family_id := _family_id(enemy)
    var species_id := _species_id(enemy)
    var record := RemanenceRuntime.entity_state(entity_id)
    record["family_id"] = family_id
    record["species_id"] = species_id if species_id != "" else str(record.get("species_id", ""))
    record["surrender_outcome"] = outcome
    record["surrender_resolution_run"] = RemanenceRuntime.run_index
    record["return_eligible_run"] = RemanenceRuntime.run_index + MIN_RETURN_DELAY_RUNS
    record["former_nemesis_id"] = former_id
    record["former_kin_relationship"] = relationship.duplicate(true)
    record["testimony_strength"] = maxi(1, abs(reputation_delta))
    if not record.has("future_role_history"):
        record["future_role_history"] = []
    RemanenceRuntime.entities[entity_id] = record

    if former_id != "" and RemanenceRuntime.entities.has(former_id) and family_id != "":
        _record_family_testimony(former_id, family_id, entity_id, outcome, relationship, reputation_delta, context)
    RemanenceRuntime.remanence_changed.emit()
    return {
        "entity_id": entity_id,
        "family_id": family_id,
        "species_id": species_id,
        "outcome": outcome,
        "return_eligible_run": int(record.get("return_eligible_run", 0)),
        "future_role": role_for_entity(entity_id, RemanenceRuntime.run_index + MIN_RETURN_DELAY_RUNS)
    }

static func role_for_entity(entity_id: String, current_run: int = -1) -> String:
    var record := RemanenceRuntime.entity_state(entity_id)
    if record.is_empty():
        return ""
    var run_value := RemanenceRuntime.run_index if current_run < 0 else current_run
    if run_value < int(record.get("return_eligible_run", 999999)):
        return "dormant"
    return _future_role(record, run_value)

static func family_reputation_state(family_id: String) -> Dictionary:
    if family_id == "":
        return {"family_id": "", "known": false, "score": 50, "testimony_count": 0, "attitude": "unknown"}
    var weighted_score := 0
    var total_weight := 0
    var testimony_count := 0
    var former_ids: Array[String] = []
    var latest_run := -1
    for value: Variant in RemanenceRuntime.entities.values():
        if not (value is Dictionary):
            continue
        var former: Dictionary = value
        var ledger: Dictionary = former.get("family_reputation_ledger", {})
        if not ledger.has(family_id):
            continue
        var state: Dictionary = ledger.get(family_id, {})
        var count := maxi(1, int(state.get("testimony_count", 0)))
        weighted_score += int(state.get("score", 50)) * count
        total_weight += count
        testimony_count += int(state.get("testimony_count", 0))
        latest_run = maxi(latest_run, int(state.get("last_run", -1)))
        former_ids.append(str(former.get("id", "")))
    if total_weight <= 0:
        return {"family_id": family_id, "known": false, "score": 50, "testimony_count": 0, "attitude": "unknown", "former_nemesis_ids": []}
    var score := int(round(float(weighted_score) / float(total_weight)))
    return {
        "family_id": family_id,
        "known": true,
        "score": score,
        "testimony_count": testimony_count,
        "attitude": _family_attitude(score),
        "former_nemesis_ids": former_ids,
        "last_run": latest_run
    }

static func prepare_encounter(actors: Array, region_id: String, seed: int = 0) -> Dictionary:
    var output: Array = actors.duplicate(true)
    var family_effects: Array[Dictionary] = []
    var seen_families: Dictionary = {}
    for index in range(output.size()):
        if not (output[index] is Dictionary):
            continue
        var actor: Dictionary = output[index]
        var family_id := _family_id(actor)
        if family_id == "":
            continue
        var reputation := family_reputation_state(family_id)
        if bool(reputation.get("known", false)):
            actor = _apply_family_reputation(actor, reputation)
            output[index] = actor
            if not seen_families.has(family_id):
                family_effects.append(reputation.duplicate(true))
                seen_families[family_id] = true

    var candidate := _select_return_candidate(output, region_id, seed)
    var projection: Dictionary = {}
    var hostile_injected := false
    if not candidate.is_empty():
        projection = _project_candidate(candidate, RemanenceRuntime.run_index)
        if str(projection.get("role", "")) == "resentful_adversary":
            var replace_index := _matching_actor_index(output, candidate)
            if replace_index >= 0:
                var actor: Dictionary = output[replace_index]
                actor["memory_entity_id"] = str(candidate.get("id", ""))
                actor["memory_stage"] = str(candidate.get("stage", "memorial"))
                actor["surrender_return_role"] = "resentful_adversary"
                actor["surrender_history_return"] = true
                actor["name"] = str(candidate.get("name", actor.get("name", "Adversaire rancunier")))
                actor["former_nemesis_id"] = str(candidate.get("former_nemesis_id", ""))
                actor["former_kin_relationship"] = (candidate.get("former_kin_relationship", {}) as Dictionary).duplicate(true)
                output[replace_index] = actor
                projection["combat_actor"] = true
                projection["actor_index"] = replace_index
                hostile_injected = true
        _mark_return(candidate, str(projection.get("role", "")), region_id)

    return {
        "actors": output,
        "family_reputation_effects": family_effects,
        "family_effect_count": family_effects.size(),
        "survivor_projection": projection,
        "survivor_projected": not projection.is_empty(),
        "hostile_return_injected": hostile_injected
    }

static func _record_family_testimony(former_id: String, family_id: String, witness_id: String, outcome: String, relationship: Dictionary, reputation_delta: int, context: Dictionary) -> void:
    var former := RemanenceRuntime.entity_state(former_id)
    var ledger: Dictionary = (former.get("family_reputation_ledger", {}) as Dictionary).duplicate(true)
    var state: Dictionary = (ledger.get(family_id, {}) as Dictionary).duplicate(true)
    state["score"] = clampi(int(state.get("score", 50)) + reputation_delta, 0, 100)
    state["testimony_count"] = int(state.get("testimony_count", 0)) + 1
    state["last_run"] = RemanenceRuntime.run_index
    state["last_outcome"] = outcome
    var witnesses: Array = (state.get("witnesses", []) as Array).duplicate()
    if not witnesses.has(witness_id):
        witnesses.append(witness_id)
    while witnesses.size() > 16:
        witnesses.pop_front()
    state["witnesses"] = witnesses
    ledger[family_id] = state
    former["family_reputation_ledger"] = ledger

    var testimonies: Array = (former.get("family_testimonies", []) as Array).duplicate(true)
    testimonies.append({
        "run_index": RemanenceRuntime.run_index,
        "family_id": family_id,
        "witness_entity_id": witness_id,
        "outcome": outcome,
        "reputation_delta": reputation_delta,
        "relationship": relationship.duplicate(true),
        "region_id": str(context.get("region_id", ""))
    })
    while testimonies.size() > MAX_TESTIMONIES:
        testimonies.pop_front()
    former["family_testimonies"] = testimonies
    RemanenceRuntime.entities[former_id] = former

static func _apply_family_reputation(actor: Dictionary, reputation: Dictionary) -> Dictionary:
    if bool(actor.get("family_reputation_applied", false)):
        return actor
    var output := actor.duplicate(true)
    var score := int(reputation.get("score", 50))
    output["family_reputation_applied"] = true
    output["family_memory_score"] = score
    output["family_testimony_count"] = int(reputation.get("testimony_count", 0))
    output["family_attitude"] = str(reputation.get("attitude", "wary"))
    if score >= 65:
        output["enemy_fear"] = clampi(int(output.get("enemy_fear", 0)) + 8, 0, 100)
        output["former_kin_respect"] = clampi(int(output.get("former_kin_respect", 35)) + 10, 0, 100)
        output["family_surrender_pressure"] = 1
        output["family_testimony_effect"] = "conciliation_pressure"
    elif score <= 35:
        output["enemy_fear"] = maxi(0, int(output.get("enemy_fear", 0)) - 4)
        output["former_kin_respect"] = maxi(0, int(output.get("former_kin_respect", 35)) - 5)
        output["remanence_capture_resistance"] = mini(40, int(output.get("remanence_capture_resistance", 0)) + 5)
        output["family_surrender_pressure"] = -1
        output["family_testimony_effect"] = "resentful_resistance"
    else:
        output["family_surrender_pressure"] = 0
        output["family_testimony_effect"] = "wary_memory"
    return output

static func _select_return_candidate(actors: Array, region_id: String, seed: int) -> Dictionary:
    var families: Array[String] = []
    var species: Array[String] = []
    for value: Variant in actors:
        if not (value is Dictionary):
            continue
        var actor: Dictionary = value
        var family_id := _family_id(actor)
        var species_id := _species_id(actor)
        if family_id != "" and not families.has(family_id):
            families.append(family_id)
        if species_id != "" and not species.has(species_id):
            species.append(species_id)
    var candidates: Array[Dictionary] = []
    for value: Variant in RemanenceRuntime.entities.values():
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        if str(record.get("surrender_outcome", "")) == "":
            continue
        if str(record.get("status", "active")) in ["dead", "recruited"]:
            continue
        var record_region := str(record.get("region_id", ""))
        if region_id != "" and record_region != "" and record_region != region_id:
            continue
        if RemanenceRuntime.run_index < int(record.get("return_eligible_run", 999999)):
            continue
        if RemanenceRuntime.run_index < int(record.get("last_future_return_run", -999)) + RETURN_COOLDOWN_RUNS:
            continue
        var family_id := str(record.get("family_id", ""))
        var species_id := str(record.get("species_id", ""))
        if not species.has(species_id) and not families.has(family_id):
            continue
        candidates.append(record.duplicate(true))
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_age := RemanenceRuntime.run_index - int(left.get("surrender_resolution_run", RemanenceRuntime.run_index))
        var right_age := RemanenceRuntime.run_index - int(right.get("surrender_resolution_run", RemanenceRuntime.run_index))
        if left_age == right_age:
            return str(left.get("id", "")) < str(right.get("id", ""))
        return left_age > right_age
    )
    var index := abs(seed) % candidates.size() if seed != 0 else 0
    return candidates[index].duplicate(true)

static func _project_candidate(record: Dictionary, current_run: int) -> Dictionary:
    var role := _future_role(record, current_run)
    if role in ["", "dormant", "recruited_ally"]:
        return {}
    return {
        "entity_id": str(record.get("id", "")),
        "name": str(record.get("name", "Survivant")),
        "family_id": str(record.get("family_id", "")),
        "species_id": str(record.get("species_id", "")),
        "role": role,
        "age_runs": maxi(0, current_run - int(record.get("surrender_resolution_run", current_run))),
        "outcome": str(record.get("surrender_outcome", "")),
        "former_nemesis_id": str(record.get("former_nemesis_id", "")),
        "relationship": (record.get("former_kin_relationship", {}) as Dictionary).duplicate(true),
        "combat_actor": false,
        "recruitment_possible": role == "potential_recruit",
        "information_available": role == "informant",
        "neutral": role in ["survivor", "neutral", "family_returnee", "informant", "potential_recruit"],
        "summary": _role_summary(record, role)
    }

static func _future_role(record: Dictionary, current_run: int) -> String:
    if str(record.get("status", "")) == "recruited":
        return "recruited_ally"
    var age := maxi(0, current_run - int(record.get("surrender_resolution_run", current_run)))
    if age < MIN_RETURN_DELAY_RUNS:
        return "dormant"
    var outcome := str(record.get("surrender_outcome", ""))
    var relation: Dictionary = record.get("former_kin_relationship", {})
    var trust := int(relation.get("trust", 0))
    var respect := int(relation.get("respect", 0))
    var resentment := int(relation.get("resentment", 0))
    match outcome:
        "surrender_accepted":
            if age <= 3:
                return "survivor"
            if age >= 5 and trust >= 18 and respect >= 55:
                return "informant"
            if age >= 6:
                return "family_returnee"
            return "neutral"
        "surrender_negotiated":
            if age >= 5 and trust >= 20 and respect >= 55:
                return "potential_recruit"
            if age >= 3:
                return "informant"
            return "neutral"
        "surrender_refused", "negotiation_failed":
            return "resentful_adversary" if resentment >= 30 else "family_returnee"
        "rallied":
            return "recruited_ally"
    return "neutral"

static func _mark_return(record: Dictionary, role: String, region_id: String) -> void:
    if role == "" or not RemanenceRuntime.entities.has(str(record.get("id", ""))):
        return
    var entity_id := str(record.get("id", ""))
    var stored := RemanenceRuntime.entity_state(entity_id)
    stored["last_future_return_run"] = RemanenceRuntime.run_index
    stored["last_future_role"] = role
    var history: Array = (stored.get("future_role_history", []) as Array).duplicate(true)
    history.append({"run_index": RemanenceRuntime.run_index, "role": role, "region_id": region_id})
    while history.size() > MAX_ROLE_HISTORY:
        history.pop_front()
    stored["future_role_history"] = history
    RemanenceRuntime.entities[entity_id] = stored
    RemanenceRuntime.record_event(entity_id, "surrender_survivor_return", {
        "region_id": region_id,
        "role": role,
        "summary": _role_summary(stored, role)
    })

static func _matching_actor_index(actors: Array, record: Dictionary) -> int:
    var species_id := str(record.get("species_id", ""))
    for index in range(actors.size()):
        if actors[index] is Dictionary and _species_id(actors[index]) == species_id:
            return index
    return -1

static func _family_attitude(score: int) -> String:
    if score >= 65:
        return "conciliatory"
    if score <= 35:
        return "resentful"
    return "wary"

static func _role_summary(record: Dictionary, role: String) -> String:
    var name := str(record.get("name", "Le survivant"))
    match role:
        "survivor": return "%s réapparaît vivant après avoir déposé les armes." % name
        "neutral": return "%s revient sans reprendre immédiatement le combat." % name
        "informant": return "%s revient avec des informations transmises par son ancienne famille." % name
        "potential_recruit": return "%s revient de son plein gré et peut être rallié sans effacer son histoire." % name
        "family_returnee": return "%s a réintégré son ancienne famille, qui connaît désormais son témoignage." % name
        "resentful_adversary": return "%s revient comme adversaire rancunier et se souvient du refus des Veilleurs." % name
    return "%s demeure inscrit dans la mémoire de sa famille." % name

static func _family_id(value: Dictionary) -> String:
    return str(value.get("family_id", value.get("family", "")))

static func _species_id(value: Dictionary) -> String:
    return str(value.get("species_id", value.get("species", "")))
