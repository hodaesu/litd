extends Node3D
class_name VeilleursGE01PlayableWorld

const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")
const SENSOR_SCRIPT := preload("res://scripts/world/veilleurs_ge01_room_sensor.gd")

@onready var local_runtime: VeilleursGE01PlayableBridge = $Runtime as VeilleursGE01PlayableBridge
@onready var blockout: VeilleursGE01Blockout = $Blockout as VeilleursGE01Blockout

var runtime: VeilleursGE01PlayableBridge
var party: Node3D
var current_room_id := "ge_01"
var prompt_label: Label

func _ready() -> void:
    runtime = _resolve_persistent_runtime()
    var state := runtime.start("GE01_PLAYABLE")
    current_room_id = str(state.get("current_room", "ge_01"))
    _spawn_party()
    _build_room_sensors()
    _build_hud()
    _sync_prompt()

func _resolve_persistent_runtime() -> VeilleursGE01PlayableBridge:
    var existing := get_tree().root.get_node_or_null("GE01Runtime") as VeilleursGE01PlayableBridge
    if existing != null:
        if local_runtime != null and local_runtime != existing:
            local_runtime.queue_free()
        return existing
    local_runtime.make_persistent_root()
    return local_runtime

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        _execute_default_interaction()

func _spawn_party() -> void:
    var instance := PARTY_SCENE.instantiate()
    if not (instance is Node3D):
        push_error("GE01: exploration party placeholder is not Node3D")
        return
    party = instance as Node3D
    party.name = "GE01Party"
    add_child(party)
    var anchor := blockout.room_anchor(current_room_id)
    if anchor == null:
        anchor = blockout.room_anchor("ge_01")
    if anchor != null:
        party.global_position = anchor.global_position + Vector3.UP * 0.7

func _build_room_sensors() -> void:
    var root := Node3D.new()
    root.name = "RoomSensors"
    add_child(root)
    for room_id: String in blockout.ROOM_POSITIONS.keys():
        var sensor: VeilleursGE01RoomSensor = SENSOR_SCRIPT.new() as VeilleursGE01RoomSensor
        sensor.configure(room_id, blockout.ROOM_POSITIONS[room_id])
        sensor.party_entered.connect(_on_room_entered)
        root.add_child(sensor)

func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "GE01HUD"
    add_child(canvas)
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    panel.offset_left = 16
    panel.offset_top = 12
    panel.offset_right = -16
    panel.offset_bottom = 78
    canvas.add_child(panel)
    prompt_label = Label.new()
    prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(prompt_label)

func _on_room_entered(room_id: String) -> void:
    var result := runtime.enter_room(room_id)
    if bool(result.get("success", false)):
        current_room_id = room_id
        SaveManager.autosave("GE01 · %s" % room_id)
        _sync_prompt()

func interaction_options(room_id: String = current_room_id) -> Array[String]:
    if room_id in ["ge_04", "ge_09", "ge_11", "ge_12"] and runtime.combat_available(room_id):
        return ["fight", "observe_enemy"]
    match room_id:
        "ge_02": return ["observe", "deep_observe"]
        "ge_03b": return ["inspect_risk", "take_reward", "leave"]
        "ge_05": return ["observe_corpse", "examine_corpse", "deep_examine_corpse", "recover_body", "leave_body"]
        "ge_06": return ["clear", "detour", "climb"]
        "ge_07": return ["inspect_reward", "take_reward"]
        "ge_08": return ["rekindle", "field_care", "scout"]
        "ge_10": return ["extract_route", "continue_deeper"]
        "ge_13": return ["extract"]
        "ge_14": return ["read_archive", "take_fragment"]
        _: return []

func execute_interaction(action_id: String) -> Dictionary:
    if current_room_id in ["ge_04", "ge_09", "ge_11", "ge_12"]:
        if action_id == "fight": return runtime.begin_room_combat(current_room_id)
        if action_id == "observe_enemy": return runtime.spend_light("simple_observation")
    match current_room_id:
        "ge_02":
            if action_id == "observe": return runtime.spend_light("simple_observation")
            if action_id == "deep_observe": return runtime.spend_light("deep_observation")
        "ge_03b":
            if action_id == "inspect_risk": return runtime.spend_light("simple_observation")
            if action_id == "take_reward": return {"success": true, "reward_requested": true, "room_id": current_room_id}
            if action_id == "leave": return {"success": true, "left_optional_room": true}
        "ge_05":
            if action_id == "observe_corpse": return runtime.spend_light("simple_observation")
            if action_id == "examine_corpse":
                var light_result := runtime.spend_light("anatomy_inspection")
                runtime.mark_objective_complete("corpse_examined")
                return light_result
            if action_id == "deep_examine_corpse":
                var deep_result := runtime.spend_light("deep_observation")
                runtime.mark_objective_complete("corpse_deep_examined")
                return deep_result
            if action_id in ["recover_body", "leave_body"]: return {"success": true, "corpse_choice": action_id}
        "ge_06":
            if action_id in ["clear", "detour", "climb"]:
                return ExplorationDirector.solve_obstacle("ge_06_collapse", "collapse", action_id)
        "ge_07":
            if action_id == "inspect_reward": return runtime.spend_light("simple_observation")
            if action_id == "take_reward": return {"success": true, "reward_requested": true, "room_id": current_room_id}
        "ge_08":
            if action_id in ["rekindle", "field_care", "scout"]: return runtime.resolve_refuge(action_id)
        "ge_10":
            if action_id == "extract_route": return {"success": true, "route": "ge_13"}
            if action_id == "continue_deeper": return {"success": true, "route": "ge_11"}
        "ge_13":
            if action_id == "extract": return runtime.extract("ge_13_exit")
        "ge_14":
            if action_id == "read_archive":
                ExplorationDirector.record_discovery("ge14_archive", "fall_truth", {"room_id": "ge_14"})
                return {"success": true, "knowledge": "ge14_archive"}
            if action_id == "take_fragment": return {"success": true, "reward_requested": true, "room_id": current_room_id}
    return {"success": false, "reason": "interaction_not_available", "room_id": current_room_id, "action_id": action_id}

func _execute_default_interaction() -> void:
    var options := interaction_options()
    if options.is_empty(): return
    var result := execute_interaction(options[0])
    if not bool(result.get("success", false)):
        GameState.add_log("GE01 · interaction impossible : %s" % str(result.get("reason", "indisponible")))
    _sync_prompt()

func _sync_prompt() -> void:
    if prompt_label == null: return
    var state := runtime.snapshot()
    var options := interaction_options()
    prompt_label.text = "LES GALERIES ÉTEINTES · %s · Lumière %d (%s)%s" % [
        current_room_id.to_upper(),
        int(state.get("light", 0)),
        str(state.get("light_state", "?")),
        " · E : %s" % str(options[0]) if not options.is_empty() else ""
    ]
