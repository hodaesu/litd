extends Node

signal report_changed
var current: Dictionary = {}
var history: Array = []

func begin_expedition(dungeon_id: String) -> void:
    current = {
        "id":"run_%d" % Time.get_unix_time_from_system(),
        "dungeon_id":dungeon_id,
        "started_at":Time.get_datetime_string_from_system(),
        "consumables":[],
        "loot":[],
        "injuries_before":_injuries_snapshot(),
        "trait_progress":[],
        "relations":[],
        "deeds":[],
        "enemy_fear_created":0,
        "quest_updates":[],
        "bounty_updates":[],
        "sanctuary_consequences":[],
        "combats":0
    }
    report_changed.emit()

func record_consumable(hero: Dictionary, item: Dictionary) -> void:
    _ensure_current()
    current["consumables"].append({"hero":String(hero.get("name", "")),"item":String(item.get("name", ""))})

func record_loot(item: Dictionary) -> void:
    _ensure_current()
    current["loot"].append(item.duplicate(true))

func record_enemy_fear(amount: int) -> void:
    _ensure_current()
    current["enemy_fear_created"] = int(current.get("enemy_fear_created", 0)) + maxi(0, amount)

func record_update(category: String, text: String) -> void:
    _ensure_current()
    if not current.has(category):
        current[category] = []
    current[category].append(text)

func finish_expedition(success: bool) -> Dictionary:
    _ensure_current()
    current["success"] = success
    current["ended_at"] = Time.get_datetime_string_from_system()
    current["injuries_after"] = _injuries_snapshot()
    current["heroes"] = GameState.party.map(func(hero: Dictionary): return {"id":hero.get("id", ""),"name":hero.get("name", ""),"hp":hero.get("hp", 0),"fear":hero.get("fear", 0),"madness":hero.get("madness", 0)})
    history.push_front(current.duplicate(true))
    if history.size() > 50:
        history.resize(50)
    var result := current.duplicate(true)
    current = {}
    report_changed.emit()
    return result

func latest() -> Dictionary:
    return history[0].duplicate(true) if not history.is_empty() else current.duplicate(true)

func serialize() -> Dictionary:
    return {"current":current.duplicate(true),"history":history.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    current = payload.get("current", {}).duplicate(true)
    history = payload.get("history", []).duplicate(true)
    report_changed.emit()

func reset_new_game() -> void:
    current = {}
    history = []
    report_changed.emit()

func _ensure_current() -> void:
    if current.is_empty():
        begin_expedition("unknown")

func _injuries_snapshot() -> Dictionary:
    var result: Dictionary = {}
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        result[String(hero.get("id", ""))] = hero.get("persistent_injuries", []).duplicate(true)
    return result
