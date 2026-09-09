extends RefCounted
class_name VeilleursCombatSandboxRuntime

const BRIDGE_PATH := "res://data/veilleurs/combat_sandbox_quartet_bridge.json"
const ZONES := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]

var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var party_knowledge: Dictionary = {}
var active_hero_index := 0
var round := 1

func setup() -> Dictionary:
    var raw := FileAccess.get_file_as_string(BRIDGE_PATH)
    var parsed: Variant = JSON.parse_string(raw)
    if not parsed is Dictionary:
        return {"ok":false,"reason":"invalid_bridge_json"}
    var data: Dictionary = parsed
    heroes.clear()
    enemies.clear()
    for hero_value: Variant in data.get("heroes", []):
        if not hero_value is Dictionary:
            continue
        var hero: Dictionary = (hero_value as Dictionary).duplicate(true)
        hero["hp"] = int(hero.get("max_hp", 1))
        hero["ap"] = 2
        hero["side"] = "hero"
        hero["vital_state"] = "stable"
        hero["pain_state"] = "controlled"
        hero["bleeding_state"] = "none"
        hero["psych_state"] = "stable"
        hero["anatomy"] = _fresh_anatomy()
        heroes.append(hero)
    var encounter: Dictionary = data.get("first_encounter", {})
    for enemy_value: Variant in encounter.get("enemies", []):
        if not enemy_value is Dictionary:
            continue
        var enemy: Dictionary = (enemy_value as Dictionary).duplicate(true)
        enemy["hp"] = int(enemy.get("max_hp", 1))
        enemy["side"] = "enemy"
        enemy["vital_state"] = "stable"
        enemy["public_vital_state"] = "stable"
        enemy["pain_state"] = "controlled"
        enemy["bleeding_state"] = "none"
        enemy["psych_state"] = "stable"
        enemy["anatomy"] = _fresh_anatomy()
        enemy["observed_patterns"] = {}
        enemies.append(enemy)
    active_hero_index = 0
    round = 1
    return {"ok":true,"heroes":heroes,"enemies":enemies,"active_hero":active_hero()}

func active_hero() -> Dictionary:
    if heroes.is_empty():
        return {}
    return heroes[clampi(active_hero_index, 0, heroes.size() - 1)]

func available_actions() -> Array:
    var hero := active_hero()
    return (hero.get("sandbox_actions", []) as Array).duplicate(true) if not hero.is_empty() else []

func perform_action(action_id: String, target_index: int, zone: String = "torso") -> Dictionary:
    var hero := active_hero()
    if hero.is_empty():
        return {"ok":false,"reason":"no_active_hero"}
    var action := _find_action(hero, action_id)
    if action.is_empty():
        return {"ok":false,"reason":"unknown_action"}
    var cost := int(action.get("ap", 1))
    if int(hero.get("ap", 0)) < cost:
        return {"ok":false,"reason":"not_enough_ap"}
    var target_type := str(action.get("target", "enemy"))
    if target_type.begins_with("enemy"):
        if target_index < 0 or target_index >= enemies.size():
            return {"ok":false,"reason":"invalid_target"}
        var target: Dictionary = enemies[target_index]
        if int(target.get("hp", 0)) <= 0:
            return {"ok":false,"reason":"target_dead"}
        var result := _resolve_enemy_action(hero, action, target, zone)
        if not bool(result.get("ok", false)):
            return result
        hero["ap"] = int(hero.get("ap", 0)) - cost
        result["remaining_ap"] = hero["ap"]
        result["ai_reaction"] = _enemy_observe_and_react(target, hero, action, zone, result)
        return result
    if target_type == "ally":
        if target_index < 0 or target_index >= heroes.size():
            return {"ok":false,"reason":"invalid_target"}
        var ally: Dictionary = heroes[target_index]
        var result := _resolve_ally_action(action, ally)
        if bool(result.get("ok", false)):
            hero["ap"] = int(hero.get("ap", 0)) - cost
            result["remaining_ap"] = hero["ap"]
        return result
    return {"ok":false,"reason":"unsupported_target_type"}

func end_active_turn() -> Dictionary:
    if heroes.is_empty():
        return {"ok":false}
    active_hero_index += 1
    if active_hero_index >= heroes.size():
        active_hero_index = 0
        round += 1
        _enemy_phase()
        for hero in heroes:
            hero["ap"] = 2
    else:
        heroes[active_hero_index]["ap"] = 2
    return {"ok":true,"round":round,"active_hero":active_hero()}

func inspect_actor(side: String, index: int) -> Dictionary:
    if side == "hero":
        if index < 0 or index >= heroes.size(): return {"ok":false,"reason":"invalid_actor"}
        return VeilleursCombatContextRuntime.detailed_inspection(heroes[index])
    if side == "enemy":
        if index < 0 or index >= enemies.size(): return {"ok":false,"reason":"invalid_actor"}
        return VeilleursCombatContextRuntime.detailed_inspection(enemies[index], party_knowledge)
    return {"ok":false,"reason":"invalid_side"}

func _resolve_enemy_action(hero: Dictionary, action: Dictionary, target: Dictionary, zone: String) -> Dictionary:
    if str(action.get("effect", "")) == "expose":
        target["exposed_zone"] = zone if zone in ZONES else "torso"
        VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "observations", ["Ouverture créée par %s" % str(hero.get("name", "un Veilleur"))])
        return {"ok":true,"kind":"expose","target":str(target.get("id")),"zone":target["exposed_zone"]}
    if str(action.get("effect", "")) == "reveal_observation":
        VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "vital_state", str(target.get("public_vital_state", "unknown")))
        VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "pain_state", str(target.get("pain_state", "unknown")))
        return {"ok":true,"kind":"observe","target":str(target.get("id"))}
    if str(action.get("effect", "")) == "psychological_pressure":
        target["psych_state"] = "tense"
        VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "psych_state", "tense")
        return {"ok":true,"kind":"psychology","target":str(target.get("id"))}

    var normalized := zone if zone in ZONES else "torso"
    var accuracy := int(action.get("accuracy", 75))
    var deterministic_roll := _stable_roll(str(hero.get("id")) + str(target.get("id")) + action.get("id", "") + normalized + str(round))
    if deterministic_roll >= accuracy:
        return {"ok":true,"kind":"attack","hit":false,"roll":deterministic_roll,"accuracy":accuracy,"zone":normalized,"target":str(target.get("id"))}
    var power := int(action.get("power", 1))
    var armor_factor := 1.0
    if str(target.get("name", "")) == "Porte-Cendre" and normalized in ["torso", "left_arm", "right_arm"]:
        armor_factor = 0.55
    if bool(action.get("armor_break", false)):
        armor_factor = minf(1.0, armor_factor + 0.25)
    var damage := maxi(1, int(round(float(power) * armor_factor)))
    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    var severity := 1
    if damage >= 13: severity = 3
    elif damage >= 8: severity = 2
    if normalized in ["left_leg", "right_leg"] and damage >= 8:
        severity = maxi(severity, 2)
    var anatomy: Dictionary = target.get("anatomy", {})
    var zone_state: Dictionary = anatomy.get(normalized, {})
    zone_state["state"] = "injured"
    zone_state["function"] = "impaired" if severity >= 2 else "functional"
    zone_state["armor"] = "strong" if armor_factor < 0.8 else "weak"
    var injuries: Array = zone_state.get("injuries", [])
    injuries.append({"severity":severity,"impact":str(action.get("impact", "unknown")),"source":str(action.get("id", ""))})
    zone_state["injuries"] = injuries
    anatomy[normalized] = zone_state
    target["anatomy"] = anatomy
    target["pain_state"] = "severe" if severity >= 3 else "strong"
    if bool(action.get("bleed_bias", false)) or str(action.get("impact", "")) == "slashing":
        target["bleeding_state"] = "important" if severity >= 2 else "light"
    target["public_vital_state"] = _vital_label(target)
    target["vital_state"] = target["public_vital_state"]
    VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "vital_state", target["vital_state"])
    VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "pain_state", target["pain_state"])
    VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "bleeding_state", target["bleeding_state"])
    VeilleursCombatContextRuntime.record_enemy_zone(party_knowledge, str(target.get("id", "")), normalized, zone_state)
    return {"ok":true,"kind":"attack","hit":true,"roll":deterministic_roll,"accuracy":accuracy,"damage":damage,"severity":severity,"zone":normalized,"target":str(target.get("id")),"functional_loss":str(zone_state.get("function"))}

func _resolve_ally_action(action: Dictionary, ally: Dictionary) -> Dictionary:
    if str(action.get("effect", "")) != "stabilize":
        return {"ok":false,"reason":"unsupported_ally_action"}
    ally["bleeding_state"] = "light" if str(ally.get("bleeding_state", "none")) in ["important", "critical"] else "none"
    if str(ally.get("pain_state", "controlled")) in ["severe", "unbearable"]:
        ally["pain_state"] = "strong"
    return {"ok":true,"kind":"stabilize","target":str(ally.get("id"))}

func _enemy_observe_and_react(enemy: Dictionary, hero: Dictionary, action: Dictionary, zone: String, result: Dictionary) -> Dictionary:
    var patterns: Dictionary = enemy.get("observed_patterns", {})
    var key := "%s:%s" % [str(hero.get("id", "")), zone]
    patterns[key] = int(patterns.get(key, 0)) + 1
    enemy["observed_patterns"] = patterns
    var count := int(patterns[key])
    if count >= 2:
        enemy["guarded_zone"] = zone
        return {"observed":true,"hypothesis":"repeated_zone","confidence":"medium","decision":"guard_zone","zone":zone}
    if bool(result.get("hit", false)) and str(result.get("functional_loss", "")) == "impaired":
        return {"observed":true,"hypothesis":"functional_injury","confidence":"low","decision":"exploit_wounded_actor","hero":str(hero.get("id"))}
    return {"observed":true,"hypothesis":"insufficient_pattern","confidence":"low","decision":"none"}

func _enemy_phase() -> void:
    var alive_heroes: Array[Dictionary] = []
    for hero in heroes:
        if int(hero.get("hp", 0)) > 0:
            alive_heroes.append(hero)
    if alive_heroes.is_empty(): return
    for enemy in enemies:
        if int(enemy.get("hp", 0)) <= 0: continue
        var target: Dictionary = alive_heroes[0]
        for candidate in alive_heroes:
            if int(candidate.get("hp", 0)) < int(target.get("hp", 0)):
                target = candidate
        var damage := 6 if str(enemy.get("id")) == "charognard_sandbox" else 9
        target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
        target["vital_state"] = _vital_label(target)
        target["pain_state"] = "strong" if damage >= 8 else "controlled"

func _find_action(hero: Dictionary, action_id: String) -> Dictionary:
    for value: Variant in hero.get("sandbox_actions", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == action_id:
            return (value as Dictionary).duplicate(true)
    return {}

func _fresh_anatomy() -> Dictionary:
    var result := {}
    for zone in ZONES:
        result[zone] = {"state":"healthy","armor":"unknown","function":"functional","injuries":[]}
    return result

func _stable_roll(seed_text: String) -> int:
    return absi(hash(seed_text)) % 100

func _vital_label(actor: Dictionary) -> String:
    var hp := int(actor.get("hp", 0))
    var max_hp := maxi(1, int(actor.get("max_hp", 1)))
    if hp <= 0: return "agony"
    var ratio := float(hp) / float(max_hp)
    if ratio <= 0.25: return "critical"
    if ratio <= 0.6: return "wounded"
    return "stable"
