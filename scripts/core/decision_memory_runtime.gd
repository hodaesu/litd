extends Node

signal decision_memory_recorded(hero_id: String, memory_id: String)
signal decision_memory_reframed(hero_id: String, memory_id: String, event_id: String)
signal collective_memory(text: String)

const DATA_PATH := "res://data/hero_decision_memory.json"
const RELATIONSHIP_HISTORY_LIMIT: int = 16
const RELATIONSHIP_METRICS: Array[String] = ["trust", "admiration", "mistrust", "resentment"]

var data: Dictionary = {}

func _ready() -> void:
    _load_data()
    if not GameState.state_changed.is_connected(_on_state_changed):
        GameState.state_changed.connect(_on_state_changed)
    prepare_party()

func _load_data() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func _on_state_changed() -> void:
    prepare_party()

func prepare_party() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var defaults: Dictionary = _profile_for(str(hero.get("id", "")))
        if not hero.has("convictions") or not (hero.get("convictions", {}) is Dictionary):
            hero["convictions"] = defaults.duplicate(true)
        else:
            var convictions: Dictionary = hero.get("convictions", {})
            for key_value in data.get("convictions", []):
                var key: String = str(key_value)
                if not convictions.has(key):
                    convictions[key] = int(defaults.get(key, 0))
            hero["convictions"] = convictions
        if not hero.has("decision_memories") or not (hero.get("decision_memories", []) is Array):
            hero["decision_memories"] = []

func record_political_choice(quest: Dictionary, choice_id: String, choice: Dictionary) -> Dictionary:
    prepare_party()
    var quest_id: String = str(quest.get("id", ""))
    if quest_id == "" or choice_id == "":
        return {"applied": false}
    var vector: Dictionary = _choice_vector(quest_id, choice_id)
    if vector.is_empty():
        return {"applied": false}
    var memory_id: String = _memory_id(quest_id, choice_id)
    var observers: Array[Dictionary] = GameState.alive_heroes()
    var reactions: Dictionary = {}
    var added: int = 0
    for hero_value in observers:
        var hero: Dictionary = hero_value
        if _find_memory(hero, memory_id) >= 0:
            continue
        var score: int = _score(hero, vector)
        var stance: String = _stance(score)
        var memory: Dictionary = {
            "id": memory_id,
            "type": "political_choice",
            "quest_id": quest_id,
            "quest_name": str(quest.get("name", quest_id)),
            "choice_id": choice_id,
            "choice_label": str(choice.get("label", choice_id)),
            "chapter_id": CampaignState.current_chapter_id,
            "initial_score": score,
            "score": score,
            "initial_stance": stance,
            "stance": stance,
            "rationale": _rationale(hero, vector),
            "reevaluations": []
        }
        var memories: Array = hero.get("decision_memories", [])
        memories.append(memory)
        _trim_memories(memories)
        hero["decision_memories"] = memories
        reactions[str(hero.get("id", ""))] = {"score": score, "stance": stance}
        added += 1
        decision_memory_recorded.emit(str(hero.get("id", "")), memory_id)
    if added <= 0:
        return {"applied": false}
    _apply_initial_relationship_reactions(observers, reactions, memory_id)
    var line: String = _collective_choice_line(choice, observers, reactions)
    collective_memory.emit(line)
    GameState.add_log("MÉMOIRE — " + line)
    return {"applied": true, "memory_id": memory_id, "reactions": reactions, "text": line}

func record_social_event(event: Dictionary) -> Dictionary:
    prepare_party()
    var event_id: String = str(event.get("id", ""))
    if event_id == "":
        return {"applied": false}
    var rules_value: Variant = data.get("social_reevaluations", {}).get(event_id, [])
    var rules: Array = rules_value if rules_value is Array else []
    if rules.is_empty():
        return {"applied": false}
    var changes: Array[Dictionary] = []
    for rule_value in rules:
        var rule: Dictionary = rule_value
        var quest_id: String = str(rule.get("quest_id", ""))
        var choice_id: String = str(rule.get("choice_id", ""))
        var memory_id: String = _memory_id(quest_id, choice_id)
        var old_groups: Dictionary = {}
        var new_groups: Dictionary = {}
        for hero_value in GameState.party:
            var hero: Dictionary = hero_value
            var index: int = _find_memory(hero, memory_id)
            if index < 0:
                continue
            var memories: Array = hero.get("decision_memories", [])
            var memory: Dictionary = memories[index]
            if _reevaluation_seen(memory, event_id):
                continue
            var old_score: int = int(memory.get("score", 0))
            var old_stance: String = str(memory.get("stance", _stance(old_score)))
            var raw_delta: int = _score(hero, rule.get("score_vector", {}))
            var score_delta: int = clampi(raw_delta, -6, 6)
            var new_score: int = clampi(old_score + score_delta, -40, 40)
            var new_stance: String = _stance(new_score)
            var reevaluations: Array = memory.get("reevaluations", [])
            reevaluations.append({
                "event_id": event_id,
                "chapter_id": CampaignState.current_chapter_id,
                "score_delta": score_delta,
                "previous_stance": old_stance,
                "stance": new_stance,
                "text": str(rule.get("text", event.get("name", event_id)))
            })
            memory["score"] = new_score
            memory["stance"] = new_stance
            memory["reevaluations"] = reevaluations
            memories[index] = memory
            hero["decision_memories"] = memories
            var hero_id: String = str(hero.get("id", ""))
            old_groups[hero_id] = _stance_group(old_stance)
            new_groups[hero_id] = _stance_group(new_stance)
            changes.append({
                "hero_id": hero_id,
                "hero_name": str(hero.get("name", "Le héros")),
                "memory_id": memory_id,
                "old_stance": old_stance,
                "stance": new_stance,
                "score_delta": score_delta
            })
            decision_memory_reframed.emit(hero_id, memory_id, event_id)
        _apply_reevaluation_relationships(old_groups, new_groups, memory_id, event_id)
    if changes.is_empty():
        return {"applied": false}
    var line: String = _collective_reevaluation_line(event, changes)
    collective_memory.emit(line)
    GameState.add_log("MÉMOIRE — " + line)
    return {"applied": true, "event_id": event_id, "changes": changes, "text": line}

func decision_summary(quest_id: String) -> String:
    var support: int = 0
    var oppose: int = 0
    var uncertain: int = 0
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var memory: Dictionary = _latest_memory_for_quest(hero, quest_id)
        if memory.is_empty():
            continue
        var group: int = _stance_group(str(memory.get("stance", "uncertain")))
        if group > 0:
            support += 1
        elif group < 0:
            oppose += 1
        else:
            uncertain += 1
    if support + oppose + uncertain == 0:
        return ""
    if support > 0 and oppose > 0:
        return "La compagnie reste divisée sur cette décision."
    if support > 0:
        return "La compagnie tend à assumer cette décision, même si certains doutent encore." if uncertain > 0 else "La compagnie assume largement cette décision."
    if oppose > 0:
        return "La décision laisse un malaise durable dans la compagnie."
    return "La compagnie n'a pas encore arrêté son jugement."

func hero_memory_line(hero: Dictionary) -> String:
    if hero.is_empty():
        return ""
    var memories: Array = hero.get("decision_memories", [])
    if memories.is_empty():
        return ""
    var memory: Dictionary = memories[memories.size() - 1]
    var stance: String = str(memory.get("stance", "uncertain"))
    var choice_label: String = str(memory.get("choice_label", "cette décision"))
    var hero_name: String = str(hero.get("name", "Le héros"))
    match stance:
        "strong_support": return "%s considère encore « %s » comme un choix essentiel." % [hero_name, choice_label]
        "support": return "%s continue d'approuver « %s »." % [hero_name, choice_label]
        "oppose": return "%s n'a toujours pas accepté « %s »." % [hero_name, choice_label]
        "strong_oppose": return "%s garde un profond ressentiment envers « %s »." % [hero_name, choice_label]
        _: return "%s reste partagé au sujet de « %s »." % [hero_name, choice_label]

func recent_memory_lines(limit: int = 3) -> Array[String]:
    var result: Array[String] = []
    var candidates: Array[Dictionary] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var memories: Array = hero.get("decision_memories", [])
        if memories.is_empty():
            continue
        var memory: Dictionary = memories[memories.size() - 1]
        var reevaluations: Array = memory.get("reevaluations", [])
        var importance: int = absi(int(memory.get("score", 0))) + reevaluations.size() * 3
        candidates.append({"importance": importance, "hero": hero})
    candidates.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("importance", 0)) > int(right.get("importance", 0)))
    for index in range(mini(limit, candidates.size())):
        var hero_value: Variant = candidates[index].get("hero", {})
        var candidate_hero: Dictionary = hero_value if hero_value is Dictionary else {}
        var line: String = hero_memory_line(candidate_hero)
        if line != "":
            result.append(line)
    return result

func conviction_summary(hero: Dictionary) -> String:
    if hero.is_empty():
        return ""
    var convictions: Dictionary = hero.get("convictions", {})
    var ranked: Array[Dictionary] = []
    for key_value in data.get("convictions", []):
        var key: String = str(key_value)
        ranked.append({"key": key, "weight": int(convictions.get(key, 0))})
    ranked.sort_custom(func(left: Dictionary, right: Dictionary): return absi(int(left.get("weight", 0))) > absi(int(right.get("weight", 0))))
    var labels: Array[String] = []
    for item in ranked:
        if int(item.get("weight", 0)) <= 0:
            continue
        labels.append(_conviction_label(str(item.get("key", ""))))
        if labels.size() >= 2:
            break
    if labels.is_empty():
        return "convictions encore difficiles à lire"
    return "attentif surtout à %s" % " et ".join(labels)

func _apply_initial_relationship_reactions(observers: Array[Dictionary], reactions: Dictionary, memory_id: String) -> void:
    var effects: Dictionary = data.get("relationship_effects", {})
    for left_index in range(observers.size()):
        var left: Dictionary = observers[left_index]
        var left_reaction: Dictionary = reactions.get(str(left.get("id", "")), {})
        if left_reaction.is_empty():
            continue
        for right_index in range(left_index + 1, observers.size()):
            var right: Dictionary = observers[right_index]
            var right_reaction: Dictionary = reactions.get(str(right.get("id", "")), {})
            if right_reaction.is_empty():
                continue
            var left_group: int = _stance_group(str(left_reaction.get("stance", "uncertain")))
            var right_group: int = _stance_group(str(right_reaction.get("stance", "uncertain")))
            if left_group != 0 and left_group == right_group:
                _apply_relationship_mutual(left, right, effects.get("same_side", {}), "decision_alignment:%s" % memory_id)
                if absi(int(left_reaction.get("score", 0))) >= _strong_threshold() and absi(int(right_reaction.get("score", 0))) >= _strong_threshold():
                    _apply_relationship_mutual(left, right, effects.get("strong_same_side", {}), "decision_conviction:%s" % memory_id)
            elif left_group * right_group < 0:
                _apply_relationship_mutual(left, right, effects.get("opposite_side", {}), "decision_disagreement:%s" % memory_id)
                if absi(int(left_reaction.get("score", 0))) >= _strong_threshold() and absi(int(right_reaction.get("score", 0))) >= _strong_threshold():
                    _apply_relationship_mutual(left, right, effects.get("strong_opposition", {}), "decision_resentment:%s" % memory_id)

func _apply_reevaluation_relationships(old_groups: Dictionary, new_groups: Dictionary, memory_id: String, event_id: String) -> void:
    var ids: Array = new_groups.keys()
    var effects: Dictionary = data.get("relationship_effects", {})
    for left_index in range(ids.size()):
        for right_index in range(left_index + 1, ids.size()):
            var left_id: String = str(ids[left_index])
            var right_id: String = str(ids[right_index])
            var old_product: int = int(old_groups.get(left_id, 0)) * int(old_groups.get(right_id, 0))
            var new_product: int = int(new_groups.get(left_id, 0)) * int(new_groups.get(right_id, 0))
            var left: Dictionary = _hero_by_id(left_id)
            var right: Dictionary = _hero_by_id(right_id)
            if old_product < 0 and new_product >= 0:
                _apply_relationship_mutual(left, right, effects.get("reevaluation_convergence", {}), "decision_convergence:%s:%s" % [memory_id, event_id])
            elif old_product >= 0 and new_product < 0:
                _apply_relationship_mutual(left, right, effects.get("reevaluation_divergence", {}), "decision_divergence:%s:%s" % [memory_id, event_id])

func _apply_relationship_mutual(left: Dictionary, right: Dictionary, delta_value: Variant, event_id: String) -> void:
    var delta: Dictionary = delta_value if delta_value is Dictionary else {}
    _apply_relationship_delta(left, right, delta, event_id)
    _apply_relationship_delta(right, left, delta, event_id)

func _apply_relationship_delta(source: Dictionary, target: Dictionary, delta: Dictionary, event_id: String) -> void:
    if source.is_empty() or target.is_empty() or delta.is_empty():
        return
    var state: Dictionary = RelationshipRuntime.relation(source, target)
    if state.is_empty():
        return
    for metric in RELATIONSHIP_METRICS:
        if delta.has(metric):
            state[metric] = clampi(int(state.get(metric, 0)) + int(delta.get(metric, 0)), 0, 100)
    var history: Array = state.get("history", [])
    history.append({"event_id": event_id, "chapter": CampaignState.current_chapter_id})
    while history.size() > RELATIONSHIP_HISTORY_LIMIT:
        history.pop_front()
    state["history"] = history
    var relationships: Dictionary = source.get("relationships", {})
    relationships[str(target.get("id", ""))] = state
    source["relationships"] = relationships
    RelationshipRuntime.relationship_changed.emit(str(source.get("id", "")), str(target.get("id", "")), event_id)

func _collective_choice_line(choice: Dictionary, observers: Array[Dictionary], reactions: Dictionary) -> String:
    var supporters: int = 0
    var opponents: int = 0
    for hero_value in observers:
        var hero: Dictionary = hero_value
        var reaction: Dictionary = reactions.get(str(hero.get("id", "")), {})
        var group: int = _stance_group(str(reaction.get("stance", "uncertain")))
        supporters += 1 if group > 0 else 0
        opponents += 1 if group < 0 else 0
    var label: String = str(choice.get("label", "la décision"))
    if supporters > 0 and opponents > 0:
        return "« %s » divise déjà la compagnie : certains y voient une nécessité, d'autres une faute à ne pas oublier." % label
    if supporters > 0:
        return "« %s » trouve un écho favorable dans la compagnie, sans devenir pour autant une vérité définitive." % label
    if opponents > 0:
        return "« %s » laisse un malaise visible parmi les héros présents." % label
    return "« %s » laisse la compagnie dans l'incertitude." % label

func _collective_reevaluation_line(event: Dictionary, changes: Array[Dictionary]) -> String:
    for entry in changes:
        if str(entry.get("old_stance", "")) != str(entry.get("stance", "")):
            return "%s change la manière dont %s juge une ancienne décision." % [str(event.get("name", "Un événement")), str(entry.get("hero_name", "un héros"))]
    return "%s ravive une décision que la compagnie croyait derrière elle." % str(event.get("name", "Un événement"))

func _choice_vector(quest_id: String, choice_id: String) -> Dictionary:
    var value: Variant = data.get("choice_vectors", {}).get(quest_id, {}).get(choice_id, {})
    return value if value is Dictionary else {}

func _score(hero: Dictionary, vector_value: Variant) -> int:
    var vector: Dictionary = vector_value if vector_value is Dictionary else {}
    var convictions: Dictionary = hero.get("convictions", _profile_for(str(hero.get("id", ""))))
    var total: int = 0
    for key_value in data.get("convictions", []):
        var key: String = str(key_value)
        total += int(convictions.get(key, 0)) * int(vector.get(key, 0))
    return total

func _stance(score: int) -> String:
    var thresholds: Dictionary = data.get("stance_thresholds", {})
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
    if stance in ["support", "strong_support"]:
        return 1
    if stance in ["oppose", "strong_oppose"]:
        return -1
    return 0

func _strong_threshold() -> int:
    return int(data.get("stance_thresholds", {}).get("strong_support", 8))

func _rationale(hero: Dictionary, vector: Dictionary) -> Array[String]:
    var convictions: Dictionary = hero.get("convictions", {})
    var ranked: Array[Dictionary] = []
    for key_value in data.get("convictions", []):
        var key: String = str(key_value)
        var contribution: int = int(convictions.get(key, 0)) * int(vector.get(key, 0))
        if contribution != 0:
            ranked.append({"key": key, "contribution": contribution})
    ranked.sort_custom(func(left: Dictionary, right: Dictionary): return absi(int(left.get("contribution", 0))) > absi(int(right.get("contribution", 0))))
    var result: Array[String] = []
    for index in range(mini(2, ranked.size())):
        result.append(_conviction_label(str(ranked[index].get("key", ""))))
    return result

func _conviction_label(key: String) -> String:
    return str(data.get("conviction_labels", {}).get(key, key))

func _profile_for(hero_id: String) -> Dictionary:
    var value: Variant = data.get("hero_profiles", {}).get(hero_id, {})
    if value is Dictionary and not value.is_empty():
        return value
    var fallback: Dictionary = {}
    for key_value in data.get("convictions", []):
        fallback[str(key_value)] = 0
    return fallback

func _memory_id(quest_id: String, choice_id: String) -> String:
    return "politics:%s:%s" % [quest_id, choice_id]

func _find_memory(hero: Dictionary, memory_id: String) -> int:
    var memories: Array = hero.get("decision_memories", [])
    for index in range(memories.size()):
        var memory: Dictionary = memories[index]
        if str(memory.get("id", "")) == memory_id:
            return index
    return -1

func _latest_memory_for_quest(hero: Dictionary, quest_id: String) -> Dictionary:
    var memories: Array = hero.get("decision_memories", [])
    for index in range(memories.size() - 1, -1, -1):
        var memory: Dictionary = memories[index]
        if str(memory.get("quest_id", "")) == quest_id:
            return memory
    return {}

func _reevaluation_seen(memory: Dictionary, event_id: String) -> bool:
    for value in memory.get("reevaluations", []):
        var item: Dictionary = value
        if str(item.get("event_id", "")) == event_id:
            return true
    return false

func _trim_memories(memories: Array) -> void:
    var limit: int = maxi(1, int(data.get("history_limit", 20)))
    while memories.size() > limit:
        memories.pop_front()

func _hero_by_id(hero_id: String) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}
