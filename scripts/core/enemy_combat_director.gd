extends Node

var data: Dictionary = {}
var skills: Array = []
var archetype_rules: Array = []

func _ready() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_combat_profiles.json"))
    if parsed is Dictionary:
        data = parsed
        skills = data.get("skills", [])
        archetype_rules = data.get("archetype_rules", [])

func archetype(enemy: Dictionary) -> String:
    if bool(enemy.get("boss", false)):
        return "boss"
    var searchable := String(enemy.get("name", "")).to_lower()
    for rule_value: Variant in archetype_rules:
        var rule: Dictionary = rule_value
        for token_value: Variant in rule.get("contains", []):
            if searchable.contains(String(token_value).to_lower()):
                return String(rule.get("archetype", "any"))
    return String(enemy.get("archetype", "any"))

func choose_action(enemy: Dictionary, heroes: Array) -> Dictionary:
    var candidates: Array[Dictionary] = []
    var enemy_archetype := archetype(enemy)
    for skill_value: Variant in skills:
        var skill: Dictionary = skill_value
        var allowed: Array = skill.get("archetypes", [])
        if not allowed.has("any") and not allowed.has(enemy_archetype):
            continue
        if not _requirements_met(enemy, skill.get("requires", {})):
            continue
        for _weight in range(maxi(1, int(skill.get("weight", 1)))):
            candidates.append(skill)
    if candidates.is_empty():
        return {"id":"basic_attack","name":"Attaque","power":1.0,"target":"random"}
    var chosen: Dictionary = candidates[randi() % candidates.size()].duplicate(true)
    chosen["target_index"] = _target_index(heroes, String(chosen.get("target", "random")))
    return chosen

func apply_secondary(action: Dictionary, enemy: Dictionary, target: Dictionary, all_targets: Array) -> Array[String]:
    var messages: Array[String] = []
    if String(action.get("self_status", "")) == "guarding":
        enemy["guarding"] = true
        messages.append("%s renforce sa garde." % String(enemy.get("name", "L’ennemi")))
    var fear_damage := int(action.get("fear_damage", 0))
    if fear_damage > 0:
        for hero_value: Variant in all_targets:
            var hero: Dictionary = hero_value
            hero["fear"] = mini(100, int(hero.get("fear", 0)) + fear_damage)
        messages.append("Le cri répand %d Peur dans toute la compagnie." % fear_damage)
    var status := String(action.get("status", "none"))
    if status != "none" and randi_range(1, 100) <= int(action.get("status_chance", 0)):
        target[status] = 2
        messages.append("%s subit %s." % [String(target.get("name", "La cible")), status.replace("_", " ")])
    return messages

func intent_preview(enemy: Dictionary) -> String:
    var enemy_archetype := archetype(enemy)
    var fear := int(enemy.get("enemy_fear", enemy.get("fear_gauge", 0)))
    if fear >= 70:
        return "Panique probable · intention instable"
    if enemy_archetype == "spider":
        return "Entrave ou attaque d’une cible vulnérable"
    if enemy_archetype in ["boss", "veil"]:
        return "Menace collective ou attaque lourde"
    if enemy_archetype in ["humanoid", "undead"]:
        return "Garde, rupture ou attaque directe"
    return "Attaque prédatrice"

func _requirements_met(enemy: Dictionary, requirements: Dictionary) -> bool:
    var fear := int(enemy.get("enemy_fear", enemy.get("fear_gauge", 0)))
    var hp_percent := 100.0 * float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", enemy.get("hp", 1))))
    if fear < int(requirements.get("fear_min", 0)):
        return false
    if fear > int(requirements.get("fear_max", 100)):
        return false
    if hp_percent > float(requirements.get("hp_percent_max", 100.0)):
        return false
    return true

func _target_index(heroes: Array, mode: String) -> int:
    if heroes.is_empty():
        return -1
    var best_index := randi() % heroes.size()
    var best_score := -INF
    for index in range(heroes.size()):
        var hero: Dictionary = heroes[index]
        var score := 0.0
        match mode:
            "weakest": score = 1.0 - float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("max_hp", 1)))
            "fastest": score = float(hero.get("speed", 0))
            "highest_hope": score = float(hero.get("hope", 0))
            "highest_precision": score = float(hero.get("precision", 0))
            "guarding": score = 1.0 if bool(hero.get("guarding", false)) else 0.0
            "nearest": score = -float(hero.get("combat_position", index))
            _: score = randf()
        if score > best_score:
            best_score = score
            best_index = index
    return best_index
