extends Node

func normalize(effect: Variant, owner: Dictionary = {}) -> Dictionary:
    var source: Dictionary = effect if effect is Dictionary else {"id":String(effect)}
    var effect_id := String(source.get("id", source.get("name", "effect")))
    return {
        "id": effect_id,
        "name": String(source.get("name", effect_id.replace("_", " ").capitalize())),
        "source": String(source.get("source", owner.get("name", "inconnue"))),
        "power": float(source.get("power", source.get("value", 0))),
        "duration": int(source.get("duration", source.get("turns", 1))),
        "stacks": int(source.get("stacks", 1)),
        "max_stacks": int(source.get("max_stacks", 1)),
        "dissipation": String(source.get("dissipation", "expire à la fin de sa durée")),
        "stat": String(source.get("stat", source.get("modifier", "effet contextuel")))
    }

func describe(effect: Variant, owner: Dictionary = {}) -> String:
    var data := normalize(effect, owner)
    return "%s · origine : %s · puissance : %s · durée : %d tour(s) · cumul : %d/%d · statistique : %s · dissipation : %s" % [
        String(data.get("name", "")), String(data.get("source", "")), str(data.get("power", 0)),
        int(data.get("duration", 0)), int(data.get("stacks", 1)), int(data.get("max_stacks", 1)),
        String(data.get("stat", "")), String(data.get("dissipation", ""))
    ]

func describe_all(effects: Array, owner: Dictionary = {}) -> Array[String]:
    var lines: Array[String] = []
    for value: Variant in effects:
        lines.append(describe(value, owner))
    return lines
