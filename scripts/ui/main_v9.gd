extends "res://scripts/ui/main_v8.gd"

# Combat v9 : psychologie des mutilations.
var mutilation_psychology: Dictionary = {}
var anatomy_actor_context: Dictionary = {}

func _ready() -> void:
    _load_mutilation_psychology()
    super._ready()

func _load_mutilation_psychology() -> void:
    if not mutilation_psychology.is_empty():
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_mutilation_psychology.json"))
    mutilation_psychology = parsed if parsed is Dictionary else {}

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    anatomy_actor_context = hero
    super._hero_attack_action(hero, action)
    anatomy_actor_context = {}

func _technique_damage(hero: Dictionary, target: Dictionary, power: float) -> int:
    anatomy_actor_context = hero
    var damage := super._technique_damage(hero, target, power)
    anatomy_actor_context = {}
    return damage

func _report_anatomy_result(target: Dictionary, result: Dictionary) -> void:
    super._report_anatomy_result(target, result)
    if not bool(result.get("severed", false)):
        return
    target["mutilation_recent"] = true
    _apply_mutilation_psychology(target, anatomy_actor_context)

func _apply_mutilation_psychology(target: Dictionary, attacker: Dictionary) -> void:
    _load_mutilation_psychology()
    var attacker_id := str(attacker.get("id", ""))
    var boss_bonus := int(mutilation_psychology.get("boss_dismemberment_fear_bonus", 2)) if bool(target.get("is_boss", false)) or bool(target.get("boss", false)) or bool(target.get("deep_vestige_boss", false)) else 0
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var band := _psychology_band(int(hero.get("madness", 0)))
        var multiplier := float(mutilation_psychology.get("attacker_multiplier", 0.5)) if str(hero.get("id", "")) == attacker_id else 1.0
        var fear_gain := int(round(float(int(band.get("fear", 0)) + boss_bonus) * multiplier))
        var madness_gain := int(round(float(int(band.get("madness", 0))) * multiplier))
        var hope_delta := int(round(float(int(band.get("hope", 0))) * multiplier))
        var bonuses := hero_bonuses(hero)
        fear_gain = maxi(0, fear_gain - int(round(float(bonuses.get("fear_resistance", 0)) * 0.10)))
        madness_gain = maxi(0, madness_gain - int(round(float(bonuses.get("madness_resistance", 0)) * 0.10)))
        if int(hero.get("hope", 0)) >= int(mutilation_psychology.get("high_hope_threshold", 60)):
            fear_gain = maxi(0, fear_gain - int(mutilation_psychology.get("high_hope_fear_reduction", 2)))
        var max_madness := 100 + int(bonuses.get("max_madness", 0))
        hero["fear"] = clampi(int(hero.get("fear", 0)) + fear_gain, 0, 100)
        hero["madness"] = clampi(int(hero.get("madness", 0)) + madness_gain, 0, max_madness)
        hero["hope"] = clampi(int(hero.get("hope", 0)) + hope_delta, 0, 100 + int(bonuses.get("max_hope", 0)))
        hero["last_mutilation_response"] = str(band.get("state", "lucide"))
        if fear_gain > 0 or madness_gain > 0 or hope_delta != 0:
            GameState.add_log("%s réagit à la mutilation : %s (Peur %d · Folie %d · Espoir %d)." % [
                str(hero.get("name", "Héros")), str(band.get("state", "lucide")), fear_gain, madness_gain, hope_delta
            ])

func _psychology_band(madness: int) -> Dictionary:
    for value in mutilation_psychology.get("witness_bands", []):
        var band: Dictionary = value
        if madness <= int(band.get("max_madness", 1000)):
            return band
    return {"state":"dissocié","fear":3,"madness":6,"hope":-3}
