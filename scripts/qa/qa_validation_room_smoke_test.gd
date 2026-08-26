extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    await get_tree().process_frame
    GameState.reset_new_game()
    QATestRoomState.reset_session()
    var packed := load("res://scenes/qa/qa_validation_room.tscn") as PackedScene
    _check(packed != null, "QA validation room must load")
    if packed == null:
        _finish()
        return
    var room := packed.instantiate()
    add_child(room)
    await get_tree().process_frame
    await get_tree().process_frame

    _check(AshlandsRuntime.current_zone_id == "qa_validation_room", "QA room must register its isolated zone")
    _check(AshlandsSceneRouter.has_zone("qa_validation_room"), "QA room must be routable")
    _check(room.find_child("QATestParty", true, false) != null, "QA room must spawn the exploration party")
    var npc := room.find_child("IlyanDialogueTest", true, false)
    var chest := room.find_child("LootChestTest", true, false)
    var encounter := room.find_child("CombatTestTrigger", true, false)
    _check(npc != null and npc.has_method("interact"), "QA room must expose an interactive NPC")
    _check(chest != null and chest.has_method("interact"), "QA room must expose an interactive chest")
    _check(encounter is EncounterTrigger, "QA room must expose a real combat trigger")

    if npc != null:
        npc.interact()
        _check(bool(QATestRoomState.results.get("dialogue", false)), "NPC interaction must validate dialogue")
        QuestGiverPresentation.close_dialogue()
    if chest != null:
        var before := EquipmentManager.items.size()
        chest.interact()
        _check(EquipmentManager.items.size() > before, "Chest must add generated equipment")
        _check(bool(QATestRoomState.results.get("loot", false)), "Chest loot must validate inventory insertion")

    room.call("_inject_psychology")
    room.call("_inject_injury")
    room.call("_test_ash_guidance")
    _check(bool(QATestRoomState.results.get("psychology", false)), "Psychology injection must pass")
    _check(bool(QATestRoomState.results.get("injury", false)), "Persistent injury injection must pass")
    _check(bool(QATestRoomState.results.get("ash_guidance", false)), "Ash guidance request must pass")

    GameState.gold = 777
    _check(SaveManager.save_qa_snapshot(), "QA snapshot must save")
    GameState.gold = 1
    _check(SaveManager.load_qa_snapshot(), "QA snapshot must load")
    _check(GameState.gold == 777, "QA snapshot must restore state")
    SaveManager.delete_qa_snapshot()
    _finish()

func _finish() -> void:
    SaveManager.delete_qa_snapshot()
    if failures.is_empty():
        print("QA_VALIDATION_ROOM_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("QA_VALIDATION_ROOM_SMOKE: " + failure)
    get_tree().quit(1)
