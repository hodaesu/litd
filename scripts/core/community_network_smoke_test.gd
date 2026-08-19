extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    ExpeditionManager.reset_to_full_resupply()
    AshlandsRuntime.current_zone_id = "zone_02_village_ravage"
    await _frames(2)

    var first := FieldEncounterRuntime.resolve_choice("c01_village_survivors", "full_aid")
    _check(bool(first.get("applied", false)), "The village survivor choice must resolve before community propagation")
    _check(CommunityRuntime.knows_fact("ashlands_travellers", "three_marks_aided"), "The survivor decision must enter collective_memory without a reputation score")

    AshlandsRuntime.current_zone_id = "c03_abandoned_relay"
    var returned := FieldEncounterRuntime.resolve_return("c03_survivor_outpost")
    _check(bool(returned.get("applied", false)), "The chapter III survivor return must propagate into the living sanctuary")

    var people: Array[Dictionary] = CommunityRuntime.sanctuary_people()
    _check(people.size() == 3, "Mara, Yoren and Iven must become concrete sanctuary-network presences after their return")
    _check(_has_person(people, "mara_three_marks"), "Mara must persist as a sanctuary-network person")
    _check(_has_person(people, "yoren_three_marks"), "Yoren must persist as a sanctuary-network person")
    _check(_has_person(people, "iven_three_marks"), "Iven must persist as a sanctuary-network person")
    _check(not CommunityRuntime.sanctuary_visual_cues().is_empty(), "Living people must alter visible sanctuary cues")
    _check(not CommunityRuntime.sanctuary_population_cues().is_empty(), "Living people must alter sanctuary population cues")

    var quest_entries: Array[Dictionary] = CommunityRuntime.quest_entries()
    _check(_has_quest(quest_entries, "q_iven_erased_days", "offered"), "Iven's narrative quest must exist only after his survival branch returns")
    _check(_has_quest(quest_entries, "q_yoren_false_exit", "offered"), "Yoren's narrative route quest must emerge from the same persistent population")

    var medicine_before: int = int(ExpeditionManager.inventory.get("medicine", 0))
    _check(CommunityRuntime.accept_quest("q_iven_erased_days"), "An offered emergent quest must be accept-able")
    _check(Chapter03Runtime.collect_evidence("ev_korem_redaction"), "The existing Kor-Em evidence must remain a real campaign objective")
    await _frames(1)
    _check(_has_quest(CommunityRuntime.quest_entries(), "q_iven_erased_days", "completed"), "Existing world evidence must complete the emergent quest")
    _check(int(ExpeditionManager.inventory.get("medicine", 0)) == medicine_before + 1, "Quest completion must grant its concrete expedition reward")

    var rumor_lines: Array[String] = CommunityRuntime.recent_rumor_lines(6)
    _check(not rumor_lines.is_empty(), "Field outcomes must become qualitative rumors")
    for line in rumor_lines:
        _check(not line.contains("/100"), "Community rumors must never expose a moral meter")
    var listened := CommunityRuntime.listen_next_rumor()
    _check(not listened.is_empty(), "The Tavern must be able to surface an unheard community rumor")

    var snapshot := CommunityRuntime.serialize()
    _check(snapshot.has("collective_memory") and snapshot.has("people_state") and snapshot.has("quest_states"), "Community state must expose a complete save payload")
    CommunityRuntime.reset_new_game()
    _check(CommunityRuntime.sanctuary_people().is_empty(), "A fresh game must not inherit survivor residents")
    CommunityRuntime.deserialize(snapshot)
    _check(CommunityRuntime.sanctuary_people().size() == 3, "Save restore must recover the exact living sanctuary population")
    _check(_has_quest(CommunityRuntime.quest_entries(), "q_iven_erased_days", "completed"), "Save restore must preserve emergent quest history")

    GameState.reset_new_game()
    await _frames(1)
    _check(CommunityRuntime.sanctuary_people().is_empty(), "GameState new_game_reset must clear persistent community history")
    _finish()

func _has_person(people: Array[Dictionary], person_id: String) -> bool:
    for person in people:
        if str(person.get("id", "")) == person_id:
            return true
    return false

func _has_quest(entries: Array[Dictionary], quest_id: String, state: String) -> bool:
    for entry in entries:
        if str(entry.get("id", "")) == quest_id and str(entry.get("state", "")) == state:
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
        print("COMMUNITY_NETWORK_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("COMMUNITY_NETWORK_SMOKE: " + failure)
    print("COMMUNITY_NETWORK_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
