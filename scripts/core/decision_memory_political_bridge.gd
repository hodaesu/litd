extends Node

func _ready() -> void:
    if not PoliticalState.politics_changed.is_connected(_on_politics_changed):
        PoliticalState.politics_changed.connect(_on_politics_changed)
    call_deferred("_sync_from_political_state")

func _on_politics_changed() -> void:
    # Les décisions de Concorde sont sauvegardées immédiatement par PoliticalUI.
    # La mémoire doit donc être créée avant le retour de complete_quest(), pas au frame suivant.
    _sync_from_political_state()

func _sync_from_political_state() -> void:
    DecisionMemoryRuntime.prepare_party()
    for quest_value in PoliticalState.completed_quests():
        var quest: Dictionary = quest_value
        var quest_id := str(quest.get("id", ""))
        var choice_id := PoliticalState.quest_choice(quest_id)
        if quest_id == "" or choice_id == "":
            continue
        var memory_id := "politics:%s:%s" % [quest_id, choice_id]
        if _party_has_memory(memory_id):
            continue
        var choice_value = quest.get("choices", {}).get(choice_id, {})
        var choice: Dictionary = choice_value if choice_value is Dictionary else {}
        DecisionMemoryRuntime.record_political_choice(quest, choice_id, choice)

    for event_id_value in PoliticalState.seen_events:
        var event_id := str(event_id_value)
        var event := _social_event(event_id)
        if not event.is_empty():
            DecisionMemoryRuntime.record_social_event(event)

func _party_has_memory(memory_id: String) -> bool:
    var found_any := false
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var found := false
        for memory_value in hero.get("decision_memories", []):
            var memory: Dictionary = memory_value
            if str(memory.get("id", "")) == memory_id:
                found = true
                found_any = true
                break
        if not found:
            return false
    return found_any

func _social_event(event_id: String) -> Dictionary:
    for event_value in PoliticalState.social_data.get("dynamic_events", []):
        var event: Dictionary = event_value
        if str(event.get("id", "")) == event_id:
            return event
    return {}
