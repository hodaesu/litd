extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"
const MIN_TOUCH_HEIGHT := 48.0
var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    CampaignState.reset_new_game()
    EquipmentManager.reset_new_game(9401)
    CreatureManager.reset_new_game(9402)
    await _frames(2)

    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must load for canonical UX smoke")
    _check(await _wait_for_main(), "Main must become active for canonical UX smoke")
    await _frames(4)

    var main := get_tree().current_scene
    _check(main != null and main.name == "Main", "Canonical UX must be owned by Main")
    if main == null or main.name != "Main":
        _finish()
        return

    main.call("show_screen", "sanctuary")
    await _frames(4)
    _audit_location_feedback(main)

    main.call("show_screen", "navigation")
    await _frames(4)
    _check(_find_node_named(main, "CanonicalSectionRule") != null, "Canonical surfaces must render their typography separator")
    _audit_canonical_touch_targets(main)

    main.call("show_screen", "sanctuary")
    await _frames(3)
    main.call("show_screen", "contextual")
    await _frames(4)
    _check(_find_label_contains("TOUCHE DIRECTEMENT LE NOM") != null, "Contextual help from the hub must explain direct-name interaction")
    _check(_find_button_contains("RETOUR") != null, "Contextual help must expose a return action")

    var party_backup: Array = GameState.party.duplicate(true)
    GameState.party.clear()
    main.call("show_screen", "hero_profile")
    await _frames(4)
    _check(_find_node_named(main, "CanonicalRecoveryState") != null, "Empty active party must render a recovery state")
    _check(_find_label_contains("AUCUN HÉROS ACTIF") != null, "Empty active party must be explained explicitly")
    _check(_find_button_contains("OUVRIR LA COMPAGNIE") != null, "Empty active party must offer a clear recovery route")

    GameState.party.clear()
    for hero_value: Variant in party_backup:
        GameState.party.append(hero_value)

    main.call("show_screen", "results_options")
    await _frames(4)
    _check(_find_label_contains("AUCUNE EXPÉDITION ACTIVE") != null, "Results screen must explain the no-expedition state")
    _audit_canonical_touch_targets(main)

    _finish()

func _audit_location_feedback(main: Node) -> void:
    var hotspot_count := 0
    for node_value in main.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.has_meta("litd_location_hotspot"):
            continue
        hotspot_count += 1
        var overlay := button.get_node_or_null("CanonicalLocationFeedback")
        _check(overlay != null, "Each Sanctuary hotspot must own a non-rectangular feedback overlay")
        _check(button.get_theme_color("font_color").a <= 0.01, "Technical Sanctuary button text must stay invisible")
        _check(button.focus_mode == Control.FOCUS_ALL, "Sanctuary hotspot must support keyboard/controller focus")
        if overlay != null:
            var glow := overlay.get_node_or_null("Glow") as Label
            var underline := overlay.get_node_or_null("Underline") as ColorRect
            _check(glow != null, "Sanctuary feedback overlay must expose the decor-name glow")
            _check(underline != null, "Sanctuary feedback overlay must expose a thin underline")
            if glow != null:
                _check(glow.get_theme_color("font_color").a <= 0.01, "Location glow must be invisible while idle")
            if underline != null:
                _check(underline.color.a <= 0.01, "Location underline must be invisible while idle")
        main.call("_set_location_feedback", button, 1)
        if overlay != null:
            var active_underline := overlay.get_node_or_null("Underline") as ColorRect
            if active_underline != null:
                _check(active_underline.color.a >= 0.5, "Location feedback must become visible on hover/focus")
        main.call("_set_location_feedback", button, 0)
    _check(hotspot_count >= 7, "Sanctuary must retain its visitable-place hotspots")

func _audit_canonical_touch_targets(main: Node) -> void:
    var checked := 0
    var current := str(GameState.current_screen)
    for node_value in main.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.is_visible_in_tree():
            continue
        if current in ["navigation", "hero_profile", "hud_reference", "contextual", "results_options", "options"]:
            checked += 1
            _check(button.size.y + 0.01 >= MIN_TOUCH_HEIGHT or button.custom_minimum_size.y + 0.01 >= MIN_TOUCH_HEIGHT, "Visible canonical control '%s' must remain touch-safe" % button.text)
    _check(checked > 0, "Canonical UX audit must inspect visible controls")

func _find_label_contains(fragment: String) -> Label:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    var needle := fragment.to_upper()
    for node_value in scene.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label != null and not label.is_queued_for_deletion() and label.text.to_upper().contains(needle):
            return label
    return null

func _find_button_contains(fragment: String) -> Button:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    var needle := fragment.to_upper()
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null and not button.is_queued_for_deletion() and button.text.to_upper().contains(needle):
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
        print("CANONICAL_UX_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("CANONICAL_UX_SMOKE: " + failure)
    print("CANONICAL_UX_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
