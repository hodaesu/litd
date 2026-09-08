extends Node

const REPORT_PATH := "res://reports/player-bot-v9-save-integrity.json"

var failures: Array[String] = []
var expected_state: Dictionary = {}
var actual_state: Dictionary = {}
var drift: Dictionary = {}

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    SaveManager.delete_qa_snapshot()
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(9909)
    CreatureManager.reset_new_game(9919)

    GameState.gold = 777
    GameState.essence = 333
    if GameState.party.is_empty():
        failures.append("empty_party")
        _finish()
        return
    var hero: Dictionary = GameState.party[0]
    hero["hp"] = maxi(1, int(hero.get("max_hp", 10)) - 3)
    hero["name"] = "QA-SAVE-V9"
    expected_state = _state_snapshot()

    if not SaveManager.save_qa_snapshot():
        failures.append("save_failed")
        _finish()
        return

    GameState.gold = 1
    GameState.essence = 2
    GameState.party[0]["hp"] = 1
    GameState.party[0]["name"] = "MUTATED"

    if not SaveManager.load_qa_snapshot():
        failures.append("load_failed")
    else:
        actual_state = _state_snapshot()
        drift = _diff(expected_state, actual_state)
        if not drift.is_empty():
            failures.append("roundtrip_drift")

    SaveManager.delete_qa_snapshot()
    _finish()

func _state_snapshot() -> Dictionary:
    var first: Dictionary = GameState.party[0] if not GameState.party.is_empty() else {}
    return {
        "gold": GameState.gold,
        "essence": GameState.essence,
        "hero_id": str(first.get("id", "")),
        "hp": int(first.get("hp", 0)),
        "name": str(first.get("name", ""))
    }

func _diff(expected: Dictionary, actual: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key_value in expected.keys():
        var key := str(key_value)
        if actual.get(key) != expected.get(key):
            result[key] = {"expected": expected.get(key), "actual": actual.get(key)}
    return result

func _finish() -> void:
    var report := {
        "schema_version":9,
        "suite":"player_bot_v9_save_integrity",
        "expected": expected_state,
        "actual": actual_state,
        "drift": drift,
        "failures":failures,
        "status":"passed" if failures.is_empty() else "failed"
    }
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  "))
        file.store_line("")
        file.close()
    if failures.is_empty():
        print("PLAYER_BOT_V9_OK")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("PLAYER_BOT_V9: %s drift=%s" % [failure, JSON.stringify(drift)])
        get_tree().quit(1)
