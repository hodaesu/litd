extends Node

signal injuries_changed(character: Dictionary)
signal injury_treated(character: Dictionary, injury_id: String)

const DATA_PATH := "res://data/persistent_injuries.json"
const MEDICAL_CLASSES := ["surgeon", "vestal"]

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

func apply_injury(character: Dictionary, injury_id: String, severity: String = "minor") -> Dictionary:
    prepare_character(character)
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
            injuries_changed.emit(character)
            return existing.duplicate(true)
    var injury := {
        "id": injury_id,
        "severity": severity,
        "untreated_runs": 0,
        "stabilized": false,
        "permanent": bool(injury_definition.get("permanent", false))
    }
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

func has_party_healer(party: Array) -> bool:
    for value: Variant in party:
        var member: Dictionary = value
        if int(member.get("hp", 0)) > 0 and String(member.get("class_id", "")) in MEDICAL_CLASSES:
            return true
    return false

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
        for value: Variant in party:
            var candidate: Dictionary = value
            if int(candidate.get("hp", 0)) > 0 and String(candidate.get("class_id", "")) in MEDICAL_CLASSES:
                selected_healer = candidate
                break
    if selected_healer.is_empty() or String(selected_healer.get("class_id", "")) not in MEDICAL_CLASSES:
        return {"ok": false, "reason": "no_living_healer"}
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
        injuries_changed.emit(character)
    return worsened

func _severity_rank(severity: String) -> int:
    return int(data.get("severities", {}).get(severity, {}).get("rank", 0))

func _next_severity(severity: String) -> String:
    match severity:
        "minor": return "serious"
        "serious": return "critical"
    return severity
