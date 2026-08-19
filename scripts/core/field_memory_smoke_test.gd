extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    DecisionMemoryRuntime.prepare_party()
    FieldMemoryRuntime.prepare_party()
    AshlandsRuntime.current_zone_id = "ashlands_village"
    await _frames(2)

    _check(GameState.party.size() >= 2, "Field memory smoke requires at least two heroes")
    if GameState.party.size() < 2:
        _finish()
        return

    var creature := {
        "instance_id": "hungry-ghoul-smoke",
        "species_id": "hungry_ghoul",
        "name": "Goule liée",
        "level": 1
    }
    CreatureManager.creature_captured.emit(creature)
    await _frames(1)

    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var memories: Array = hero.get("field_memories", [])
        _check(not memories.is_empty(), "A captured creature must become a field memory for direct witnesses")
        if not memories.is_empty():
            var memory: Dictionary = memories[memories.size() - 1]
            _check(str(memory.get("type", "")) == "creature_recruited", "Creature capture must use creature_recruited memory type")
            _check(str(memory.get("witness_mode", "")) == "direct", "Present heroes must remember field events as direct witnesses")
            _check(str(memory.get("zone_id", "")) == "ashlands_village", "Field memory must preserve the location context")

    var before_reevaluation := _latest_reevaluation_count(GameState.party[0], "creature_recruited")
    var reevaluated := FieldMemoryRuntime.reevaluate("creature_proved_itself", "hungry_ghoul")
    _check(bool(reevaluated.get("applied", false)), "A recruited creature proving itself must reevaluate the earlier memory")
    var after_reevaluation := _latest_reevaluation_count(GameState.party[0], "creature_recruited")
    _check(after_reevaluation == before_reevaluation + 1, "Field reevaluation must be stored in the original memory")
    var duplicate_reevaluation := FieldMemoryRuntime.reevaluate("creature_proved_itself", "hungry_ghoul")
    _check(not bool(duplicate_reevaluation.get("applied", false)), "The same delayed consequence must not be applied twice")

    var boss_result := FieldMemoryRuntime.record_boss_outcome("c01_boss_ash_witness", "spared")
    _check(bool(boss_result.get("applied", false)), "An eligible boss must accept a post-victory outcome memory")
    _check(FieldMemoryRuntime.has_boss_outcome("c01_boss_ash_witness"), "Boss outcome must be queryable after it is recorded")
    var duplicate_boss := FieldMemoryRuntime.record_boss_outcome("c01_boss_ash_witness", "executed")
    _check(not bool(duplicate_boss.get("applied", false)), "A boss fate must not be rewritten by clicking a second outcome")

    var aid := FieldMemoryRuntime.record_resource_choice("ashlands_stranded_survivors", "aid")
    _check(bool(aid.get("applied", false)), "Resource sacrifice decisions must be recordable by the field memory layer")

    var retreat := FieldMemoryRuntime.record_expedition_retreat("voluntary")
    _check(bool(retreat.get("applied", false)), "A voluntary retreat must become a field memory")

    var lines := FieldMemoryRuntime.recent_field_memory_lines(3)
    _check(not lines.is_empty(), "Field memories must expose narrative lines rather than raw meters")
    if not lines.is_empty():
        _check(not str(lines[0]).contains("/100"), "Narrative field memory text must not expose numeric meters")

    var serialized := JSON.stringify(GameState.party)
    _check(serialized.contains("field_memories"), "Field memories must persist inside the existing party save payload")
    _finish()

func _latest_reevaluation_count(hero: Dictionary, memory_type: String) -> int:
    var memories: Array = hero.get("field_memories", [])
    for index in range(memories.size() - 1, -1, -1):
        var memory: Dictionary = memories[index]
        if str(memory.get("type", "")) == memory_type:
            return memory.get("reevaluations", []).size()
    return 0

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("FIELD_MEMORY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("FIELD_MEMORY_SMOKE: " + failure)
    print("FIELD_MEMORY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
