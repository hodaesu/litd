extends Node

const REPORT_PATH := "res://reports/player-bot-v9-save-integrity.json"

var failures: Array[String] = []

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
    var expected := _signature()

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
    elif _signature() != expected:
        failures.append("roundtrip_drift")

    SaveManager.delete_qa_snapshot()
    _finish()

func _signature() -> String:
    var first: Dictionary = GameState.party[0] if not GameState.party.is_empty() else {}
    return "%d|%d|%s|%d|%s" % [
        GameState.gold,
        GameState.essence,
        str(first.get("id", "")),
        int(first.get("hp", 0)),
        str(first.get("name", ""))
    ]

func _finish() -> void:
    var report := {
        "schema_version":9,
        "suite":"player_bot_v9_save_integrity",
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
            push_error("PLAYER_BOT_V9: " + failure)
        get_tree().quit(1)
