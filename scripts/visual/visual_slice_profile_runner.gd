extends SceneTree

const CONTRACT_PATH := "res://data/visual_vertical_slice.json"
const OUTPUT_PATH := "res://reports/vertical_slice/profile.json"

func _initialize() -> void:
    call_deferred("_run_profile")

func _run_profile() -> void:
    var contract := JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH)) as Dictionary
    var final_path := str(contract.get("slice", {}).get("final_scene_target", ""))
    var proxy_path := str(contract.get("slice", {}).get("target_scene", ""))
    var scene_path := final_path if ResourceLoader.exists(final_path) else proxy_path
    if not ResourceLoader.exists(scene_path):
        push_error("Vertical slice scene missing")
        quit(2)
        return
    var packed := load(scene_path) as PackedScene
    var instance := packed.instantiate()
    root.add_child(instance)
    var fps_values: Array[float] = []
    var draw_values: Array[float] = []
    var primitive_values: Array[float] = []
    for frame in range(120):
        await process_frame
        if frame < 20:
            continue
        fps_values.append(float(Performance.get_monitor(Performance.TIME_FPS)))
        draw_values.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
        primitive_values.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
    var avg_fps := _average(fps_values)
    var avg_draw := _average(draw_values)
    var avg_primitives := _average(primitive_values)
    var frame_budget: Dictionary = contract.get("mobile_budget", {}).get("frame", {})
    var min_fps := float(frame_budget.get("minimum_validation_fps", 50))
    var max_draw := float(frame_budget.get("draw_calls_goal_max", 220))
    var payload := {
        "version": 1,
        "scene": scene_path,
        "samples": fps_values.size(),
        "fps_avg": avg_fps,
        "draw_calls_avg": avg_draw,
        "primitives_avg": avg_primitives,
        "memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
        "checks": {
            "fps": {"pass": avg_fps >= min_fps, "min": min_fps},
            "draw_calls": {"pass": avg_draw <= max_draw, "max": max_draw}
        }
    }
    payload["status"] = "pass" if payload["checks"]["fps"]["pass"] and payload["checks"]["draw_calls"]["pass"] else "warn"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/vertical_slice"))
    var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(payload, "  ") + "\n")
    print("VISUAL_SLICE_PROFILE_OK")
    quit()

func _average(values: Array[float]) -> float:
    if values.is_empty():
        return 0.0
    var total := 0.0
    for value in values:
        total += value
    return total / float(values.size())
