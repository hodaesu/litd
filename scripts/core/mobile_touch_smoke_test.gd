extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const MIN_TOUCH := Vector2(96.0, 48.0)
const EDGE_TOLERANCE: float = 1.0
const DEVICE_PROFILES := [
    {"name": "iphone_compact_landscape", "size": Vector2i(844, 390)},
    {"name": "iphone_standard_landscape", "size": Vector2i(852, 393)},
    {"name": "iphone_large_landscape", "size": Vector2i(932, 430)},
    {"name": "reference_16_9", "size": Vector2i(1280, 720)},
]

var failures: Array[String] = []
var active_device_name: String = ""
var active_window_size := Vector2i(1280, 720)

func run() -> void:
    _check(str(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "keep", "Mobile UI must preserve its 16:9 design aspect")
    _check(str(ProjectSettings.get_setting("display/window/stretch/mode", "")) == "canvas_items", "Mobile UI must use canvas_items stretch")

    for profile_value in DEVICE_PROFILES:
        var profile: Dictionary = profile_value
        active_device_name = str(profile.get("name", "mobile"))
        active_window_size = profile.get("size", Vector2i(1280, 720))
        await _run_device_profile()

    _finish()

func _run_device_profile() -> void:
    EndgameState.reset_profile_progress()
    GameState.reset_new_game()
    CampaignState.reset_new_game()
    EquipmentManager.reset_new_game(8101)
    CreatureManager.reset_new_game(8102)
    AshlandsRuntime.reset_world_progression()
    ExpeditionManager.return_to_hub("mobile_touch_smoke_reset")
    AshlandsCombatBridge.active = false
    AshlandsCombatBridge.encounter_id = ""
    AshlandsCombatBridge.encounter_type = ""

    get_tree().root.size = active_window_size
    await _frames(3)

    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must load on %s" % active_device_name)
    _check(await _wait_for_main(), "Main scene must become active on %s" % active_device_name)
    await _frames(4)

    _check(GameState.current_screen == "title", "Title must be visible on %s" % active_device_name)
    _audit_visible_buttons("title")
    _check(await _touch_button("NOUVELLE PARTIE", true), "Touch must activate Nouvelle Partie on %s" % active_device_name)
    _check(GameState.current_screen == "sanctuary", "Touch Nouvelle Partie must open Sanctuary on %s" % active_device_name)

    _audit_visible_buttons("sanctuary")
    _check(_count_buttons("INFIRMERIE\nSoins et blessures", true) == 1, "Sanctuary must expose exactly one Infirmary button on %s" % active_device_name)
    _check(_count_buttons("CHAPELLE\nPeur, folie et espoir", true) == 1, "Sanctuary must expose exactly one Chapel button on %s" % active_device_name)
    _check(_count_buttons("TAVERNE\nRecruter et rumeurs", true) == 1, "Sanctuary must expose exactly one Tavern button on %s" % active_device_name)
    _check(_count_buttons("MÉMORIAL\nHéros tombés", true) == 1, "Sanctuary must expose exactly one Memorial button on %s" % active_device_name)
    _check(await _touch_button("LA PORTE", false), "Touch must activate La Porte on %s" % active_device_name)
    _check(GameState.current_screen == "expedition", "Touch La Porte must open expedition screen on %s" % active_device_name)

    _audit_visible_buttons("expedition")
    _check(await _touch_button("RETOUR", true), "Touch must return from expedition setup on %s" % active_device_name)
    _check(GameState.current_screen == "sanctuary", "Touch Retour must restore Sanctuary on %s" % active_device_name)

    for screen_name_value in ["company", "market", "creatures", "infirmary", "chapel", "tavern", "memorial"]:
        var screen_name := str(screen_name_value)
        GameState.request_screen(screen_name)
        await _frames(4)
        _check(GameState.current_screen == screen_name, "%s screen must render on %s" % [screen_name, active_device_name])
        _audit_visible_buttons(screen_name)

    GameState.request_screen("sanctuary")
    await _frames(3)
    var main := get_tree().current_scene
    _check(main != null and main.name == "Main", "Main must still own UI before mobile combat on %s" % active_device_name)
    if main == null or main.name != "Main":
        return

    main.call("start_random_battle")
    await _frames(5)
    _check(GameState.current_screen == "combat", "Prototype combat must render for touch audit on %s" % active_device_name)
    _audit_visible_buttons("combat")
    _check(await _touch_button("GARDE", true), "Touch must activate GARDE in combat on %s" % active_device_name)
    _check(_log_contains("se met en garde"), "Combat touch must execute GARDE on %s" % active_device_name)

func _audit_visible_buttons(screen_name: String) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        _check(false, "%s has no scene on %s" % [screen_name, active_device_name])
        return
    await _frames(2)
    var visible_count := 0
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or button.is_queued_for_deletion() or not button.is_visible_in_tree():
            continue
        visible_count += 1
        var actual_size := button.size
        _check(actual_size.x + 0.01 >= MIN_TOUCH.x, "%s button '%s' is too narrow on %s: %.1f" % [screen_name, button.text, active_device_name, actual_size.x])
        _check(actual_size.y + 0.01 >= MIN_TOUCH.y, "%s button '%s' is too short on %s: %.1f" % [screen_name, button.text, active_device_name, actual_size.y])
        var rect := button.get_global_rect()
        _check(rect.position.x >= -EDGE_TOLERANCE, "%s button '%s' exits left edge on %s" % [screen_name, button.text, active_device_name])
        _check(rect.position.y >= -EDGE_TOLERANCE, "%s button '%s' exits top edge on %s" % [screen_name, button.text, active_device_name])
        _check(rect.end.x <= DESIGN_SIZE.x + EDGE_TOLERANCE, "%s button '%s' exits right edge on %s (%.1f)" % [screen_name, button.text, active_device_name, rect.end.x])
        _check(rect.end.y <= DESIGN_SIZE.y + EDGE_TOLERANCE, "%s button '%s' exits bottom edge on %s (%.1f)" % [screen_name, button.text, active_device_name, rect.end.y])
    _check(visible_count > 0, "%s must contain at least one visible button on %s" % [screen_name, active_device_name])
    print("MOBILE_UI_AUDIT screen=%s device=%s buttons=%d window=%dx%d" % [screen_name, active_device_name, visible_count, active_window_size.x, active_window_size.y])

func _touch_button(fragment: String, exact: bool) -> bool:
    var button := _find_button(fragment, exact)
    if button == null or button.disabled or not button.is_visible_in_tree():
        return false
    var logical_center := button.get_global_rect().get_center()
    var window_center := _logical_to_window(logical_center)

    var down := InputEventScreenTouch.new()
    down.index = 0
    down.position = window_center
    down.pressed = true
    Input.parse_input_event(down)
    await _frames(2)

    var up := InputEventScreenTouch.new()
    up.index = 0
    up.position = window_center
    up.pressed = false
    Input.parse_input_event(up)
    await _frames(5)
    return true

func _logical_to_window(point: Vector2) -> Vector2:
    var window_size := Vector2(active_window_size)
    var scale := minf(window_size.x / DESIGN_SIZE.x, window_size.y / DESIGN_SIZE.y)
    var drawn_size := DESIGN_SIZE * scale
    var offset := (window_size - drawn_size) * 0.5
    return offset + point * scale

func _find_button(fragment: String, exact: bool) -> Button:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or button.is_queued_for_deletion() or not button.is_visible_in_tree():
            continue
        if exact and button.text == fragment:
            return button
        if not exact and button.text.contains(fragment):
            return button
    return null

func _count_buttons(fragment: String, exact: bool) -> int:
    var scene := get_tree().current_scene
    if scene == null:
        return 0
    var count := 0
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or button.is_queued_for_deletion() or not button.is_visible_in_tree():
            continue
        if exact and button.text == fragment:
            count += 1
        elif not exact and button.text.contains(fragment):
            count += 1
    return count

func _log_contains(fragment: String) -> bool:
    var needle := fragment.to_lower()
    for line_value in GameState.log_lines:
        if str(line_value).to_lower().contains(needle):
            return true
    return false

func _wait_for_main(max_frames: int = 180) -> bool:
    for _index in range(max_frames):
        var scene := get_tree().current_scene
        if scene != null and scene.name == "Main":
            return true
        await get_tree().process_frame
    return false

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("MOBILE_TOUCH_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("MOBILE_TOUCH_SMOKE: " + failure)
    print("MOBILE_TOUCH_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
