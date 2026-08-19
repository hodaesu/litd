extends Node

signal field_memory_recorded(hero_id: String, memory_id: String)
signal field_memory_reframed(hero_id: String, memory_id: String, event_id: String)
signal field_memory_moment(text: String)

const DATA_PATH := "res://data/field_memory.json"
const RELATIONSHIP_METRICS: Array[String] = ["trust", "admiration", "mistrust", "resentment"]
const RELATIONSHIP_HISTORY_LIMIT: int = 16

var data: Dictionary = {}

func _ready() -> void:
    _load_data()
    prepare_party()
    if not GameState.state_changed.is_connected(_on_state_changed):
        GameState.state_changed.connect(_on_state_changed)
    if not CreatureManager.creature_captured.is_connected(_on_creature_captured):
        CreatureManager.creature_captured.connect(_on_creature_captured)
    if not CreatureManager.creature_leveled.is_connected(_on_creature_leveled):
        CreatureManager.creature_leveled.connect(_on_creature_leveled)
    if not ExpeditionManager.expedition_ended.is_connected(_on_expedition_ended):
        ExpeditionManager.expedition_ended.connect(_on_expedition_ended)
    if not AshlandsCombatBridge.ashlands_combat_finished.is_connected(_on_combat_finished):
        AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)

func _load_data() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func _on_state_changed() -> void:
    prepare_party()

func prepare_party() -> void:
    DecisionMemoryRuntime.prepare_party()
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if not hero.has("field_memories") or not (hero.get("field_memories", []) is Array):
            hero["field_memories"] = []

func boss_outcome_eligible(encounter_id: String) -> bool:
    return data.get("boss_outcomes", {}).has(encounter_id)

func boss_outcome_prompt(encounter_id: String) -> String:
    var definition_value: Variant = data.get("boss_outcomes", {}).get(encounter_id, {})
    var definition: Dictionary = definition_value if definition_value is Dictionary else {}
    return str(definition.get("prompt", "Le combat est terminé, mais le sort de l'adversaire reste à décider."))

func boss_name(encounter_id: String) -> String:
    var definition_value: Variant = data.get("boss_outcomes", {}).get(encounter_id, {})
    var definition: Dictionary = definition_value if definition_value is Dictionary else {}
    return str(definition.get("name", encounter_id))

func has_boss_outcome(encounter_id: String) -> bool:
    if encounter_id == "":
        return false
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        for memory_value in hero.get("field_memories", []):
            var memory: Dictionary = memory_value
            if str(memory.get("encounter_id", "")) == encounter_id and str(memory.get("type", "")).begins_with("boss_"):
                return true
    return false

func record_boss_outcome(encounter_id: String, outcome: String) -> Dictionary:
    if encounter_id == "" or has_boss_outcome(encounter_id):
        return {"applied": false}
    var memory_type := "boss_spared" if outcome == "spared" else "boss_executed"
    var label := "épargner %s" % boss_name(encounter_id) if outcome == "spared" else "achever %s" % boss_name(encounter_id)
    return _record_field_decision(memory_type, label, {
        "encounter_id": encounter_id,
        "boss_name": boss_name(encounter_id),
        "outcome": outcome,
        "zone_id": AshlandsRuntime.current_zone_id,
        "witness_mode": "direct"
    })

func record_resource_choice(event_id: String, choice_id: String, label: String = "") -> Dictionary:
    var memory_type := "aid_survivors" if choice_id == "aid" else "keep_resources"
    var resolved_label := label
    if resolved_label == "":
        resolved_label = "partager les ressources avec les survivants" if choice_id == "aid" else "préserver les ressources de la compagnie"
    return _record_field_decision(memory_type, resolved_label, {
        "event_id": event_id,
        "choice_id": choice_id,
        "zone_id": AshlandsRuntime.current_zone_id,
        "witness_mode": "direct"
    })

func record_expedition_retreat(reason: String) -> Dictionary:
    return _record_field_decision("expedition_retreat", "quitter l'expédition avant son terme", {
        "return_reason": reason,
        "zone_id": AshlandsRuntime.current_zone_id,
        "witness_mode": "direct",
        "living_count": GameState.alive_heroes().size()
    })

func recent_field_memory_lines(limit: int = 3) -> Array[String]:
    var candidates: Array[Dictionary] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var memories_value: Variant = hero.get("field_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        if memories.is_empty():
            continue
        var memory_value: Variant = memories[memories.size() - 1]
        var memory: Dictionary = memory_value if memory_value is Dictionary else {}
        var reevaluations_value: Variant = memory.get("reevaluations", [])
        var reevaluations: Array = reevaluations_value if reevaluations_value is Array else []
        var importance: int = absi(int(memory.get("score", 0))) + reevaluations.size() * 3
        candidates.append({"importance": importance, "hero": hero, "memory": memory})
    candidates.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("importance", 0)) > int(right.get("importance", 0)))
    var result: Array[String] = []
    for index in range(mini(limit, candidates.size())):
        var entry: Dictionary = candidates[index]
        var line := field_memory_line(entry.get("hero", {}), entry.get("memory", {}))
        if line != "":
            result.append(line)
    return result

func field_memory_line(hero: Dictionary, memory: Dictionary = {}) -> String:
    if hero.is_empty():
        return ""
    var resolved := memory
    if resolved.is_empty():
        var memories_value: Variant = hero.get("field_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        if memories.is_empty():
            return ""
        var memory_value: Variant = memories[memories.size() - 1]
        resolved = memory_value if memory_value is Dictionary else {}
    var hero_name := str(hero.get("name", "Le héros"))
    var label := str(resolved.get("choice_label", "ce qui s'est passé"))
    var stance := str(resolved.get("stance", "uncertain"))
    var reevaluations_value: Variant = resolved.get("reevaluations", [])
    var reevaluations: Array = reevaluations_value if reevaluations_value is Array else []
    var changed := not reevaluations.is_empty() and str(resolved.get("initial_stance", stance)) != stance
    if changed:
        return "%s a changé de jugement sur « %s »." % [hero_name, label]
    match stance:
        "strong_support": return "%s défend encore le choix de %s." % [hero_name, label]
        "support": return "%s continue d'assumer %s." % [hero_name, label]
        "oppose": return "%s n'a toujours pas accepté le choix de %s." % [hero_name, label]
        "strong_oppose": return "%s garde un ressentiment profond autour du choix de %s." % [hero_name, label]
        _: return "%s reste partagé au sujet du choix de %s." % [hero_name, label]

func reevaluate(event_id: String, target_id: String = "") -> Dictionary:
    var rule_value: Variant = data.get("reevaluations", {}).get(event_id, {})
    var rule: Dictionary = rule_value if rule_value is Dictionary else {}
    if rule.is_empty():
        return {"applied": false}
    var memory_type := str(rule.get("memory_type", ""))
    var vector_value: Variant = rule.get("vector", {})
    var vector: Dictionary = vector_value if vector_value is Dictionary else {}
    var changes: Array[Dictionary] = []
    var old_groups: Dictionary = {}
    var new_groups: Dictionary = {}
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var memories_value: Variant = hero.get("field_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        for index in range(memories.size()):
            var memory_value: Variant = memories[index]
            var memory: Dictionary = memory_value if memory_value is Dictionary else {}
            if str(memory.get("type", "")) != memory_type:
                continue
            if target_id != "" and str(memory.get("target_id", memory.get("species_id", memory.get("encounter_id", "")))) != target_id:
                continue
            if _reevaluation_seen(memory, event_id):
                continue
            var old_score := int(memory.get("score", 0))
            var old_stance := str(memory.get("stance", _stance(old_score)))
            var delta := clampi(_score(hero, vector), -6, 6)
            var new_score := clampi(old_score + delta, -40, 40)
            var new_stance := _stance(new_score)
            var reevaluations_value: Variant = memory.get("reevaluations", [])
            var reevaluations: Array = reevaluations_value if reevaluations_value is Array else []
            reevaluations.append({
                "event_id": event_id,
                "chapter_id": CampaignState.current_chapter_id,
                "score_delta": delta,
                "previous_stance": old_stance,
                "stance": new_stance,
                "text": str(rule.get("text", event_id))
            })
            memory["score"] = new_score
            memory["stance"] = new_stance
            memory["reevaluations"] = reevaluations
            memories[index] = memory
            hero["field_memories"] = memories
            var hero_id := str(hero.get("id", ""))
            old_groups[hero_id] = _stance_group(old_stance)
            new_groups[hero_id] = _stance_group(new_stance)
            changes.append({"hero_id": hero_id, "memory_id": str(memory.get("id", "")), "old_stance": old_stance, "stance": new_stance})
            field_memory_reframed.emit(hero_id, str(memory.get("id", "")), event_id)
    if changes.is_empty():
        return {"applied": false}
    _apply_reevaluation_relationships(old_groups, new_groups, event_id)
    var text := str(rule.get("text", "Un ancien choix revient dans la mémoire de la compagnie."))
    field_memory_moment.emit(text)
    GameState.add_log("MÉMOIRE DE TERRAIN — " + text)
    return {"applied": true, "event_id": event_id, "changes": changes, "text": text}

func _record_field_decision(memory_type: String, choice_label: String, context: Dictionary) -> Dictionary:
    prepare_party()
    var vector_value: Variant = data.get("decision_vectors", {}).get(memory_type, {})
    var vector: Dictionary = vector_value if vector_value is Dictionary else {}
    if vector.is_empty():
        return {"applied": false}
    var memory_id := _memory_id(memory_type, context)
    var observers: Array[Dictionary] = GameState.alive_heroes()
    var reactions: Dictionary = {}
    var added := 0
    for hero_value in observers:
        var hero: Dictionary = hero_value
        if _find_memory(hero, memory_id) >= 0:
            continue
        var score := _score(hero, vector)
        var stance := _stance(score)
        var memory := {
            "id": memory_id,
            "type": memory_type,
            "choice_label": choice_label,
            "chapter_id": CampaignState.current_chapter_id,
            "zone_id": str(context.get("zone_id", AshlandsRuntime.current_zone_id)),
            "witness_mode": str(context.get("witness_mode", "direct")),
            "initial_score": score,
            "score": score,
            "initial_stance": stance,
            "stance": stance,
            "reevaluations": []
        }
        for key_value in context.keys():
            var key := str(key_value)
            memory[key] = context.get(key_value)
        var memories_value: Variant = hero.get("field_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        memories.append(memory)
        _trim_memories(memories)
        hero["field_memories"] = memories
        reactions[str(hero.get("id", ""))] = {"score": score, "stance": stance}
        added += 1
        field_memory_recorded.emit(str(hero.get("id", "")), memory_id)
    if added <= 0:
        return {"applied": false}
    _apply_initial_relationships(observers, reactions, memory_id)
    var text := _collective_line(choice_label, reactions)
    field_memory_moment.emit(text)
    GameState.add_log("MÉMOIRE DE TERRAIN — " + text)
    return {"applied": true, "memory_id": memory_id, "reactions": reactions, "text": text}

func _on_creature_captured(creature: Dictionary) -> void:
    var species_id := str(creature.get("species_id", ""))
    var creature_name := str(creature.get("name", "une créature"))
    _record_field_decision("creature_recruited", "lier %s à la compagnie" % creature_name, {
        "species_id": species_id,
        "target_id": species_id,
        "creature_name": creature_name,
        "instance_id": str(creature.get("instance_id", "")),
        "zone_id": AshlandsRuntime.current_zone_id,
        "witness_mode": "direct"
    })

func _on_creature_leveled(creature: Dictionary) -> void:
    var species_id := str(creature.get("species_id", ""))
    if species_id != "":
        reevaluate("creature_proved_itself", species_id)

func _on_expedition_ended(reason: String) -> void:
    if reason in ["voluntary", "defeat", "retreat"]:
        record_expedition_retreat(reason)

func _on_combat_finished(encounter_id: String, victory: bool, _loot: Dictionary) -> void:
    if not victory or encounter_id == "":
        return
    if boss_outcome_eligible(encounter_id) and not has_boss_outcome(encounter_id):
        # Filet de sécurité pour les parcours automatisés ou anciennes interfaces :
        # une victoire ne doit pas effacer l'événement de la mémoire même si le choix
        # post-combat n'a pas pu être présenté.
        _record_field_decision("boss_executed", "laisser mourir %s après sa défaite" % boss_name(encounter_id), {
            "encounter_id": encounter_id,
            "boss_name": boss_name(encounter_id),
            "outcome": "legacy_defeat",
            "zone_id": AshlandsRuntime.current_zone_id,
            "witness_mode": "direct"
        })

func _memory_id(memory_type: String, context: Dictionary) -> String:
    var anchor := str(context.get("encounter_id", context.get("event_id", context.get("instance_id", context.get("return_reason", "event")))))
    return "field:%s:%s:%s" % [memory_type, anchor, CampaignState.current_chapter_id]

func _score(hero: Dictionary, vector: Dictionary) -> int:
    var convictions_value: Variant = hero.get("convictions", {})
    var convictions: Dictionary = convictions_value if convictions_value is Dictionary else {}
    var total := 0
    for key_value in vector.keys():
        var key := str(key_value)
        total += int(convictions.get(key, 0)) * int(vector.get(key_value, 0))
    return total

func _stance(score: int) -> String:
    var thresholds_value: Variant = data.get("stance_thresholds", {})
    var thresholds: Dictionary = thresholds_value if thresholds_value is Dictionary else {}
    if score >= int(thresholds.get("strong_support", 8)):
        return "strong_support"
    if score >= int(thresholds.get("support", 4)):
        return "support"
    if score <= int(thresholds.get("strong_oppose", -8)):
        return "strong_oppose"
    if score <= int(thresholds.get("oppose", -4)):
        return "oppose"
    return "uncertain"

func _stance_group(stance: String) -> int:
    if stance in ["strong_support", "support"]:
        return 1
    if stance in ["strong_oppose", "oppose"]:
        return -1
    return 0

func _find_memory(hero: Dictionary, memory_id: String) -> int:
    var memories_value: Variant = hero.get("field_memories", [])
    var memories: Array = memories_value if memories_value is Array else []
    for index in range(memories.size()):
        var memory_value: Variant = memories[index]
        var memory: Dictionary = memory_value if memory_value is Dictionary else {}
        if str(memory.get("id", "")) == memory_id:
            return index
    return -1

func _reevaluation_seen(memory: Dictionary, event_id: String) -> bool:
    for item_value in memory.get("reevaluations", []):
        var item: Dictionary = item_value
        if str(item.get("event_id", "")) == event_id:
            return true
    return false

func _trim_memories(memories: Array) -> void:
    var limit := int(data.get("history_limit", 20))
    while memories.size() > limit:
        memories.pop_front()

func _apply_initial_relationships(observers: Array[Dictionary], reactions: Dictionary, memory_id: String) -> void:
    var effects_value: Variant = data.get("relationship_effects", {})
    var effects: Dictionary = effects_value if effects_value is Dictionary else {}
    for left_index in range(observers.size()):
        var left: Dictionary = observers[left_index]
        var left_reaction_value: Variant = reactions.get(str(left.get("id", "")), {})
        var left_reaction: Dictionary = left_reaction_value if left_reaction_value is Dictionary else {}
        for right_index in range(left_index + 1, observers.size()):
            var right: Dictionary = observers[right_index]
            var right_reaction_value: Variant = reactions.get(str(right.get("id", "")), {})
            var right_reaction: Dictionary = right_reaction_value if right_reaction_value is Dictionary else {}
            if left_reaction.is_empty() or right_reaction.is_empty():
                continue
            var left_group := _stance_group(str(left_reaction.get("stance", "uncertain")))
            var right_group := _stance_group(str(right_reaction.get("stance", "uncertain")))
            if left_group != 0 and left_group == right_group:
                _apply_relationship_mutual(left, right, effects.get("same_side", {}), "field_alignment:%s" % memory_id)
                if absi(int(left_reaction.get("score", 0))) >= 8 and absi(int(right_reaction.get("score", 0))) >= 8:
                    _apply_relationship_mutual(left, right, effects.get("strong_same_side", {}), "field_conviction:%s" % memory_id)
            elif left_group * right_group < 0:
                _apply_relationship_mutual(left, right, effects.get("opposite_side", {}), "field_disagreement:%s" % memory_id)
                if absi(int(left_reaction.get("score", 0))) >= 8 and absi(int(right_reaction.get("score", 0))) >= 8:
                    _apply_relationship_mutual(left, right, effects.get("strong_opposition", {}), "field_resentment:%s" % memory_id)

func _apply_reevaluation_relationships(old_groups: Dictionary, new_groups: Dictionary, event_id: String) -> void:
    var effects_value: Variant = data.get("relationship_effects", {})
    var effects: Dictionary = effects_value if effects_value is Dictionary else {}
    var ids: Array = new_groups.keys()
    for left_index in range(ids.size()):
        for right_index in range(left_index + 1, ids.size()):
            var left_id := str(ids[left_index])
            var right_id := str(ids[right_index])
            var old_product := int(old_groups.get(left_id, 0)) * int(old_groups.get(right_id, 0))
            var new_product := int(new_groups.get(left_id, 0)) * int(new_groups.get(right_id, 0))
            var left := _hero_by_id(left_id)
            var right := _hero_by_id(right_id)
            if old_product < 0 and new_product >= 0:
                _apply_relationship_mutual(left, right, effects.get("later_convergence", {}), "field_convergence:%s" % event_id)
            elif old_product >= 0 and new_product < 0:
                _apply_relationship_mutual(left, right, effects.get("later_divergence", {}), "field_divergence:%s" % event_id)

func _apply_relationship_mutual(left: Dictionary, right: Dictionary, delta_value: Variant, event_id: String) -> void:
    var delta: Dictionary = delta_value if delta_value is Dictionary else {}
    _apply_relationship_delta(left, right, delta, event_id)
    _apply_relationship_delta(right, left, delta, event_id)

func _apply_relationship_delta(source: Dictionary, target: Dictionary, delta: Dictionary, event_id: String) -> void:
    if source.is_empty() or target.is_empty() or delta.is_empty():
        return
    var state := RelationshipRuntime.relation(source, target)
    if state.is_empty():
        return
    for metric in RELATIONSHIP_METRICS:
        if delta.has(metric):
            state[metric] = clampi(int(state.get(metric, 0)) + int(delta.get(metric, 0)), 0, 100)
    var history_value: Variant = state.get("history", [])
    var history: Array = history_value if history_value is Array else []
    history.append({"event_id": event_id, "chapter": CampaignState.current_chapter_id})
    while history.size() > RELATIONSHIP_HISTORY_LIMIT:
        history.pop_front()
    state["history"] = history
    var relationships_value: Variant = source.get("relationships", {})
    var relationships: Dictionary = relationships_value if relationships_value is Dictionary else {}
    relationships[str(target.get("id", ""))] = state
    source["relationships"] = relationships
    RelationshipRuntime.relationship_changed.emit(str(source.get("id", "")), str(target.get("id", "")), event_id)

func _collective_line(choice_label: String, reactions: Dictionary) -> String:
    var support := 0
    var oppose := 0
    for reaction_value in reactions.values():
        var reaction: Dictionary = reaction_value
        var group := _stance_group(str(reaction.get("stance", "uncertain")))
        if group > 0:
            support += 1
        elif group < 0:
            oppose += 1
    if support > 0 and oppose > 0:
        return "Le choix de %s divise immédiatement ceux qui l'ont vu." % choice_label
    if support > 0:
        return "Le choix de %s trouve un écho favorable dans la compagnie." % choice_label
    if oppose > 0:
        return "Le choix de %s laisse un malaise durable parmi les témoins." % choice_label
    return "Le choix de %s reste difficile à juger pour ceux qui étaient présents." % choice_label

func _hero_by_id(hero_id: String) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}
