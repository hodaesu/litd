extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"

var failures: Array[String] = []

func run() -> void:
    seed(1337)
    EndgameState.reset_profile_progress()
    GameState.reset_new_game()
    CampaignState.reset_new_game()
    EquipmentManager.reset_new_game(7001)
    CreatureManager.reset_new_game(7002)
    AshlandsRuntime.reset_world_progression()
    if ExpeditionManager.expedition_active:
        ExpeditionManager.return_to_hub("ui_roguelike_journey_reset")
    ExpeditionManager.reset_to_full_resupply()
    AshlandsCombatBridge.active = false
    await _frames(3)

    await _load_main_scene()
    await _drive_title_and_departure()
    await _enter_first_room()
    await _reach_combat_room()
    await _exercise_capture_and_victory()
    await _extract_back_to_sanctuary()
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _load_main_scene() -> void:
    var error: Error = get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must accept a real SceneTree change")
    _check(await _wait_for_main_scene(), "Main scene must become active")
    await _frames(3)
    _check(_find_button("NOUVELLE PARTIE", true) != null, "Title UI must expose Nouvelle Partie")

func _drive_title_and_departure() -> void:
    _check(await _press_button("NOUVELLE PARTIE", true), "Player must start a new game through the UI")
    _check(GameState.current_screen == "sanctuary", "New Game must open the Sanctuary")
    _check(await _press_button("LA PORTE", false), "La Porte must be usable")
    _check(GameState.current_screen == "expedition", "La Porte must open the expedition screen")
    _check(_find_button("DESCENDRE DANS LE DONJON", true) != null, "Roguelike departure must expose the descent button")
    _check(await _press_button("DESCENDRE DANS LE DONJON", true), "Player must launch the procedural expedition through the UI")
    _check(ExpeditionManager.expedition_active, "Visible launch must activate ExpeditionManager")
    _check(get_tree().current_scene != null and get_tree().current_scene.name == "Main", "Procedural dungeon map must stay in Main UI")

    # Stabilise le seed du smoke après avoir réellement utilisé le bouton de départ.
    var runtime: Variant = ExpeditionManager.roguelike_runtime
    _check(runtime != null, "Roguelike runtime must exist after launch")
    if runtime != null:
        runtime.start_run(424242)
        ExpeditionManager.expedition_seed = 424242
        var scene: Node = get_tree().current_scene
        if scene != null:
            scene.call("show_screen", "expedition")
        await _frames(4)
    _check(_node_tree_contains_text(get_tree().current_scene, "CARTE DU DONJON"), "Procedural map title must be visible")
    _check(_find_button("ENTRÉE", false) != null, "Generated dungeon must expose the entrance room")
    _check(_find_button("EXTRAIRE LE BUTIN", true) != null, "Map must expose voluntary extraction")
    _check(_find_button("ÉTEINDRE 1 LUMIÈRE", true) != null, "Map must expose deliberate light reduction")

func _enter_first_room() -> void:
    _check(await _press_button("ENTRÉE", false), "Player must enter the generated start room through its map node")
    _check(GameState.current_screen == "rewards", "Non-combat entrance must resolve through the room reward screen")
    _check(_find_button("CONTINUER PLUS PROFOND", true) != null, "Room resolution must offer push-your-luck continuation")
    _check(await _press_button("CONTINUER PLUS PROFOND", true), "Player must return from room resolution to the dungeon map")
    _check(GameState.current_screen == "expedition", "Continue must return to the procedural map")

func _reach_combat_room() -> void:
    for _step in range(24):
        if GameState.current_screen == "combat":
            break
        if GameState.current_screen == "rewards":
            var continue_button: Button = _find_button("CONTINUER PLUS PROFOND", true)
            if continue_button == null:
                break
            continue_button.pressed.emit()
            await _frames(4)
            continue
        if GameState.current_screen != "expedition":
            break
        var room_button: Button = _find_unvisited_reachable_room_button()
        _check(room_button != null, "Dungeon map must keep at least one unexplored reachable room")
        if room_button == null:
            break
        room_button.pressed.emit()
        await _frames(5)
    _check(GameState.current_screen == "combat", "Procedural route must eventually enter a combat room")
    if GameState.current_screen == "combat":
        _check(_find_button("FRAPPE", true) != null, "Roguelike combat must reuse tactical combat actions")
        _check(_find_button("CAPTURER", true) != null, "Roguelike combat must expose capture")
        _check(GameState.battle_enemies.size() >= 1, "Combat room must create enemies")

func _exercise_capture_and_victory() -> void:
    if GameState.current_screen != "combat":
        return
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        hero["hp"] = int(hero.get("max_hp", 1))
        hero["fear"] = 0
        hero["madness"] = 0
    for enemy_value in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        enemy["damage"] = [1, 1]
        enemy["fear"] = 0

    var capture_index: int = _capturable_enemy_index()
    _check(capture_index >= 0, "At least one ordinary combat target must satisfy the roguelike capture gate")
    if capture_index >= 0:
        var target: Dictionary = GameState.battle_enemies[capture_index]
        target["max_hp"] = maxi(20, int(target.get("max_hp", target.get("hp", 20))))
        target["hp"] = 1
        GameState.essence = 100
        _check(_prime_capture_success(target), "Smoke must deterministically prime the legacy capture roll after the roguelike gate")
        _check(await _select_enemy(capture_index), "Player must select the wounded capture target")
        _check(await _press_button("CAPTURER", true), "Player must capture through the visible button")
        _check(CreatureManager.captured_creatures.size() == 1, "Successful UI capture must persist in CreatureManager")
        _check(bool(target.get("captured", false)), "Captured target must be marked captured")
        var runtime: Variant = ExpeditionManager.roguelike_runtime
        if runtime != null:
            var active_run: Dictionary = runtime.active_run
            var captures: Dictionary = active_run.get("captures_by_zone", {})
            _check(not captures.is_empty(), "Successful UI capture must be registered in roguelike run state")

    var final_index: int = -1
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        if int(enemy.get("hp", 0)) <= 0:
            continue
        if final_index < 0:
            final_index = index
            enemy["hp"] = 1
            enemy["damage"] = [1, 1]
        else:
            enemy["hp"] = 0
    _check(final_index >= 0, "At least one enemy must remain to validate combat victory")
    if final_index >= 0:
        _check(await _select_enemy(final_index), "Player must select the final enemy")
        _check(await _press_button("FRAPPE", true), "Visible strike must finish the combat")
    _check(GameState.current_screen == "rewards", "Roguelike victory must open the room reward screen")
    _check(_find_button("EXTRAIRE", false) != null, "Room rewards must offer explicit extraction")
    _check(ExpeditionManager.expedition_active, "Run must remain active while rewards are shown")

func _extract_back_to_sanctuary() -> void:
    if GameState.current_screen != "rewards":
        return
    var runtime: Variant = ExpeditionManager.roguelike_runtime
    var history_before := 0
    if runtime != null:
        var history: Array = runtime.run_history
        history_before = history.size()
    _check(await _press_button("EXTRAIRE", false), "Player must secure the run through the extraction button")
    _check(await _wait_for_main_scene(), "Extraction must keep/restore Main scene")
    await _frames(4)
    _check(GameState.current_screen == "sanctuary", "Extraction must return to the Sanctuary")
    _check(not ExpeditionManager.expedition_active, "Extraction must close the active expedition")
    _check(_find_button("LA PORTE", false) != null, "Sanctuary must remain usable after extraction")
    if runtime != null:
        var history_after: Array = runtime.run_history
        _check(history_after.size() == history_before + 1, "Extraction must append a persistent run-history entry")
        if not history_after.is_empty():
            var last_run: Dictionary = history_after[-1]
            _check(bool(last_run.get("success", false)), "Extracted run must be recorded as successful")

func _capturable_enemy_index() -> int:
    var zone_id: String = ""
    var runtime: Variant = ExpeditionManager.roguelike_runtime
    if runtime != null:
        var active_run: Dictionary = runtime.active_run
        zone_id = str(active_run.get("current_room_id", ""))
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        if bool(enemy.get("boss", false)) or bool(enemy.get("is_boss", false)):
            continue
        if CreatureManager.definition_for_battle_enemy(enemy).is_empty():
            continue
        var max_hp: int = maxi(20, int(enemy.get("max_hp", enemy.get("hp", 20))))
        enemy["max_hp"] = max_hp
        enemy["hp"] = 1
        var gate: Dictionary = ExpeditionManager.capture_check(enemy, zone_id)
        if bool(gate.get("allowed", false)):
            return index
    return -1

func _find_unvisited_reachable_room_button() -> Button:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return null
    for node_value in scene.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button == null or button.disabled or not button.is_visible_in_tree():
            continue
        if button.custom_minimum_size != Vector2(142, 56):
            continue
        if button.text.begins_with("✓") or button.text.begins_with("◆"):
            continue
        return button
    return null

func _wait_for_main_scene(max_frames: int = 180) -> bool:
    for _index in range(max_frames):
        var scene: Node = get_tree().current_scene
        if scene != null and scene.name == "Main":
            return true
        await get_tree().process_frame
    return false

func _find_button(fragment: String, exact: bool) -> Button:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return null
    for node_value in scene.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button == null:
            continue
        if exact and button.text == fragment:
            return button
        if not exact and button.text.contains(fragment):
            return button
    return null

func _press_button(fragment: String, exact: bool) -> bool:
    var button: Button = _find_button(fragment, exact)
    if button == null:
        return false
    _check(not button.disabled, "Button must be enabled before press: %s" % fragment)
    _check(button.is_visible_in_tree(), "Button must be visible before press: %s" % fragment)
    if button.disabled or not button.is_visible_in_tree():
        return false
    button.pressed.emit()
    await _frames(5)
    return true

func _select_enemy(index: int) -> bool:
    if index < 0 or index >= GameState.battle_enemies.size():
        return false
    var enemy: Dictionary = GameState.battle_enemies[index]
    var button: Button = _find_enemy_button(str(enemy.get("name", "")))
    if button == null:
        return false
    button.pressed.emit()
    await _frames(3)
    var scene: Node = get_tree().current_scene
    if scene == null:
        return false
    return int(scene.get("selected_enemy")) == index

func _find_enemy_button(enemy_name: String) -> Button:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return null
    for node_value in scene.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button != null and _node_contains_text(button, enemy_name):
            return button
    return null

func _node_tree_contains_text(node: Node, fragment: String) -> bool:
    if node == null:
        return false
    return _node_contains_text(node, fragment)

func _node_contains_text(node: Node, fragment: String) -> bool:
    if node is Label and (node as Label).text.contains(fragment):
        return true
    if node is Button and (node as Button).text.contains(fragment):
        return true
    for child_value in node.get_children():
        var child: Node = child_value as Node
        if child != null and _node_contains_text(child, fragment):
            return true
    return false

func _prime_capture_success(target: Dictionary) -> bool:
    var definition: Dictionary = CreatureManager.definition_for_battle_enemy(target)
    if definition.is_empty():
        return false
    var chance: int = CreatureManager.capture_chance(target)
    var next_attempt: int = CreatureManager.capture_attempt_counter + 1
    var encounter_hash: int = hash(String(definition.get("encounter_id", "")))
    var enemy_id: int = int(target.get("id", 0))
    for candidate in range(1, 5000):
        var rng := RandomNumberGenerator.new()
        rng.seed = candidate ^ (enemy_id * 73856093) ^ encounter_hash ^ (next_attempt * 19349663)
        if rng.randi_range(1, 100) <= chance:
            CreatureManager.capture_seed = candidate
            return true
    return false

func _finish() -> void:
    if failures.is_empty():
        print("UI_PLAYER_JOURNEY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("UI_PLAYER_JOURNEY_SMOKE: " + failure)
    print("UI_PLAYER_JOURNEY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
