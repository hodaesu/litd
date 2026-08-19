extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"
var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    CampaignState.reset_new_game()
    EquipmentManager.reset_new_game(9101)
    CreatureManager.reset_new_game(9102)
    await _frames(2)

    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must load for Sanctuary building smoke")
    _check(await _wait_for_main(), "Main must become active")
    await _frames(4)

    _check(await _press_button("NOUVELLE PARTIE", true), "New Game must enter Sanctuary")
    _check(GameState.current_screen == "sanctuary", "New Game must open Sanctuary")
    _check(_count_visible_buttons("CHAPELLE\nPeur, folie et espoir") == 1, "Sanctuary must expose one functional Chapel button")
    _check(_count_visible_buttons("TAVERNE\nRecruter et rumeurs") == 1, "Sanctuary must expose one functional Tavern button")
    _check(_count_visible_buttons("MÉMORIAL\nHéros tombés") == 1, "Sanctuary must expose one functional Memorial button")

    await _test_chapel()
    await _test_tavern()
    await _test_memorial()
    _finish()

func _test_chapel() -> void:
    _check(await _press_button("CHAPELLE\nPeur, folie et espoir", true), "Chapel button must open the Chapel")
    _check(GameState.current_screen == "chapel", "Chapel screen must be active")
    var main := get_tree().current_scene
    _check(main != null, "Main missing in Chapel test")
    if main == null:
        return
    var hero: Dictionary = GameState.party[0]
    hero["fear"] = 60
    hero["madness"] = 30
    hero["hope"] = 40
    var psychology := PsychologyRuntime.ensure_hero(hero)
    psychology["madness_exposure"] = 30
    hero["psychology"] = psychology
    main.set("selected_hero_id", str(hero.get("id", "")))
    main.call("show_screen", "chapel")
    await _frames(3)
    var gold_before := GameState.gold
    var hope_before := int(hero.get("hope", 0))
    _check(await _press_button("APAISER", true), "Chapel must expose a usable appeasement action")
    _check(GameState.gold == gold_before - 12, "Chapel appeasement must cost exactly 12 gold")
    _check(int(hero.get("fear", 0)) == 42, "Chapel must reduce Fear by 18")
    _check(int(hero.get("madness", 0)) == 30, "Chapel must not erase legacy Madness numerically")
    _check(int(PsychologyRuntime.state_for(hero).get("madness_exposure", 0)) == 18, "Chapel must stabilize hidden madness exposure")
    _check(int(hero.get("hope", 0)) == hope_before, "Chapel must not turn Hope into a numeric resource")
    _check(not PsychologyRuntime.state_for(hero).get("hope_history", []).is_empty(), "Chapel must record a Hope manifestation")
    _check(await _press_button("RETOUR AU SANCTUAIRE", true), "Chapel must return to Sanctuary")

func _test_tavern() -> void:
    _check(await _press_button("TAVERNE\nRecruter et rumeurs", true), "Tavern button must open the Tavern")
    _check(GameState.current_screen == "tavern", "Tavern screen must be active")
    _check(await _press_button("ÉCOUTER LES RUMEURS", true), "Tavern must expose rumors")
    _check(_log_contains("rumeur"), "Listening to rumors must create a Tavern log entry")

    var hope_before: Dictionary = {}
    var history_before: Dictionary = {}
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        hero["fear"] = 20
        hero["hope"] = 40
        hope_before[str(hero.get("id", ""))] = int(hero.get("hope", 0))
        history_before[str(hero.get("id", ""))] = PsychologyRuntime.state_for(hero).get("hope_history", []).size()
    var supplies_before := GameState.supplies
    _check(await _press_button("REPAS PARTAGÉ · 1 VIVRE", true), "Tavern must expose the shared meal")
    _check(GameState.supplies == supplies_before - 1, "Shared meal must consume one supply")
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        _check(int(hero.get("fear", 0)) == 15, "Shared meal must reduce Fear for every living hero")
        _check(int(hero.get("hope", 0)) == int(hope_before.get(hero_id, 0)), "Shared meal must keep Hope non-numeric")
        _check(PsychologyRuntime.state_for(hero).get("hope_history", []).size() > int(history_before.get(hero_id, 0)), "Shared meal must record Hope for every living hero")
    _check(await _press_button("RETOUR AU SANCTUAIRE", true), "Tavern must return to Sanctuary")

func _test_memorial() -> void:
    _check(await _press_button("MÉMORIAL\nHéros tombés", true), "Memorial button must open the Memorial")
    _check(GameState.current_screen == "memorial", "Memorial screen must be active")
    var hope_before: Dictionary = {}
    var history_before: Dictionary = {}
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        hero["fear"] = 10
        hero["hope"] = 30
        hope_before[str(hero.get("id", ""))] = int(hero.get("hope", 0))
        history_before[str(hero.get("id", ""))] = PsychologyRuntime.state_for(hero).get("hope_history", []).size()
    var flag := "memorial_honored_%s" % CampaignState.current_chapter_id
    _check(not bool(CampaignState.chapter_flags.get(flag, false)), "Memorial flag must start unset")
    _check(await _press_button("SE RECUEILLIR", true), "Memorial must allow one gathering")
    _check(bool(CampaignState.chapter_flags.get(flag, false)), "Memorial gathering must persist a chapter flag")
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        _check(int(hero.get("fear", 0)) == 6, "Memorial must reduce Fear by 4 including the Hope relief")
        _check(int(hero.get("hope", 0)) == int(hope_before.get(hero_id, 0)), "Memorial must keep Hope non-numeric")
        _check(PsychologyRuntime.state_for(hero).get("hope_history", []).size() > int(history_before.get(hero_id, 0)), "Memorial must record a Hope manifestation")
    _check(_find_button("DÉJÀ HONORÉ CE CHAPITRE", true) != null, "Memorial must visibly lock repeated gathering")
    var locked := _find_button("DÉJÀ HONORÉ CE CHAPITRE", true)
    _check(locked != null and locked.disabled, "Repeated Memorial benefit must be disabled")
    _check(await _press_button("RETOUR AU SANCTUAIRE", true), "Memorial must return to Sanctuary")

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

func _count_visible_buttons(text: String) -> int:
    var scene := get_tree().current_scene
    if scene == null:
        return 0
    var count := 0
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null and not button.is_queued_for_deletion() and button.is_visible_in_tree() and button.text == text:
            count += 1
    return count

func _press_button(fragment: String, exact: bool) -> bool:
    var button := _find_button(fragment, exact)
    if button == null or button.disabled:
        return false
    button.pressed.emit()
    await _frames(4)
    return true

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
        print("SANCTUARY_BUILDINGS_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("SANCTUARY_BUILDINGS_SMOKE: " + failure)
    print("SANCTUARY_BUILDINGS_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
