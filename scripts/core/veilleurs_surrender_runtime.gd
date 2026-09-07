extends RefCounted

const CHOICE_ACCEPT := "accept"
const CHOICE_REFUSE := "refuse"
const CHOICE_NEGOTIATE := "negotiate"
const CHOICE_RALLY := "rally"

static func choices(enemy: Dictionary) -> Array[Dictionary]:
    if not bool(enemy.get("former_kin_surrender_available", false)):
        return []
    return [
        {"id": CHOICE_ACCEPT, "label": "Accepter", "summary": "Met fin au combat avec cette cible sans la recruter."},
        {"id": CHOICE_REFUSE, "label": "Refuser", "summary": "Maintient l'affrontement et durcit la mémoire de la cible."},
        {"id": CHOICE_NEGOTIATE, "label": "Négocier", "summary": "Cherche une reddition conditionnelle et améliore la relation si elle aboutit."},
        {"id": CHOICE_RALLY, "label": "Rallier", "summary": "Transforme la reddition en ralliement durable si la cible est recrutable."}
    ]

static func resolve(enemy: Dictionary, choice_id: String, context: Dictionary = {}) -> Dictionary:
    if not bool(enemy.get("former_kin_surrender_available", false)):
        return {"resolved": false, "reason": "surrender_unavailable"}
    if choice_id not in [CHOICE_ACCEPT, CHOICE_REFUSE, CHOICE_NEGOTIATE, CHOICE_RALLY]:
        return {"resolved": false, "reason": "invalid_choice"}

    var entity_id := str(enemy.get("remanence_id", ""))
    if entity_id == "":
        entity_id = RemanenceRuntime.prepare_enemy(enemy, str(context.get("region_id", AshlandsRuntime.current_zone_id)))
    var recruit := CreatureManager.active_creature()
    var former_id := str(recruit.get("source_remanence_id", ""))
    var relationship_delta := {"trust": 0, "respect": 0, "fear": 0, "resentment": 0}
    var reputation_delta := 0
    var removed_from_combat := false
    var recruited := false
    var outcome := ""

    match choice_id:
        CHOICE_ACCEPT:
            relationship_delta = {"trust": 8, "respect": 12, "fear": -10, "resentment": -8}
            reputation_delta = 6
            enemy["hp"] = 0
            enemy["surrendered"] = true
            enemy["captured"] = false
            removed_from_combat = true
            outcome = "surrender_accepted"
            RemanenceRuntime.set_entity_status(entity_id, "surrendered")
        CHOICE_REFUSE:
            relationship_delta = {"trust": -8, "respect": -4, "fear": 10, "resentment": 18}
            reputation_delta = -6
            enemy["former_kin_surrender_available"] = false
            enemy["surrender_refused"] = true
            enemy["intent"] = "desperate_retaliation"
            outcome = "surrender_refused"
        CHOICE_NEGOTIATE:
            var fear := int(enemy.get("enemy_fear", 0))
            var respect := int(enemy.get("former_kin_respect", 0))
            var succeeds := fear >= 60 and respect >= 45
            if succeeds:
                relationship_delta = {"trust": 14, "respect": 16, "fear": -12, "resentment": -12}
                reputation_delta = 10
                enemy["hp"] = 0
                enemy["surrendered"] = true
                enemy["negotiated_surrender"] = true
                removed_from_combat = true
                outcome = "surrender_negotiated"
                RemanenceRuntime.set_entity_status(entity_id, "surrendered")
            else:
                relationship_delta = {"trust": -2, "respect": 4, "fear": 4, "resentment": 6}
                enemy["former_kin_surrender_available"] = false
                enemy["intent"] = "negotiation_failed"
                outcome = "negotiation_failed"
        CHOICE_RALLY:
            if not CreatureManager.is_capturable(enemy):
                relationship_delta = {"trust": 0, "respect": 4, "fear": 4, "resentment": 4}
                outcome = "rally_not_capturable"
            else:
                var definition := CreatureManager.definition_for_battle_enemy(enemy)
                var creature_value: Variant = CreatureManager.call("_create_creature", definition)
                var creature: Dictionary = creature_value if creature_value is Dictionary else {}
                if creature.is_empty():
                    return {"resolved": false, "reason": "creature_creation_failed"}
                creature["rallied_from_surrender"] = true
                creature["rallied_by_former_nemesis"] = former_id
                CreatureManager.captured_creatures.append(creature)
                if CreatureManager.active_instance_id == "":
                    CreatureManager.active_instance_id = str(creature.get("instance_id", ""))
                enemy["hp"] = 0
                enemy["captured"] = true
                enemy["surrendered"] = true
                removed_from_combat = true
                recruited = true
                relationship_delta = {"trust": 20, "respect": 18, "fear": -18, "resentment": -18}
                reputation_delta = 14
                outcome = "rallied"
                RemanenceRuntime.set_entity_status(entity_id, "recruited")
                CreatureManager.creatures_changed.emit()
                CreatureManager.creature_captured.emit(creature.duplicate(true))

    _apply_relationship_memory(enemy, entity_id, former_id, relationship_delta, reputation_delta, outcome, context)
    return {
        "resolved": true,
        "choice": choice_id,
        "outcome": outcome,
        "entity_id": entity_id,
        "former_nemesis_id": former_id,
        "relationship_delta": relationship_delta.duplicate(true),
        "reputation_delta": reputation_delta,
        "removed_from_combat": removed_from_combat,
        "recruited": recruited
    }

static func _apply_relationship_memory(enemy: Dictionary, entity_id: String, former_id: String, delta: Dictionary, reputation_delta: int, outcome: String, context: Dictionary) -> void:
    var relation: Dictionary = (enemy.get("former_kin_relationship", {}) as Dictionary).duplicate(true)
    for axis in ["trust", "respect", "fear", "resentment"]:
        relation[axis] = clampi(int(relation.get(axis, _relationship_seed(enemy, axis))) + int(delta.get(axis, 0)), 0, 100)
    relation["state"] = _relationship_state(relation)
    enemy["former_kin_relationship"] = relation

    if entity_id != "" and RemanenceRuntime.entities.has(entity_id):
        var record := RemanenceRuntime.entity_state(entity_id)
        record["former_kin_relationship"] = relation.duplicate(true)
        record["last_surrender_outcome"] = outcome
        record["last_surrender_run"] = RemanenceRuntime.run_index
        RemanenceRuntime.entities[entity_id] = record

    if former_id != "" and RemanenceRuntime.entities.has(former_id):
        var former := RemanenceRuntime.entity_state(former_id)
        former["allied_reputation"] = clampi(int(former.get("allied_reputation", 50)) + reputation_delta, 0, 100)
        var decisions: Array = (former.get("surrender_decisions", []) as Array).duplicate(true)
        decisions.append({
            "run_index": RemanenceRuntime.run_index,
            "target_entity_id": entity_id,
            "outcome": outcome,
            "relationship": relation.duplicate(true),
            "reputation_delta": reputation_delta,
            "region_id": str(context.get("region_id", AshlandsRuntime.current_zone_id))
        })
        while decisions.size() > 16:
            decisions.pop_front()
        former["surrender_decisions"] = decisions
        RemanenceRuntime.entities[former_id] = former
        RemanenceRuntime.link_archive_nodes(former_id, entity_id, "surrender_decision", {
            "run_index": RemanenceRuntime.run_index,
            "outcome": outcome,
            "relationship": relation.duplicate(true),
            "reputation_delta": reputation_delta
        })

    if entity_id != "":
        RemanenceRuntime.record_event(entity_id, "surrender_decision", {
            "summary": "Décision de reddition : %s" % outcome,
            "object_id": former_id,
            "outcome": outcome,
            "relationship": relation.duplicate(true),
            "reputation_delta": reputation_delta
        })
    RemanenceRuntime.remanence_changed.emit()

static func _relationship_seed(enemy: Dictionary, axis: String) -> int:
    match axis:
        "respect": return int(enemy.get("former_kin_respect", 35))
        "fear": return int(enemy.get("enemy_fear", 0))
        "trust": return 10
        "resentment": return 20
    return 0

static func _relationship_state(relation: Dictionary) -> String:
    var trust := int(relation.get("trust", 0))
    var respect := int(relation.get("respect", 0))
    var fear := int(relation.get("fear", 0))
    var resentment := int(relation.get("resentment", 0))
    if resentment >= 65:
        return "resentful"
    if trust >= 55 and respect >= 55:
        return "willing_alignment"
    if fear >= 65 and respect >= 45:
        return "fearful_respect"
    if respect >= 50:
        return "guarded_respect"
    return "unstable"
