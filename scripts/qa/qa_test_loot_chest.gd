extends Area3D
class_name QATestLootChest

signal chest_opened(item: Dictionary)

var opened := false
var interaction_id := "qa_loot_chest"

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func interact() -> void:
    if opened:
        HUDDirector.notify_interaction("Déjà ouvert", "Coffre d'essai")
        return
    var item := EquipmentManager.grant_random_party_weapon("uncommon", interaction_id)
    if item.is_empty():
        var bundle := EquipmentManager.grant_test_level_bundle(0, "uncommon")
        if not bundle.is_empty():
            item = bundle[0]
    opened = true
    set_meta("opened", true)
    AshlandsRuntime.record_interaction(interaction_id)
    QATestRoomState.mark("chest")
    QATestRoomState.mark("loot", not item.is_empty())
    var item_name := str(item.get("name", "Objet d'essai"))
    HUDDirector.notify_pickup(item_name, 1)
    GameState.add_log("Coffre d'essai ouvert : %s." % item_name)
    chest_opened.emit(item.duplicate(true))

func reset_chest() -> void:
    opened = false
    set_meta("opened", false)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player_party"):
        HUDDirector.notify_interaction("Ouvrir" if not opened else "Déjà ouvert", "Coffre d'essai")
