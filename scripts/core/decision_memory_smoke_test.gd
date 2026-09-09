extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    DecisionMemoryRuntime.prepare_party()
    await _frames(2)

    _check(GameState.party.size() == 4, "Decision-memory smoke requires the canonical four-hero party")
    if GameState.party.size() < 2:
        _finish()
        return

    var expected_ids: Array[String] = ["mathilde", "marec", "anouk", "aurelien"]
    for hero_id in expected_ids:
        _check(not _hero(hero_id).is_empty(), "Current canonical hero must exist: " + hero_id)

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
    var stance_groups: Dictionary = {}
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var memory := _memory(hero, memory_id)
        _check(memory.size() > 0, "Political choices must become memories for heroes who were present")
        var stance := str(memory.get("stance", "uncertain"))
        _check(stance in ["strong_support", "support", "uncertain", "oppose", "strong_oppose"], "Every stored memory must expose a valid stance")
        stance_groups[str(hero.get("id", ""))] = stance

    _check(stance_groups.size() == 4, "All four current heroes must interpret the political choice")
    _check(_relationship_history_total() > 0, "A shared political choice must leave at least one relationship history trace")

    var social_event := _social_event("xenophobic_whisper")
    _check(not social_event.is_empty(), "Smoke requires the delayed xenophobic-whisper event")
    var reframed := DecisionMemoryRuntime.record_social_event(social_event)
    _check(bool(reframed.get("applied", false)), "A later social event must be able to reframe an earlier decision")

    var reevaluation_count := 0
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var memory := _memory(hero, memory_id)
        reevaluation_count += memory.get("reevaluations", []).size()
    _check(reevaluation_count > 0, "Reframing must be stored inside persistent decision memories")

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
    _check(not serialized.contains("malvor") and not serialized.contains("lysandra") and not serialized.contains("darius"), "Legacy starter identities must not leak into current party state")
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

func _relationship_history_total() -> int:
    var total := 0
    for source_value in GameState.party:
        var source: Dictionary = source_value
        for target_value in GameState.party:
            var target: Dictionary = target_value
            if source == target:
                continue
            var relation := RelationshipRuntime.relation(source, target)
            total += relation.get("history", []).size()
    return total

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
