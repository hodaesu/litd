extends Node

const REPORT_PATH := "res://reports/player-bot-v10-sanctuary-ui-smoke.json"
const SCREENS: Array[String] = ["sanctuary", "company", "market", "tavern", "inventory_equipment", "skills"]

var failures: Array[String] = []
var visited: Array[String] = []
var controller: Control

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(10110)
    CreatureManager.reset_new_game(10120)

    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        failures.append("main_scene_missing")
        _finish()
        return
    controller = packed.instantiate() as Control
    if controller == null:
        failures.append("main_scene_instantiate")
        _finish()
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    for screen_name in SCREENS:
        controller.show_screen(screen_name)
        await get_tree().process_frame
        visited.append(screen_name)
        if not is_instance_valid(controller):
            failures.append("controller_lost_%s" % screen_name)
            break
        if not is_instance_valid(controller.content):
            failures.append("content_missing_%s" % screen_name)
            break
        if controller.content.get_child_count() <= 0:
            failures.append("empty_screen_%s" % screen_name)

    _finish()

func _finish() -> void:
    var report := {
        "schema_version":10,
        "suite":"player_bot_v10_sanctuary_ui_smoke",
        "requested_screens":SCREENS,
        "visited":visited,
        "failures":failures,
        "status":"passed" if failures.is_empty() else "failed"
    }
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  "))
        file.store_line("")
        file.close()
    if failures.is_empty():
        print("PLAYER_BOT_V10_OK screens=%d" % visited.size())
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("PLAYER_BOT_V10: " + failure)
        get_tree().quit(1)
