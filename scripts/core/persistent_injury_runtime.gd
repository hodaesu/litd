extends Node

signal injuries_changed(character: Dictionary)
signal injury_treated(character: Dictionary, injury_id: String)

const DATA_PATH := "res://data/persistent_injuries.json"

var data: Dictionary = {}

func _ready() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func prepare_character(character: Dictionary) -> void:
    if not character.has("persistent_injuries"):
        character["persistent_injuries"] = []

func definition(injury_id: String) -> Dictionary:
    for value: Variant in data.get("definitions", []):
        var entry: Dictionary = value
        if String(entry.get("id", "")) == injury_id:
            return entry
    return {}

func apply_injury(character: Dictionary, injury_id: String, severity: String = "minor", context: Dictionary = {}) -> Dictionary:
    prepare_character(character)
    ContentScopeDirector.record_context_event("first_persistent_injury")
    if ContentScopeDirector.is_world_rule_active("all_healing_characters_can_treat") and has_party_healer(GameState.party):
        ContentScopeDirector.record_context_event("first_injury_with_healer")
    var injury_definition := definition(injury_id)
    if injury_definition.is_empty():
        return {}
    var injuries: Array = character.get("persistent_injuries", [])
    for value: Variant in injuries:
        var existing: Dictionary = value
        if String(existing.get("id", "")) == injury_id:
            if _severity_rank(severity) > _severity_rank(String(existing.get("severity", "minor"))):
                existing["severity"] = severity
            existing["untreated_runs"] = 0
            _merge_injury_context(existing, injury_definition, context)
            injuries_changed.emit(character)
            return existing.duplicate(true)
    var injury := {
        "id": injury_id,
        "severity": severity,
        "zone": str(context.get("zone", injury_definition.get("body_part", "systemic"))),
        "treatment": str(context.get("treatment", "untreated")),
        "sequela": str(context.get("sequela", "")),
        "cause": str(context.get("cause", "")),
        "untreated_runs": 0,
        "stabilized": false,
        "permanent": bool(injury_definition.get("permanent", false))
    }
    for key_value: Variant in context.keys():
        var key := str(key_value)
        if not injury.has(key):
            injury[key] = context.get(key_value)
    injuries.append(injury)
    character["persistent_injuries"] = injuries
    injuries_changed.emit(character)
    return injury.duplicate(true)

func active_debuffs(character: Dictionary, equipment_context: Dictionary = {}) -> Dictionary:
    prepare_character(character)
    var result: Dictionary = {}
    for value: Variant in character.get("persistent_injuries", []):
        var injury: Dictionary = value
        var injury_definition := definition(String(injury.get("id", "")))
        var raw_debuffs: Dictionary = injury_definition.get("debuffs", {})
        var debuffs := CharacterTraitDirector.adapt_single_injury_debuffs(character, String(injury.get("id", "")), raw_debuffs, equipment_context)
        for key: Variant in debuffs.keys():
            result[String(key)] = float(result.get(String(key), 0.0)) + float(debuffs[key])
    return result

func has_healing_capability(character: Dictionary) -> bool:
    if bool(character.get("can_treat_injuries", false)):
        return true
    if character.has("class_id"):
        for skill_value: Variant in HeroSkillManager.known_combat_skills(character):
            var skill: Dictionary = skill_value
            if String(skill.get("effect", "")) == "heal":
                return true
            if String(skill.get("effect", "")) == "support" and int(skill.get("heal", 0)) > 0:
                return true
    var unlocked: Array = character.get("unlocked_skills", [])
    if character.has("species_id") and not unlocked.is_empty():
        for branch_value: Variant in ["offense", "defense", "special"]:
            for node_value: Variant in CreatureManager.skill_nodes(character, String(branch_value)):
                var node: Dictionary = node_value
                if unlocked.has(String(node.get("id", ""))) and String(node.get("stat", "")) in ["healing_power", "party_heal"]:
                    return true
    return false

func available_healer(party: Array) -> Dictionary:
    for value: Variant in party:
        var member: Dictionary = value
        if int(member.get("hp", 1)) > 0 and has_healing_capability(member):
            return member
    for creature_value: Variant in CreatureManager.captured_creatures:
        var creature: Dictionary = creature_value
        if not bool(creature.get("anatomy_recovery_locked", false)) and has_healing_capability(creature):
            return creature
    return {}

func has_party_healer(party: Array) -> bool:
    return not available_healer(party).is_empty()

func treat_injury(patient: Dictionary, injury_id: String, party: Array, at_infirmary := false) -> Dictionary:
    prepare_character(patient)
    if not at_infirmary and not has_party_healer(party):
        return {"ok": false, "reason": "healer_or_infirmary_required"}
    var injuries: Array = patient.get("persistent_injuries", [])
    for value: Variant in injuries.duplicate():
        var injury: Dictionary = value
        if String(injury.get("id", "")) != injury_id:
            continue
        if bool(injury.get("permanent", false)):
            injury["stabilized"] = true
            injury["untreated_runs"] = 0
            injury["treatment"] = "stabilized_permanent"
            injuries_changed.emit(patient)
            return {"ok": true, "stabilized": true, "permanent": true}
        injuries.erase(value)
        patient["persistent_injuries"] = injuries
        injury_treated.emit(patient, injury_id)
        injuries_changed.emit(patient)
        return {"ok": true, "removed": injury_id}
    return {"ok": false, "reason": "injury_not_found"}

func treat_all_party_injuries(party: Array, healer: Dictionary = {}) -> Dictionary:
    var selected_healer := healer
    if selected_healer.is_empty():
        selected_healer = available_healer(party)
    if selected_healer.is_empty() or not has_healing_capability(selected_healer):
        return {"ok": false, "reason": "no_healing_capability"}
    var treated := 0
    var stabilized := 0
    for value: Variant in party:
        var patient: Dictionary = value
        prepare_character(patient)
        for injury_value: Variant in (patient.get("persistent_injuries", []) as Array).duplicate():
            var result := treat_injury(patient, String((injury_value as Dictionary).get("id", "")), party, false)
            if bool(result.get("ok", false)):
                if bool(result.get("permanent", false)):
                    stabilized += 1
                else:
                    treated += 1
    return {"ok": true, "healer_id": String(selected_healer.get("id", "")), "treated": treated, "stabilized": stabilized}

func stabilize_in_field(character: Dictionary, injury_id: String) -> bool:
    prepare_character(character)
    for value: Variant in character.get("persistent_injuries", []):
        var injury: Dictionary = value
        if String(injury.get("id", "")) == injury_id:
            injury["stabilized"] = true
            injury["treatment"] = "field_stabilized"
            injury["untreated_runs"] = 0
            injuries_changed.emit(character)
            return true
    return false

func close_expedition(party: Array) -> Array:
    var worsened: Array = []
    for value: Variant in party:
        var character: Dictionary = value
        prepare_character(character)
        for injury_value: Variant in character.get("persistent_injuries", []):
            var injury: Dictionary = injury_value
            if bool(injury.get("stabilized", false)) or bool(injury.get("permanent", false)):
                continue
            injury["untreated_runs"] = int(injury.get("untreated_runs", 0)) + 1
            var severity := String(injury.get("severity", "minor"))
            var rule: Dictionary = data.get("severities", {}).get(severity, {})
            if int(injury.get("untreated_runs", 0)) >= int(rule.get("worsen_after_runs", 99)):
                var next := _next_severity(severity)
                if next != severity:
                    injury["severity"] = next
                    injury["untreated_runs"] = 0
                    worsened.append({"character_id": String(character.get("id", "")), "injury_id": String(injury.get("id", "")), "severity": next})
                    ContentScopeDirector.record_context_event("first_injury_aggravation")
        injuries_changed.emit(character)
    return worsened

func critical_extraction_plan(patient: Dictionary, carrier: Dictionary) -> Dictionary:
    prepare_character(patient)
    if patient.is_empty() or carrier.is_empty():
        return {"ok": false, "reason": "patient_and_carrier_required"}
    if patient == carrier or str(patient.get("id", "")) == str(carrier.get("id", "")):
        return {"ok": false, "reason": "carrier_must_be_other_ally"}
    if int(carrier.get("hp", 0)) <= 0:
        return {"ok": false, "reason": "carrier_incapacitated"}
    var critical_injury := false
    for injury_value: Variant in patient.get("persistent_injuries", []):
        if injury_value is Dictionary and str((injury_value as Dictionary).get("severity", "")) == "critical":
            critical_injury = true
            break
    var max_hp := maxi(1, int(patient.get("max_hp", patient.get("hp", 1))))
    var hp_critical := int(patient.get("hp", 0)) > 0 and float(patient.get("hp", 0)) / float(max_hp) <= 0.25
    if not critical_injury and not hp_critical:
        return {"ok": false, "reason": "patient_not_critical"}
    return {
        "ok": true,
        "patient_id": str(patient.get("id", "")),
        "carrier_id": str(carrier.get("id", "")),
        "patient_can_extract": true,
        "carrier_penalties": {"movement_speed": -30, "dodge_chance": -10, "rank_change_cost": 1},
        "patient_penalties": {"actions_locked": true, "carried": true}
    }

func apply_critical_extraction_carry(patient: Dictionary, carrier: Dictionary) -> Dictionary:
    var plan := critical_extraction_plan(patient, carrier)
    if not bool(plan.get("ok", false)):
        return plan
    patient["being_carried"] = true
    patient["carried_by"] = str(carrier.get("id", ""))
    patient["actions_locked"] = true
    carrier["carrying_critical_ally"] = str(patient.get("id", ""))
    carrier["carry_penalties"] = (plan.get("carrier_penalties", {}) as Dictionary).duplicate(true)
    return plan

func clear_extraction_carry(patient: Dictionary, carrier: Dictionary) -> void:
    patient.erase("being_carried")
    patient.erase("carried_by")
    patient.erase("actions_locked")
    carrier.erase("carrying_critical_ally")
    carrier.erase("carry_penalties")

func _merge_injury_context(injury: Dictionary, injury_definition: Dictionary, context: Dictionary) -> void:
    if not injury.has("zone"):
        injury["zone"] = str(injury_definition.get("body_part", "systemic"))
    if not injury.has("treatment"):
        injury["treatment"] = "untreated"
    if not injury.has("sequela"):
        injury["sequela"] = ""
    for key_value: Variant in context.keys():
        injury[str(key_value)] = context.get(key_value)

func _severity_rank(severity: String) -> int:
    return int(data.get("severities", {}).get(severity, {}).get("rank", 0))

func _next_severity(severity: String) -> String:
    match severity:
        "minor": return "serious"
        "serious": return "critical"
    return severity

func treat_all_at_infirmary(party: Array) -> Dictionary:
    ContentScopeDirector.record_context_event("first_return_with_injury")
    var treated := 0
    var stabilized := 0
    for value: Variant in party:
        var patient: Dictionary = value
        prepare_character(patient)
        for injury_value: Variant in (patient.get("persistent_injuries", []) as Array).duplicate():
            var result := treat_injury(patient, String((injury_value as Dictionary).get("id", "")), party, true)
            if bool(result.get("ok", false)):
                if bool(result.get("permanent", false)):
                    stabilized += 1
                else:
                    treated += 1
    return {"ok": true, "treated": treated, "stabilized": stabilized}
