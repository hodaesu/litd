extends Node

const SAVE_PATH := "user://light_in_the_dark_save.json"

func save_game() -> bool:
    var payload := {
        "version": "0.10",
        "gold": GameState.gold,
        "essence": GameState.essence,
        "light": GameState.light,
        "supplies": GameState.supplies,
        "party": GameState.party,
        "expedition_room": GameState.expedition_room
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
    GameState.expedition_room = int(payload.get("expedition_room", 0))
    GameState.add_log("Sauvegarde chargée.")
    return true
