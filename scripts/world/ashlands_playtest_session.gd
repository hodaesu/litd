extends Node

signal report_updated(zone_id: String, report: Dictionary)

const MANIFEST_PATH := "res://data/levels/terre_des_cendres_blockout_manifest.json"
const REPORT_PATH := "user://ashlands_preblender_playtest.json"
const PACING_TARGETS_PATH := "res://data/levels/ashlands_pacing_targets.json"

var zone_ids: Array[String] = []
var reports: Dictionary = {}
var pacing_targets: Dictionary = {}
var active_route := ""
var _route_started_msec := 0
var _route_distance := 0.0
var _last_route_position := Vector3.ZERO
var _trail: Array = []
var _sample_elapsed := 0.0

func _ready() -> void:
    _load_zone_ids()
    _load_pacing_targets()
    load_report()

func _process(delta: float) -> void:
    if active_route == "":
        return
    var party := _get_party()
    if party == null:
        return
    _route_distance += party.global_position.distance_to(_last_route_position)
    _last_route_position = party.global_position
    _sample_elapsed += delta
    if _sample_elapsed >= 0.5:
        _sample_elapsed = 0.0
        _trail.append([party.global_position.x, party.global_position.y, party.global_position.z])

func start_route(route_name: String) -> void:
    var party := _get_party()
    if party == null or route_name not in ["primary", "bypass"]:
        return
    active_route = route_name
    _route_started_msec = Time.get_ticks_msec()
    _route_distance = 0.0
    _last_route_position = party.global_position
    _trail = [[party.global_position.x, party.global_position.y, party.global_position.z]]
    _sample_elapsed = 0.0

func finish_route() -> Dictionary:
    if active_route == "":
        return capture_current_zone()
    var route_name := active_route
    var duration_seconds := float(Time.get_ticks_msec() - _route_started_msec) / 1000.0
    active_route = ""
    var report := capture_current_zone()
    var route_metrics: Dictionary = report.get("route_metrics", {})
    route_metrics[route_name] = {
        "duration_seconds": duration_seconds,
        "distance_m": _route_distance,
        "average_speed_mps": _route_distance / max(duration_seconds, 0.001),
        "trail": _trail.duplicate(true),
        "target": _get_target(route_name),
        "within_target": _within_target(route_name, duration_seconds)
    }
    report["route_metrics"] = route_metrics
    report["%s_route_checked" % route_name] = true
    reports[AshlandsRuntime.current_zone_id] = report
    save_report()
    report_updated.emit(AshlandsRuntime.current_zone_id, report)
    return report

func previous_zone() -> void:
    _load_relative_zone(-1)

func next_zone() -> void:
    _load_relative_zone(1)

func capture_current_zone() -> Dictionary:
    var zone_id := AshlandsRuntime.current_zone_id
    var report: Dictionary = reports.get(zone_id, {})
    report["zone_id"] = zone_id
    report["captured_at_unix"] = int(Time.get_unix_time_from_system())
    var probes := get_tree().get_nodes_in_group("ashlands_performance_probe")
    if not probes.is_empty() and probes[0].has_method("sample_now"):
        report["performance"] = probes[0].sample_now()
    report["primary_route_checked"] = bool(report.get("primary_route_checked", false))
    report["bypass_route_checked"] = bool(report.get("bypass_route_checked", false))
    report["camera_checked"] = bool(report.get("camera_checked", false))
    report["mobile_checked"] = bool(report.get("mobile_checked", false))
    reports[zone_id] = report
    save_report()
    report_updated.emit(zone_id, report)
    return report

func toggle_gate(gate: String) -> Dictionary:
    var report := capture_current_zone()
    report[gate] = not bool(report.get(gate, false))
    reports[AshlandsRuntime.current_zone_id] = report
    save_report()
    report_updated.emit(AshlandsRuntime.current_zone_id, report)
    return report

func completion_summary() -> Dictionary:
    var completed := 0
    for zone_id in zone_ids:
        var report: Dictionary = reports.get(zone_id, {})
        if _zone_complete(report):
            completed += 1
    return {"completed": completed, "total": zone_ids.size()}

func save_report() -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"version": 1, "zones": reports}, "  "))

func load_report() -> void:
    if not FileAccess.file_exists(REPORT_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        reports = parsed.get("zones", {})

func _load_relative_zone(delta: int) -> void:
    if zone_ids.is_empty():
        return
    var current := zone_ids.find(AshlandsRuntime.current_zone_id)
    if current < 0:
        current = 0
    var next_index := posmod(current + delta, zone_ids.size())
    AshlandsSceneRouter.load_zone(zone_ids[next_index])

func _load_zone_ids() -> void:
    zone_ids.clear()
    if not FileAccess.file_exists(MANIFEST_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    for zone in parsed.get("zones", []):
        zone_ids.append(str(zone.get("id", "")))

func _load_pacing_targets() -> void:
    if not FileAccess.file_exists(PACING_TARGETS_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(PACING_TARGETS_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        pacing_targets = parsed.get("zones", {})

func _get_party() -> Node3D:
    var parties := get_tree().get_nodes_in_group("player_party")
    return parties[0] as Node3D if not parties.is_empty() else null

func _get_target(route_name: String) -> Array:
    return pacing_targets.get(AshlandsRuntime.current_zone_id, {}).get("%s_seconds" % route_name, [])

func _within_target(route_name: String, duration_seconds: float) -> bool:
    var target := _get_target(route_name)
    return target.size() >= 2 and duration_seconds >= float(target[0]) and duration_seconds <= float(target[1])

func _zone_complete(report: Dictionary) -> bool:
    return bool(report.get("primary_route_checked", false)) \
        and bool(report.get("bypass_route_checked", false)) \
        and bool(report.get("camera_checked", false)) \
        and bool(report.get("mobile_checked", false)) \
        and report.has("performance")
