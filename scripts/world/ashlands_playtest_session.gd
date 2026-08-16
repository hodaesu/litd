extends Node

signal report_updated(zone_id: String, report: Dictionary)

const MANIFEST_PATH := "res://data/levels/terre_des_cendres_blockout_manifest.json"
const REPORT_PATH := "user://ashlands_preblender_playtest.json"

var zone_ids: Array[String] = []
var reports: Dictionary = {}

func _ready() -> void:
    _load_zone_ids()
    load_report()

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

func _zone_complete(report: Dictionary) -> bool:
    return bool(report.get("primary_route_checked", false)) \
        and bool(report.get("bypass_route_checked", false)) \
        and bool(report.get("camera_checked", false)) \
        and bool(report.get("mobile_checked", false)) \
        and report.has("performance")
