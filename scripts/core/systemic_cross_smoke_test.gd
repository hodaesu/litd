extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    await _frames(2)
    CampaignState.current_chapter_id = "chapter_02_before_fall"

    var price_before := PoliticalState.price_modifier()
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.lhaor_seeds_that_remain", "protect_lhaor_basin"), "First contextual choice must be recorded")
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.dhor_khal_bridge_two_valleys", "restore_grain_bridge"), "Second contextual choice must be recorded")
    await _frames(1)

    var food_event := "cross.food.local_security_and_grain_bridge"
    _check(SystemicCrossRuntime.event_applied(food_event), "Two compatible saved choices must trigger their systemic cross event")
    _check(SystemicCrossRuntime.applied_event_ids().count(food_event) == 1, "A systemic cross event must apply exactly once")
    _check(SystemicCrossRuntime.route_state("dhor_khal_grain_bridge") == "open", "The grain bridge crossing must alter the persistent route state")
    _check(SystemicCrossRuntime.active_economy_tags().has("grain_flow_recovered"), "The grain bridge crossing must feed the existing economy through a qualitative tag")
    _check(PoliticalState.price_modifier() < price_before, "Recovered grain flow must reduce the existing market price pressure without a moral score")
    _check(CommunityRuntime.knows_fact("systemic_cross", "systemic_fact_cross_food_local_security_and_grain_bridge"), "A systemic cross event must enter collective memory as a fact distinct from rumors")
    _check(not CommunityRuntime.sanctuary_visual_cues().is_empty(), "A systemic cross event must create persistent Sanctuary visual cues")
    _check(not CommunityRuntime.sanctuary_audio_cues().is_empty(), "A systemic cross event must create persistent Sanctuary audio cues")
    _check(not CommunityRuntime.recent_rumor_lines(4).is_empty(), "A systemic cross event must create qualitative rumors")

    var cross_snapshot := SystemicCrossRuntime.serialize()
    var community_snapshot := CommunityRuntime.serialize()
    var event_count_before := SystemicCrossRuntime.applied_event_ids().size()
    SystemicCrossRuntime.reset_new_game()
    CommunityRuntime.reset_new_game()
    CommunityRuntime.deserialize(community_snapshot)
    SystemicCrossRuntime.deserialize(cross_snapshot)
    await _frames(1)
    _check(SystemicCrossRuntime.event_applied(food_event), "Save restore must preserve applied systemic events")
    _check(SystemicCrossRuntime.applied_event_ids().size() == event_count_before, "Deserialization must not replay an already-applied cross event")
    _check(not SystemicCrossRuntime.record_contextual_choice("quest.litd1.lhaor_seeds_that_remain", "protect_lhaor_basin"), "Repeating an identical saved choice must be idempotent")
    _check(SystemicCrossRuntime.applied_event_ids().size() == event_count_before, "Repeated choice ingestion must not duplicate consequences")

    GameState.reset_new_game()
    await _frames(2)
    CampaignState.current_chapter_id = "chapter_02_before_fall"
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.lhaor_seeds_that_remain", "equip_refugee_convoy"), "Refugee seed choice must be recordable after a fresh game")
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.dhor_khal_bridge_two_valleys", "restore_high_rope_passage"), "High passage choice must be recordable after a fresh game")
    _check(SystemicCrossRuntime.event_applied("cross.food.refugee_seed_and_high_passage"), "Refugee seed and high passage must trigger their cross event")
    _check(SystemicCrossRuntime.record_external_trigger("winter_resource_pressure", {"source": "smoke_winter"}), "Winter pressure must be accepted as an external systemic trigger")
    await _frames(1)
    _check(SystemicCrossRuntime.cascade_is_applied("cascade.winter_refugee_pressure"), "Winter pressure plus a qualifying crossing must trigger the winter cascade")
    _check(SystemicCrossRuntime.active_economy_tags().has("winter_capacity_pressure"), "The winter cascade must feed capacity pressure into the existing economy")

    var death_context := {"name": "Iria Sen", "cause": "le convoi médical a été retardé par la saturation du passage"}
    _check(SystemicCrossRuntime.record_external_trigger("contextual_named_death", death_context), "A named material death may become an external systemic trigger")
    await _frames(1)
    var death_event := "cross.relationship.named_death_after_difficult_choice"
    _check(SystemicCrossRuntime.event_applied(death_event), "A named death after a contextual choice must trigger the bereavement crossing")
    _check(_systemic_fact_contains("Iria Sen"), "The Memorial fact must preserve the dead person's name instead of reducing the loss to a score")
    var death_event_count := SystemicCrossRuntime.applied_event_ids().size()
    _check(not SystemicCrossRuntime.record_external_trigger("contextual_named_death", death_context), "Repeating the same external trigger must not count as a new trigger")
    _check(SystemicCrossRuntime.applied_event_ids().size() == death_event_count, "A named-death crossing must never replay twice")

    GameState.reset_new_game()
    await _frames(1)
    _check(SystemicCrossRuntime.applied_event_ids().is_empty(), "A genuine new game must clear systemic cross history")
    _check(SystemicCrossRuntime.active_economy_tags().is_empty(), "A genuine new game must clear systemic economy tags")
    _finish()

func _systemic_fact_contains(fragment: String) -> bool:
    for fact in CommunityRuntime.facts_for_scope("systemic_cross"):
        if str(fact.get("text", "")).contains(fragment):
            return true
    return false

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("SYSTEMIC_CROSS_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("SYSTEMIC_CROSS_SMOKE: " + failure)
    print("SYSTEMIC_CROSS_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
