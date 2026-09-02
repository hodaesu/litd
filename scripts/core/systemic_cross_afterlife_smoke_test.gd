extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    GameState.current_screen = "expedition"
    await _frames(2)
    CampaignState.current_chapter_id = "chapter_02_before_fall"
    CampaignState.campaign_changed.emit()

    var source_id: String = "cross.food.local_security_and_grain_bridge"
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.lhaor_seeds_that_remain", "protect_lhaor_basin"), "The first source choice must be recorded")
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.dhor_khal_bridge_two_valleys", "restore_grain_bridge"), "The second source choice must be recorded")
    await _frames(2)
    _check(SystemicCrossRuntime.event_applied(source_id), "The source crossing must exist before an afterlife can emerge")
    _check(SystemicCrossAfterlifeRuntime.pending_beat_count() == 0, "No delayed echo may appear in the same chapter as its source")
    _check(SystemicCrossAfterlifeRuntime.relation_history_for("hero.aurelien", "hero.mathilde").is_empty(), "A relationship echo must not be fabricated immediately")

    CampaignState.current_chapter_id = "chapter_03_threshold"
    CampaignState.campaign_changed.emit()
    await _frames(2)
    _check(SystemicCrossAfterlifeRuntime.pending_beat_count() == 1, "One chapter later the source must queue exactly one delayed echo")
    var relation_history: Array[Dictionary] = SystemicCrossAfterlifeRuntime.relation_history_for("hero.aurelien", "hero.mathilde")
    _check(relation_history.size() == 1, "The delayed consequence must leave one non-numeric relationship echo for its canonical pair")
    if not relation_history.is_empty():
        _check(str(relation_history[0].get("tag", "")) != "", "A relationship echo must preserve a qualitative meaning")
        _check(relation_history[0].get("numeric_score", true) is bool and not bool(relation_history[0].get("numeric_score", true)), "A relationship echo must never become an approval score")
    _check(_rumor_contains("plan unique"), "The delayed phase must add a traceable transformed rumor")
    _check(CommunityRuntime.knows_fact("systemic_cross", "systemic_fact_cross_food_local_security_and_grain_bridge"), "Rumor transformation must never erase the original fact")

    GameState.request_screen("sanctuary")
    await _frames(3)
    _check(SystemicCrossNarrativeRuntime.scene_seen(source_id), "The immediate sanctuary consequence must keep priority on the first return")
    _check(SystemicCrossAfterlifeRuntime.pending_beat_count() == 1, "The delayed echo must wait if an immediate systemic scene was presented on that return")
    _check(not _phase_presented(source_id, "echo"), "Immediate and delayed scenes must not stack on the same sanctuary entry")

    GameState.current_screen = "expedition"
    GameState.request_screen("sanctuary")
    await _frames(3)
    _check(_phase_presented(source_id, "echo"), "The next sanctuary return must surface the delayed echo")
    _check(SystemicCrossAfterlifeRuntime.pending_beat_count() == 0, "A presented delayed echo must leave the queue")

    CampaignState.current_chapter_id = "chapter_04_first_rupture"
    CampaignState.campaign_changed.emit()
    await _frames(2)
    var remanences: Array[Dictionary] = SystemicCrossAfterlifeRuntime.remanences()
    _check(remanences.size() == 1, "Two chapters later the source must produce one emergent Remanence")
    if not remanences.is_empty():
        var remanence: Dictionary = remanences[0]
        _check(remanence.has("SOURCE") and remanence.has("TRANSMISSION") and remanence.has("REMANENCE"), "A Remanence must preserve SOURCE -> TRANSMISSION -> REMANENCE")
        var transmission_value: Variant = remanence.get("TRANSMISSION", {})
        var transmission: Dictionary = transmission_value if transmission_value is Dictionary else {}
        _check(bool(transmission.get("source_trace_preserved", false)), "A Remanence must keep its source trace")
        _check(str(remanence.get("status", "")) == "emergent_not_objective_truth", "A future interpretation must not become objective cosmology")
    _check(_rumor_contains("existait avant la crise"), "The Remanence phase must make visible how emergency practice can be mythologized")

    GameState.current_screen = "expedition"
    GameState.request_screen("sanctuary")
    await _frames(3)
    _check(_phase_presented(source_id, "remanence"), "The emergent Remanence must be surfaced on a later sanctuary return")

    var systemic_snapshot: Dictionary = SystemicCrossRuntime.serialize()
    SystemicCrossRuntime.reset_new_game()
    SystemicCrossAfterlifeRuntime.reset_new_game()
    _check(SystemicCrossAfterlifeRuntime.remanences().is_empty(), "A genuine reset must clear afterlives with their source crossings")
    SystemicCrossRuntime.deserialize(systemic_snapshot)
    CampaignState.campaign_changed.emit()
    await _frames(2)
    _check(SystemicCrossAfterlifeRuntime.remanences().size() == 1, "Afterlife history must persist through the existing systemic-cross save payload")
    _check(SystemicCrossAfterlifeRuntime.relation_history_for("aurelien", "mathilde").size() == 1, "Relationship echoes must persist without a separate global meter")

    _finish()

func _phase_presented(source_id: String, phase: String) -> bool:
    var source_value: Variant = SystemicCrossRuntime.applied_events.get(source_id, {})
    var source: Dictionary = source_value if source_value is Dictionary else {}
    var afterlife_value: Variant = source.get("afterlife", {})
    var afterlife: Dictionary = afterlife_value if afterlife_value is Dictionary else {}
    var presented_value: Variant = afterlife.get("presented_phases", [])
    var presented: Array = presented_value if presented_value is Array else []
    return presented.has(phase)

func _rumor_contains(fragment: String) -> bool:
    for line: String in CommunityRuntime.recent_rumor_lines(24):
        if line.contains(fragment):
            return true
    return false

func _frames(count: int) -> void:
    for _index: int in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("SYSTEMIC_CROSS_AFTERLIFE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("SYSTEMIC_CROSS_AFTERLIFE_SMOKE: " + failure)
    print("SYSTEMIC_CROSS_AFTERLIFE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
