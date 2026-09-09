extends Node

const FIXED_SEEDS: Array[int] = [101, 202, 303, 404, 505]
const REPORT_PATH := "res://reports/developer-autotest-godot.json"

var failures: Array[String] = []
var checks: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var started_ms := Time.get_ticks_msec()

    _check("party_loaded", not GameState.party.is_empty(), {"party_size": GameState.party.size()})
    _check("level_cap", GameState.MAX_CHARACTER_LEVEL == 50, {"max_level": GameState.MAX_CHARACTER_LEVEL})
    _check_resources("initial_resources")
    _check_party("initial_party")

    var baseline := _new_game_signature()
    for seed_value: int in FIXED_SEEDS:
        seed(seed_value)
        GameState.reset_new_game()
        var signature := _state_signature()
        _check(
            "deterministic_reset_seed_%d" % seed_value,
            signature == baseline,
            {"seed": seed_value, "signature": signature.sha256_text()}
        )
        _check_resources("resources_seed_%d" % seed_value)
        _check_party("party_seed_%d" % seed_value)

    _check_save_roundtrip()
    _check_qa_contract()

    var report := {
        "schema_version": 1,
        "suite": "developer_autotest_godot",
        "godot_version": Engine.get_version_info().get("string", "unknown"),
        "fixed_seeds": FIXED_SEEDS,
        "checks_total": checks.size(),
        "checks_passed": checks.size() - failures.size(),
        "failures": failures,
        "checks": checks,
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)

    SaveManager.delete_qa_snapshot()
    GameState.reset_new_game()

    if failures.is_empty():
        print("DEVELOPER_AUTOTEST_OK checks=%d seeds=%d report=%s" % [checks.size(), FIXED_SEEDS.size(), REPORT_PATH])
        await get_tree().process_frame
        get_tree().quit(0)
        return

    for failure: String in failures:
        push_error("DEVELOPER_AUTOTEST: " + failure)
    await get_tree().process_frame
    get_tree().quit(1)

func _new_game_signature() -> String:
    GameState.reset_new_game()
    return _state_signature()

func _state_signature() -> String:
    var party_signature: Array[Dictionary] = []
    for hero_value: Variant in GameState.party:
        if not hero_value is Dictionary:
            continue
        var hero: Dictionary = hero_value
        party_signature.append({
            "id": str(hero.get("id", "")),
            "canonical_id": str(hero.get("canonical_id", "")),
            "name": str(hero.get("name", "")),
            "level": int(hero.get("level", 1)),
            "hp": int(hero.get("hp", 0)),
            "max_hp": int(hero.get("max_hp", 0))
        })
    return JSON.stringify({
        "gold": GameState.gold,
        "essence": GameState.essence,
        "light": GameState.light,
        "supplies": GameState.supplies,
        "expedition_room": GameState.expedition_room,
        "party": party_signature
    })

func _check_resources(check_id: String) -> void:
    var ok := GameState.gold >= 0 and GameState.essence >= 0 and GameState.light >= 0 and GameState.supplies >= 0
    _check(check_id, ok, {
        "gold": GameState.gold,
        "essence": GameState.essence,
        "light": GameState.light,
        "supplies": GameState.supplies
    })

func _check_party(check_id: String) -> void:
    var ok := not GameState.party.is_empty()
    var invalid: Array[String] = []
    for hero_value: Variant in GameState.party:
        if not hero_value is Dictionary:
            ok = false
            invalid.append("non_dictionary")
            continue
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        var level := int(hero.get("level", 1))
        var hp := int(hero.get("hp", 0))
        var max_hp := int(hero.get("max_hp", 0))
        if hero_id.is_empty() or level < 1 or level > GameState.MAX_CHARACTER_LEVEL or max_hp <= 0 or hp < 0 or hp > max_hp:
            ok = false
            invalid.append(hero_id if not hero_id.is_empty() else "missing_id")
    _check(check_id, ok, {"invalid": invalid, "party_size": GameState.party.size()})

func _check_save_roundtrip() -> void:
    GameState.reset_new_game()
    var original_gold := GameState.gold
    var original_light := GameState.light
    var saved := SaveManager.save_qa_snapshot()
    _check("qa_snapshot_save", saved, {})
    if not saved:
        return

    GameState.gold = original_gold + 777
    GameState.light = 1
    var loaded := SaveManager.load_qa_snapshot()
    _check("qa_snapshot_load", loaded, {})
    _check(
        "qa_snapshot_roundtrip",
        loaded and GameState.gold == original_gold and GameState.light == original_light,
        {"gold": GameState.gold, "light": GameState.light}
    )

func _check_qa_contract() -> void:
    QATestRoomState.reset_session()
    _check("qa_checklist_initially_empty", QATestRoomState.completed_count() == 0, {"completed": QATestRoomState.completed_count()})
    for check_id: String in QATestRoomState.CHECKS:
        QATestRoomState.mark(check_id)
    _check(
        "qa_checklist_contract",
        QATestRoomState.all_passed(),
        {"completed": QATestRoomState.completed_count(), "expected": QATestRoomState.CHECKS.size()}
    )

func _check(check_id: String, passed: bool, details: Dictionary) -> void:
    checks.append({"id": check_id, "passed": passed, "details": details})
    if not passed:
        failures.append(check_id)

func _write_report(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        failures.append("report_write")
        push_error("Unable to write developer autotest report: " + REPORT_PATH)
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
