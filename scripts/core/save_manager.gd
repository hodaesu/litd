extends Node

const SAVE_PATH := "user://light_in_the_dark_save.json"
const SAVE_VERSION := "0.15"

func save_game() -> bool:
    var payload := {
        "version": SAVE_VERSION,
        "gold": GameState.gold,
        "essence": GameState.essence,
        "light": GameState.light,
        "supplies": GameState.supplies,
        "party": GameState.party,
        "equipment": EquipmentManager.serialize(),
        "expedition_room": GameState.expedition_room,
        "ashlands": AshlandsRuntime.serialize(),
        "expedition": ExpeditionManager.serialize(),
        "ashlands_minibosses": AshlandsMinibossDirector.serialize(),
        "ashlands_combat": AshlandsCombatBridge.serialize()
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload))
    GameState.add_log("Partie sauvegardée.")
    return true

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var payload = JSON.parse_string(file.get_as_text())
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    GameState.gold = int(payload.get("gold", 120))
    GameState.essence = int(payload.get("essence", 18))
    GameState.light = int(payload.get("light", 75))
    GameState.supplies = int(payload.get("supplies", 8))
    GameState.party = payload.get("party", DataLoader.heroes.duplicate(true))
    EquipmentManager.deserialize(payload.get("equipment", {}))
    GameState.expedition_room = int(payload.get("expedition_room", 0))
    AshlandsRuntime.deserialize(payload.get("ashlands", {}))
    ExpeditionManager.deserialize(payload.get("expedition", {}))
    AshlandsMinibossDirector.deserialize(payload.get("ashlands_minibosses", {}))
    AshlandsCombatBridge.deserialize(payload.get("ashlands_combat", {}))
    GameState.add_log("Sauvegarde chargée.")
    return true
