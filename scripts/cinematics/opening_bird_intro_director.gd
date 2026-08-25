extends Node3D
class_name OpeningBirdIntroDirector

signal intro_started
signal beat_started(beat_id: String)
signal camera_handoff_started
signal intro_finished(skipped: bool)

const CONTRACT_PATH := "res://data/cinematics/opening_bird_intro.json"
const INTRO_FLAG := "opening_bird_intro_seen"
const CAMERA_NAME := "OpeningBirdPOV"
const CITY_PROXY := preload("res://scripts/cinematics/opening_city_proxy_builder.gd")
const OPENING_TUTORIAL := preload("res://scripts/tutorials/opening_exploration_tutorial.gd")

var contract: Dictionary = {}
var party: Node3D
var exploration_camera: Camera3D
var city_proxy: OpeningCityProxyBuilder
var bird_rig: Node3D
var bird_camera: Camera3D
var overlay: CanvasLayer
var eyelids: ColorRect
var skip_label: Label
var _running := false
var _finished := false
var _skip_armed_until := 0
var _party_target := Vector3.ZERO


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process_input(true)
    call_deferred("_begin_if_needed")


func _begin_if_needed() -> void:
    if bool(CampaignState.chapter_flags.get(INTRO_FLAG, false)):
        queue_free()
        return
    contract = _read_json(CONTRACT_PATH)
    if contract.is_empty():
        push_error("OpeningBirdIntroDirector: contrat d'introduction absent")
        queue_free()
        return
    party = _find_party()
    exploration_camera = get_viewport().get_camera_3d()
    if party == null or exploration_camera == null:
        push_error("OpeningBirdIntroDirector: caméra ou groupe d'exploration introuvable")
        queue_free()
        return
    _build_runtime()
    await _play()


func _build_runtime() -> void:
    _party_target = party.global_position
    party.visible = false
    _set_party_controls(false)
    city_proxy = CITY_PROXY.new()
    add_child(city_proxy)
    city_proxy.build()

    bird_rig = Node3D.new()
    bird_rig.name = CAMERA_NAME
    bird_rig.top_level = true
    add_child(bird_rig)
    bird_camera = Camera3D.new()
    bird_camera.name = "Eyes"
    bird_camera.fov = 76.0
    bird_camera.current = true
    bird_rig.add_child(bird_camera)

    overlay = CanvasLayer.new()
    overlay.name = "OpeningBirdOverlay"
    overlay.layer = 190
    add_child(overlay)
    eyelids = ColorRect.new()
    eyelids.name = "EyelidOcclusion"
    eyelids.color = Color(0.01, 0.008, 0.006, 0.0)
    eyelids.mouse_filter = Control.MOUSE_FILTER_IGNORE
    eyelids.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(eyelids)
    skip_label = Label.new()
    skip_label.position = Vector2(34, 650)
    skip_label.text = "Retour : passer la cinématique"
    skip_label.modulate = Color(0.86, 0.82, 0.74, 0.68)
    skip_label.add_theme_font_size_override("font_size", 14)
    overlay.add_child(skip_label)

    var waypoints: Array = contract.get("runtime_waypoints", [])
    if not waypoints.is_empty():
        bird_rig.global_transform = _waypoint_transform(waypoints[0])


func _play() -> void:
    _running = true
    intro_started.emit()
    HUDDirector.set_disclosure_level(HUDDirector.LEVEL_WORLD_ONLY)
    var waypoints: Array = contract.get("runtime_waypoints", [])
    for index in range(1, waypoints.size()):
        if not _running:
            return
        var waypoint: Dictionary = waypoints[index]
        var beat_id := str(waypoint.get("id", "flight"))
        beat_started.emit(beat_id)
        if beat_id == "shockwave":
            city_proxy.begin_fall()
        elif beat_id == "collision":
            city_proxy.hide_old_city()
        var duration := float(waypoint.get("duration", 2.0))
        if beat_id in ["shockwave", "collision", "fall"] and not AccessibilityDirector.allows_screen_shake():
            duration *= 1.25
        await _move_camera(_waypoint_transform(waypoint), duration)

    if _running:
        await _last_breath_and_handoff()


func _move_camera(target: Transform3D, duration: float) -> void:
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(bird_rig, "global_transform", target, maxf(0.05, duration))
    await tween.finished


func _last_breath_and_handoff() -> void:
    beat_started.emit("last_breath")
    await _blink(0.35, 0.32)
    await get_tree().create_timer(0.7, true).timeout
    await _blink(0.55, 0.45)

    beat_started.emit("heroes_approach")
    var approach := create_tween()
    approach.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    approach.set_trans(Tween.TRANS_SINE)
    approach.set_ease(Tween.EASE_OUT)
    approach.tween_property(city_proxy.hero_group, "global_position", _party_target + Vector3(0.0, 0.0, 4.5), 3.2)
    await approach.finished

    if is_instance_valid(city_proxy.approach_hero):
        beat_started.emit("hero_kneels")
        var compassion := create_tween()
        compassion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        compassion.set_trans(Tween.TRANS_SINE)
        compassion.set_ease(Tween.EASE_OUT)
        compassion.tween_property(city_proxy.approach_hero, "position:z", -2.2, 1.15)
        await compassion.finished

    beat_started.emit("compassion_choice")
    camera_handoff_started.emit()
    var cover := create_tween()
    cover.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    cover.tween_property(eyelids, "color:a", 1.0, 0.55)
    await cover.finished
    _complete(false)


func _blink(close_seconds: float, hold_seconds: float) -> void:
    var close_tween := create_tween()
    close_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    close_tween.tween_property(eyelids, "color:a", 0.92, close_seconds)
    await close_tween.finished
    await get_tree().create_timer(hold_seconds, true).timeout
    var open_tween := create_tween()
    open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    open_tween.tween_property(eyelids, "color:a", 0.12, close_seconds * 1.4)
    await open_tween.finished


func _complete(skipped: bool) -> void:
    if _finished:
        return
    _finished = true
    _running = false
    CampaignState.set_chapter_flag(INTRO_FLAG, true)
    party.global_position = _party_target
    party.visible = true
    _set_party_controls(true)
    if is_instance_valid(exploration_camera):
        exploration_camera.make_current()
    HUDDirector.set_screen_context("exploration")
    if is_instance_valid(city_proxy):
        city_proxy.queue_free()
    if is_instance_valid(overlay):
        overlay.queue_free()
    if is_instance_valid(bird_rig):
        bird_rig.queue_free()
    _start_tutorial()
    intro_finished.emit(skipped)
    queue_free()


func _start_tutorial() -> void:
    if bool(CampaignState.chapter_flags.get("opening_tutorial_complete", false)):
        return
    var tutorial := OPENING_TUTORIAL.new()
    tutorial.name = "OpeningExplorationTutorial"
    get_tree().current_scene.add_child(tutorial)
    tutorial.begin(party)


func _input(event: InputEvent) -> void:
    if not _running or not event.is_action_pressed("back"):
        return
    var now := Time.get_ticks_msec()
    if now <= _skip_armed_until:
        _complete(true)
    else:
        _skip_armed_until = now + 3000
        skip_label.text = "Appuyez encore sur Retour pour passer"
        var restore := get_tree().create_timer(3.0, true)
        restore.timeout.connect(func():
            if is_instance_valid(skip_label) and Time.get_ticks_msec() > _skip_armed_until:
                skip_label.text = "Retour : passer la cinématique"
        )
    get_viewport().set_input_as_handled()


func _set_party_controls(enabled: bool) -> void:
    if party == null:
        return
    party.set_physics_process(enabled)
    party.set_process_unhandled_input(enabled)
    var mobile := party.get_node_or_null("MobileControls") as CanvasItem
    if mobile != null:
        mobile.visible = enabled


func _find_party() -> Node3D:
    var parties := get_tree().get_nodes_in_group("player_party")
    if not parties.is_empty() and parties[0] is Node3D:
        return parties[0] as Node3D
    return get_tree().current_scene.find_child("ExplorationPartyRuntime", true, false) as Node3D


func _waypoint_transform(waypoint: Dictionary) -> Transform3D:
    var position := _vec3(waypoint.get("position", [0.0, 2.0, 0.0]))
    var target := _vec3(waypoint.get("look_at", [0.0, 1.0, -1.0]))
    var direction := (target - position).normalized()
    if direction.length_squared() < 0.001:
        direction = Vector3.FORWARD
    return Transform3D(Basis.looking_at(direction, Vector3.UP), position)


func _vec3(value: Variant) -> Vector3:
    if value is Array and value.size() >= 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
