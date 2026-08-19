extends Node

var reported := false

func _process(_delta: float) -> void:
    if reported or GameState.current_screen != "combat":
        return
    var scene: Node = get_tree().current_scene
    if scene == null or scene.name != "Main" or not scene.has_method("_active_round_hero"):
        return
    await get_tree().process_frame
    var hero: Dictionary = scene.call("_active_round_hero")
    var rank := int(hero.get("battle_rank", -1))
    var can_strike := bool(scene.call("_can_use_attack_from_rank", hero, "strike")) if scene.has_method("_can_use_attack_from_rank") else false
    var rows: Array[String] = []
    for node_value in scene.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null and button.text == "FRAPPE":
            rows.append("visible=%s disabled=%s path=%s" % [button.is_visible_in_tree(), button.disabled, str(button.get_path())])
    print("UI_TACTICAL_PROBE hero=%s id=%s rank=%d can_strike=%s buttons=[%s]" % [str(hero.get("name", "?")), str(hero.get("id", "?")), rank, can_strike, "; ".join(rows)])
    reported = true
