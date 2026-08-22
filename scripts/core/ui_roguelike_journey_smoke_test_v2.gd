extends "res://scripts/core/ui_roguelike_journey_smoke_test.gd"

# v2 : une salle "créature" peut ne contenir qu'une cible. Si cette cible est
# capturée, le combat est légitimement terminé et doit ouvrir les récompenses.

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

    if GameState.alive_enemies().is_empty():
        _check(GameState.current_screen == "rewards", "Capturing the final creature must resolve the combat room")
    else:
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
        _check(final_index >= 0, "At least one enemy must remain when capture does not finish the room")
        if final_index >= 0:
            # Le smoke place explicitement la cible finale en E1 : il vérifie ainsi
            # la nouvelle Frappe de mêlée dans une configuration tactiquement valide.
            var final_target: Dictionary = GameState.battle_enemies[final_index]
            var final_uid: String = str(final_target.get("combat_uid", ""))
            final_target["combat_position"] = 0
            var parked_rank: int = 1
            for index in range(GameState.battle_enemies.size()):
                if index == final_index:
                    continue
                var parked: Dictionary = GameState.battle_enemies[index]
                parked["combat_position"] = mini(3, parked_rank)
                parked_rank += 1

            # main_v32 trie le tableau selon E1–E4 lors du rendu. On reconstruit donc
            # le HUD puis on retrouve la même cible via son UID avant de cliquer.
            var scene: Node = get_tree().current_scene
            if scene != null:
                scene.call("show_screen", "combat")
                await _frames(4)
            final_index = -1
            for index in range(GameState.battle_enemies.size()):
                var candidate: Dictionary = GameState.battle_enemies[index]
                if str(candidate.get("combat_uid", "")) == final_uid:
                    final_index = index
                    break
            _check(final_index >= 0, "Repositioned final target must survive tactical HUD sorting")
            if final_index >= 0:
                _check(await _select_enemy(final_index), "Player must select the final enemy")
                _check(await _press_button("1 · Frappe", false), "Visible equipped strike must finish the combat")

    _check(GameState.current_screen == "rewards", "Roguelike victory must open the room reward screen")
    _check(_find_button("EXTRAIRE", false) != null, "Room rewards must offer explicit extraction")
    _check(ExpeditionManager.expedition_active, "Run must remain active while rewards are shown")
