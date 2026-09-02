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

    # Mathilde test fixture: the default Godot prototype roster does not contain all Seven.
    # The smoke inserts her explicitly so production code never fabricates an absent hero.
    _add_test_hero("mathilde", "Mathilde")
    RelationshipRuntime.prepare_party()
    GameState.state_changed.emit()
    await _frames(1)
    var pair_before: Dictionary = RelationshipRuntime.pair_state(_hero("aurelien"), _hero("mathilde"))

    CampaignState.current_chapter_id = "chapter_03_threshold"
    CampaignState.campaign_changed.emit()
    await _frames(3)
    _check(SystemicCrossAfterlifeRuntime.pending_beat_count() == 1, "One chapter later the source must queue exactly one delayed echo")
    var relation_history: Array[Dictionary] = SystemicCrossAfterlifeRuntime.relation_history_for("hero.aurelien", "hero.mathilde")
    _check(relation_history.size() == 1, "The delayed consequence must leave one non-numeric relationship echo for its canonical pair")
    if not relation_history.is_empty():
        _check(str(relation_history[0].get("tag", "")) != "", "A relationship echo must preserve a qualitative meaning")
        _check(relation_history[0].get("numeric_score", true) is bool and not bool(relation_history[0].get("numeric_score", true)), "A relationship echo must never become an approval score")
        _check(str(relation_history[0].get("application_state", "")) == "applied", "A present canonical pair must feed the existing RelationshipRuntime")
    var pair_after: Dictionary = RelationshipRuntime.pair_state(_hero("aurelien"), _hero("mathilde"))
    _check(int(pair_after.get("trust", 0)) > int(pair_before.get("trust", 0)), "A shared delayed burden must affect the existing RelationshipRuntime without a new meter")
    _check(_relationship_afterlife_event_count("aurelien", "mathilde") == 2, "A mutual delayed echo must write one directional history entry per living hero")
    _check(_rumor_contains("plan unique"), "The delayed phase must add a traceable transformed rumor")
    _check(CommunityRuntime.knows_fact("systemic_cross", "systemic_fact_cross_food_local_security_and_grain_bridge"), "Rumor transformation must never erase the original fact")

    var lineage_after_echo: Array[Dictionary] = SystemicCrossAfterlifeRuntime.rumor_lineage(source_id)
    _check(lineage_after_echo.size() == 2, "The rumor lineage must preserve source then echo before any Remanence")
    if lineage_after_echo.size() == 2:
        _check(str(lineage_after_echo[0].get("stage", "")) == "source", "Rumor lineage must start from the source")
        _check(str(lineage_after_echo[1].get("stage", "")) == "echo", "Rumor lineage must identify the first transformed echo")
        _check(str(lineage_after_echo[1].get("parent_source_id", "")) == source_id, "The echo must point back to its source")
        _check(str(lineage_after_echo[1].get("distortion_kind", "")) != "", "Every transformed rumor must identify its distortion_kind")

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
    await _frames(3)
    var remanences: Array[Dictionary] = SystemicCrossAfterlifeRuntime.remanences()
    _check(remanences.size() == 1, "Two chapters later the source must produce one emergent Remanence")
    if not remanences.is_empty():
        var remanence: Dictionary = remanences[0]
        _check(remanence.has("SOURCE") and remanence.has("TRANSMISSION") and remanence.has("REMANENCE"), "A Remanence must preserve SOURCE -> TRANSMISSION -> REMANENCE")
        var transmission_value: Variant = remanence.get("TRANSMISSION", {})
        var transmission: Dictionary = transmission_value if transmission_value is Dictionary else {}
        _check(bool(transmission.get("source_trace_preserved", false)), "A Remanence must keep its source trace")
        _check(str(transmission.get("future_target", "")) == "post_litd1", "A LITD1 Remanence must only target the post-LITD1 future_target")
        _check(transmission.get("backward_causation", true) is bool and not bool(transmission.get("backward_causation", true)), "A LITD1 Remanence must keep backward_causation false")
        _check(str(remanence.get("status", "")) == "emergent_not_objective_truth", "A future interpretation must not become objective cosmology")
    _check(_rumor_contains("existait avant la crise"), "The Remanence phase must make visible how emergency practice can be mythologized")

    var full_lineage: Array[Dictionary] = SystemicCrossAfterlifeRuntime.rumor_lineage(source_id)
    _check(full_lineage.size() == 3, "The rumor lineage must keep source, echo and remanence stages together")
    if full_lineage.size() == 3:
        _check(str(full_lineage[2].get("stage", "")) == "remanence", "The final rumor lineage stage must be remanence")
        _check(str(full_lineage[2].get("parent_source_id", "")) == "afterlife.echo." + source_id, "The Remanence rumor must retain its echo parent")
        _check(full_lineage[2].get("backward_causation", true) is bool and not bool(full_lineage[2].get("backward_causation", true)), "Rumor lineage must never back-cause earlier games")

    GameState.current_screen = "expedition"
    GameState.request_screen("sanctuary")
    await _frames(3)
    _check(_phase_presented(source_id, "remanence"), "The emergent Remanence must be surfaced on a later sanctuary return")

    # A second, unrelated systemic consequence later in the campaign must accumulate on the
    # same relationship through a distinct history entry instead of overwriting the first one.
    CampaignState.current_chapter_id = "chapter_08_outer_world"
    CampaignState.campaign_changed.emit()
    await _frames(2)
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.azravel_burned_margins", "wounded_and_food"), "The Azravel survival choice must be recordable")
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.azravel_table_still_open", "no_name_registry"), "The Azravel anonymity choice must be recordable")
    CampaignState.current_chapter_id = "chapter_09_veil_nature"
    CampaignState.campaign_changed.emit()
    await _frames(3)
    var second_source: String = "cross.azravel.survival_and_anonymity"
    _check(SystemicCrossRuntime.event_applied(second_source), "The later Azravel crossing must be applied")
    CampaignState.current_chapter_id = "chapter_10_final_choice"
    CampaignState.campaign_changed.emit()
    await _frames(3)
    _check(SystemicCrossAfterlifeRuntime.relation_history_for("aurelien", "mathilde").size() >= 2, "Distinct consequences must accumulate through distinct afterlife history entries")
    _check(_relationship_afterlife_event_count("aurelien", "mathilde") == 4, "Two mutual afterlife echoes must accumulate instead of replaying or overwriting")
    var count_before_repeat: int = _relationship_afterlife_event_count("aurelien", "mathilde")
    CampaignState.campaign_changed.emit()
    GameState.state_changed.emit()
    await _frames(3)
    _check(_relationship_afterlife_event_count("aurelien", "mathilde") == count_before_repeat, "Accumulated relationship consequences must remain idempotent")

    var systemic_snapshot: Dictionary = SystemicCrossRuntime.serialize()
    SystemicCrossRuntime.reset_new_game()
    SystemicCrossAfterlifeRuntime.reset_new_game()
    _check(SystemicCrossAfterlifeRuntime.remanences().is_empty(), "A genuine reset must clear afterlives with their source crossings")
    SystemicCrossRuntime.deserialize(systemic_snapshot)
    CampaignState.campaign_changed.emit()
    await _frames(3)
    _check(SystemicCrossAfterlifeRuntime.remanences().size() >= 1, "Afterlife history must persist through the existing systemic-cross save payload")
    _check(SystemicCrossAfterlifeRuntime.relation_history_for("aurelien", "mathilde").size() >= 2, "Relationship echoes must persist without a separate global meter")
    _check(SystemicCrossAfterlifeRuntime.rumor_lineage(source_id).size() == 3, "Rumor lineage must persist through the existing systemic-cross save payload")

    _finish()

func _add_test_hero(hero_id: String, hero_name: String) -> void:
    if not _hero(hero_id).is_empty():
        return
    GameState.party.append({
        "id": hero_id,
        "name": hero_name,
        "hp": 100,
        "max_hp": 100,
        "fear": 0,
        "madness": 0,
        "hope": 50,
        "relationships": {}
    })

func _hero(hero_id: String) -> Dictionary:
    for value: Variant in GameState.party:
        var hero: Dictionary = value if value is Dictionary else {}
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _relationship_afterlife_event_count(left_id: String, right_id: String) -> int:
    var count: int = 0
    for source_id: String in [left_id, right_id]:
        var source: Dictionary = _hero(source_id)
        var target_id: String = right_id if source_id == left_id else left_id
        var relation: Dictionary = RelationshipRuntime.relation(source, _hero(target_id))
        var history_value: Variant = relation.get("history", [])
        var history: Array = history_value if history_value is Array else []
        for value: Variant in history:
            var entry: Dictionary = value if value is Dictionary else {}
            if str(entry.get("event_id", "")).begins_with("systemic_afterlife:"):
                count += 1
    return count

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
