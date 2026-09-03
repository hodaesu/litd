extends Node3D
class_name VeilleursVS001PlayableWorld

const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")
const INTERACTION_PROXY_SCRIPT := preload("res://scripts/world/veilleurs_vs001_interaction_proxy.gd")
const ROOM_SENSOR_SCRIPT := preload("res://scripts/world/veilleurs_vs001_room_sensor.gd")

@onready var blockout: VeilleursVS001BlockoutBuilder = $Blockout as VeilleursVS001BlockoutBuilder

var party: Node3D = null
var status_label: Label = null
var context_panel: PanelContainer = null
var context_title: Label = null
var context_description: Label = null
var options_grid: GridContainer = null
var current_anchor_id := ""

func _ready() -> void:
    VeilleursVS001WorldRuntime.ensure_session()
    AshlandsRuntime.enter_zone(VeilleursVS001WorldRuntime.ZONE_ID)
    _connect_runtime()
    _build_room_sensors()
    _build_interaction_proxies()
    _spawn_party()
    _build_hud()
    _sync_from_state(VeilleursVS001WorldRuntime.snapshot())

func _connect_runtime() -> void:
    if not VeilleursVS001WorldRuntime.interaction_previewed.is_connected(_on_interaction_previewed):
        VeilleursVS001WorldRuntime.interaction_previewed.connect(_on_interaction_previewed)
    if not VeilleursVS001WorldRuntime.interaction_resolved.is_connected(_on_interaction_resolved):
        VeilleursVS001WorldRuntime.interaction_resolved.connect(_on_interaction_resolved)
    if not VeilleursVS001WorldRuntime.session_changed.is_connected(_sync_from_state):
        VeilleursVS001WorldRuntime.session_changed.connect(_sync_from_state)

func _build_room_sensors() -> void:
    var old: Node = get_node_or_null("RoomSensors")
    if old != null:
        old.queue_free()
    var root := Node3D.new()
    root.name = "RoomSensors"
    add_child(root)
    var map_data: Dictionary = blockout.physical_map
    var rooms: Array = map_data.get("rooms", [])
    for room_value: Variant in rooms:
        var room: Dictionary = room_value
        var sensor: VeilleursVS001RoomSensor = ROOM_SENSOR_SCRIPT.new() as VeilleursVS001RoomSensor
        var center: Vector3 = _vec3(room.get("center", [0.0, 0.0, 0.0]))
        var size: Vector3 = _vec3(room.get("size", [10.0, 4.0, 10.0]))
        sensor.configure(str(room.get("id", "")), center, size)
        sensor.party_entered.connect(_on_room_sensor_entered)
        root.add_child(sensor)

func _build_interaction_proxies() -> void:
    var old: Node = get_node_or_null("InteractionProxies")
    if old != null:
        old.queue_free()
    var root := Node3D.new()
    root.name = "InteractionProxies"
    add_child(root)
    var anchors: Array = blockout.physical_map.get("gameplay_anchors", [])
    for anchor_value: Variant in anchors:
        var anchor: Dictionary = anchor_value
        var anchor_id := str(anchor.get("id", ""))
        if anchor_id == "entry_spawn":
            continue
        var marker: Marker3D = blockout.marker_node(anchor_id)
        if marker == null:
            continue
        var proxy: VeilleursVS001InteractionProxy = INTERACTION_PROXY_SCRIPT.new() as VeilleursVS001InteractionProxy
        proxy.configure(anchor_id)
        proxy.collision_layer = 1
        proxy.collision_mask = 0
        proxy.monitoring = false
        proxy.monitorable = true
        var collision := CollisionShape3D.new()
        collision.name = "InteractionShape"
        var shape := SphereShape3D.new()
        shape.radius = 0.85 if anchor_id != "extraction_gate" else 1.15
        collision.shape = shape
        proxy.add_child(collision)
        root.add_child(proxy)
        proxy.global_position = marker.global_position + Vector3.UP * 0.85

func _spawn_party() -> void:
    var parties: Array[Node] = get_tree().get_nodes_in_group("player_party")
    if not parties.is_empty() and parties[0] is Node3D:
        party = parties[0] as Node3D
        return
    var instance: Node = PARTY_SCENE.instantiate()
    if not (instance is Node3D):
        push_error("VeilleursVS001PlayableWorld: exploration party scene is not Node3D")
        return
    party = instance as Node3D
    party.name = "VeilleursPartyProxy"
    add_child(party)
    var entry: Marker3D = blockout.marker_node("entry_spawn")
    if entry != null:
        party.global_position = entry.global_position + Vector3.UP * 0.7

func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "VeilleursVS001HUD"
    add_child(canvas)

    var status_panel := PanelContainer.new()
    status_panel.position = Vector2(22.0, 20.0)
    status_panel.size = Vector2(720.0, 52.0)
    status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(status_panel)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 17)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_panel.add_child(status_label)

    context_panel = PanelContainer.new()
    context_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    context_panel.position = Vector2(-470.0, -382.0)
    context_panel.size = Vector2(940.0, 350.0)
    context_panel.visible = false
    canvas.add_child(context_panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    context_panel.add_child(column)

    var header := HBoxContainer.new()
    header.custom_minimum_size = Vector2(0.0, 46.0)
    column.add_child(header)
    context_title = Label.new()
    context_title.add_theme_font_size_override("font_size", 21)
    context_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(context_title)
    var close_button := Button.new()
    close_button.text = "FERMER"
    close_button.custom_minimum_size = Vector2(120.0, 48.0)
    close_button.pressed.connect(_close_context)
    header.add_child(close_button)

    context_description = Label.new()
    context_description.custom_minimum_size = Vector2(0.0, 64.0)
    context_description.add_theme_font_size_override("font_size", 15)
    context_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(context_description)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0.0, 210.0)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)
    options_grid = GridContainer.new()
    options_grid.columns = 2
    options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    options_grid.add_theme_constant_override("h_separation", 8)
    options_grid.add_theme_constant_override("v_separation", 8)
    scroll.add_child(options_grid)

func _on_room_sensor_entered(room_id: String) -> void:
    var result: Dictionary = VeilleursVS001WorldRuntime.enter_room(room_id)
    if not bool(result.get("success", false)) and str(result.get("reason", "")) != "room_not_reachable":
        GameState.add_log("Transition VS001 refusée : %s" % str(result.get("reason", "inconnue")))

func _on_interaction_previewed(anchor_id: String, preview: Dictionary) -> void:
    current_anchor_id = anchor_id
    _show_context(preview)

func _on_interaction_resolved(anchor_id: String, _action_id: String, result: Dictionary) -> void:
    if anchor_id != current_anchor_id:
        return
    if bool(result.get("combat_started", false)):
        _close_context()
        return
    if not bool(result.get("success", false)):
        GameState.add_log("Action impossible : %s" % str(result.get("reason", "indisponible")))
    if VeilleursVS001WorldRuntime.is_active():
        VeilleursVS001WorldRuntime.preview_anchor(anchor_id)

func _sync_from_state(state_value: Dictionary) -> void:
    if status_label != null:
        status_label.text = "LES VOIX SOUS LE SANCTUAIRE   ·   Salle %s   ·   Lumière %d   ·   Bruit %d   ·   Objectif %s" % [
            str(state_value.get("current_room", "?")),
            int(state_value.get("light", 0)),
            int(state_value.get("noise", 0)),
            "ACCOMPLI" if bool(state_value.get("objective_complete", false)) else "EN COURS"
        ]
    blockout.set_secret_connection_open(bool(state_value.get("s8_unlocked", false)))

func _show_context(preview: Dictionary) -> void:
    if context_panel == null or context_title == null or context_description == null or options_grid == null:
        return
    context_title.text = str(preview.get("title", "Interaction"))
    context_description.text = str(preview.get("description", ""))
    for child: Node in options_grid.get_children():
        child.queue_free()
    var options: Array = preview.get("options", [])
    for option_value: Variant in options:
        var option: Dictionary = option_value
        var action_id := str(option.get("id", ""))
        var label_value := str(option.get("label", action_id.to_upper()))
        var irreversible := bool(option.get("irreversible", false))
        var button := Button.new()
        button.text = ("CONFIRMER · " if irreversible else "") + label_value
        button.custom_minimum_size = Vector2(410.0, 54.0)
        button.add_theme_font_size_override("font_size", 15)
        button.pressed.connect(_on_option_pressed.bind(action_id))
        options_grid.add_child(button)
    context_panel.visible = true

func _on_option_pressed(action_id: String) -> void:
    if current_anchor_id.is_empty():
        return
    VeilleursVS001WorldRuntime.execute_anchor_action(current_anchor_id, action_id)

func _close_context() -> void:
    current_anchor_id = ""
    if context_panel != null:
        context_panel.visible = false

func _vec3(value: Variant) -> Vector3:
    if not (value is Array):
        return Vector3.ZERO
    var values: Array = value
    if values.size() < 3:
        return Vector3.ZERO
    return Vector3(float(values[0]), float(values[1]), float(values[2]))
