extends Node

var round_index := 1
var initiative: Array[Dictionary] = []

func rebuild(heroes: Array, enemies: Array) -> Array[Dictionary]:
    initiative.clear()
    for hero_value: Variant in heroes:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        initiative.append(_entry(hero, false))
    for enemy_value: Variant in enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        initiative.append(_entry(enemy, true))
    initiative.sort_custom(func(left: Dictionary, right: Dictionary): return float(left.get("initiative", 0)) > float(right.get("initiative", 0)))
    return initiative.duplicate(true)

func preview_lines(heroes: Array, enemies: Array) -> Array[String]:
    var lines: Array[String] = []
    for entry: Dictionary in rebuild(heroes, enemies):
        var suffix := ""
        if bool(entry.get("enemy", false)):
            suffix = " · " + String(entry.get("intent", "intention incertaine"))
        if bool(entry.get("guarding", false)):
            suffix += " · garde"
        if int(entry.get("riposte", 0)) > 0:
            suffix += " · riposte %d%%" % int(entry.get("riposte", 0))
        lines.append("%s %s%s" % ["ENNEMI" if bool(entry.get("enemy", false)) else "HÉROS", String(entry.get("name", "")), suffix])
    return lines

func modify_initiative(character_id: String, amount: float) -> void:
    for entry: Dictionary in initiative:
        if String(entry.get("id", "")) == character_id:
            entry["initiative"] = float(entry.get("initiative", 0)) + amount
            break
    initiative.sort_custom(func(left: Dictionary, right: Dictionary): return float(left.get("initiative", 0)) > float(right.get("initiative", 0)))

func next_round() -> void:
    round_index += 1

func _entry(character: Dictionary, enemy: bool) -> Dictionary:
    var fear_penalty := float(character.get("enemy_fear", character.get("fear_gauge", 0))) * 0.08 if enemy else float(character.get("fear", 0)) * 0.03
    return {
        "id": String(character.get("id", "")),
        "name": String(character.get("name", "Combattant")),
        "enemy": enemy,
        "initiative": float(character.get("speed", 10)) - fear_penalty,
        "intent": EnemyCombatDirector.intent_preview(character) if enemy else "",
        "guarding": bool(character.get("guarding", false)),
        "riposte": int(character.get("riposte_chance", 0))
    }
