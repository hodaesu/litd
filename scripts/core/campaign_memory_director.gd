extends Node

signal memory_changed

var expeditions: Array = []
var memorial: Array = []
var decisions: Array = []
var notable_enemies: Array = []
var sanctuary_evolution: Array = []
var codex_knowledge: Dictionary = {}

func reset_new_game() -> void:
    expeditions = []
    memorial = []
    decisions = []
    notable_enemies = []
    sanctuary_evolution = []
    codex_knowledge = {}
    memory_changed.emit()

func record_expedition(report: Dictionary) -> void:
    expeditions.push_front(report.duplicate(true))
    if expeditions.size() > 100:
        expeditions.resize(100)
    memory_changed.emit()

func record_death(hero: Dictionary, cause: String, zone_id: String) -> void:
    var hero_id := String(hero.get("id", ""))
    for entry: Dictionary in memorial:
        if String(entry.get("hero_id", "")) == hero_id:
            return
    memorial.push_front({"hero_id":hero_id,"name":String(hero.get("name", "Héros inconnu")),"cause":cause,"zone":zone_id,"date":Time.get_datetime_string_from_system(),"deeds":hero.get("deeds", {}).duplicate(true)})
    memory_changed.emit()

func record_decision(decision_id: String, label: String, consequence: String, quest_id: String = "") -> void:
    decisions.push_front({"id":decision_id,"label":label,"consequence":consequence,"quest_id":quest_id,"chapter":CampaignState.current_chapter_number(),"date":Time.get_datetime_string_from_system()})
    memory_changed.emit()

func record_notable_enemy(enemy: Dictionary, outcome: String) -> void:
    notable_enemies.push_front({"id":String(enemy.get("id", "")),"name":String(enemy.get("name", "Adversaire")),"outcome":outcome,"fear":int(enemy.get("enemy_fear", enemy.get("fear_gauge", 0))),"date":Time.get_datetime_string_from_system()})
    memory_changed.emit()

func record_sanctuary_change(change_id: String, description: String) -> void:
    sanctuary_evolution.push_front({"id":change_id,"description":description,"date":Time.get_datetime_string_from_system()})
    memory_changed.emit()

func learn_enemy(enemy: Dictionary, amount: int = 1) -> void:
    var enemy_id := String(enemy.get("id", ""))
    var entry: Dictionary = codex_knowledge.get(enemy_id, {"encounters":0,"defeated":0,"max_knowledge":5})
    entry["name"] = String(enemy.get("name", "Créature"))
    entry["encounters"] = int(entry.get("encounters", 0)) + maxi(0, amount)
    if int(enemy.get("hp", 1)) <= 0:
        entry["defeated"] = int(entry.get("defeated", 0)) + 1
    entry["knowledge"] = mini(int(entry.get("max_knowledge", 5)), int(entry.get("encounters", 0)) + int(entry.get("defeated", 0)))
    codex_knowledge[enemy_id] = entry
    memory_changed.emit()

func knowledge(enemy_id: String) -> int:
    return int((codex_knowledge.get(enemy_id, {}) as Dictionary).get("knowledge", 0))

func serialize() -> Dictionary:
    return {"expeditions":expeditions.duplicate(true),"memorial":memorial.duplicate(true),"decisions":decisions.duplicate(true),"notable_enemies":notable_enemies.duplicate(true),"sanctuary_evolution":sanctuary_evolution.duplicate(true),"codex_knowledge":codex_knowledge.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    expeditions = payload.get("expeditions", []).duplicate(true)
    memorial = payload.get("memorial", []).duplicate(true)
    decisions = payload.get("decisions", []).duplicate(true)
    notable_enemies = payload.get("notable_enemies", []).duplicate(true)
    sanctuary_evolution = payload.get("sanctuary_evolution", []).duplicate(true)
    codex_knowledge = payload.get("codex_knowledge", {}).duplicate(true)
    memory_changed.emit()
