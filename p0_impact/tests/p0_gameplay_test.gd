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

func _free_game(game) -> void:
    game.queue_free()
    await process_frame

func _wait_for_player_turn(game, label: String) -> void:
    var elapsed := 0.0
    var timeout := 3.0
    while (not game.player_turn or game.busy) and elapsed < timeout:
        await create_timer(0.02).timeout
        elapsed += 0.02
    _assert_true(game.player_turn and not game.busy, label)

func _run() -> void:
    print("=== P0 GAMEPLAY + REGRESSION TESTS ===")

    # Baseline setup and canonical wall-collision sequence.
    var game = await _new_game()
    _assert_eq(game.sahen_cell, Vector2i(2, 2), "initial Sahen cell")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "initial Rampant cell")
    _assert_eq(game.wall_cell, Vector2i(5, 2), "wall cell")
    _assert_eq(game.rampant_vit, 46, "initial Rampant VIT")
    _assert_eq(game.rampant_post, 38, "initial Rampant POST")
    _assert_true(game.player_turn, "initial player turn")

    await game._try_shoulder_bash()
    await _wait_for_player_turn(game, "player turn restored after shoulder #1")
    _assert_eq(game.rampant_vit, 28, "shoulder #1 total VIT after collision")
    _assert_eq(game.rampant_post, 10, "shoulder #1 POST after enemy-turn recovery")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "enemy returns adjacent after shoulder #1")
    _assert_true(not game.rampant_downed, "shoulder #1 does not down Rampant")

    await game._try_shoulder_bash()
    await _wait_for_player_turn(game, "player turn restored with enemy down")
    _assert_eq(game.rampant_vit, 10, "shoulder #2 total VIT")
    _assert_eq(game.rampant_post, 0, "shoulder #2 breaks POST")
    _assert_eq(game.rampant_cell, Vector2i(4, 2), "downed Rampant stays at collision cell")
    _assert_true(game.rampant_downed, "shoulder #2 downs Rampant")
    await _free_game(game)

    # Basic attack + retaliation + posture recovery cap.
    game = await _new_game()
    await game._try_basic_attack()
    await _wait_for_player_turn(game, "player turn restored after basic attack")
    _assert_eq(game.rampant_vit, 32, "basic attack Rampant VIT")
    _assert_eq(game.rampant_post, 32, "basic attack Rampant POST after recovery")
    _assert_eq(game.sahen_vit, 111, "enemy retaliation Sahen VIT")
    _assert_eq(game.sahen_post, 65, "Sahen POST recovers to cap after retaliation")
    _assert_true(not game.rampant_downed, "basic attack does not down Rampant")
    await _free_game(game)

    # Valid movement + minimal enemy chase.
    game = await _new_game()
    await game._try_move(Vector2i(1, 2))
    await _wait_for_player_turn(game, "turn returns after movement/enemy turn")
    _assert_eq(game.sahen_cell, Vector2i(1, 2), "Sahen moves one tile")
    _assert_eq(game.rampant_cell, Vector2i(2, 2), "Rampant advances toward Sahen")
    await _free_game(game)

    # Push 2 with no obstacle: no collision damage should be added.
    game = await _new_game()
    game.wall_cell = Vector2i(0, 0)
    game.sahen_cell = Vector2i(1, 2)
    game.rampant_cell = Vector2i(2, 2)
    game._refresh_visuals()
    await game._try_shoulder_bash()
    await _wait_for_player_turn(game, "turn returns after free Push 2")
    _assert_eq(game.rampant_vit, 34, "free Push 2 only applies shoulder VIT")
    _assert_eq(game.rampant_post, 22, "free Push 2 POST after recovery")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "enemy advances after free Push 2")
    _assert_true(not game.rampant_downed, "free Push 2 does not down Rampant")
    await _free_game(game)

    # Grid edge behaves as a solid boundary for unfulfilled Push.
    game = await _new_game()
    game.wall_cell = Vector2i(0, 0)
    game.sahen_cell = Vector2i(3, 2)
    game.rampant_cell = Vector2i(4, 2)
    game._refresh_visuals()
    await game._try_shoulder_bash()
    await _wait_for_player_turn(game, "turn returns after edge collision")
    _assert_eq(game.rampant_vit, 28, "edge collision adds one collision VIT step")
    _assert_eq(game.rampant_post, 10, "edge collision POST after recovery")
    _assert_eq(game.rampant_cell, Vector2i(4, 2), "enemy returns one tile after edge collision")
    _assert_true(not game.rampant_downed, "single edge collision does not down Rampant")
    await _free_game(game)

    # Shoulder bash must do nothing when target is not adjacent.
    game = await _new_game()
    game.sahen_cell = Vector2i(0, 0)
    game.rampant_cell = Vector2i(3, 2)
    game._refresh_visuals()
    var far_vit = game.rampant_vit
    var far_post = game.rampant_post
    game._try_shoulder_bash()
    await process_frame
    _assert_eq(game.rampant_vit, far_vit, "non-adjacent shoulder leaves VIT unchanged")
    _assert_eq(game.rampant_post, far_post, "non-adjacent shoulder leaves POST unchanged")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "non-adjacent shoulder leaves position unchanged")
    _assert_true(game.player_turn, "invalid shoulder does not consume turn")
    await _free_game(game)

    # Shoulder bash must not hit an already downed target.
    game = await _new_game()
    game.rampant_downed = true
    game.rampant_vit = 10
    game.rampant_post = 0
    game._refresh_visuals()
    game._try_shoulder_bash()
    await process_frame
    _assert_eq(game.rampant_vit, 10, "downed target VIT unchanged by shoulder")
    _assert_eq(game.rampant_post, 0, "downed target POST unchanged by shoulder")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "downed target position unchanged by shoulder")
    _assert_true(game.player_turn, "invalid downed-target shoulder does not consume turn")
    await _free_game(game)

    # Movement validation: distance and occupancy.
    game = await _new_game()
    game._try_move(Vector2i(0, 0))
    await process_frame
    _assert_eq(game.sahen_cell, Vector2i(2, 2), "long move rejected")
    _assert_true(game.player_turn, "long move does not consume turn")

    game._try_move(Vector2i(3, 2))
    await process_frame
    _assert_eq(game.sahen_cell, Vector2i(2, 2), "occupied move rejected")
    _assert_true(game.player_turn, "occupied move does not consume turn")
    await _free_game(game)

    # No player movement should execute outside the player's turn.
    game = await _new_game()
    game.player_turn = false
    game._try_move(Vector2i(1, 2))
    await process_frame
    _assert_eq(game.sahen_cell, Vector2i(2, 2), "movement blocked outside player turn")
    await _free_game(game)

    # Pure posture recovery is capped at maximum.
    game = await _new_game()
    game.sahen_post = 64
    game.rampant_downed = true
    await game._end_player_turn()
    _assert_eq(game.sahen_post, 65, "posture recovery caps at max")
    _assert_true(game.player_turn, "turn restored after recovery-only enemy phase")
    await _free_game(game)

    # Reset restores every canonical P0 combat value.
    game = await _new_game()
    game.sahen_cell = Vector2i(0, 0)
    game.rampant_cell = Vector2i(4, 4)
    game.sahen_vit = 1
    game.sahen_post = 1
    game.rampant_vit = 1
    game.rampant_post = 0
    game.rampant_downed = true
    game.player_turn = false
    game.mode = "attack"
    game._reset_combat()
    await process_frame
    _assert_eq(game.sahen_cell, Vector2i(2, 2), "reset Sahen cell")
    _assert_eq(game.rampant_cell, Vector2i(3, 2), "reset Rampant cell")
    _assert_eq(game.sahen_vit, 120, "reset Sahen VIT")
    _assert_eq(game.sahen_post, 65, "reset Sahen POST")
    _assert_eq(game.rampant_vit, 46, "reset Rampant VIT")
    _assert_eq(game.rampant_post, 38, "reset Rampant POST")
    _assert_true(not game.rampant_downed, "reset clears downed")
    _assert_true(game.player_turn, "reset restores player turn")
    _assert_eq(game.mode, "shoulder", "reset restores shoulder mode")
    await _free_game(game)

    if failures.is_empty():
        print("=== P0 GAMEPLAY + REGRESSION TESTS: PASS ===")
        quit(0)
    else:
        print("=== P0 GAMEPLAY + REGRESSION TESTS: %d FAILURE(S) ===" % failures.size())
        for failure in failures:
            print(" - %s" % failure)
        quit(1)
