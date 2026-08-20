extends SceneTree

const CONTRACT_PATH := "res://data/visual_vertical_slice.json"
const OUTPUT_RELATIVE := "reports/vertical_slice/profile.json"

func _initialize() -> void:
    call_deferred("_run_profile")

func _run_profile() -> void:
    var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH)) as Dictionary
    var slice: Dictionary = contract.get("slice", {}) as Dictionary
    var final_path: String = str(slice.get("final_scene_target", ""))
    var proxy_path: String = str(slice.get("target_scene", ""))
    var scene_path: String = final_path if ResourceLoader.exists(final_path) else proxy_path
    if not ResourceLoader.exists(scene_path):
        push_error("Vertical slice scene missing")
        quit(2)
        return
    var packed: PackedScene = load(scene_path) as PackedScene
    var instance: Node = packed.instantiate()
    root.add_child(instance)
    var fps_values: Array[float] = []
    var draw_values: Array[float] = []
    var primitive_values: Array[float] = []
    for frame: int in range(120):
        await process_frame
        if frame < 20:
            continue
        fps_values.append(float(Performance.get_monitor(Performance.TIME_FPS)))
        draw_values.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
        primitive_values.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
    var avg_fps: float = _average(fps_values)
    var avg_draw: float = _average(draw_values)
    var avg_primitives: float = _average(primitive_values)
    var mobile_budget: Dictionary = contract.get("mobile_budget", {}) as Dictionary
    var frame_budget: Dictionary = mobile_budget.get("frame", {}) as Dictionary
    var min_fps: float = float(frame_budget.get("minimum_validation_fps", 50))
    var max_draw: float = float(frame_budget.get("draw_calls_goal_max", 220))
    var checks: Dictionary = {
        "fps": {"pass": avg_fps >= min_fps, "min": min_fps},
        "draw_calls": {"pass": avg_draw <= max_draw, "max": max_draw}
    }
    var payload: Dictionary = {
        "version": 1,
        "scene": scene_path,
        "samples": fps_values.size(),
        "fps_avg": avg_fps,
        "draw_calls_avg": avg_draw,
        "primitives_avg": avg_primitives,
        "memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
        "checks": checks
    }
    var fps_check: Dictionary = checks.get("fps", {}) as Dictionary
    var draw_check: Dictionary = checks.get("draw_calls", {}) as Dictionary
    payload["status"] = "pass" if bool(fps_check.get("pass", false)) and bool(draw_check.get("pass", false)) else "warn"
    var project_root: String = ProjectSettings.globalize_path("res://")
    var output_path: String = project_root + "/" + OUTPUT_RELATIVE
    DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
    var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(payload, "  ") + "\n")
    print("VISUAL_SLICE_PROFILE_OK")
    quit()

func _average(values: Array[float]) -> float:
    if values.is_empty():
        return 0.0
    var total: float = 0.0
    for value: float in values:
        total += value
    return total / float(values.size())
