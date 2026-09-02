extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    await _frames(2)
    _ensure_test_hero("aurelien", "Aurélien")
    _ensure_test_hero("mathilde", "Mathilde")
    RelationshipRuntime.prepare_party()
    GameState.state_changed.emit()
    await _frames(1)

    _check(LegendarySevenRelationshipRuntime.pair_count() == 21, "pair_count() == 21")
    _check(LegendarySevenRelationshipRuntime.memory_topic_count() == 11, "memory_topic_count() == 11")
    var aurelien_mathilde: Dictionary = LegendarySevenRelationshipRuntime.profile_for_ids("aurelien", "mathilde")
    _check(str(aurelien_mathilde.get("romance_status", "")) == "not_canonized", "Aurélien and Mathilde romance must remain not_canonized")
    _check(str(aurelien_mathilde.get("central_disagreement", "")).contains("acceptable"), "Aurélien and Mathilde must keep acceptable-cost disagreement")
    _check(str(LegendarySevenRelationshipRuntime.profile_for_ids("mathilde", "marec").get("bond_type", "")) == "maternal_protective", "Mathilde and Marec must keep maternal_protective bond")
    _check(str(LegendarySevenRelationshipRuntime.profile_for_ids("marec", "anouk").get("bond_type", "")) == "fraternal", "Marec and Anouk must keep fraternal bond")

    GameState.current_screen = "sanctuary"
    _set_pair_metrics("aurelien", "mathilde", 20, 0, 0)
    _check(LegendarySevenRelationshipRuntime.relationship_stage_for_ids("aurelien", "mathilde") == "opening", "opening stage must derive from real trust")
    var opening: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(opening.get("pair_id", "")) == "aurelien_mathilde" and str(opening.get("stage", "")) == "opening", "opening scene must select Aurélien and Mathilde")
    _check(opening.get("lines", []).size() == 1, "pair scene must remain sparse rather than become an NPC queue")
    _check(LegendarySevenRelationshipRuntime.present_best_pending_scene().is_empty(), "an already seen generic stage must not replay")

    var route_event_id := "systemic_afterlife:cross_food_local_security_and_grain_bridge"
    _append_qualitative_history("aurelien", "mathilde", route_event_id, "responsabilite_partagee", "qui_portera_le_cout_apres_l_urgence")
    _append_qualitative_history("mathilde", "aurelien", route_event_id, "responsabilite_partagee", "qui_portera_le_cout_apres_l_urgence")
    var route_memory: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(route_memory.get("stage", "")) == "opening", "same stage may replay for a distinct exact memory")
    _check(bool(route_memory.get("memory_context_applied", false)), "memory_context_applied must be true for a known systemic topic")
    _check(str(route_memory.get("memory_event_id", "")) == route_event_id, "memory_event_id must preserve the exact relationship history event")
    _check(route_memory.get("lines", []).size() == 2, "a living contextual memory may add at most one second voice")
    _check(str(route_memory.get("direction", "")).contains("sac de grain"), "exact route memory must change Aurélien-Mathilde staging")
    _check(LegendarySevenRelationshipRuntime.present_best_pending_scene().is_empty(), "same exact memory must not replay")

    var second_route_event_id := "systemic_afterlife:cross_food_distributed_risk_and_local_repairs"
    _append_qualitative_history("aurelien", "mathilde", second_route_event_id, "responsabilite_partagee", "qui_portera_le_cout_apres_l_urgence")
    _append_qualitative_history("mathilde", "aurelien", second_route_event_id, "responsabilite_partagee", "qui_portera_le_cout_apres_l_urgence")
    var second_route_memory: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(second_route_memory.get("memory_event_id", "")) == second_route_event_id, "same stage may replay for a distinct exact memory")
    _check(bool(second_route_memory.get("memory_context_applied", false)), "topic fallback must contextualize a source without an exact override")
    _check(LegendarySevenRelationshipRuntime.present_best_pending_scene().is_empty(), "same exact memory must not replay")

    _set_pair_metrics("aurelien", "mathilde", 25, 25, 20)
    _check(LegendarySevenRelationshipRuntime.relationship_stage_for_ids("aurelien", "mathilde") == "friction", "friction stage must derive from real tension")
    _check(SystemicCrossNarrativeRuntime.queue_scene("cross.food.local_security_and_grain_bridge"), "systemic fixture scene must be queueable")
    _check(LegendarySevenRelationshipRuntime.present_best_pending_scene().is_empty(), "systemic priority must block pair dialogue")
    SystemicCrossNarrativeRuntime.pending_scene_ids.clear()
    var friction: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(friction.get("stage", "")) == "friction", "friction must surface once systemic priority is clear")

    _set_pair_metrics("aurelien", "mathilde", 25, 40, 30)
    _check(LegendarySevenRelationshipRuntime.relationship_stage_for_ids("aurelien", "mathilde") == "rupture", "rupture stage must derive from severe tension")
    var rupture: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(rupture.get("stage", "")) == "rupture", "rupture must be stageable without creating a new meter")

    _set_pair_metrics("aurelien", "mathilde", 40, 5, 5)
    _append_qualitative_history("aurelien", "mathilde", "test_disagreement", "desaccord_persistant", "cout_acceptable")
    _append_qualitative_history("aurelien", "mathilde", "test_shared", "responsabilite_partagee", "cout_acceptable")
    _append_qualitative_history("mathilde", "aurelien", "test_disagreement", "desaccord_persistant", "cout_acceptable")
    _append_qualitative_history("mathilde", "aurelien", "test_shared", "responsabilite_partagee", "cout_acceptable")
    _check(LegendarySevenRelationshipRuntime.relationship_stage_for_ids("aurelien", "mathilde") == "repair", "repair must require disagreement followed by shared responsibility")
    var repair: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(repair.get("stage", "")) == "repair", "repair scene must be presented exactly once")

    _set_pair_metrics("aurelien", "mathilde", 70, 5, 5)
    _check(LegendarySevenRelationshipRuntime.relationship_stage_for_ids("aurelien", "mathilde") == "durable", "repair must be transitional so the pair can progress to durable")
    var durable: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(durable.get("stage", "")) == "durable", "durable bond must emerge from trust plus multiple qualitative memories")

    var mathilde: Dictionary = _hero("mathilde")
    mathilde["hp"] = 0
    _check(LegendarySevenRelationshipRuntime.relationship_stage_for_ids("aurelien", "mathilde") == "bereavement", "bereavement must replace living stages after one death")
    var bereavement: Dictionary = LegendarySevenRelationshipRuntime.present_best_pending_scene()
    _check(str(bereavement.get("stage", "")) == "bereavement", "bereavement scene must exist")
    var death_lines: Array = bereavement.get("lines", [])
    _check(death_lines.size() == 1, "bereavement must use only one living voice")
    if death_lines.size() == 1:
        _check(str(death_lines[0].get("speaker_id", "")) == "hero.aurelien", "dead hero must never speak")
    _check(LegendarySevenRelationshipRuntime.present_best_pending_scene().is_empty(), "bereavement must not replay on every Sanctuary return")

    _finish()

func _ensure_test_hero(hero_id: String, hero_name: String) -> void:
    if not _hero(hero_id).is_empty():
        var existing: Dictionary = _hero(hero_id)
        existing["hp"] = maxi(1, int(existing.get("max_hp", 100)))
        existing["max_hp"] = maxi(1, int(existing.get("max_hp", 100)))
        existing["relationships"] = {}
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

func _set_pair_metrics(left_id: String, right_id: String, trust: int, mistrust: int, resentment: int) -> void:
    _set_directional_metrics(left_id, right_id, trust, mistrust, resentment)
    _set_directional_metrics(right_id, left_id, trust, mistrust, resentment)

func _set_directional_metrics(source_id: String, target_id: String, trust: int, mistrust: int, resentment: int) -> void:
    var source: Dictionary = _hero(source_id)
    var target: Dictionary = _hero(target_id)
    var state: Dictionary = RelationshipRuntime.relation(source, target)
    state["trust"] = trust
    state["admiration"] = 0
    state["mistrust"] = mistrust
    state["resentment"] = resentment
    var relationships_value: Variant = source.get("relationships", {})
    var relationships: Dictionary = relationships_value if relationships_value is Dictionary else {}
    relationships[target_id] = state
    source["relationships"] = relationships

func _append_qualitative_history(source_id: String, target_id: String, event_id: String, tag: String, topic: String) -> void:
    var source: Dictionary = _hero(source_id)
    var target: Dictionary = _hero(target_id)
    var state: Dictionary = RelationshipRuntime.relation(source, target)
    var history_value: Variant = state.get("history", [])
    var history: Array = history_value if history_value is Array else []
    history.append({
        "event_id": event_id,
        "chapter": CampaignState.current_chapter_id,
        "qualitative_tag": tag,
        "topic": topic
    })
    state["history"] = history
    var relationships_value: Variant = source.get("relationships", {})
    var relationships: Dictionary = relationships_value if relationships_value is Dictionary else {}
    relationships[target_id] = state
    source["relationships"] = relationships

func _hero(hero_id: String) -> Dictionary:
    for value: Variant in GameState.party:
        var hero: Dictionary = value if value is Dictionary else {}
        if str(hero.get("id", "")).to_lower() == hero_id.to_lower():
            return hero
    return {}

func _frames(count: int) -> void:
    for _index: int in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("LEGENDARY_SEVEN_RELATIONSHIP_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("LEGENDARY_SEVEN_RELATIONSHIP_SMOKE: " + failure)
    print("LEGENDARY_SEVEN_RELATIONSHIP_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
