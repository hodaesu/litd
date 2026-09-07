extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert_eq(actual, expected, label: String) -> void:
    if actual != expected:
        failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
        push_error("FAIL %s" % failures[-1])
    else:
        print("PASS %s => %s" % [label, str(actual)])

func _assert_true(value: bool, label: String) -> void:
    if not value:
        failures.append("%s: expected true" % label)
        push_error("FAIL %s" % failures[-1])
    else:
        print("PASS %s" % label)

func _new_game():
    var scene := load("res://scenes/CombatTest.tscn")
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    return game

func _run() -> void:
    print("=== P0 GAMEPLAY TESTS ===")

    var game = await _new_game()
    _assert_eq(game.sahen_cell, Vector2i(2, 2), "initial Sahen cell")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "initial Rampant cell")
    _assert_eq(game.wall_cell, Vector2i(5, 2), "wall cell")
    _assert_eq(game.rampant_vit, 46, "initial Rampant VIT")
    _assert_eq(game.rampant_post, 38, "initial Rampant POST")
    _assert_true(game.player_turn, "initial player turn")

    # First shoulder bash: one free push tile, then wall collision.
    await game._try_shoulder_bash()
    _assert_eq(game.rampant_vit, 28, "shoulder #1 total VIT after collision")
    _assert_eq(game.rampant_post, 10, "shoulder #1 POST after enemy turn recovery")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "enemy returns adjacent after shoulder #1")
    _assert_true(not game.rampant_downed, "shoulder #1 does not down Rampant")
    _assert_true(game.player_turn, "player turn restored after enemy turn")

    # Second shoulder bash repeats the collision and must break posture.
    await game._try_shoulder_bash()
    _assert_eq(game.rampant_vit, 10, "shoulder #2 total VIT")
    _assert_eq(game.rampant_post, 0, "shoulder #2 breaks POST")
    _assert_eq(game.rampant_cell, Vector2i(4, 2), "downed Rampant stays at collision cell")
    _assert_true(game.rampant_downed, "shoulder #2 downs Rampant")
    _assert_true(game.player_turn, "player turn restored with enemy down")

    game.queue_free()
    await process_frame

    # Basic attack scenario.
    game = await _new_game()
    await game._try_basic_attack()
    _assert_eq(game.rampant_vit, 32, "basic attack Rampant VIT")
    _assert_eq(game.rampant_post, 32, "basic attack Rampant POST after recovery")
    _assert_eq(game.sahen_vit, 111, "enemy retaliation Sahen VIT")
    _assert_eq(game.sahen_post, 65, "Sahen POST recovers to cap after retaliation")
    _assert_true(not game.rampant_downed, "basic attack does not down Rampant")

    game.queue_free()
    await process_frame

    # Movement scenario.
    game = await _new_game()
    await game._try_move(Vector2i(1, 2))
    _assert_eq(game.sahen_cell, Vector2i(1, 2), "Sahen moves one tile")
    _assert_eq(game.rampant_cell, Vector2i(2, 2), "Rampant advances toward Sahen")
    _assert_true(game.player_turn, "turn returns after movement/enemy turn")

    game.queue_free()
    await process_frame

    if failures.is_empty():
        print("=== P0 GAMEPLAY TESTS: PASS ===")
        quit(0)
    else:
        print("=== P0 GAMEPLAY TESTS: %d FAILURE(S) ===" % failures.size())
        for failure in failures:
            print(" - %s" % failure)
        quit(1)
