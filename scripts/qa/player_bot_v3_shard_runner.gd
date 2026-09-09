extends "res://scripts/qa/player_bot_v3_tactical_driver.gd"

const SHARD_COUNT := 4

func _run() -> void:
    await get_tree().process_frame
    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        push_error("PLAYER_BOT_V3_SHARD: cannot load Main.tscn")
        get_tree().quit(1)
        return
    controller = packed.instantiate() as Control
    if controller == null:
        push_error("PLAYER_BOT_V3_SHARD: cannot instantiate Main.tscn")
        get_tree().quit(1)
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    var builds := _build_matrix()
    var shard_index := int(OS.get_environment("BOT_SHARD_INDEX"))
    if shard_index < 0 or shard_index >= SHARD_COUNT or shard_index >= builds.size():
        push_error("PLAYER_BOT_V3_SHARD: invalid shard index %d" % shard_index)
        get_tree().quit(1)
        return

    var started_ms := Time.get_ticks_msec()
    var selected_builds: Array[Dictionary] = [builds[shard_index]]
    for build in selected_builds:
        for seed_value in SEEDS:
            results.append(await _run_build_seed(build, seed_value))

    var summary := _summarize(selected_builds)
    var report := {
        "schema_version": 3,
        "suite": "player_bot_v3_build_matrix_shard",
        "driver": "real_main_controller",
        "shard_index": shard_index,
        "shard_count": SHARD_COUNT,
        "seeds": SEEDS,
        "scenarios": SCENARIOS,
        "builds": selected_builds,
        "results": results,
        "summary": summary,
        "failures": failures,
        "thresholds": {"dominance_gap":DOMINANCE_GAP,"underperform_gap":UNDERPERFORM_GAP},
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    var report_path := "res://reports/player-bot-v3-build-matrix-shard-%d.json" % shard_index
    var file := FileAccess.open(report_path, FileAccess.WRITE)
    if file == null:
        push_error("PLAYER_BOT_V3_SHARD: report_write")
        get_tree().quit(1)
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()

    if failures.is_empty():
        print("PLAYER_BOT_V3_SHARD_OK shard=%d runs=%d" % [shard_index, results.size()])
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V3_SHARD: " + str(failure))
    get_tree().quit(1)
