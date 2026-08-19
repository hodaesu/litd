extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    ExpeditionManager.reset_to_full_resupply()
    FieldMemoryRuntime.prepare_party()
    AshlandsRuntime.current_zone_id = "zone_02_village_ravage"
    await _frames(2)

    _check(int(ExpeditionManager.inventory.get("food", 0)) == 8, "Reactive encounter smoke expects a full food resupply")
    _check(int(ExpeditionManager.inventory.get("water", 0)) == 8, "Reactive encounter smoke expects a full water resupply")
    _check(int(ExpeditionManager.inventory.get("medicine", 0)) == 2, "Reactive encounter smoke expects two medicines")

    var chapter_one := FieldEncounterRuntime.encounters_for(1, "zone_02_village_ravage")
    _check(_contains_event(chapter_one, "c01_village_survivors"), "The chapter I survivor group must exist as a real exploration encounter")

    var result := FieldEncounterRuntime.resolve_choice("c01_village_survivors", "full_aid")
    _check(bool(result.get("applied", false)), "Sharing resources with the trapped survivors must resolve the field encounter")
    _check(FieldEncounterRuntime.outcome_for("c01_village_survivors") == "aided", "The chosen survivor outcome must persist globally")
    _check(int(ExpeditionManager.inventory.get("food", 0)) == 6, "Full aid must consume two food")
    _check(int(ExpeditionManager.inventory.get("water", 0)) == 6, "Full aid must consume two water")
    _check(int(ExpeditionManager.inventory.get("medicine", 0)) == 1, "Full aid must consume one medicine")

    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var memory := _latest_memory(hero, "aid_survivors", "c01_village_survivors")
        _check(not memory.is_empty(), "Every living direct witness must remember the resource sacrifice")
        if not memory.is_empty():
            _check(str(memory.get("witness_mode", "")) == "direct", "The chapter I survivors must be remembered as a direct event")
            _check(str(memory.get("zone_id", "")) == "zone_02_village_ravage", "The survivor memory must preserve its exploration zone")

    var duplicate := FieldEncounterRuntime.resolve_choice("c01_village_survivors", "keep")
    _check(not bool(duplicate.get("applied", false)), "A resolved field encounter must never accept a second choice")

    var chapter_three := FieldEncounterRuntime.encounters_for(3, "c03_abandoned_relay")
    _check(_contains_event(chapter_three, "c03_survivor_outpost"), "Aided survivors must be able to return in chapter III")
    _check(not _contains_event(chapter_three, "c03_survivors_without_aid"), "The refusal-only return must not spawn after aid")

    var snapshot := FieldEncounterRuntime.serialize()
    _check(snapshot.has("resolved"), "Reactive field outcomes must expose a save payload")
    FieldEncounterRuntime.reset_new_game()
    _check(not FieldEncounterRuntime.is_resolved("c01_village_survivors"), "Reset must clear reactive encounter state")
    FieldEncounterRuntime.deserialize(snapshot)
    _check(FieldEncounterRuntime.outcome_for("c01_village_survivors") == "aided", "Save restore must recover the exact survivor outcome")

    AshlandsRuntime.current_zone_id = "c03_abandoned_relay"
    var before_reevaluation := _latest_reevaluation_count(GameState.party[0], "aid_survivors", "c01_village_survivors")
    var returned := FieldEncounterRuntime.resolve_return("c03_survivor_outpost")
    _check(bool(returned.get("applied", false)), "The chapter III survivor outpost must resolve when its source outcome is present")
    _check(int(ExpeditionManager.inventory.get("food", 0)) == 8, "The established outpost must be able to return two food")
    _check(int(ExpeditionManager.inventory.get("water", 0)) == 8, "The established outpost must be able to return two water")
    _check(int(ExpeditionManager.inventory.get("light", 0)) == 7, "The established outpost must be able to return one light")
    var after_reevaluation := _latest_reevaluation_count(GameState.party[0], "aid_survivors", "c01_village_survivors")
    _check(after_reevaluation == before_reevaluation + 1, "A survivor return must reframe the original field memory")

    FieldMemoryRuntime.record_boss_outcome("c01_boss_ash_witness", "spared")
    var witness_returns := FieldEncounterRuntime.encounters_for(3, "c03_diplomatic_post")
    _check(_contains_event(witness_returns, "c03_spared_witness_return"), "An spared Ash Witness must be able to reappear later in exploration")

    FieldEncounterRuntime.reset_new_game()
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.inventory["medicine"] = 0
    var food_before: int = int(ExpeditionManager.inventory.get("food", 0))
    var failed := FieldEncounterRuntime.resolve_choice("c01_village_survivors", "full_aid")
    _check(not bool(failed.get("applied", false)), "A resource choice must fail cleanly when the expedition cannot pay its cost")
    _check(not FieldEncounterRuntime.is_resolved("c01_village_survivors"), "An unaffordable choice must not consume the narrative encounter")
    _check(int(ExpeditionManager.inventory.get("food", 0)) == food_before, "An unaffordable choice must not partially consume resources")

    _finish()

func _contains_event(items: Array[Dictionary], event_id: String) -> bool:
    for item in items:
        if str(item.get("id", "")) == event_id:
            return true
    return false

func _latest_memory(hero: Dictionary, memory_type: String, event_id: String) -> Dictionary:
    var memories_value: Variant = hero.get("field_memories", [])
    var memories: Array = memories_value if memories_value is Array else []
    for index in range(memories.size() - 1, -1, -1):
        var memory_value: Variant = memories[index]
        var memory: Dictionary = memory_value if memory_value is Dictionary else {}
        if str(memory.get("type", "")) == memory_type and str(memory.get("event_id", "")) == event_id:
            return memory
    return {}

func _latest_reevaluation_count(hero: Dictionary, memory_type: String, event_id: String) -> int:
    var memory := _latest_memory(hero, memory_type, event_id)
    if memory.is_empty():
        return 0
    var reevaluations_value: Variant = memory.get("reevaluations", [])
    var reevaluations: Array = reevaluations_value if reevaluations_value is Array else []
    return reevaluations.size()

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("FIELD_ENCOUNTER_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("FIELD_ENCOUNTER_SMOKE: " + failure)
    print("FIELD_ENCOUNTER_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
