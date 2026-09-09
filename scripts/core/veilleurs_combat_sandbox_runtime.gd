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
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BRIDGE_PATH))
    if not parsed is Dictionary:
        return {"ok":false,"reason":"invalid_bridge_json"}
    var data: Dictionary = parsed
    heroes.clear(); enemies.clear(); party_knowledge.clear()
    for hero_value: Variant in data.get("heroes", []):
        if not hero_value is Dictionary: continue
        var hero: Dictionary = (hero_value as Dictionary).duplicate(true)
        hero["hp"] = int(hero.get("max_hp", 1)); hero["ap"] = 2; hero["side"] = "hero"
        hero["vital_state"] = "stable"; hero["pain_state"] = "controlled"; hero["bleeding_state"] = "none"; hero["psych_state"] = "stable"
        hero["anatomy"] = _fresh_anatomy(); hero["posture"] = "none"; hero["reaction"] = "none"; hero["protected_by"] = ""
        hero["coordination_bonus"] = 0; hero["trame_overload"] = 0; hero["trame_symptom"] = "none"
        heroes.append(hero)
    var encounter: Dictionary = data.get("first_encounter", {})
    for enemy_value: Variant in encounter.get("enemies", []):
        if not enemy_value is Dictionary: continue
        var enemy: Dictionary = (enemy_value as Dictionary).duplicate(true)
        enemy["hp"] = int(enemy.get("max_hp", 1)); enemy["side"] = "enemy"; enemy["vital_state"] = "stable"; enemy["public_vital_state"] = "stable"
        enemy["pain_state"] = "controlled"; enemy["bleeding_state"] = "none"; enemy["psych_state"] = "stable"; enemy["anatomy"] = _fresh_anatomy()
        enemy["observed_patterns"] = {}; enemy["control_state"] = "none"
        enemies.append(enemy)
    active_hero_index = 0; round = 1
    return {"ok":true,"heroes":heroes,"enemies":enemies,"active_hero":active_hero()}

func active_hero() -> Dictionary:
    return {} if heroes.is_empty() else heroes[clampi(active_hero_index, 0, heroes.size() - 1)]

func available_actions() -> Array:
    var hero := active_hero()
    return (hero.get("sandbox_actions", []) as Array).duplicate(true) if not hero.is_empty() else []

func perform_action(action_id: String, target_index: int, zone: String = "torso") -> Dictionary:
    var hero := active_hero()
    if hero.is_empty(): return {"ok":false,"reason":"no_active_hero"}
    var action := _find_action(hero, action_id)
    if action.is_empty(): return {"ok":false,"reason":"unknown_action"}
    var cost := int(action.get("ap", 1))
    if int(hero.get("ap", 0)) < cost: return {"ok":false,"reason":"not_enough_ap"}
    var target_type := str(action.get("target", "enemy"))
    var result: Dictionary = {}
    if target_type.begins_with("enemy"):
        if target_index < 0 or target_index >= enemies.size(): return {"ok":false,"reason":"invalid_target"}
        var target: Dictionary = enemies[target_index]
        if int(target.get("hp", 0)) <= 0: return {"ok":false,"reason":"target_dead"}
        result = _resolve_enemy_action(hero, action, target, zone)
        if bool(result.get("ok", false)):
            result["ai_reaction"] = _enemy_observe_and_react(target, hero, action, zone, result)
    elif target_type == "ally":
        if target_index < 0 or target_index >= heroes.size(): return {"ok":false,"reason":"invalid_target"}
        result = _resolve_ally_action(hero, action, heroes[target_index], zone)
    elif target_type == "self":
        result = _resolve_self_action(hero, action)
    else:
        return {"ok":false,"reason":"unsupported_target_type"}
    if bool(result.get("ok", false)):
        hero["ap"] = int(hero.get("ap", 0)) - cost
        result["remaining_ap"] = hero["ap"]
        _apply_trame_cost(hero, action, result)
    return result

func end_active_turn() -> Dictionary:
    if heroes.is_empty(): return {"ok":false}
    active_hero_index += 1
    if active_hero_index >= heroes.size():
        active_hero_index = 0; round += 1; _enemy_phase()
        for hero in heroes:
            hero["ap"] = 2
            hero["coordination_bonus"] = maxi(0, int(hero.get("coordination_bonus", 0)) - 5)
    else:
        heroes[active_hero_index]["ap"] = 2
    return {"ok":true,"round":round,"active_hero":active_hero()}

func inspect_actor(side: String, index: int) -> Dictionary:
    if side == "hero":
        if index < 0 or index >= heroes.size(): return {"ok":false,"reason":"invalid_actor"}
        var detail := VeilleursCombatContextRuntime.detailed_inspection(heroes[index])
        detail["posture"] = heroes[index].get("posture", "none")
        detail["reaction"] = heroes[index].get("reaction", "none")
        detail["trame_overload"] = heroes[index].get("trame_overload", 0)
        detail["trame_symptom"] = heroes[index].get("trame_symptom", "none")
        detail["coordination_bonus"] = heroes[index].get("coordination_bonus", 0)
        return detail
    if side == "enemy":
        if index < 0 or index >= enemies.size(): return {"ok":false,"reason":"invalid_actor"}
        return VeilleursCombatContextRuntime.detailed_inspection(enemies[index], party_knowledge)
    return {"ok":false,"reason":"invalid_side"}

func _resolve_self_action(hero: Dictionary, action: Dictionary) -> Dictionary:
    var effect := str(action.get("effect", ""))
    match effect:
        "reaction_parry":
            hero["reaction"] = "parry"
            return {"ok":true,"kind":"reaction_ready","reaction":"parry"}
        "guard_stance":
            hero["posture"] = "guard"
            return {"ok":true,"kind":"posture","posture":"guard"}
        "stance_precision":
            hero["posture"] = "precision"
            return {"ok":true,"kind":"posture","posture":"precision"}
        "stance_force_cost":
            hero["posture"] = "force_cost"
            return {"ok":true,"kind":"posture","posture":"force_cost","body_cost_warning":true}
        "trame_stance":
            hero["posture"] = "trame_focus"
            return {"ok":true,"kind":"posture","posture":"trame_focus"}
        "reduce_overload":
            var recovery := int(action.get("overload_recovery", 1))
            hero["trame_overload"] = maxi(0, int(hero.get("trame_overload", 0)) - recovery)
            _refresh_trame_symptom(hero)
            return {"ok":true,"kind":"recovery","overload":hero["trame_overload"],"symptom":hero["trame_symptom"]}
    return {"ok":false,"reason":"unsupported_self_action"}

func _resolve_ally_action(hero: Dictionary, action: Dictionary, ally: Dictionary, zone: String) -> Dictionary:
    var effect := str(action.get("effect", ""))
    match effect:
        "stabilize":
            ally["bleeding_state"] = "light" if str(ally.get("bleeding_state", "none")) in ["important", "critical"] else "none"
            if str(ally.get("pain_state", "controlled")) in ["severe", "unbearable"]: ally["pain_state"] = "strong"
            return {"ok":true,"kind":"stabilize","target":str(ally.get("id"))}
        "anatomical_splint":
            var normalized := zone if zone in ZONES else _first_impaired_zone(ally)
            var anatomy: Dictionary = ally.get("anatomy", {})
            var state: Dictionary = anatomy.get(normalized, {})
            if str(state.get("function", "functional")) != "impaired": return {"ok":false,"reason":"no_impaired_function","zone":normalized}
            state["function"] = "stabilized"
            state["treatment"] = "splint"
            anatomy[normalized] = state; ally["anatomy"] = anatomy
            return {"ok":true,"kind":"anatomical_care","target":str(ally.get("id")),"zone":normalized,"function":"stabilized"}
        "protect_ally":
            ally["protected_by"] = str(hero.get("id", "")); hero["reaction"] = "protect"
            return {"ok":true,"kind":"protection","target":str(ally.get("id")),"protector":str(hero.get("id"))}
        "reaction_intercept":
            hero["reaction"] = "intercept"; ally["protected_by"] = str(hero.get("id", ""))
            return {"ok":true,"kind":"reaction_ready","reaction":"intercept","target":str(ally.get("id"))}
        "coordinate_ally":
            ally["coordination_bonus"] = 10
            return {"ok":true,"kind":"coordination","target":str(ally.get("id")),"accuracy_bonus":10}
        "reaction_reassign":
            ally["reaction"] = "reassigned"
            return {"ok":true,"kind":"reaction_reassign","target":str(ally.get("id"))}
    return {"ok":false,"reason":"unsupported_ally_action"}

func _resolve_enemy_action(hero: Dictionary, action: Dictionary, target: Dictionary, zone: String) -> Dictionary:
    var effect := str(action.get("effect", ""))
    if effect == "expose":
        target["exposed_zone"] = zone if zone in ZONES else "torso"
        VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "observations", ["Ouverture créée par %s" % str(hero.get("name", "un Veilleur"))])
        return {"ok":true,"kind":"expose","target":str(target.get("id")),"zone":target["exposed_zone"]}
    if effect == "reveal_observation":
        VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "vital_state", str(target.get("public_vital_state", "unknown")))
        VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "pain_state", str(target.get("pain_state", "unknown")))
        return {"ok":true,"kind":"observe","target":str(target.get("id"))}
    if effect == "trame_control":
        target["control_state"] = "deviated"
        target["accuracy_penalty"] = 10
        return {"ok":true,"kind":"control","target":str(target.get("id")),"control_state":"deviated"}

    var normalized := zone if zone in ZONES else "torso"
    var accuracy := int(action.get("accuracy", 75)) + int(hero.get("coordination_bonus", 0))
    if str(hero.get("posture", "none")) == "precision": accuracy += 6
    var deterministic_roll := _stable_roll(str(hero.get("id")) + str(target.get("id")) + action.get("id", "") + normalized + str(round))
    if deterministic_roll >= clampi(accuracy, 5, 97):
        return {"ok":true,"kind":"attack","hit":false,"roll":deterministic_roll,"accuracy":accuracy,"zone":normalized,"target":str(target.get("id"))}
    var power := int(action.get("power", 1))
    if str(hero.get("posture", "none")) == "force_cost": power += 3
    var armor_factor := 0.55 if str(target.get("name", "")) == "Porte-Cendre" and normalized in ["torso", "left_arm", "right_arm"] else 1.0
    var damage := maxi(1, int(round(float(power) * armor_factor)))
    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    var severity := 3 if damage >= 13 else (2 if damage >= 8 else 1)
    var anatomy: Dictionary = target.get("anatomy", {}); var zone_state: Dictionary = anatomy.get(normalized, {})
    zone_state["state"] = "injured"; zone_state["function"] = "impaired" if severity >= 2 else "functional"; zone_state["armor"] = "strong" if armor_factor < 0.8 else "weak"
    var injuries: Array = zone_state.get("injuries", []); injuries.append({"severity":severity,"impact":str(action.get("impact", "unknown")),"source":str(action.get("id", ""))}); zone_state["injuries"] = injuries
    anatomy[normalized] = zone_state; target["anatomy"] = anatomy
    target["pain_state"] = "severe" if severity >= 3 else "strong"
    if str(action.get("impact", "")) == "slashing": target["bleeding_state"] = "important" if severity >= 2 else "light"
    target["public_vital_state"] = _vital_label(target); target["vital_state"] = target["public_vital_state"]
    VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "vital_state", target["vital_state"])
    VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "pain_state", target["pain_state"])
    VeilleursCombatContextRuntime.record_enemy_observation(party_knowledge, str(target.get("id", "")), "bleeding_state", target["bleeding_state"])
    VeilleursCombatContextRuntime.record_enemy_zone(party_knowledge, str(target.get("id", "")), normalized, zone_state)
    if str(hero.get("posture", "none")) == "force_cost": _apply_effort_cost(hero)
    return {"ok":true,"kind":"attack","hit":true,"damage":damage,"severity":severity,"zone":normalized,"target":str(target.get("id")),"functional_loss":str(zone_state.get("function"))}

func _apply_trame_cost(hero: Dictionary, action: Dictionary, result: Dictionary) -> void:
    var cost := int(action.get("trame_cost", 0))
    if cost <= 0: return
    if str(hero.get("posture", "none")) == "trame_focus": cost += 1
    hero["trame_overload"] = int(hero.get("trame_overload", 0)) + cost
    _refresh_trame_symptom(hero)
    result["trame_overload"] = hero["trame_overload"]
    result["trame_symptom"] = hero["trame_symptom"]

func _refresh_trame_symptom(hero: Dictionary) -> void:
    var overload := int(hero.get("trame_overload", 0))
    hero["trame_symptom"] = "none" if overload <= 1 else ("fine_tremor" if overload <= 3 else ("photophobia_fatigue" if overload <= 5 else "numbness_critical"))
    if overload >= 6: hero["reaction"] = "trame_stop"

func _apply_effort_cost(hero: Dictionary) -> void:
    hero["pain_state"] = "strong" if str(hero.get("pain_state", "controlled")) == "controlled" else "severe"
    var anatomy: Dictionary = hero.get("anatomy", {}); var shoulder: Dictionary = anatomy.get("right_arm", {})
    shoulder["state"] = "strained"; if str(shoulder.get("function", "functional")) == "functional": shoulder["function"] = "impaired"
    anatomy["right_arm"] = shoulder; hero["anatomy"] = anatomy

func _enemy_observe_and_react(enemy: Dictionary, hero: Dictionary, action: Dictionary, zone: String, result: Dictionary) -> Dictionary:
    var patterns: Dictionary = enemy.get("observed_patterns", {}); var key := "%s:%s" % [str(hero.get("id", "")), zone]
    patterns[key] = int(patterns.get(key, 0)) + 1; enemy["observed_patterns"] = patterns
    if int(patterns[key]) >= 2:
        enemy["guarded_zone"] = zone
        return {"observed":true,"hypothesis":"repeated_zone","confidence":"medium","decision":"guard_zone","zone":zone}
    if bool(result.get("hit", false)) and str(result.get("functional_loss", "")) == "impaired":
        return {"observed":true,"hypothesis":"functional_injury","confidence":"low","decision":"exploit_wounded_actor","hero":str(hero.get("id"))}
    return {"observed":true,"hypothesis":"insufficient_pattern","confidence":"low","decision":"none"}

func _enemy_phase() -> void:
    var alive: Array[Dictionary] = []
    for hero in heroes:
        if int(hero.get("hp", 0)) > 0: alive.append(hero)
    if alive.is_empty(): return
    for enemy in enemies:
        if int(enemy.get("hp", 0)) <= 0: continue
        var target: Dictionary = alive[0]
        for candidate in alive:
            if int(candidate.get("hp", 0)) < int(target.get("hp", 0)): target = candidate
        var damage := 6 if str(enemy.get("id")) == "charognard_sandbox" else 9
        damage = maxi(1, damage - int(enemy.get("accuracy_penalty", 0)) / 5)
        var protector := _hero_by_id(str(target.get("protected_by", "")))
        if not protector.is_empty() and str(protector.get("reaction", "none")) in ["protect", "intercept"]:
            var absorbed := mini(4, damage - 1); damage -= absorbed; protector["hp"] = maxi(0, int(protector.get("hp", 0)) - absorbed)
            protector["reaction"] = "none"; target["protected_by"] = ""
        elif str(target.get("reaction", "none")) == "parry":
            damage = maxi(1, damage - 4); target["reaction"] = "none"
        if str(target.get("posture", "none")) == "guard": damage = maxi(1, damage - 2)
        target["hp"] = maxi(0, int(target.get("hp", 0)) - damage); target["vital_state"] = _vital_label(target)
        target["pain_state"] = "strong" if damage >= 8 else str(target.get("pain_state", "controlled"))

func _hero_by_id(hero_id: String) -> Dictionary:
    if hero_id.is_empty(): return {}
    for hero in heroes:
        if str(hero.get("id", "")) == hero_id: return hero
    return {}

func _first_impaired_zone(actor: Dictionary) -> String:
    var anatomy: Dictionary = actor.get("anatomy", {})
    for zone in ZONES:
        if str((anatomy.get(zone, {}) as Dictionary).get("function", "functional")) == "impaired": return zone
    return "torso"

func _find_action(hero: Dictionary, action_id: String) -> Dictionary:
    for value: Variant in hero.get("sandbox_actions", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == action_id: return (value as Dictionary).duplicate(true)
    return {}

func _fresh_anatomy() -> Dictionary:
    var result := {}
    for zone in ZONES: result[zone] = {"state":"healthy","armor":"unknown","function":"functional","injuries":[]}
    return result

func _stable_roll(seed_text: String) -> int:
    return absi(hash(seed_text)) % 100

func _vital_label(actor: Dictionary) -> String:
    var hp := int(actor.get("hp", 0)); var max_hp := maxi(1, int(actor.get("max_hp", 1)))
    if hp <= 0: return "agony"
    var ratio := float(hp) / float(max_hp)
    if ratio <= 0.25: return "critical"
    if ratio <= 0.6: return "wounded"
    return "stable"
