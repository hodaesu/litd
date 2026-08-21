extends "res://scripts/core/ui_roguelike_journey_smoke_test_v2.gd"

# v3 : le joueur n'active plus un événement directement depuis une case de carte.
# Il entre dans une salle réelle, résout son contenu, revient dans la salle, puis
# emprunte un passage ou ouvre la carte macro.

func _drive_title_and_departure() -> void:
    _check(await _press_button("NOUVELLE PARTIE", true), "Player must start a new game through the UI")
    _check(GameState.current_screen == "sanctuary", "New Game must open the Sanctuary")
    _check(await _press_button("LA PORTE", false), "La Porte must be usable")
    _check(GameState.current_screen == "expedition", "La Porte must open the expedition screen")
    _check(_find_button("DESCENDRE DANS LE DONJON", true) != null, "Roguelike departure must expose the descent button")
    _check(await _press_button("DESCENDRE DANS LE DONJON", true), "Player must launch the expedition through the UI")
    _check(ExpeditionManager.expedition_active, "Visible launch must activate ExpeditionManager")

    var runtime: Variant = ExpeditionManager.roguelike_runtime
    _check(runtime != null, "Roguelike runtime must exist after launch")
    if runtime != null:
        runtime.start_run(424242)
        ExpeditionManager.expedition_seed = 424242
        var scene: Node = get_tree().current_scene
        if scene != null:
            scene.call("show_screen", "expedition")
        await _frames(4)

    _check(_node_tree_contains_text(get_tree().current_scene, "CARTE MACRO"), "Physical dungeon must expose the macro map")
    _check(_node_tree_contains_text(get_tree().current_scene, "1 NŒUD = 1 SALLE VISITABLE"), "Map must state the physical-room contract")
    _check(_find_button("Porte du Premier Voile", false) != null, "Macro map must expose the real entrance room")
    _check(_find_button("EXTRAIRE", true) != null, "Macro map must expose voluntary extraction")
    _check(_find_button("ÉTEINDRE 1 LUMIÈRE", true) != null, "Map must expose deliberate light reduction")

func _enter_first_room() -> void:
    _check(await _press_button("Porte du Premier Voile", false), "Player must enter the physical entrance room")
    _check(GameState.current_screen == "dungeon_room", "Map node must open a real room screen instead of resolving an abstract tile")
    _check(_node_tree_contains_text(get_tree().current_scene, "ISSUES ET PASSAGES"), "Physical room must expose its passages")
    _check(await _press_button("FRANCHIR ET INSPECTER LE SEUIL", true), "Player must resolve the entrance from inside the room")
    _check(GameState.current_screen == "rewards", "Resolved room must open rewards")
    _check(await _press_button("RETOURNER DANS LA SALLE", true), "Rewards must return to the physical room")
    _check(GameState.current_screen == "dungeon_room", "Player must physically return to the cleared room")
    _check(await _press_button("OUVRIR LA CARTE MACRO", true), "Player must be able to reopen the macro map")
    _check(GameState.current_screen == "expedition", "Macro map must reopen from the physical room")

func _reach_combat_room() -> void:
    for _step in range(40):
        if GameState.current_screen == "combat":
            break
        if GameState.current_screen == "rewards":
            var return_button: Button = _find_button("RETOURNER DANS LA SALLE", true)
            if return_button == null:
                break
            return_button.pressed.emit()
            await _frames(4)
            continue
        if GameState.current_screen == "dungeon_room":
            var action_button: Button = _find_physical_room_action_button()
            if action_button != null:
                action_button.pressed.emit()
                await _frames(5)
                continue
            var map_button: Button = _find_button("OUVRIR LA CARTE MACRO", true)
            if map_button == null:
                break
            map_button.pressed.emit()
            await _frames(4)
            continue
        if GameState.current_screen != "expedition":
            break
        var room_button: Button = _find_unvisited_reachable_room_button()
        _check(room_button != null, "Macro map must keep at least one unexplored reachable room")
        if room_button == null:
            break
        room_button.pressed.emit()
        await _frames(5)

    _check(GameState.current_screen == "combat", "Physical route must eventually start combat from inside a room")
    if GameState.current_screen == "combat":
        _check(_find_button("FRAPPE", true) != null, "Dungeon combat must reuse tactical combat actions")
        _check(_find_button("CAPTURER", true) != null, "Dungeon combat must expose capture")
        _check(GameState.battle_enemies.size() >= 1, "Combat room must create enemies")

func _find_physical_room_action_button() -> Button:
    var fragments: Array[String] = [
        "ENGAGER LE COMBAT",
        "TRAVERSER ET DÉJOUER LE PIÈGE",
        "RÉSOUDRE L'ÉNIGME",
        "FOUILLER LA SALLE",
        "EXPLORER ET INTERAGIR",
        "ROMPRE LE DERNIER SCEAU",
        "AFFRONTER L'ANGE"
    ]
    for fragment in fragments:
        var button: Button = _find_button(fragment, false)
        if button != null and not button.disabled and button.is_visible_in_tree():
            return button
    return null

func _find_unvisited_reachable_room_button() -> Button:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return null
    for node_value in scene.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button == null or button.disabled or not button.is_visible_in_tree():
            continue
        if button.custom_minimum_size != Vector2(178, 68):
            continue
        if button.text.begins_with("✓") or button.text.begins_with("◆"):
            continue
        return button
    return null
