extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    DecisionMemoryRuntime.prepare_party()
    await _frames(2)

    _check(GameState.party.size() >= 4, "Decision-memory smoke requires the authored four-hero test party")
    if GameState.party.size() < 2:
        _finish()
        return

    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        _check(hero.get("convictions", {}) is Dictionary, "Every hero must receive a conviction profile")
        _check(hero.get("decision_memories", []) is Array, "Every hero must carry persistent decision memories")

    GameState.expedition_room = 1
    PoliticalState.refresh_unlocks()
    _check(PoliticalState.quest_status("ashlands_refugee_gate") == "available", "Refugee-gate decision must be available in the smoke setup")
    var completed := PoliticalState.complete_quest("ashlands_refugee_gate", "welcome")
    _check(completed, "Political choice must complete successfully")
    await _frames(3)

    var memory_id := "politics:ashlands_refugee_gate:welcome"
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        _check(_memory(hero, memory_id).size() > 0, "Political choices must become memories for heroes who were present")

    var aurelien := _hero("aurelien")
    var malvor := _hero("malvor")
    var lysandra := _hero("lysandra")
    var darius := _hero("darius")
    _check(str(_memory(aurelien, memory_id).get("stance", "")) == "strong_support", "Aurélien's authored convictions must strongly support opening the gates")
    _check(str(_memory(malvor, memory_id).get("stance", "")) == "oppose", "Malvor's authored convictions must oppose the risky opening")
    _check(str(_memory(lysandra, memory_id).get("stance", "")) == "strong_support", "Lysandra's authored convictions must strongly support solidarity")
    _check(str(_memory(darius, memory_id).get("stance", "")) == "uncertain", "Darius must begin conflicted between solidarity and security")

    var aurelien_to_malvor := RelationshipRuntime.relation(aurelien, malvor)
    _check(int(aurelien_to_malvor.get("mistrust", 0)) >= 2, "Opposite convictions must create a small playable relationship tension")
    var aurelien_to_lysandra := RelationshipRuntime.relation(aurelien, lysandra)
    _check(int(aurelien_to_lysandra.get("trust", 0)) >= 2, "Shared convictions must create a small trust gain")

    var social_event := _social_event("xenophobic_whisper")
    _check(not social_event.is_empty(), "Smoke requires the delayed xenophobic-whisper event")
    var darius_mistrust_before := int(RelationshipRuntime.relation(darius, aurelien).get("mistrust", 0))
    var reframed := DecisionMemoryRuntime.record_social_event(social_event)
    _check(bool(reframed.get("applied", false)), "A later social event must be able to reframe an earlier decision")
    var darius_memory := _memory(darius, memory_id)
    _check(str(darius_memory.get("stance", "")) == "oppose", "Darius must be able to change his mind when later events validate his security concerns")
    _check(not darius_memory.get("reevaluations", []).is_empty(), "Reframing must be stored inside the persistent decision memory")
    _check(int(RelationshipRuntime.relation(darius, aurelien).get("mistrust", 0)) > darius_mistrust_before, "A new disagreement after reevaluation must affect the relationship")

    var repeated := DecisionMemoryRuntime.record_social_event(social_event)
    _check(not bool(repeated.get("applied", false)), "The same delayed consequence must never be applied twice")

    var summary := DecisionMemoryRuntime.decision_summary("ashlands_refugee_gate")
    _check(summary != "", "Completed decisions must expose a narrative company summary")
    _check(not summary.contains("/100"), "Decision summaries must not expose hidden relationship or conviction meters")
    var lines := DecisionMemoryRuntime.recent_memory_lines(3)
    _check(not lines.is_empty(), "The Sanctuary must be able to surface recent decision memories as prose")

    var serialized := JSON.stringify(GameState.party)
    _check(serialized.contains("convictions"), "Convictions must persist through the existing party save payload")
    _check(serialized.contains("decision_memories"), "Decision memories must persist through the existing party save payload")
    _finish()

func _hero(hero_id: String) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _memory(hero: Dictionary, memory_id: String) -> Dictionary:
    for value in hero.get("decision_memories", []):
        var memory: Dictionary = value
        if str(memory.get("id", "")) == memory_id:
            return memory
    return {}

func _social_event(event_id: String) -> Dictionary:
    for value in PoliticalState.social_data.get("dynamic_events", []):
        var event: Dictionary = value
        if str(event.get("id", "")) == event_id:
            return event
    return {}

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("DECISION_MEMORY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("DECISION_MEMORY_SMOKE: " + failure)
    print("DECISION_MEMORY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
