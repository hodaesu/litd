extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"
const ENCOUNTER_TRIGGER_SCRIPT := preload("res://scripts/world/encounter_trigger.gd")

var failures: Array[String] = []
var encounter_id_under_test := ""

func run() -> void:
    seed(1337)
    EndgameState.reset_profile_progress()
    GameState.reset_new_game()
    CampaignState.reset_new_game()
    # This journey exercises the capture UI after the company has learned it.
    if not GameState.party.is_empty():
        (GameState.party[0] as Dictionary)["level"] = 14
    _check(ContentScopeDirector.is_unlocked("capture"), "UI capture must unlock at company rank 4")
    EquipmentManager.reset_new_game(7001)
    CreatureManager.reset_new_game(7002)
    AshlandsRuntime.reset_world_progression()
    ExpeditionManager.return_to_hub("ui_player_journey_reset")
    AshlandsCombatBridge.active = false
    AshlandsCombatBridge.encounter_id = ""
    AshlandsCombatBridge.encounter_type = ""
    await _frames(3)

    await _load_main_scene()
    await _drive_title_and_sanctuary()
    await _launch_real_expedition_from_ui()
    await _enter_combat_from_world_contact()
    await _drive_combat_actions()
    await _finish_combat_and_rewards()
    await _return_to_sanctuary_from_exploration_menu()
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
    _check(await _wait_for_main_scene(), "Main scene must become the active scene")
    await _frames(3)
    _check(_find_button("NOUVELLE PARTIE", true) != null, "Title UI must expose the Nouvelle Partie button")

func _drive_title_and_sanctuary() -> void:
    _check(await _press_button("NOUVELLE PARTIE", true), "Player must be able to start a new game through the title button")
    _check(GameState.current_screen == "sanctuary", "New Game button must open the Sanctuary")
    _check(_find_button("LA PORTE", false) != null, "Sanctuary must expose La Porte")

    _check(await _press_button("LA PORTE", false), "Player must be able to activate La Porte")
    _check(GameState.current_screen == "expedition", "La Porte must open the expedition screen")
    _check(_find_button("LANCER L'EXPÉDITION", true) != null, "Expedition screen must expose the launch button")

func _launch_real_expedition_from_ui() -> void:
    _check(CampaignState.current_chapter_id == "chapter_01_ashlands", "Fresh journey must begin in Chapter I")
    _check(await _press_button("LANCER L'EXPÉDITION", true), "Player must be able to launch the expedition through the UI")
    _check(await _wait_for_zone("zone_01_faubourg_cendreux"), "Launch button must perform a real scene change into the Ashlands")
    _check(ExpeditionManager.expedition_active, "Real UI launch must activate the expedition runtime")
    _check(AshlandsRuntime.current_zone_id == "zone_01_faubourg_cendreux", "Real UI launch must enter the first Ashlands zone")
    _check(get_tree().current_scene != null and get_tree().current_scene.name != "Main", "Exploration must no longer be the Main UI scene")
    await _frames(5)
    _check(not get_tree().get_nodes_in_group("player_party").is_empty(), "Exploration scene must contain the player party")

func _enter_combat_from_world_contact() -> void:
    var scene: Node = get_tree().current_scene
    _check(scene != null, "Exploration scene missing before encounter")
    if scene == null:
        return

    var trigger: Node = _find_normal_encounter_trigger(scene)
    _check(trigger != null, "Ashlands scene must expose at least one normal EncounterTrigger")
    var parties: Array[Node] = get_tree().get_nodes_in_group("player_party")
    _check(not parties.is_empty(), "Player party missing before encounter contact")
    if trigger == null or parties.is_empty():
        return

    encounter_id_under_test = str(trigger.get("encounter_id"))
    _check(encounter_id_under_test != "", "Encounter trigger must have a stable encounter id")
    trigger.emit_signal("body_entered", parties[0])
    _check(await _wait_for_combat_main(), "World contact must route into the real combat UI")
    await _frames(4)
    _check(AshlandsCombatBridge.active, "Combat entered from exploration must be owned by AshlandsCombatBridge")
    _check(AshlandsCombatBridge.encounter_id == encounter_id_under_test, "Combat bridge must preserve the world encounter id")
    _check(GameState.battle_enemies.size() == 3, "Normal world encounter must create three combat enemies")
    _check(_find_button("FRAPPE", true) != null, "Combat UI must expose FRAPPE")
    _check(_find_button("GARDE", true) != null, "Combat UI must expose GARDE")
    _check(_find_button("SOIN", true) != null, "Combat UI must expose SOIN")
    _check(_find_button("CAPTURER", true) != null, "Combat UI must expose CAPTURER")

func _drive_combat_actions() -> void:
    if GameState.party.size() < 4 or GameState.battle_enemies.size() < 3:
        _check(false, "UI combat journey requires four heroes and three enemies")
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

    # Ordre réel du round : Aurélien, Malvor, Lysandra, Darius.
    # Chaque action respecte la formation tactique canonique.
    var attack_target: Dictionary = GameState.battle_enemies[0]
    attack_target["hp"] = int(attack_target.get("max_hp", attack_target.get("hp", 1)))
    var attack_before: int = int(attack_target.get("hp", 0))
    _check(await _select_enemy(0), "Player must be able to select an enemy through its combat card")
    _check(await _press_button("FRAPPE", true), "Aurélien must be able to use FRAPPE from his tactical rank")
    _check(int(attack_target.get("hp", 0)) < attack_before, "Aurélien's FRAPPE must damage the selected enemy")

    _check(await _press_button("GARDE", true), "Malvor must be able to use the real GARDE button")
    _check(_log_contains("se met en garde"), "GARDE button must execute the guard action")

    var wounded: Dictionary = GameState.party[3]
    wounded["hp"] = maxi(1, int(wounded.get("max_hp", 1)) - 20)
    var wounded_before: int = int(wounded.get("hp", 0))
    _check(await _press_button("SOIN", true), "Lysandra must be able to use the real SOIN button")
    _check(int(wounded.get("hp", 0)) > wounded_before, "Lysandra's SOIN must actually restore HP")

    attack_target["max_hp"] = maxi(10, int(attack_target.get("max_hp", 10)))
    attack_target["hp"] = 1
    GameState.essence = 100
    _check(_prime_capture_success(attack_target), "Smoke test must be able to deterministically prime one successful capture roll")
    _check(await _select_enemy(0), "Player must be able to reselect the weakened capture target")
    _check(await _press_button("CAPTURER", true), "Darius must be able to use the real CAPTURER button")
    _check(CreatureManager.captured_creatures.size() == 1, "UI capture must add one creature to the roster")
    _check(bool(attack_target.get("captured", false)), "UI capture must mark the selected enemy as captured")
    _check(GameState.current_screen == "combat", "Successful partial capture must keep combat active while enemies remain")

func _finish_combat_and_rewards() -> void:
    # Le round suivant recommence avec Aurélien. Il élimine d'abord l'ennemi arrière
    # (rang 3), puis Malvor termine l'ennemi de rang 2 : deux frappes légales même
    # si aucune compaction de formation n'a encore eu lieu.
    var rear_index: int = _last_living_enemy_index()
    _check(rear_index >= 0, "A rear enemy must remain after the capture")
    if rear_index >= 0:
        var rear_enemy: Dictionary = GameState.battle_enemies[rear_index]
        rear_enemy["hp"] = 1
        rear_enemy["damage"] = [1, 1]
        rear_enemy["fear"] = 0
        _check(await _select_enemy(rear_index), "Aurélien must be able to select the rear remaining enemy")
        _check(await _press_button("FRAPPE", true), "Aurélien must be able to finish the rear enemy with FRAPPE")

    var front_index: int = _first_living_enemy_index()
    _check(front_index >= 0, "A front enemy must remain for Malvor")
    if front_index >= 0:
        var front_enemy: Dictionary = GameState.battle_enemies[front_index]
        front_enemy["hp"] = 1
        front_enemy["damage"] = [1, 1]
        front_enemy["fear"] = 0
        _check(await _select_enemy(front_index), "Malvor must be able to select the final front enemy")
        _check(await _press_button("FRAPPE", true), "Malvor must be able to finish the final enemy with FRAPPE")

    _check(GameState.alive_enemies().is_empty(), "UI combat journey must reach a real victory state")
    _check(GameState.current_screen == "rewards", "Victory must remain on the rewards screen until the player continues")
    _check(get_tree().current_scene != null and get_tree().current_scene.name == "Main", "Rewards must remain in the Main UI scene")
    _check(AshlandsCombatBridge.active, "Campaign combat must stay active while rewards are displayed")
    _check(_find_button("RETOUR À L'EXPLORATION", true) != null, "Campaign rewards must expose an explicit return-to-exploration button")

    _check(await _press_button("RETOUR À L'EXPLORATION", true), "Player must be able to leave rewards explicitly")
    _check(await _wait_for_zone("zone_01_faubourg_cendreux"), "Reward continuation must return to the real exploration scene")
    _check(not AshlandsCombatBridge.active, "Combat bridge must close after the reward continuation")
    _check(AshlandsRuntime.is_encounter_cleared(encounter_id_under_test), "Won encounter must remain cleared after returning to exploration")
    await _frames(4)

func _return_to_sanctuary_from_exploration_menu() -> void:
    var back_event := InputEventAction.new()
    back_event.action = "back"
    back_event.pressed = true
    Input.parse_input_event(back_event)
    await _frames(3)

    var return_button: Button = _find_button("RETOUR AU SANCTUAIRE", true)
    _check(return_button != null, "Back action must reveal the contextual expedition menu")
    if return_button == null:
        return
    _check(await _press_button("RETOUR AU SANCTUAIRE", true), "Player must be able to return to the Sanctuary from the contextual expedition menu")
    _check(await _wait_for_main_scene(), "Return to Sanctuary must perform a real scene change back to Main")
    await _frames(4)
    _check(GameState.current_screen == "sanctuary", "Return button must restore the Sanctuary screen")
    _check(not ExpeditionManager.expedition_active, "Returning to Sanctuary must close the expedition")
    _check(_find_button("LA PORTE", false) != null, "Sanctuary must be usable again after the full journey")
    _check(CreatureManager.captured_creatures.size() == 1, "Creature captured through combat UI must persist after returning to Sanctuary")

func _wait_for_main_scene(max_frames: int = 180) -> bool:
    for _index in range(max_frames):
        var scene: Node = get_tree().current_scene
        if scene != null and scene.name == "Main":
            return true
        await get_tree().process_frame
    return false

func _wait_for_combat_main(max_frames: int = 180) -> bool:
    for _index in range(max_frames):
        var scene: Node = get_tree().current_scene
        if scene != null and scene.name == "Main" and GameState.current_screen == "combat":
            return true
        await get_tree().process_frame
    return false

func _wait_for_zone(zone_id: String, max_frames: int = 240) -> bool:
    for _index in range(max_frames):
        var scene: Node = get_tree().current_scene
        if scene != null and scene.name != "Main" and AshlandsRuntime.current_zone_id == zone_id:
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

func _find_enemy_button(enemy_name: String) -> Button:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return null
    for node_value in scene.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button != null and _node_contains_text(button, enemy_name):
            return button
    return null

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

func _press_button(fragment: String, exact: bool) -> bool:
    var button: Button = _find_button(fragment, exact)
    if button == null:
        return false
    _check(not button.disabled, "Button must be enabled before press: %s" % fragment)
    _check(button.is_visible_in_tree(), "Button must be visible to the player before press: %s" % fragment)
    if button.disabled or not button.is_visible_in_tree():
        return false
    button.pressed.emit()
    await _frames(4)
    return true

func _select_enemy(index: int) -> bool:
    if index < 0 or index >= GameState.battle_enemies.size():
        return false
    var enemy: Dictionary = GameState.battle_enemies[index]
    var button: Button = _find_enemy_button(str(enemy.get("name", "")))
    if button == null:
        return false
    _check(button.is_visible_in_tree(), "Enemy card must be visible before target selection")
    if not button.is_visible_in_tree():
        return false
    button.pressed.emit()
    await _frames(3)
    var scene: Node = get_tree().current_scene
    if scene == null or scene.name != "Main":
        return false
    return int(scene.get("selected_enemy")) == index

func _find_normal_encounter_trigger(root: Node) -> Node:
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back() as Node
        if node == null:
            continue
        if node.get_script() == ENCOUNTER_TRIGGER_SCRIPT:
            if str(node.get("encounter_type")) == "normal" and bool(node.call("can_start")):
                return node
        for child_value in node.get_children():
            var child: Node = child_value as Node
            if child != null:
                stack.append(child)
    return null

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

func _first_living_enemy_index() -> int:
    for index in range(GameState.battle_enemies.size()):
        if int(GameState.battle_enemies[index].get("hp", 0)) > 0:
            return index
    return -1

func _last_living_enemy_index() -> int:
    for index in range(GameState.battle_enemies.size() - 1, -1, -1):
        if int(GameState.battle_enemies[index].get("hp", 0)) > 0:
            return index
    return -1

func _log_contains(fragment: String) -> bool:
    var needle: String = fragment.to_lower()
    for line_value in GameState.log_lines:
        if str(line_value).to_lower().contains(needle):
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
