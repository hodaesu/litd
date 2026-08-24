extends Node

signal campaign_changed

const CAMPAIGN_PATH := "res://data/world/main_campaign.json"
const ENDINGS_PATH := "res://data/world/main_campaign_endings.json"

var campaign: Dictionary = {}
var ending_data: Dictionary = {}
var current_chapter_id := "chapter_01_ashlands"
var completed_main_quests: Dictionary = {}
var discovered_revelations: Dictionary = {}
var chapter_flags: Dictionary = {}
var metrics := {
    "creature_relations": 0,
    "absent_contact": 0,
    "foreign_alliances": 0,
    "justice_integrity": 50,
    "veil_knowledge": 0,
    "stabilizer_nodes": 0
}

func _ready() -> void:
    campaign = _load_json(CAMPAIGN_PATH)
    ending_data = _load_json(ENDINGS_PATH)
    reset_new_game()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    current_chapter_id = "chapter_01_ashlands"
    completed_main_quests = {}
    discovered_revelations = {}
    chapter_flags = {}
    metrics = {
        "creature_relations": 0,
        "absent_contact": 0,
        "foreign_alliances": 0,
        "justice_integrity": 50,
        "veil_knowledge": 0,
        "stabilizer_nodes": 0
    }
    campaign_changed.emit()

func chapters() -> Array:
    return campaign.get("chapters", [])

func get_chapter(chapter_id: String) -> Dictionary:
    for chapter_value in chapters():
        var chapter: Dictionary = chapter_value
        if String(chapter.get("id", "")) == chapter_id:
            return chapter
    return {}

func current_chapter() -> Dictionary:
    return get_chapter(current_chapter_id)

func current_chapter_number() -> int:
    return int(current_chapter().get("number", 1))

func chapter_index(chapter_id: String) -> int:
    var chapter_list: Array = chapters()
    for index in range(chapter_list.size()):
        var chapter: Dictionary = chapter_list[index]
        if String(chapter.get("id", "")) == chapter_id:
            return index
    return -1

func main_quest(quest_id: String) -> Dictionary:
    for chapter_value in chapters():
        for quest_value in chapter_value.get("main_quests", []):
            var quest: Dictionary = quest_value
            if String(quest.get("id", "")) == quest_id:
                return quest
    return {}

func complete_main_quest(quest_id: String) -> bool:
    var quest := main_quest(quest_id)
    if quest.is_empty():
        return false
    completed_main_quests[quest_id] = true
    var revelation := String(quest.get("revelation", ""))
    if revelation != "":
        discovered_revelations[quest_id] = revelation
        metrics["veil_knowledge"] = clampi(int(metrics.get("veil_knowledge", 0)) + 4, 0, 100)
    _try_advance_chapter()
    campaign_changed.emit()
    return true

func is_main_quest_completed(quest_id: String) -> bool:
    return bool(completed_main_quests.get(quest_id, false))

func active_main_quests() -> Array:
    var result: Array = []
    for quest_value in current_chapter().get("main_quests", []):
        var quest: Dictionary = quest_value
        if not is_main_quest_completed(String(quest.get("id", ""))):
            result.append(quest)
    return result

func _try_advance_chapter() -> void:
    var chapter := current_chapter()
    if chapter.is_empty():
        return
    for quest_value in chapter.get("main_quests", []):
        if not is_main_quest_completed(String(quest_value.get("id", ""))):
            return
    var unlock := String(chapter.get("unlock", ""))
    if unlock != "" and unlock != "endings" and not get_chapter(unlock).is_empty():
        chapter_flags["completed_%s" % current_chapter_id] = true
        current_chapter_id = unlock
        ContentScopeDirector.refresh_unlock_announcements()

func add_metric(metric_id: String, amount: int) -> void:
    if not metrics.has(metric_id):
        return
    metrics[metric_id] = clampi(int(metrics.get(metric_id, 0)) + amount, 0, 100)
    campaign_changed.emit()

func set_chapter_flag(flag_id: String, value := true) -> void:
    chapter_flags[flag_id] = value
    campaign_changed.emit()

func ending_score_context() -> Dictionary:
    return {
        "trust": PoliticalState.trust,
        "tension": PoliticalState.tension,
        "reputation": PoliticalState.reputation,
        "body": int(PoliticalState.three_awakenings.get("body", 50)),
        "spirit": int(PoliticalState.three_awakenings.get("spirit", 50)),
        "city": int(PoliticalState.three_awakenings.get("city", 50)),
        "creature_relations": int(metrics.get("creature_relations", 0)),
        "absent_contact": int(metrics.get("absent_contact", 0)),
        "foreign_alliances": int(metrics.get("foreign_alliances", 0)),
        "justice_integrity": int(metrics.get("justice_integrity", 50)),
        "veil_knowledge": int(metrics.get("veil_knowledge", 0)),
        "stabilizer_nodes": int(metrics.get("stabilizer_nodes", 0))
    }

func available_endings() -> Array:
    var result: Array = []
    var ctx := ending_score_context()
    for ending_value in ending_data.get("endings", []):
        var ending: Dictionary = ending_value
        if _requirements_met(ending.get("requirements", {}), ctx):
            result.append(ending)
    return result

func _requirements_met(requirements: Dictionary, ctx: Dictionary) -> bool:
    var key_map := {
        "trust_min": "trust",
        "body_min": "body",
        "spirit_min": "spirit",
        "city_min": "city",
        "creature_relations_min": "creature_relations",
        "absent_contact_min": "absent_contact",
        "foreign_alliances_min": "foreign_alliances",
        "justice_integrity_min": "justice_integrity",
        "veil_knowledge_min": "veil_knowledge",
        "stabilizer_nodes_min": "stabilizer_nodes"
    }
    for req_key in requirements.keys():
        var ctx_key := String(key_map.get(String(req_key), ""))
        if ctx_key == "":
            continue
        if int(ctx.get(ctx_key, 0)) < int(requirements[req_key]):
            return false
    return true

func serialize() -> Dictionary:
    return {
        "current_chapter_id": current_chapter_id,
        "completed_main_quests": completed_main_quests.duplicate(true),
        "discovered_revelations": discovered_revelations.duplicate(true),
        "chapter_flags": chapter_flags.duplicate(true),
        "metrics": metrics.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    current_chapter_id = String(payload.get("current_chapter_id", "chapter_01_ashlands"))
    if get_chapter(current_chapter_id).is_empty():
        current_chapter_id = "chapter_01_ashlands"
    completed_main_quests = payload.get("completed_main_quests", {}).duplicate(true)
    discovered_revelations = payload.get("discovered_revelations", {}).duplicate(true)
    chapter_flags = payload.get("chapter_flags", {}).duplicate(true)
    metrics = payload.get("metrics", metrics).duplicate(true)
    for key in ["creature_relations","absent_contact","foreign_alliances","justice_integrity","veil_knowledge","stabilizer_nodes"]:
        metrics[key] = clampi(int(metrics.get(key, 0)), 0, 100)
    campaign_changed.emit()
