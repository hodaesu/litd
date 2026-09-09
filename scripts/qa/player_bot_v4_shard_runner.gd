extends "res://scripts/qa/player_bot_v4_tactical_driver.gd"

const SHARD_COUNT := 6

func _run() -> void:
    await get_tree().process_frame
    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        push_error("PLAYER_BOT_V4_SHARD: cannot load Main.tscn")
        get_tree().quit(1)
        return
    controller = packed.instantiate() as Control
    if controller == null:
        push_error("PLAYER_BOT_V4_SHARD: cannot instantiate Main.tscn")
        get_tree().quit(1)
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    var shard_index := int(OS.get_environment("BOT_SHARD_INDEX"))
    if shard_index < 0 or shard_index >= SHARD_COUNT:
        push_error("PLAYER_BOT_V4_SHARD: invalid shard index %d" % shard_index)
        get_tree().quit(1)
        return

    var started_ms := Time.get_ticks_msec()
    var builds := _build_profiles()
    var all_cases := _factorial_cases(builds)
    var selected_cases: Array[Dictionary] = []
    for case_index in range(all_cases.size()):
        if case_index % SHARD_COUNT == shard_index:
            selected_cases.append(all_cases[case_index])

    for case_value in selected_cases:
        var case: Dictionary = case_value
        for seed_value in SEEDS:
            results.append(await _run_case(case, seed_value))

    var summary := _summarize()
    var report := {
        "schema_version": 4,
        "suite": "player_bot_v4_factorial_matrix_shard",
        "driver": "real_main_controller",
        "shard_index": shard_index,
        "shard_count": SHARD_COUNT,
        "levels": LEVELS,
        "rarities": RARITIES,
        "policies": POLICIES,
        "companion_states": COMPANION_STATES,
        "seeds": SEEDS,
        "scenarios": SCENARIOS,
        "cases": selected_cases,
        "results": results,
        "summary": summary,
        "failures": failures,
        "thresholds": {
            "dominance_gap": DOMINANCE_GAP,
            "boss_too_hard_below": DIFFICULTY_HIGH,
            "boss_too_easy_above": DIFFICULTY_LOW
        },
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    var report_path := "res://reports/player-bot-v4-factorial-matrix-shard-%d.json" % shard_index
    var file := FileAccess.open(report_path, FileAccess.WRITE)
    if file == null:
        push_error("PLAYER_BOT_V4_SHARD: report_write")
        get_tree().quit(1)
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()

    if failures.is_empty():
        print("PLAYER_BOT_V4_SHARD_OK shard=%d cases=%d runs=%d" % [shard_index, selected_cases.size(), results.size()])
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V4_SHARD: " + str(failure))
    get_tree().quit(1)
