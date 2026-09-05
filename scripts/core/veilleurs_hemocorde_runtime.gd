extends Node

const RESOLVER_ID := "vascular_bleeding"
const DIAGNOSTIC_IDS := ["AÏ-HÉM-06", "AÏ-HÉM-08"]
const POSTURE_ID := "AÏ-HÉM-10"

signal hemocorde_action_resolved(skill_id: String, result: Dictionary)

func handles(skill: Dictionary) -> bool:
    return str(skill.get("resolver_id", "")) == RESOLVER_ID

func profile_for(_hero: Dictionary, node: Dictionary) -> Dictionary:
    var skill_id := str(node.get("id", ""))
    var canonical_type := str(node.get("canonical_type", ""))
    var power := float(node.get("power_0_5", 0.0))
    var profile := {
        "effect": "resolver_required",
        "target": "none",
        "resolver_runtime": "VeilleursHemocordeRuntime",
        "runtime_entrypoint": "VeilleursHemocordeRuntime.resolve",
        "manual_combat_usable": false
    }
    if canonical_type in ["Passif", "Réaction", "Transformation"]:
        return profile
    if skill_id == POSTURE_ID or canonical_type == "Posture":
        profile["effect"] = "posture"
        profile["target"] = "self"
        profile["manual_combat_usable"] = true
        return profile
    if skill_id in DIAGNOSTIC_IDS:
        profile["effect"] = "diagnostic"
        profile["target"] = "enemy"
        profile["manual_combat_usable"] = true
        return profile
    profile["effect"] = "attack"
    profile["target"] = "enemy"
    profile["power"] = 0.62 + power * 0.12
    profile["accuracy_bonus"] = int(node.get("base_accuracy_pct", 100)) - 86
    profile["manual_combat_usable"] = true
    return profile

func resolve(hero: Dictionary, target: Dictionary, skill: Dictionary, damage: int = 0, _party: Array = []) -> Dictionary:
    var effect := str(skill.get("effect", ""))
    var result: Dictionary
    match effect:
        "attack":
            result = resolve_attack(hero, target, skill, damage)
        "diagnostic":
            result = resolve_diagnostic(hero, target, skill)
        "posture":
            result = resolve_posture(hero, skill)
        _:
            result = {"ok": false, "reason": "unsupported_effect", "effect": effect}
    if bool(result.get("ok", false)):
        hemocorde_action_resolved.emit(str(skill.get("id", "")), result.duplicate(true))
    return result

func resolve_attack(hero: Dictionary, target: Dictionary, skill: Dictionary, damage: int) -> Dictionary:
    if target.is_empty():
        return {"ok": false, "reason": "target_required"}
    AnatomyRuntime.ensure_state(target)
    refresh_circulatory_state(target)
    var skill_id := str(skill.get("id", ""))
    var part_id := _preferred_vascular_part(hero, target)
    if part_id == "":
        return {"ok": false, "reason": "no_targetable_part"}

    var attacker := hero.duplicate(true)
    attacker["precision"] = int(attacker.get("precision", 0)) + int(skill.get("accuracy_bonus", 0))
    if _has_skill(hero, "AÏ-HÉM-03"):
        attacker["precision"] = int(attacker.get("precision", 0)) + 8
    if _has_skill(hero, "AÏ-HÉM-07") and _open_wound_count(target) >= 2:
        attacker["precision"] = int(attacker.get("precision", 0)) + 10
    var known := _vascular_part_known(target, part_id)
    if int(hero.get("hemodynamic_posture_rounds", 0)) > 0:
        attacker["precision"] = int(attacker.get("precision", 0)) + (12 if known else -15)

    var anatomy_result := AnatomyRuntime.register_targeted_hit(attacker, target, "technique", maxi(1, damage), part_id, skill_id)
    var state := str(anatomy_result.get("state", target.get("anatomy_part_states", {}).get(part_id, "intact")))
    var functional_injury := InjuryRuntime.apply_if_needed(target, part_id, state)
    var bleeding_before := int(target.get("bleeding", 0))
    var bleed_added := 0
    var bonus_damage := 0

    match skill_id:
        "AÏ-HÉM-01":
            bleed_added = 2 + (1 if known else 0)
        "AÏ-HÉM-02":
            target["vascular_pressure_part"] = part_id
            target["vascular_pressure_rounds"] = 2
            target["speed_down"] = maxi(1, int(target.get("speed_down", 0)))
            bleed_added = 1
        "AÏ-HÉM-05":
            if bleeding_before > 0:
                bleed_added = maxi(2, int(ceil(float(bleeding_before) * 0.35)))
                target["wound_maintained_rounds"] = 2
            else:
                bleed_added = 1
        "AÏ-HÉM-09":
            if _circulatory_shock(target) >= 1 or bleeding_before >= 3:
                target["rhythm_disrupted_rounds"] = 1
                target["accuracy_down"] = maxi(1, int(target.get("accuracy_down", 0)))
                bleed_added = 1
            else:
                anatomy_result["rhythm_disrupted"] = false
        "AÏ-HÉM-12":
            if _part_is_open_and_unprotected(target, part_id):
                bleed_added = 3
                anatomy_result["open_wound_exploited"] = true
            else:
                bleed_added = 1
                anatomy_result["open_wound_exploited"] = false
        "AÏ-HÉM-14":
            var shock_before := _circulatory_shock(target)
            if shock_before >= 2 and bleeding_before >= 4 and known:
                target["circulatory_compromised_rounds"] = 2
                target["rhythm_disrupted_rounds"] = 2
                target["stunned"] = true
                bleed_added = 2
                bonus_damage = mini(maxi(1, int(round(float(target.get("max_hp", 1)) * 0.08))), maxi(0, int(target.get("hp", 0)) - 1))
                anatomy_result["circulatory_collapse"] = true
            else:
                bleed_added = 1
                anatomy_result["circulatory_collapse"] = false
        _:
            bleed_added = 1

    if _has_skill(hero, "AÏ-HÉM-11") and known and _open_wound_count(target) >= 2 and bleeding_before + bleed_added >= 5:
        bleed_added += 2
        target["critical_hemorrhage"] = true
    target["bleeding"] = maxi(0, bleeding_before + bleed_added)
    if bonus_damage > 0:
        target["hp"] = maxi(1, int(target.get("hp", 0)) - bonus_damage)
    _remember_vascular_part(target, part_id, 2)
    refresh_circulatory_state(target)

    anatomy_result["ok"] = true
    anatomy_result["resolver_id"] = RESOLVER_ID
    anatomy_result["skill_id"] = skill_id
    anatomy_result["part_id"] = part_id
    anatomy_result["part_name"] = str(AnatomyRuntime.part_definition(target, part_id).get("name", part_id))
    anatomy_result["bleeding_before"] = bleeding_before
    anatomy_result["bleed_added"] = bleed_added
    anatomy_result["bleeding_after"] = int(target.get("bleeding", 0))
    anatomy_result["circulatory_shock"] = _circulatory_shock(target)
    anatomy_result["bonus_damage"] = bonus_damage
    anatomy_result["functional_injury"] = functional_injury
    return anatomy_result

func resolve_diagnostic(hero: Dictionary, target: Dictionary, skill: Dictionary) -> Dictionary:
    if target.is_empty():
        return {"ok": false, "reason": "target_required"}
    AnatomyRuntime.ensure_state(target)
    refresh_circulatory_state(target)
    var skill_id := str(skill.get("id", ""))
    var part_id := _preferred_vascular_part(hero, target)
    if part_id == "":
        return {"ok": false, "reason": "no_targetable_part"}
    var certainty := 2 if skill_id == "AÏ-HÉM-06" else 1
    if _has_skill(hero, "AÏ-HÉM-15"):
        certainty = 3
    _remember_vascular_part(target, part_id, certainty)
    if skill_id == "AÏ-HÉM-06":
        var candidates: Array[String] = []
        for part_value: Variant in AnatomyRuntime.targetable_parts(target):
            var part: Dictionary = part_value
            var candidate_id := str(part.get("id", ""))
            if _vascular_score(part) >= 3:
                _remember_vascular_part(target, candidate_id, certainty)
                candidates.append(candidate_id)
        target["vascular_line_parts"] = candidates
    else:
        target["pulse_reading"] = {
            "observer_id": str(hero.get("id", "")),
            "shock": _circulatory_shock(target),
            "hemorrhage_risk": int(target.get("hemorrhage_risk", 0)),
            "bleeding": int(target.get("bleeding", 0)),
            "hp_ratio": _hp_ratio(target),
            "certainty": certainty,
            "run_index": RemanenceRuntime.run_index
        }
    var part := AnatomyRuntime.part_definition(target, part_id)
    return {
        "ok": true,
        "action": "diagnostic",
        "skill_id": skill_id,
        "part_id": part_id,
        "part_name": str(part.get("name", part_id)),
        "certainty": certainty,
        "circulatory_shock": _circulatory_shock(target),
        "hemorrhage_risk": int(target.get("hemorrhage_risk", 0)),
        "bleeding": int(target.get("bleeding", 0)),
        "hp_ratio": _hp_ratio(target)
    }

func resolve_posture(hero: Dictionary, skill: Dictionary) -> Dictionary:
    if str(skill.get("id", "")) != POSTURE_ID:
        return {"ok": false, "reason": "unknown_posture"}
    hero["hemodynamic_posture_rounds"] = 3
    hero["hemodynamic_unknown_penalty"] = 15
    return {"ok": true, "action": "posture", "skill_id": POSTURE_ID, "duration_rounds": 3}

func refresh_passive_state(hero: Dictionary, enemies: Array) -> void:
    hero["vascular_precision_passive"] = _has_skill(hero, "AÏ-HÉM-03")
    hero["blood_calls_blood_passive"] = _has_skill(hero, "AÏ-HÉM-07")
    hero["critical_hemorrhage_passive"] = _has_skill(hero, "AÏ-HÉM-11")
    hero["vascular_mastery"] = _has_skill(hero, "AÏ-HÉM-15")
    if bool(hero.get("vascular_mastery", false)):
        for enemy_value: Variant in enemies:
            if not (enemy_value is Dictionary):
                continue
            var enemy: Dictionary = enemy_value
            AnatomyRuntime.ensure_state(enemy)
            for part_value: Variant in AnatomyRuntime.targetable_parts(enemy):
                var part: Dictionary = part_value
                if _vascular_score(part) >= 2:
                    _remember_vascular_part(enemy, str(part.get("id", "")), 3)
            refresh_circulatory_state(enemy)

func advance_round_state(hero: Dictionary) -> void:
    if int(hero.get("hemodynamic_posture_rounds", 0)) > 0:
        hero["hemodynamic_posture_rounds"] = maxi(0, int(hero.get("hemodynamic_posture_rounds", 0)) - 1)
    if int(hero.get("hemodynamic_posture_rounds", 0)) <= 0:
        hero.erase("hemodynamic_unknown_penalty")

func refresh_circulatory_state(target: Dictionary) -> Dictionary:
    AnatomyRuntime.ensure_state(target)
    var bleeding := maxi(0, int(target.get("bleeding", 0)))
    var open_wounds := _open_wound_count(target)
    var critical_parts := 0
    for state_value: Variant in (target.get("anatomy_part_states", {}) as Dictionary).values():
        if str(state_value) == "critical":
            critical_parts += 1
    var ratio := _hp_ratio(target)
    var shock := 0
    if bleeding >= 3 or ratio <= 0.65 or open_wounds >= 2:
        shock = 1
    if bleeding >= 6 or ratio <= 0.40 or critical_parts >= 1:
        shock = 2
    if bleeding >= 9 or ratio <= 0.20 or (critical_parts >= 1 and bleeding >= 6):
        shock = 3
    var risk := clampi(bleeding * 8 + open_wounds * 12 + critical_parts * 20 + int(round((1.0 - ratio) * 25.0)), 0, 100)
    target["circulatory_shock"] = shock
    target["hemorrhage_risk"] = risk
    target["open_wound_count"] = open_wounds
    return {"shock": shock, "hemorrhage_risk": risk, "open_wounds": open_wounds, "bleeding": bleeding, "hp_ratio": ratio}

func _preferred_vascular_part(hero: Dictionary, target: Dictionary) -> String:
    var known_parts: Dictionary = target.get("vascular_known_parts", {})
    var best_known := ""
    var best_known_score := -1
    for part_value: Variant in AnatomyRuntime.targetable_parts(target):
        var part: Dictionary = part_value
        var part_id := str(part.get("id", ""))
        var certainty := int((known_parts.get(part_id, {}) as Dictionary).get("certainty", 0)) if known_parts.get(part_id, {}) is Dictionary else 0
        var score := _vascular_score(part) * 10 + certainty * 8 + int(target.get("anatomy_part_trauma", {}).get(part_id, 0))
        if certainty > 0 and score > best_known_score:
            best_known_score = score
            best_known = part_id
    if best_known != "":
        return best_known
    var best := ""
    var best_score := -1
    for part_value: Variant in AnatomyRuntime.targetable_parts(target):
        var part: Dictionary = part_value
        var score := _vascular_score(part)
        if _has_skill(hero, "AÏ-HÉM-15"):
            score += 2
        if score > best_score:
            best_score = score
            best = str(part.get("id", ""))
    return best

func _vascular_score(part: Dictionary) -> int:
    var searchable := (str(part.get("id", "")) + " " + str(part.get("name", "")) + " " + str(part.get("consequence", ""))).to_lower()
    var score := 0
    for token in ["neck", "cou", "throat", "gorge", "torso", "torse", "chest", "poitrine", "abdomen", "tronc"]:
        if searchable.contains(token):
            score += 3
    for token in ["head", "tête", "arm", "bras", "leg", "jambe", "hand", "main"]:
        if searchable.contains(token):
            score += 1
    var tags: Array = part.get("tags", [])
    if tags.has("vital"):
        score += 4
    if tags.has("support") or tags.has("attack") or tags.has("mobility"):
        score += 1
    return score

func _remember_vascular_part(target: Dictionary, part_id: String, certainty: int) -> void:
    if part_id == "":
        return
    var known: Dictionary = target.get("vascular_known_parts", {})
    var previous: Dictionary = known.get(part_id, {}) if known.get(part_id, {}) is Dictionary else {}
    known[part_id] = {
        "certainty": maxi(certainty, int(previous.get("certainty", 0))),
        "state": str(target.get("anatomy_part_states", {}).get(part_id, "intact")),
        "observer_id": "aisha_maren",
        "run_index": RemanenceRuntime.run_index
    }
    target["vascular_known_parts"] = known

func _vascular_part_known(target: Dictionary, part_id: String) -> bool:
    return (target.get("vascular_known_parts", {}) as Dictionary).has(part_id) or (target.get("aisha_diagnostics", {}) as Dictionary).has(part_id)

func _open_wound_count(target: Dictionary) -> int:
    var count := 0
    for part_value: Variant in AnatomyRuntime.targetable_parts(target):
        var part_id := str((part_value as Dictionary).get("id", ""))
        var state := str(target.get("anatomy_part_states", {}).get(part_id, "intact"))
        if state in ["injured", "critical"] or int(target.get("anatomy_part_trauma", {}).get(part_id, 0)) > 0:
            count += 1
    return count

func _part_is_open_and_unprotected(target: Dictionary, part_id: String) -> bool:
    var injured := str(target.get("anatomy_part_states", {}).get(part_id, "intact")) in ["injured", "critical"] or int(target.get("anatomy_part_trauma", {}).get(part_id, 0)) > 0
    if not injured:
        return false
    if str(target.get("protected_anatomy_part", "")) == part_id:
        return false
    if str(target.get("bandaged_anatomy_part", "")) == part_id:
        return false
    return true

func _circulatory_shock(target: Dictionary) -> int:
    return int(refresh_circulatory_state(target).get("shock", 0))

func _hp_ratio(target: Dictionary) -> float:
    return float(target.get("hp", 0)) / float(maxi(1, int(target.get("max_hp", 1))))

func _has_skill(hero: Dictionary, skill_id: String) -> bool:
    return (hero.get("unlocked_skills", []) as Array).has(skill_id)
