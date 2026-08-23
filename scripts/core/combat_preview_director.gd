extends Node

func preview(hero: Dictionary, skill: Dictionary, target: Dictionary) -> Dictionary:
    var class_definition: Dictionary = DataLoader.find_by_id(DataLoader.classes, String(hero.get("class_id", "")))
    var damage_range: Array = class_definition.get("damage", [0, 0])
    var power := float(skill.get("power", 0.0))
    var target_resistance := float(target.get("physical_resistance", target.get("resistance", 0)))
    var low := maxi(0, int(round(float(damage_range[0]) * power * (1.0 - target_resistance / 100.0))))
    var high := maxi(low, int(round(float(damage_range[1]) * power * (1.0 - target_resistance / 100.0))))
    var effect := String(skill.get("effect", "attack"))
    if effect in ["heal", "support"]:
        low = int(skill.get("heal", 0))
        high = low
    return {
        "skill_id": String(skill.get("id", "")),
        "target": String(target.get("name", "Aucune cible")),
        "target_type": String(skill.get("target", "enemy")),
        "range": String(skill.get("range", "R1–R4")),
        "damage_min": low,
        "damage_max": high,
        "accuracy": clampi(int(hero.get("precision", 75)) + int(skill.get("accuracy", 0)), 0, 100),
        "critical": clampi(int(hero.get("critical_chance", 0)) + int(skill.get("critical_chance", 0)), 0, 100),
        "resistance": int(round(target_resistance)),
        "status": String(skill.get("status", "aucun")),
        "status_chance": int(skill.get("status_chance", 0)),
        "rank_move": int(skill.get("rank_move", 0)),
        "push": int(skill.get("push", 0)),
        "pull": int(skill.get("pull", 0)),
        "cost": int(skill.get("cost", 0)),
        "cooldown": int(skill.get("cooldown", 0))
    }

func describe(result: Dictionary) -> String:
    var amount := "Soin %d" % int(result.get("damage_min", 0)) if String(result.get("target_type", "")) == "ally" else "Dégâts %d–%d" % [int(result.get("damage_min", 0)), int(result.get("damage_max", 0))]
    var movement: Array[String] = []
    if int(result.get("rank_move", 0)) != 0:
        movement.append("rang %+d" % int(result.get("rank_move", 0)))
    if int(result.get("push", 0)) > 0:
        movement.append("poussée %d" % int(result.get("push", 0)))
    if int(result.get("pull", 0)) > 0:
        movement.append("traction %d" % int(result.get("pull", 0)))
    return "%s · Cible %s · Portée %s · Précision %d%% · Crit %d%% · Résistance %d%% · %s %d%%%s · Coût %d · Recharge %d" % [
        amount, String(result.get("target", "")), String(result.get("range", "")), int(result.get("accuracy", 0)),
        int(result.get("critical", 0)), int(result.get("resistance", 0)), String(result.get("status", "aucun")),
        int(result.get("status_chance", 0)), " · " + ", ".join(movement) if not movement.is_empty() else "",
        int(result.get("cost", 0)), int(result.get("cooldown", 0))
    ]
