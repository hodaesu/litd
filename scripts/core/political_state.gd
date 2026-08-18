extends Node

signal politics_changed

const DATA_PATH := "res://data/levels/ashlands_politics.json"

var data: Dictionary = {}
var reputation := 0
var trust := 50
var tension := 20
var three_awakenings := {"body": 50, "spirit": 50, "city": 50}
var quest_states: Dictionary = {}
var flags: Dictionary = {}

func _ready() -> void:
    _load_data()
    reset_new_game()

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        data = {}
        return
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    var initial: Dictionary = data.get("sanctuary", {}).get("initial_state", {})
    reputation = int(initial.get("reputation", 0))
    trust = int(initial.get("trust", 50))
    tension = int(initial.get("tension", 20))
    three_awakenings = initial.get("three_awakenings", {"body": 50, "spirit": 50, "city": 50}).duplicate(true)
    quest_states = {}
    flags = {}
    for quest in data.get("quests", []):
        quest_states[String(quest.get("id", ""))] = {"status": "locked", "choice": ""}
    politics_changed.emit()

func get_quest(quest_id: String) -> Dictionary:
    for quest in data.get("quests", []):
        if String(quest.get("id", "")) == quest_id:
            return quest
    return {}

func is_flag_set(flag_name: String) -> bool:
    return bool(flags.get(flag_name, false))

func set_flag(flag_name: String, value := true) -> void:
    flags[flag_name] = value
    politics_changed.emit()

func unlock_quest(quest_id: String) -> bool:
    if not quest_states.has(quest_id):
        return false
    var state: Dictionary = quest_states[quest_id]
    if state.get("status", "locked") == "locked":
        state["status"] = "available"
        quest_states[quest_id] = state
        politics_changed.emit()
    return true

func complete_quest(quest_id: String, choice_id: String) -> bool:
    var quest := get_quest(quest_id)
    if quest.is_empty():
        return false
    var choices: Dictionary = quest.get("choices", {})
    if not choices.has(choice_id):
        return false
    var state: Dictionary = quest_states.get(quest_id, {"status": "locked", "choice": ""})
    if state.get("status") == "completed":
        return false
    var choice: Dictionary = choices[choice_id]
    _apply_effects(choice.get("effects", {}))
    for flag_name in choice.get("flags", []):
        flags[String(flag_name)] = true
    state["status"] = "completed"
    state["choice"] = choice_id
    quest_states[quest_id] = state
    politics_changed.emit()
    return true

func _apply_effects(effects: Dictionary) -> void:
    reputation = clampi(reputation + int(effects.get("reputation", 0)), -100, 100)
    trust = clampi(trust + int(effects.get("trust", 0)), 0, 100)
    tension = clampi(tension + int(effects.get("tension", 0)), 0, 100)
    var awakening_effects: Dictionary = effects.get("three_awakenings", {})
    for key in ["body", "spirit", "city"]:
        three_awakenings[key] = clampi(int(three_awakenings.get(key, 50)) + int(awakening_effects.get(key, 0)), 0, 100)
    if effects.has("supplies"):
        GameState.supplies = maxi(0, GameState.supplies + int(effects.get("supplies", 0)))

func price_modifier() -> float:
    return clampf(1.15 - float(trust) * 0.003 + float(tension) * 0.002, 0.80, 1.35)

func service_unlocked(service_id: String) -> bool:
    var thresholds: Dictionary = data.get("persistent_rules", {}).get("service_thresholds", {}).get(service_id, {})
    if thresholds.is_empty():
        return false
    if trust < int(thresholds.get("trust_min", 0)):
        return false
    if int(three_awakenings.get("body", 0)) < int(thresholds.get("body_min", 0)):
        return false
    if int(three_awakenings.get("spirit", 0)) < int(thresholds.get("spirit_min", 0)):
        return false
    if int(three_awakenings.get("city", 0)) < int(thresholds.get("city_min", 0)):
        return false
    return true

func get_npc_dialogue(npc_id: String, context := "default") -> String:
    for npc in data.get("npcs", []):
        if String(npc.get("id", "")) != npc_id:
            continue
        var dialogues: Dictionary = npc.get("dialogues", {})
        if context == "high_tension" and tension >= 60 and dialogues.has("high_tension"):
            return String(dialogues["high_tension"])
        if context == "low_trust" and trust <= 30 and dialogues.has("low_trust"):
            return String(dialogues["low_trust"])
        if context == "creature_recruited" and CreatureManager.serialize().get("sanctuary_creatures", []).size() > 0 and dialogues.has("creature_recruited"):
            return String(dialogues["creature_recruited"])
        if dialogues.has(context):
            return String(dialogues[context])
        return String(dialogues.get("default", ""))
    return ""

func serialize() -> Dictionary:
    return {
        "reputation": reputation,
        "trust": trust,
        "tension": tension,
        "three_awakenings": three_awakenings.duplicate(true),
        "quest_states": quest_states.duplicate(true),
        "flags": flags.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    reputation = clampi(int(payload.get("reputation", 0)), -100, 100)
    trust = clampi(int(payload.get("trust", 50)), 0, 100)
    tension = clampi(int(payload.get("tension", 20)), 0, 100)
    three_awakenings = payload.get("three_awakenings", {"body": 50, "spirit": 50, "city": 50}).duplicate(true)
    for key in ["body", "spirit", "city"]:
        three_awakenings[key] = clampi(int(three_awakenings.get(key, 50)), 0, 100)
    quest_states = payload.get("quest_states", {}).duplicate(true)
    flags = payload.get("flags", {}).duplicate(true)
    politics_changed.emit()
