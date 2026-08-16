extends CanvasLayer
class_name AshlandsPlaytestPanel

var status_label: Label

func _ready() -> void:
    layer = 90
    _build_panel()
    AshlandsPlaytestSession.report_updated.connect(_on_report_updated)
    _refresh(AshlandsPlaytestSession.capture_current_zone())

func _build_panel() -> void:
    var panel := PanelContainer.new()
    panel.name = "PreBlenderPlaytestPanel"
    panel.offset_left = 760.0
    panel.offset_top = 16.0
    panel.offset_right = 1264.0
    panel.offset_bottom = 250.0
    add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(status_label)
    var navigation := HBoxContainer.new()
    box.add_child(navigation)
    _add_button(navigation, "◀ Zone", AshlandsPlaytestSession.previous_zone)
    _add_button(navigation, "Capturer", _capture)
    _add_button(navigation, "Zone ▶", AshlandsPlaytestSession.next_zone)
    var gates := HBoxContainer.new()
    box.add_child(gates)
    _add_button(gates, "Route", _toggle_primary)
    _add_button(gates, "Détour", _toggle_bypass)
    _add_button(gates, "Caméra", _toggle_camera)
    _add_button(gates, "Mobile", _toggle_mobile)
    var pacing := HBoxContainer.new()
    box.add_child(pacing)
    _add_button(pacing, "Départ route", _start_primary_route)
    _add_button(pacing, "Départ détour", _start_bypass_route)
    _add_button(pacing, "Arrivée", _finish_route)
    _add_button(box, "Afficher/masquer les routes", _toggle_routes)

func _add_button(parent: Control, text_value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(88.0, 38.0)
    button.pressed.connect(callback)
    parent.add_child(button)

func _capture() -> void:
    _refresh(AshlandsPlaytestSession.capture_current_zone())

func _toggle_primary() -> void:
    _refresh(AshlandsPlaytestSession.toggle_gate("primary_route_checked"))

func _toggle_bypass() -> void:
    _refresh(AshlandsPlaytestSession.toggle_gate("bypass_route_checked"))

func _toggle_camera() -> void:
    _refresh(AshlandsPlaytestSession.toggle_gate("camera_checked"))

func _toggle_mobile() -> void:
    _refresh(AshlandsPlaytestSession.toggle_gate("mobile_checked"))

func _start_primary_route() -> void:
    AshlandsPlaytestSession.start_route("primary")
    _refresh(AshlandsPlaytestSession.capture_current_zone())

func _start_bypass_route() -> void:
    AshlandsPlaytestSession.start_route("bypass")
    _refresh(AshlandsPlaytestSession.capture_current_zone())

func _finish_route() -> void:
    _refresh(AshlandsPlaytestSession.finish_route())

func _toggle_routes() -> void:
    var routes := get_tree().get_nodes_in_group("ashlands_authored_routes")
    for route in routes:
        if route is Node3D:
            route.visible = not route.visible

func _on_report_updated(_zone_id: String, report: Dictionary) -> void:
    _refresh(report)

func _refresh(report: Dictionary) -> void:
    var summary := AshlandsPlaytestSession.completion_summary()
    status_label.text = "PLAYTEST PRÉ-BLENDER — %s\nZones validées : %d/%d | Chrono : %s\nRoute %s | Détour %s | Caméra %s | Mobile %s | Perf %s" % [
        AshlandsRuntime.current_zone_id,
        int(summary.get("completed", 0)), int(summary.get("total", 15)),
        AshlandsPlaytestSession.active_route if AshlandsPlaytestSession.active_route != "" else "arrêté",
        _mark(report, "primary_route_checked"), _mark(report, "bypass_route_checked"),
        _mark(report, "camera_checked"), _mark(report, "mobile_checked"),
        "✓" if report.has("performance") else "·"
    ]

func _mark(report: Dictionary, key: String) -> String:
    return "✓" if bool(report.get(key, false)) else "·"
