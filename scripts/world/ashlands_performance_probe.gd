extends Node
class_name AshlandsPerformanceProbe

signal budget_exceeded(zone_id: String, metric: String, value: float, budget: float)

@export var zone_id := ""
@export var sample_interval_seconds := 2.0
@export var minimum_fps := 30.0
@export var maximum_objects := 2200.0
@export var maximum_draw_calls := 650.0

var _elapsed := 0.0
var latest_sample: Dictionary = {}

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < sample_interval_seconds:
        return
    _elapsed = 0.0
    latest_sample = sample_now()
    _check_minimum("fps", float(latest_sample["fps"]), minimum_fps)
    _check_maximum("objects", float(latest_sample["objects"]), maximum_objects)
    _check_maximum("draw_calls", float(latest_sample["draw_calls"]), maximum_draw_calls)

func sample_now() -> Dictionary:
    return {
        "zone_id": zone_id,
        "fps": Performance.get_monitor(Performance.TIME_FPS),
        "frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
        "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
    }

func _check_minimum(metric: String, value: float, budget: float) -> void:
    if value > 0.0 and value < budget:
        budget_exceeded.emit(zone_id, metric, value, budget)

func _check_maximum(metric: String, value: float, budget: float) -> void:
    if value > budget:
        budget_exceeded.emit(zone_id, metric, value, budget)
