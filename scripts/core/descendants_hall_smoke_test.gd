extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"
var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    await _frames(2)

    var runtime: Node = ExpeditionManager.first_descent_runtime
    _check(runtime != null, "First Descent runtime must exist")
    if runtime == null:
        _finish()
        return

    runtime.reset_new_game()
    var started: Dictionary = runtime.start_attempt("first_veil_crypts", 424242, GameState.party)
    _check(bool(started.get("eligible", false)), "First attempt must be eligible")

    var party_result: Array = GameState.party.duplicate(true)
    if party_result.size() >= 2:
        party_result[0]["level"] = 5
        party_result[1]["level"] = 4
        party_result[1]["hp"] = 0
    var award: Dictionary = runtime.finish_attempt(
        "boss_defeated",
        {
            "boss_defeated": true,
            "seed": 424242,
            "rooms_cleared": 19,
            "deepest_depth": 5
        },
        party_result,
        1
    )
    _check(bool(award.get("unlocked", false)), "First Descent award must be created before Hall test")

    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must load for Hall smoke")
    _check(await _wait_for_main(), "Main must become active for Hall smoke")
    await _frames(4)

    var main := get_tree().current_scene
    _check(main != null, "Main scene missing")
    if main == null:
        _finish()
        return

    main.call("show_screen", "sanctuary")
    await _frames(3)
    _check(_find_button("HALL DES DESCENDANTS", false) != null, "Sanctuary must expose Hall of Descendants")
    _check(await _press_button("HALL DES DESCENDANTS", false), "Hall button must be functional")
    _check(GameState.current_screen == "descendants_hall", "Hall screen must become active")

    _check(_label_contains("LA PREMIÈRE DESCENTE"), "Hall must display the chronicle title")
    _check(_label_contains("Cryptes du Premier Voile"), "Hall must display the dungeon name")
    _check(_label_contains("Ange du Premier Voile"), "Hall must display the defeated boss")
    _check(_label_contains("Éclat du Premier Voile"), "Hall must display the unique relic")
    _check(_label_contains("Celui qui n'a pas remonté"), "Hall must display the unique title")
    _check(_label_contains("Malvor — niveau 4"), "Hall must preserve a fallen hero in the chronicle")
    _check(_label_contains("Lumière restante 1"), "Hall must display remaining Light")
    _check(_label_contains("Seed 424242"), "Hall must display the run seed")

    _check(await _press_button("RETOUR AU SANCTUAIRE", true), "Hall must return to Sanctuary")
    _check(GameState.current_screen == "sanctuary", "Hall back button must restore Sanctuary")
    _finish()

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

func _press_button(fragment: String, exact: bool) -> bool:
    var button := _find_button(fragment, exact)
    if button == null or button.disabled:
        return false
    button.pressed.emit()
    await _frames(4)
    return true

func _label_contains(fragment: String) -> bool:
    var scene := get_tree().current_scene
    if scene == null:
        return false
    for node_value in scene.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label != null and not label.is_queued_for_deletion() and label.is_visible_in_tree() and label.text.contains(fragment):
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
        print("DESCENDANTS_HALL_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("DESCENDANTS_HALL_SMOKE: " + failure)
    print("DESCENDANTS_HALL_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
