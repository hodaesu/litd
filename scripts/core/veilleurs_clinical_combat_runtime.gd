extends Node

const ENTaille_RESOLVER := "anatomical_lesion"
const ANATOMY_RESOLVER := "anatomical_diagnostic"
const SUTURE_RESOLVER := "medical_treatment"

const DIAGNOSTIC_ONLY_IDS := ["AÏ-ANA-01", "AÏ-ANA-02", "AÏ-ANA-05", "AÏ-ANA-08"]
const POSTURE_IDS := ["TA-ENT-10", "AÏ-ANA-10", "AÏ-SUT-10"]
const SUTURE_RESOURCE_COSTS := {
    "AÏ-SUT-05": 1,
    "AÏ-SUT-06": 1,
    "AÏ-SUT-09": 1,
    "AÏ-SUT-14": 2
}

signal clinical_action_resolved(skill_id: String, result: Dictionary)

func handles(skill: Dictionary) -> bool:
    return str(skill.get("resolver_id", "")) in [ENTaille_RESOLVER, ANATOMY_RESOLVER, SUTURE_RESOLVER]

func profile_for(hero: Dictionary, node: Dictionary) -> Dictionary:
    var resolver_id := str(node.get("resolver_id", ""))
    if resolver_id == "":
        resolver_id = str(node.get("resolver_id", ""))
    var skill_id := str(node.get("id", ""))
    var canonical_type := str(node.get("canonical_type", ""))
    var power := float(node.get("power_0_5", 0.0))
    var profile := {
        "effect": "resolver_required",
        "target": "none",
        "resolver_runtime": "VeilleursClinicalCombatRuntime",
        "runtime_entrypoint": "VeilleursClinicalCombatRuntime.resolve",
        "manual_combat_usable": false
    }

    if canonical_type in ["Passif", "Réaction", "Transformation"]:
        return profile
    if skill_id in POSTURE_IDS or canonical_type == "Posture":
        profile["effect"] = "posture"
        profile["target"] = "self"
        profile["manual_combat_usable"] = true
        return profile
    if resolver_id == SUTURE_RESOLVER:
        profile["effect"] = "medical"
        profile["target"] = "ally"
        profile["manual_combat_usable"] = true
        return profile
    if resolver_id == ANATOMY_RESOLVER and skill_id in DIAGNOSTIC_ONLY_IDS:
        profile["effect"] = "diagnostic"
        profile["target"] = "enemy"
        profile["manual_combat_usable"] = true
        return profile
    if resolver_id in [ENTaille_RESOLVER, ANATOMY_RESOLVER]:
        profile["effect"] = "attack"
        profile["target"] = "enemy"
        profile["power"] = 0.72 + power * (0.145 if resolver_id == ENTaille_RESOLVER else 0.125)
        profile["accuracy_bonus"] = int(node.get("base_accuracy_pct", 100)) - 85
        profile["manual_combat_usable"] = true
        return profile
    return profile

func resolve(hero: Dictionary, target: Dictionary, skill: Dictionary, damage: int = 0, party: Array = []) -> Dictionary:
    var effect := str(skill.get("effect", ""))
    var result: Dictionary
    match effect:
        "attack":
            result = resolve_attack(hero, target, skill, damage)
        "diagnostic":
            result = resolve_diagnostic(hero, target, skill)
        "medical":
            result = resolve_medical(hero, target, skill, party)
        "posture":
            result = resolve_posture(hero, skill)
        _:
            result = {"ok": false, "reason": "unsupported_effect", "effect": effect}
    if bool(result.get("ok", false)):
        clinical_action_resolved.emit(str(skill.get("id", "")), result.duplicate(true))
    return result

func resolve_attack(hero: Dictionary, target: Dictionary, skill: Dictionary, damage: int) -> Dictionary:
    if target.is_empty():
        return {"ok": false, "reason": "target_required"}
    AnatomyRuntime.ensure_state(target)
    var resolver_id := str(skill.get("resolver_id", ""))
    var part_id := _preferred_part(hero, target, skill)
    if part_id == "":
        return {"ok": false, "reason": "no_targetable_part"}

    var attacker := hero.duplicate(true)
    attacker["precision"] = int(attacker.get("precision", 0)) + int(skill.get("accuracy_bonus", 0))
    if _has_skill(hero, "TA-ENT-07") and _part_is_injured(target, part_id):
        attacker["precision"] = int(attacker.get("precision", 0)) + 10
    if _has_skill(hero, "AÏ-ANA-03"):
        attacker["precision"] = int(attacker.get("precision", 0)) + 8
    if int(hero.get("clinical_posture_rounds", 0)) > 0:
        attacker["precision"] = int(attacker.get("precision", 0)) + 12

    var result := AnatomyRuntime.register_targeted_hit(attacker, target, "technique", maxi(1, damage), part_id, str(skill.get("id", "")))
    var state := str(result.get("state", target.get("anatomy_part_states", {}).get(part_id, "intact")))
    var functional_injury := InjuryRuntime.apply_if_needed(target, part_id, state)
    var bonus_damage := 0
    var bleed_added := 0
    var skill_id := str(skill.get("id", ""))

    if resolver_id == ENTaille_RESOLVER:
        bleed_added = _entaille_bleed(hero, target, part_id, skill)
        if bleed_added > 0:
            target["bleeding"] = maxi(0, int(target.get("bleeding", 0))) + bleed_added
        match skill_id:
            "TA-ENT-01":
                target["traction_disrupted"] = 1
            "TA-ENT-02":
                target["tendon_compromised_part"] = part_id
                if _part_has_tag(target, part_id, "mobility"):
                    target["mobility_injury"] = "injured"
            "TA-ENT-05":
                if _part_is_injured(target, part_id):
                    hero["combat_position"] = clampi(int(hero.get("combat_position", 0)) + 1, 0, 3)
            "TA-ENT-06":
                var second_part := _alternate_part(target, part_id)
                if second_part != "":
                    var second := AnatomyRuntime.register_targeted_hit(attacker, target, "technique", maxi(1, int(round(float(damage) * 0.55))), second_part, skill_id)
                    result["second_part"] = second
                    bonus_damage = maxi(1, int(round(float(damage) * 0.25)))
            "TA-ENT-08":
                if _part_has_tag(target, part_id, "attack") or _part_has_tag(target, part_id, "weapon"):
                    target["disarmed_rounds"] = maxi(2, int(target.get("disarmed_rounds", 0)))
            "TA-ENT-09":
                if _part_is_injured(target, part_id):
                    target["bleeding"] = int(target.get("bleeding", 0)) + 2
                    result["reopened_lesion"] = true
                else:
                    result["reopened_lesion"] = false
            "TA-ENT-12":
                if bool(target.get("retreating", false)) or bool(target.get("fleeing", false)):
                    hero["pursuit_initiative_bonus"] = 15
            "TA-ENT-14":
                if _part_is_injured(target, part_id):
                    var followup := AnatomyRuntime.register_targeted_hit(attacker, target, "heavy", maxi(1, damage), part_id, skill_id)
                    result["functional_followup"] = followup
                    var followup_state := str(followup.get("state", target.get("anatomy_part_states", {}).get(part_id, "intact")))
                    functional_injury = InjuryRuntime.apply_if_needed(target, part_id, followup_state)
    elif resolver_id == ANATOMY_RESOLVER:
        match skill_id:
            "AÏ-ANA-06":
                target["controlled_section_part"] = part_id
            "AÏ-ANA-09":
                if _part_is_injured(target, part_id):
                    bonus_damage = maxi(1, int(round(float(damage) * 0.20)))
                    result["lesion_exploited"] = true
            "AÏ-ANA-14":
                if _part_is_injured(target, part_id):
                    var arrest := AnatomyRuntime.register_targeted_hit(attacker, target, "heavy", maxi(1, damage), part_id, skill_id)
                    result["arrest_hit"] = arrest
                    target["function_suppressed_part"] = part_id

    if bonus_damage > 0:
        target["hp"] = maxi(0, int(target.get("hp", 0)) - bonus_damage)
    if resolver_id == ANATOMY_RESOLVER:
        _record_diagnostic(hero, target, part_id, 2)

    result["ok"] = true
    result["resolver_id"] = resolver_id
    result["skill_id"] = skill_id
    result["part_id"] = part_id
    result["bleed_added"] = bleed_added
    result["bonus_damage"] = bonus_damage
    result["functional_injury"] = functional_injury
    return result

func resolve_diagnostic(hero: Dictionary, target: Dictionary, skill: Dictionary) -> Dictionary:
    if target.is_empty():
        return {"ok": false, "reason": "target_required"}
    AnatomyRuntime.ensure_state(target)
    var part_id := _preferred_part(hero, target, skill)
    if part_id == "":
        return {"ok": false, "reason": "no_targetable_part"}
    AnatomyRuntime.select_part(target, part_id)
    var certainty := 1
    var skill_id := str(skill.get("id", ""))
    if skill_id in ["AÏ-ANA-02", "AÏ-ANA-05"]:
        certainty = 2
    elif skill_id == "AÏ-ANA-08":
        certainty = 1
        target["physiology_hypothesis_part"] = part_id
    if skill_id == "AÏ-ANA-05":
        target["exposed_anatomy_part"] = part_id
        target["exposed"] = maxi(2, int(target.get("exposed", 0)))
    _record_diagnostic(hero, target, part_id, certainty)
    var part := AnatomyRuntime.part_definition(target, part_id)
    return {
        "ok": true,
        "action": "diagnostic",
        "skill_id": skill_id,
        "part_id": part_id,
        "part_name": str(part.get("name", part_id)),
        "state": str(target.get("anatomy_part_states", {}).get(part_id, "intact")),
        "functional": InjuryRuntime.part_functional(target, part_id),
        "consequence": str(part.get("consequence", "")),
        "certainty": certainty,
        "hit_chance": AnatomyRuntime.part_hit_chance(hero, part, target)
    }

func resolve_medical(hero: Dictionary, patient: Dictionary, skill: Dictionary, party: Array = []) -> Dictionary:
    if patient.is_empty():
        return {"ok": false, "reason": "patient_required"}
    PersistentInjuryRuntime.prepare_character(patient)
    var skill_id := str(skill.get("id", ""))
    var base_cost := int(SUTURE_RESOURCE_COSTS.get(skill_id, 0))
    var cost := maxi(0, base_cost - (1 if _has_skill(hero, "AÏ-SUT-07") else 0))
    if cost > int(GameState.supplies):
        return {"ok": false, "reason": "supplies_required", "required": cost, "available": int(GameState.supplies)}
    if cost > 0:
        GameState.supplies = maxi(0, int(GameState.supplies) - cost)

    var result := {"ok": true, "action": "medical", "skill_id": skill_id, "patient_id": str(patient.get("id", "")), "supplies_spent": cost}
    match skill_id:
        "AÏ-SUT-01":
            var before := int(patient.get("bleeding", 0))
            patient["bleeding"] = maxi(0, before - maxi(2, int(ceil(float(before) * 0.6))))
            result["bleeding_before"] = before
            result["bleeding_after"] = int(patient.get("bleeding", 0))
            result["stabilized_injury"] = _stabilize_best_injury(patient)
        "AÏ-SUT-02":
            result["protected_injury"] = _protect_best_injury(patient, 2)
        "AÏ-SUT-05":
            result["stabilized_injury"] = _stabilize_named_injury(patient, ["fracture_leg", "sprain"])
            patient["splinted_rounds"] = 4
        "AÏ-SUT-06":
            result["downgraded_injury"] = _downgrade_named_injury(patient, ["deep_wound", "arm_injury", "cracked_ribs"])
            result["stabilized_injury"] = _stabilize_best_injury(patient)
            patient["bleeding"] = maxi(0, int(patient.get("bleeding", 0)) - 3)
        "AÏ-SUT-08":
            result["protected_injury"] = _protect_best_injury(patient, 4)
            result["stabilized_injury"] = _stabilize_best_injury(patient)
        "AÏ-SUT-09":
            var hemorrhage_before := int(patient.get("bleeding", 0))
            patient["bleeding"] = 0 if hemorrhage_before >= 5 else maxi(0, hemorrhage_before - 4)
            result["bleeding_before"] = hemorrhage_before
            result["bleeding_after"] = int(patient.get("bleeding", 0))
            result["stabilized_injury"] = _stabilize_best_injury(patient)
        "AÏ-SUT-12":
            patient["bleeding"] = maxi(0, int(patient.get("bleeding", 0)) - 2)
            patient["treated_while_moving"] = true
            result["stabilized_injury"] = _stabilize_best_injury(patient)
        "AÏ-SUT-14":
            var stabilized: Array[String] = []
            for injury_value: Variant in patient.get("persistent_injuries", []):
                if not (injury_value is Dictionary):
                    continue
                var injury: Dictionary = injury_value
                var injury_id := str(injury.get("id", ""))
                if injury_id != "" and PersistentInjuryRuntime.stabilize_in_field(patient, injury_id):
                    stabilized.append(injury_id)
            patient["bleeding"] = maxi(0, int(patient.get("bleeding", 0)) - 6)
            patient["transportable"] = true
            result["stabilized_injuries"] = stabilized
        _:
            result["stabilized_injury"] = _stabilize_best_injury(patient)

    if _has_skill(hero, "AÏ-SUT-03"):
        patient["field_stabilization_bonus"] = 1
    if _has_skill(hero, "AÏ-SUT-11"):
        patient["function_preserved_until_rest"] = true
    if _has_skill(hero, "AÏ-SUT-15"):
        patient["war_medicine_priority"] = true
    return result

func resolve_posture(hero: Dictionary, skill: Dictionary) -> Dictionary:
    var skill_id := str(skill.get("id", ""))
    match skill_id:
        "TA-ENT-10":
            hero["predator_posture_rounds"] = 3
            hero["predator_defense_penalty"] = 10
        "AÏ-ANA-10":
            hero["clinical_posture_rounds"] = 3
            hero["clinical_defense_penalty"] = 10
        "AÏ-SUT-10":
            hero["triage_posture_rounds"] = 3
            hero["medical_priority_auto"] = true
        _:
            return {"ok": false, "reason": "unknown_posture", "skill_id": skill_id}
    return {"ok": true, "action": "posture", "skill_id": skill_id, "duration_rounds": 3}

func select_medical_target(party: Array) -> Dictionary:
    var best: Dictionary = {}
    var best_score := -1
    for value: Variant in party:
        if not (value is Dictionary):
            continue
        var patient: Dictionary = value
        if int(patient.get("hp", 0)) <= 0:
            continue
        var score := int(patient.get("bleeding", 0)) * 12
        for injury_value: Variant in patient.get("persistent_injuries", []):
            if not (injury_value is Dictionary):
                continue
            var severity := str((injury_value as Dictionary).get("severity", "minor"))
            score += {"minor": 10, "serious": 25, "critical": 50}.get(severity, 5)
            if not bool((injury_value as Dictionary).get("stabilized", false)):
                score += 8
        var max_hp := maxi(1, int(patient.get("max_hp", 1)))
        score += int(round((1.0 - float(patient.get("hp", max_hp)) / float(max_hp)) * 20.0))
        if score > best_score:
            best_score = score
            best = patient
    return best

func _preferred_part(hero: Dictionary, target: Dictionary, skill: Dictionary) -> String:
    AnatomyRuntime.ensure_state(target)
    var skill_id := str(skill.get("id", ""))
    if skill_id in ["TA-ENT-02", "TA-ENT-11"] or _has_skill(hero, "TA-ENT-11"):
        var mobility := _part_with_any_tag(target, ["mobility", "anchor"])
        if mobility != "":
            return mobility
    if skill_id == "TA-ENT-08":
        var weapon := _part_with_any_tag(target, ["weapon", "attack"])
        if weapon != "":
            return weapon
    if skill_id == "AÏ-ANA-11" or _has_skill(hero, "AÏ-ANA-11"):
        var locomotor := _part_with_any_tag(target, ["mobility", "support"])
        if locomotor != "":
            return locomotor
    if skill_id in ["TA-ENT-09", "TA-ENT-14", "AÏ-ANA-09", "AÏ-ANA-14"] or _has_skill(hero, "TA-ENT-15"):
        var injured := _most_injured_part(target)
        if injured != "":
            return injured
    if str(target.get("exposed_anatomy_part", "")) != "" and AnatomyRuntime.select_part(target, str(target.get("exposed_anatomy_part", ""))):
        return str(target.get("exposed_anatomy_part", ""))
    return str(AnatomyRuntime.selected_part(target).get("id", ""))

func _most_injured_part(target: Dictionary) -> String:
    AnatomyRuntime.ensure_state(target)
    var states: Dictionary = target.get("anatomy_part_states", {})
    var trauma: Dictionary = target.get("anatomy_part_trauma", {})
    var best := ""
    var best_score := 0
    for part_value: Variant in AnatomyRuntime.targetable_parts(target):
        var part: Dictionary = part_value
        var part_id := str(part.get("id", ""))
        var score := int(trauma.get(part_id, 0))
        score += {"injured": 100, "critical": 250}.get(str(states.get(part_id, "intact")), 0)
        if score > best_score:
            best_score = score
            best = part_id
    return best

func _alternate_part(target: Dictionary, excluded: String) -> String:
    for part_value: Variant in AnatomyRuntime.targetable_parts(target):
        var part_id := str((part_value as Dictionary).get("id", ""))
        if part_id != "" and part_id != excluded:
            return part_id
    return ""

func _part_with_any_tag(target: Dictionary, wanted: Array) -> String:
    for part_value: Variant in AnatomyRuntime.targetable_parts(target):
        var part: Dictionary = part_value
        for tag: Variant in part.get("tags", []):
            if wanted.has(str(tag)):
                return str(part.get("id", ""))
    return ""

func _part_has_tag(target: Dictionary, part_id: String, tag: String) -> bool:
    return (AnatomyRuntime.part_definition(target, part_id).get("tags", []) as Array).has(tag)

func _part_is_injured(target: Dictionary, part_id: String) -> bool:
    var state := str(target.get("anatomy_part_states", {}).get(part_id, "intact"))
    return state in ["injured", "critical"] or int(target.get("anatomy_part_trauma", {}).get(part_id, 0)) > 0

func _entaille_bleed(hero: Dictionary, target: Dictionary, part_id: String, skill: Dictionary) -> int:
    var amount := 1 + int(round(float(skill.get("power_0_5", 0.0)) * 0.6))
    if _has_skill(hero, "TA-ENT-03") and _part_is_injured(target, part_id):
        amount += 2
    if int(hero.get("predator_posture_rounds", 0)) > 0 and _part_is_injured(target, part_id):
        amount += 1
    return clampi(amount, 1, 6)

func _record_diagnostic(hero: Dictionary, target: Dictionary, part_id: String, certainty: int) -> void:
    var diagnostics: Dictionary = target.get("aisha_diagnostics", {})
    var previous: Dictionary = diagnostics.get(part_id, {})
    diagnostics[part_id] = {
        "certainty": maxi(certainty, int(previous.get("certainty", 0))),
        "state": str(target.get("anatomy_part_states", {}).get(part_id, "intact")),
        "functional": InjuryRuntime.part_functional(target, part_id),
        "observer_id": str(hero.get("id", "")),
        "run_index": RemanenceRuntime.run_index
    }
    target["aisha_diagnostics"] = diagnostics
    if _has_skill(hero, "AÏ-ANA-07"):
        target["anatomy_bestiarity_progress"] = int(target.get("anatomy_bestiarity_progress", 0)) + 1

func _stabilize_best_injury(patient: Dictionary) -> String:
    var best_id := ""
    var best_rank := -1
    for injury_value: Variant in patient.get("persistent_injuries", []):
        if not (injury_value is Dictionary):
            continue
        var injury: Dictionary = injury_value
        var rank := _severity_rank(str(injury.get("severity", "minor")))
        if not bool(injury.get("stabilized", false)) and rank > best_rank:
            best_rank = rank
            best_id = str(injury.get("id", ""))
    if best_id != "":
        PersistentInjuryRuntime.stabilize_in_field(patient, best_id)
    return best_id

func _stabilize_named_injury(patient: Dictionary, ids: Array) -> String:
    for injury_value: Variant in patient.get("persistent_injuries", []):
        if not (injury_value is Dictionary):
            continue
        var injury_id := str((injury_value as Dictionary).get("id", ""))
        if ids.has(injury_id):
            PersistentInjuryRuntime.stabilize_in_field(patient, injury_id)
            return injury_id
    return _stabilize_best_injury(patient)

func _protect_best_injury(patient: Dictionary, rounds: int) -> String:
    var injury_id := _stabilize_best_injury(patient)
    if injury_id == "":
        return ""
    for injury_value: Variant in patient.get("persistent_injuries", []):
        if injury_value is Dictionary and str((injury_value as Dictionary).get("id", "")) == injury_id:
            (injury_value as Dictionary)["protected_rounds"] = maxi(rounds, int((injury_value as Dictionary).get("protected_rounds", 0)))
            return injury_id
    return ""

func _downgrade_named_injury(patient: Dictionary, ids: Array) -> String:
    var injuries: Array = patient.get("persistent_injuries", [])
    for injury_value: Variant in injuries:
        if not (injury_value is Dictionary):
            continue
        var injury: Dictionary = injury_value
        if not ids.has(str(injury.get("id", ""))) or bool(injury.get("permanent", false)):
            continue
        var severity := str(injury.get("severity", "minor"))
        if severity == "critical":
            injury["severity"] = "serious"
        elif severity == "serious":
            injury["severity"] = "minor"
        injury["stabilized"] = true
        injury["untreated_runs"] = 0
        patient["persistent_injuries"] = injuries
        return str(injury.get("id", ""))
    return ""

func _severity_rank(severity: String) -> int:
    return int({"minor": 1, "serious": 2, "critical": 3}.get(severity, 0))

func _has_skill(hero: Dictionary, skill_id: String) -> bool:
    return (hero.get("unlocked_skills", []) as Array).has(skill_id)
