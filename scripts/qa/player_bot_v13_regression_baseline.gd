extends Node

const REPORT_PATH := "res://reports/player-bot-v13-regression-baseline.json"
const BASELINE_PATH := "res://data/qa/regression_baseline.json"

var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
    if parsed is not Dictionary:
        failures.append("invalid_baseline")
    else:
        var sentinels: Dictionary = (parsed as Dictionary).get("sentinels", {})
        for filename_value in sentinels.keys():
            var filename := str(filename_value)
            var rules: Dictionary = sentinels[filename_value]
            _compare_report(filename, rules)
    var report := {
        "schema_version": 13,
        "suite": "player_bot_v13_regression_baseline",
        "rows": rows,
        "failures": failures,
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
        print("PLAYER_BOT_V13_OK reports=%d" % rows.size())
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V13: " + failure)
    get_tree().quit(1)

func _compare_report(filename: String, rules: Dictionary) -> void:
    var path := "res://reports/" + filename
    if not FileAccess.file_exists(path):
        failures.append("missing_report:" + filename)
        rows.append({"report": filename, "status": "missing"})
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if parsed is not Dictionary:
        failures.append("invalid_report:" + filename)
        rows.append({"report": filename, "status": "invalid"})
        return
    var payload: Dictionary = parsed
    var report_failures: Variant = payload.get("failures", [])
    var failure_count := report_failures.size() if report_failures is Array else int(report_failures)
    var cases := int(payload.get("cases", payload.get("campaign_cycles", 0)))
    rows.append({"report": filename, "status": str(payload.get("status", "unknown")), "failures": failure_count, "cases": cases})
    var max_failures := int(rules.get("max_failures", 0))
    if failure_count > max_failures:
        failures.append("failure_regression:%s:%d>%d" % [filename, failure_count, max_failures])
    if rules.has("min_cases") and cases < int(rules.get("min_cases", 0)):
        failures.append("coverage_regression:%s:%d<%d" % [filename, cases, int(rules.get("min_cases", 0))])
