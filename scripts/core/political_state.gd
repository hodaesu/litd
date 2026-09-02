extends Node

signal politics_changed

const DATA_PATH := "res://data/levels/ashlands_politics.json"
const SOCIAL_PATH := "res://data/levels/ashlands_social_politics.json"

var data: Dictionary = {}
var social_data: Dictionary = {}
var reputation := 0
var trust := 50
var tension := 20
var three_awakenings := {"body": 50, "spirit": 50, "city": 50}
var quest_states: Dictionary = {}
var flags: Dictionary = {}
var seen_events: Array[String] = []
var world_memory_tags: Array[String] = []

func _ready() -> void:
    _load_data()
    reset_new_game()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _load_data() -> void:
    data = _load_json(DATA_PATH)
    social_data = _load_json(SOCIAL_PATH)

func reset_new_game() -> void:
    var initial: Dictionary = data.get("sanctuary", {}).get("initial_state", {})
    reputation = int(initial.get("reputation", 0))
    trust = int(initial.get("trust", 50))
    tension = int(initial.get("tension", 20))
    three_awakenings = initial.get("three_awakenings", {"body": 50, "spirit": 50, "city": 50}).duplicate(true)
    quest_states = {}
    flags = {}
    seen_events = []
    world_memory_tags = []
    for quest in data.get("quests", []):
        quest_states[String(quest.get("id", ""))] = {"status": "locked", "choice": ""}
    politics_changed.emit()

func get_quest(quest_id: String) -> Dictionary:
    for quest in data.get("quests", []):
        if String(quest.get("id", "")) == quest_id:
            return quest
    return {}

func get_npc(npc_id: String) -> Dictionary:
    for npc in data.get("npcs", []):
        if String(npc.get("id", "")) == npc_id:
            return npc
    return {}

func quest_status(quest_id: String) -> String:
    return String(quest_states.get(quest_id, {}).get("status", "locked"))

func quest_choice(quest_id: String) -> String:
    return String(quest_states.get(quest_id, {}).get("choice", ""))

func completed_quest(quest_id: String) -> bool:
    return quest_status(quest_id) == "completed"

func is_flag_set(flag_name: String) -> bool:
    return bool(flags.get(flag_name, false))

func set_flag(flag_name: String, value := true) -> void:
    flags[flag_name] = value
    _rebuild_world_memory()
    refresh_unlocks()
    politics_changed.emit()

func _trigger_satisfied(trigger: Dictionary) -> bool:
    if int(GameState.expedition_room) < int(trigger.get("expedition_room_min", 0)):
        return false
    var required_quest: String = String(trigger.get("quest_completed", ""))
    if required_quest != "" and not completed_quest(required_quest):
        return false
    if CreatureManager.captured_creatures.size() < int(trigger.get("recruited_creature_min", 0)):
        return false
    var required_flag: String = String(trigger.get("flag", ""))
    if required_flag != "" and not is_flag_set(required_flag):
        return false
    return true

func refresh_unlocks() -> void:
    var changed := false
    for quest_value in data.get("quests", []):
        var quest: Dictionary = quest_value
        var quest_id: String = String(quest.get("id", ""))
        if quest_id == "" or completed_quest(quest_id):
            continue
        var state: Dictionary = quest_states.get(quest_id, {"status": "locked", "choice": ""})
        if String(state.get("status", "locked")) == "locked" and _trigger_satisfied(quest.get("trigger", {})):
            state["status"] = "available"
            quest_states[quest_id] = state
            changed = true
    if changed:
        politics_changed.emit()

func available_quests() -> Array:
    refresh_unlocks()
    var result: Array = []
    for quest_value in data.get("quests", []):
        var quest: Dictionary = quest_value
        if quest_status(String(quest.get("id", ""))) == "available":
            result.append(quest)
    return result

func completed_quests() -> Array:
    var result: Array = []
    for quest_value in data.get("quests", []):
        var quest: Dictionary = quest_value
        if completed_quest(String(quest.get("id", ""))):
            result.append(quest)
    return result

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
    refresh_unlocks()
    var state: Dictionary = quest_states.get(quest_id, {"status": "locked", "choice": ""})
    if String(state.get("status", "locked")) != "available":
        return false
    var choices: Dictionary = quest.get("choices", {})
    if not choices.has(choice_id):
        return false
    var choice: Dictionary = choices[choice_id]
    _apply_effects(choice.get("effects", {}))
    for flag_name in choice.get("flags", []):
        flags[String(flag_name)] = true
    state["status"] = "completed"
    state["choice"] = choice_id
    quest_states[quest_id] = state
    _rebuild_world_memory()
    GameState.add_log("Décision de Concorde : %s" % String(choice.get("label", choice_id)))
    refresh_unlocks()
    politics_changed.emit()
    return true

func choice_consequence(quest_id: String, choice_id: String) -> String:
    var quest: Dictionary = get_quest(quest_id)
    return String(quest.get("choices", {}).get(choice_id, {}).get("consequence", ""))

func completed_consequence(quest_id: String) -> String:
    return choice_consequence(quest_id, quest_choice(quest_id))

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
    var base := clampf(1.15 - float(trust) * 0.003 + float(tension) * 0.002, 0.80, 1.35)
    return clampf(base * SystemicCrossRuntime.market_price_modifier(), 0.80, 1.35)

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

func dialogue_context_for(npc_id: String) -> String:
    if tension >= 60:
        return "high_tension"
    if trust <= 30:
        return "low_trust"
    if CreatureManager.captured_creatures.size() > 0 and (is_flag_set("creature_sanctuary_trial") or is_flag_set("creature_healed_released")):
        return "creature_recruited"
    if is_flag_set("refugees_welcomed"):
        return "refugees_welcomed"
    if is_flag_set("refugees_refused") and npc_id == "meira_saan":
        return "xenophobia_rising"
    return "default"

func get_npc_dialogue(npc_id: String, context := "auto") -> String:
    var npc: Dictionary = get_npc(npc_id)
    if npc.is_empty():
        return ""
    var dialogues: Dictionary = npc.get("dialogues", {})
    var resolved_context: String = dialogue_context_for(npc_id) if context == "auto" else context
    if dialogues.has(resolved_context):
        return String(dialogues[resolved_context])
    return String(dialogues.get("default", ""))

func _conversation_satisfied(entry: Dictionary) -> bool:
    if int(GameState.expedition_room) < int(entry.get("after_expedition", 0)):
        return false
    if bool(entry.get("requires_creature", false)) and CreatureManager.captured_creatures.is_empty():
        return false
    if GameState.supplies > int(entry.get("supplies_max", 9999)):
        return false
    if tension < int(entry.get("tension_min", 0)):
        return false
    var required_flag := String(entry.get("requires_flag", ""))
    if required_flag != "" and not is_flag_set(required_flag):
        return false
    var any_flags: Array = entry.get("requires_any_flag", [])
    if not any_flags.is_empty():
        var found := false
        for flag_name in any_flags:
            if is_flag_set(String(flag_name)):
                found = true
                break
        if not found:
            return false
    return true

func conversation_for(npc_id: String) -> Dictionary:
    var best: Dictionary = {}
    for entry_value in social_data.get("conversations", {}).get(npc_id, []):
        var entry: Dictionary = entry_value
        if _conversation_satisfied(entry):
            best = entry
    return best

func relationship_for(a: String, b: String) -> Dictionary:
    for relation_value in social_data.get("relationships", []):
        var relation: Dictionary = relation_value
        if (String(relation.get("a", "")) == a and String(relation.get("b", "")) == b) or (String(relation.get("a", "")) == b and String(relation.get("b", "")) == a):
            return relation
    return {}

func social_factions() -> Array:
    return social_data.get("social_factions", [])

func _event_conditions_satisfied(conditions: Dictionary) -> bool:
    if GameState.supplies > int(conditions.get("supplies_max", 9999)):
        return false
    if tension < int(conditions.get("tension_min", 0)):
        return false
    if trust > int(conditions.get("trust_max", 9999)):
        return false
    if int(GameState.expedition_room) < int(conditions.get("expedition_room_min", 0)):
        return false
    if bool(conditions.get("requires_creature", false)) and CreatureManager.captured_creatures.is_empty():
        return false
    var required_flag := String(conditions.get("requires_flag", ""))
    if required_flag != "" and not is_flag_set(required_flag):
        return false
    return true

func available_social_events() -> Array:
    var result: Array = []
    for event_value in social_data.get("dynamic_events", []):
        var event: Dictionary = event_value
        var event_id := String(event.get("id", ""))
        if seen_events.has(event_id):
            continue
        if _event_conditions_satisfied(event.get("conditions", {})):
            result.append(event)
    result.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("priority", 0)) > int(right.get("priority", 0)))
    return result

func trigger_next_social_event() -> Dictionary:
    var events := available_social_events()
    if events.is_empty():
        return {}
    var event: Dictionary = events[0]
    var event_id := String(event.get("id", ""))
    seen_events.append(event_id)
    _apply_effects(event.get("effects", {}))
    GameState.add_log("Événement au Sanctuaire : %s" % String(event.get("name", "Incident")))
    politics_changed.emit()
    return event

func visible_consequences() -> Array:
    var result: Array = []
    var definitions: Dictionary = social_data.get("visible_consequences", {})
    for flag_name in definitions.keys():
        if is_flag_set(String(flag_name)):
            var item: Dictionary = definitions[flag_name].duplicate(true)
            item["source_flag"] = String(flag_name)
            result.append(item)
    return result

func guard_delta() -> int:
    var total := 0
    for item_value in visible_consequences():
        total += int(item_value.get("guard_delta", 0))
    return total

func active_population_tags() -> Array[String]:
    var tags: Array[String] = []
    for item_value in visible_consequences():
        for tag_value in item_value.get("population_tags", []):
            var tag := String(tag_value)
            if not tags.has(tag):
                tags.append(tag)
    return tags

func active_rumors() -> Array[String]:
    var rumors: Array[String] = []
    for item_value in visible_consequences():
        for rumor_value in item_value.get("rumors", []):
            rumors.append(String(rumor_value))
    for event_id in seen_events:
        for event_value in social_data.get("dynamic_events", []):
            var event: Dictionary = event_value
            if String(event.get("id", "")) == event_id and String(event.get("rumor", "")) != "":
                rumors.append(String(event.get("rumor", "")))
    return rumors

func active_inscriptions() -> Array[String]:
    var inscriptions: Array[String] = []
    for item_value in visible_consequences():
        for text_value in item_value.get("inscriptions", []):
            inscriptions.append(String(text_value))
    return inscriptions

func _rebuild_world_memory() -> void:
    world_memory_tags = []
    var memory: Dictionary = social_data.get("world_memory", {})
    for flag_name in memory.keys():
        if not is_flag_set(String(flag_name)):
            continue
        for tag_value in memory[flag_name].get("tags", []):
            var tag := String(tag_value)
            if not world_memory_tags.has(tag):
                world_memory_tags.append(tag)

func future_effects() -> Array[String]:
    var result: Array[String] = []
    var memory: Dictionary = social_data.get("world_memory", {})
    for flag_name in memory.keys():
        if not is_flag_set(String(flag_name)):
            continue
        for effect_value in memory[flag_name].get("future_effects", []):
            result.append(String(effect_value))
    return result

func serialize() -> Dictionary:
    return {
        "reputation": reputation,
        "trust": trust,
        "tension": tension,
        "three_awakenings": three_awakenings.duplicate(true),
        "quest_states": quest_states.duplicate(true),
        "flags": flags.duplicate(true),
        "seen_events": seen_events.duplicate(),
        "world_memory_tags": world_memory_tags.duplicate()
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
    seen_events = []
    for event_value in payload.get("seen_events", []):
        seen_events.append(String(event_value))
    world_memory_tags = []
    for tag_value in payload.get("world_memory_tags", []):
        world_memory_tags.append(String(tag_value))
    for quest in data.get("quests", []):
        var quest_id: String = String(quest.get("id", ""))
        if not quest_states.has(quest_id):
            quest_states[quest_id] = {"status": "locked", "choice": ""}
    _rebuild_world_memory()
    refresh_unlocks()
    politics_changed.emit()