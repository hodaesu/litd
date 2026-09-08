extends Node

const REPORT_PATH := "res://reports/player-bot-v12-regression-replay.json"
const CASES_PATH := "res://data/qa/regression_replay_cases.json"
const POSITION_RULES := preload("res://scripts/core/combat_position_rules.gd")
const TARGETING_RULES := preload("res://scripts/core/combat_targeting_rules.gd")

var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CASES_PATH))
    if parsed is not Dictionary:
        failures.append("invalid_case_registry")
    else:
        for case_value in (parsed as Dictionary).get("cases", []):
            _run_case(case_value as Dictionary)
    var report := {
        "schema_version": 12,
        "suite": "player_bot_v12_regression_replay",
        "cases": rows.size(),
        "failures": failures,
        "rows": rows,
        "status": "passed" if failures.is_empty() else "failed"
    }
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  "))
        file.store_line("")
        file.close()
    else:
        failures.append("report_write")
    if failures.is_empty():
        print("PLAYER_BOT_V12_OK cases=%d" % rows.size())
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V12: " + failure)
    get_tree().quit(1)

func _run_case(case: Dictionary) -> void:
    var id := str(case.get("id", "case"))
    var hero: Dictionary = (case.get("hero", {}) as Dictionary).duplicate(true)
    var skill: Dictionary = (case.get("skill", {}) as Dictionary).duplicate(true)
    var row := {"id": id}
    if case.has("expect_usable"):
        var actual_usable := POSITION_RULES.is_usable(hero, skill)
        row["actual_usable"] = actual_usable
        row["expect_usable"] = bool(case.get("expect_usable", false))
        if actual_usable != bool(case.get("expect_usable", false)):
            failures.append(id + "_usable")
    if case.has("expect_targetable"):
        var enemies: Array = (case.get("enemies", []) as Array).duplicate(true)
        var target_index := clampi(int(case.get("target_index", 0)), 0, maxi(0, enemies.size() - 1))
        var target: Dictionary = enemies[target_index] if not enemies.is_empty() else {}
        var actual_targetable := TARGETING_RULES.can_target(hero, skill, target, enemies)
        row["actual_targetable"] = actual_targetable
        row["expect_targetable"] = bool(case.get("expect_targetable", false))
        if actual_targetable != bool(case.get("expect_targetable", false)):
            failures.append(id + "_targetable")
    rows.append(row)
