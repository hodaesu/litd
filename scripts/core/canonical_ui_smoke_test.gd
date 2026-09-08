extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"
const MIN_TOUCH := Vector2(96.0, 48.0)
var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    CampaignState.reset_new_game()
    EquipmentManager.reset_new_game(9301)
    CreatureManager.reset_new_game(9302)
    await _frames(2)

    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must load for canonical UI smoke")
    _check(await _wait_for_main(), "Main must become active for canonical UI smoke")
    await _frames(4)

    var main := get_tree().current_scene
    _check(main != null and main.name == "Main", "Canonical UI must be owned by Main")
    if main == null or main.name != "Main":
        _finish()
        return

    main.call("show_screen", "sanctuary")
    await _frames(4)
    _audit_sanctuary_hotspots(main)
    _audit_header(main)

    var canonical_screens := [
        "navigation",
        "hero_profile",
        "inventory_equipment",
        "skills",
        "bestiary",
        "hud_reference",
        "contextual",
        "expedition",
        "results_options",
    ]
    for screen_value: Variant in canonical_screens:
        var screen_name := str(screen_value)
        main.call("show_screen", screen_name)
        await _frames(4)
        _check(GameState.current_screen == screen_name, "Canonical screen '%s' must become active" % screen_name)
        _check(_visible_content_count(main) > 0, "Canonical screen '%s' must render visible content" % screen_name)
        _audit_header(main)

    main.call("show_screen", "navigation")
    await _frames(3)
    for marker_value: Variant in [
        "01 · HUB",
        "02 · NAVIGATION",
        "03 · FICHE HÉROS",
        "04 · INVENTAIRE / ÉQUIPEMENT",
        "05 · COMPÉTENCES",
        "06 · BESTIAIRE",
        "07 · HUD",
        "08 · CONTEXTUELS",
        "09 · EXPÉDITION",
        "10 · RÉSULTATS / OPTIONS",
    ]:
        _check(_find_button_contains(str(marker_value)) != null, "Navigation must expose '%s'" % str(marker_value))

    main.call("start_random_battle")
    await _frames(6)
    _check(GameState.current_screen == "combat", "Real prototype combat must open for canonical HUD audit")
    _check(main.get_node_or_null("Root/Content/CanonicalCombatHUD") != null or _find_node_named(main, "CanonicalCombatHUD") != null, "Canonical HUD must be injected into real combat")

    _finish()

func _audit_sanctuary_hotspots(main: Node) -> void:
    var hotspot_count := 0
    for node_value in main.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.has_meta("litd_location_hotspot"):
            continue
        hotspot_count += 1
        _check(button.size.x + 0.01 >= MIN_TOUCH.x and button.size.y + 0.01 >= MIN_TOUCH.y, "Sanctuary hotspot '%s' must stay touch-safe" % button.text)
        _check(button.get_theme_stylebox("normal") is StyleBoxEmpty, "Sanctuary hotspot '%s' must have no normal rectangle" % button.text)
        _check(button.get_theme_stylebox("hover") is StyleBoxEmpty, "Sanctuary hotspot '%s' must have no hover rectangle" % button.text)
        _check(button.get_theme_stylebox("pressed") is StyleBoxEmpty, "Sanctuary hotspot '%s' must have no pressed rectangle" % button.text)
        _check(button.get_theme_color("font_color").a <= 0.01, "Sanctuary hotspot technical text must remain invisible behind the decor label")
        _check(str(button.get_meta("litd_location_original_text", "")) != "", "Sanctuary hotspot must preserve its runtime label")
    _check(hotspot_count >= 7, "Sanctuary must expose its visitable places as transparent name hotspots")

func _audit_header(main: Node) -> void:
    var header := main.get_node_or_null("Root/Header")
    if header == null:
        header = _find_node_named(main, "Header")
    _check(header != null, "Canonical UI must retain the shared header")
    if header == null:
        return
    var menu := header.get_node_or_null("CanonicalMenu") as Button
    var context := header.get_node_or_null("CanonicalContext") as Button
    _check(menu != null, "Canonical header must expose MENU")
    _check(context != null, "Canonical header must expose contextual help")
    if menu != null:
        _check(menu.size.x + 0.01 >= MIN_TOUCH.x and menu.size.y + 0.01 >= MIN_TOUCH.y, "MENU must meet mobile touch target")
    if context != null:
        _check(context.size.x + 0.01 >= MIN_TOUCH.x and context.size.y + 0.01 >= MIN_TOUCH.y, "Context control must meet mobile touch target")

func _visible_content_count(main: Node) -> int:
    var count := 0
    for node_value in main.find_children("*", "Control", true, false):
        var control := node_value as Control
        if control != null and control.is_visible_in_tree():
            count += 1
    return count

func _find_button_contains(fragment: String) -> Button:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null and not button.is_queued_for_deletion() and button.is_visible_in_tree() and button.text.contains(fragment):
            return button
    return null

func _find_node_named(root_node: Node, node_name: String) -> Node:
    return root_node.find_child(node_name, true, false)

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
        print("CANONICAL_UI_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("CANONICAL_UI_SMOKE: " + failure)
    print("CANONICAL_UI_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
