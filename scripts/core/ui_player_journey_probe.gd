extends Node

var reported := false

func _process(_delta: float) -> void:
    if reported or GameState.current_screen != "combat":
        return
    var scene: Node = get_tree().current_scene
    if scene == null or scene.name != "Main" or not scene.has_method("_active_combat_hero"):
        return
    await get_tree().process_frame
    var hero: Dictionary = scene.call("_active_combat_hero")
    var combat_position := int(hero.get("combat_position", -1))
    var rank := combat_position + 1 if combat_position >= 0 else -1
    var tactical_rows: Array[String] = []
    var capture_rows: Array[String] = []
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null:
            continue
        if button.text.begins_with("1 · "):
            tactical_rows.append("text=%s visible=%s disabled=%s path=%s" % [
                button.text.replace("\n", " / "),
                button.is_visible_in_tree(),
                button.disabled,
                str(button.get_path())
            ])
        elif button.text == "CAPTURER":
            capture_rows.append("visible=%s disabled=%s path=%s" % [
                button.is_visible_in_tree(),
                button.disabled,
                str(button.get_path())
            ])
    print("UI_TACTICAL_PROBE hero=%s id=%s rank=%d first_skill=[%s] capture=[%s]" % [
        str(hero.get("name", "?")),
        str(hero.get("id", "?")),
        rank,
        "; ".join(tactical_rows),
        "; ".join(capture_rows)
    ])
    reported = true
