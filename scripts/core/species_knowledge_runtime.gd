extends RefCounted

const KNOWLEDGE_SCAR_TYPE := "species_knowledge"

static func ensure_species(species_id: String, species_name: String = "") -> Dictionary:
    if species_id == "":
        return {}
    var scar_id := _scar_id_for_species(species_id)
    if scar_id == "":
        scar_id = RemanenceRuntime.create_world_scar(
            "archives_species_%s" % species_id.to_snake_case(),
            KNOWLEDGE_SCAR_TYPE,
            "historical",
            {
                "protected": true,
                "species_id": species_id,
                "species_name": species_name if species_name != "" else species_id,
                "knowledge_level": 0,
                "evidence": [],
                "confirmed_facts": {},
                "observed_intent_families": [],
                "summary": "Les Archives commencent à rassembler des preuves sur %s." % (species_name if species_name != "" else species_id)
            }
        )
    return state(species_id)

static func state(species_id: String) -> Dictionary:
    var scar_id := _scar_id_for_species(species_id)
    if scar_id == "":
        return {}
    var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    var payload: Dictionary = (scar.get("payload", {}) as Dictionary).duplicate(true)
    payload["scar_id"] = scar_id
    return payload

static func record_evidence(species_id: String, evidence_type: String, context: Dictionary = {}) -> Dictionary:
    if species_id == "" or evidence_type == "":
        return {"ok": false, "reason": "invalid_evidence"}
    ensure_species(species_id, str(context.get("species_name", species_id)))
    var current := state(species_id)
    if current.is_empty():
        return {"ok": false, "reason": "knowledge_state_missing"}
    var scar_id := str(current.get("scar_id", ""))
    var evidence: Array = current.get("evidence", [])
    var evidence_key := str(context.get("evidence_key", evidence_type))
    var already_known := false
    for value: Variant in evidence:
        if value is Dictionary and str((value as Dictionary).get("key", "")) == evidence_key:
            already_known = true
            break
    if not already_known:
        evidence.append({
            "key": evidence_key,
            "type": evidence_type,
            "run_index": RemanenceRuntime.run_index,
            "source": str(context.get("source", "field")),
            "summary": str(context.get("summary", ""))
        })

    var facts: Dictionary = current.get("confirmed_facts", {})
    var incoming_facts: Dictionary = context.get("confirmed_facts", {})
    for key_value: Variant in incoming_facts.keys():
        facts[str(key_value)] = incoming_facts.get(key_value)

    var families: Array = current.get("observed_intent_families", [])
    var family := str(context.get("intent_family", ""))
    if family != "" and not families.has(family):
        families.append(family)

    current["evidence"] = evidence
    current["confirmed_facts"] = facts
    current["observed_intent_families"] = families
    current["knowledge_level"] = _level_for_evidence_count(evidence.size())
    current.erase("scar_id")
    _persist_payload(scar_id, current)
    var result := state(species_id)
    result["ok"] = true
    result["new_evidence"] = not already_known
    return result

static func intent_preview(enemy: Dictionary) -> Dictionary:
    var species_id := str(enemy.get("species_id", enemy.get("id", "unknown")))
    ensure_species(species_id, str(enemy.get("name", species_id)))
    var knowledge := state(species_id)
    var level := int(knowledge.get("knowledge_level", 0))
    var family := str(enemy.get("intent_family", enemy.get("intent", "menace incertaine")))
    if family == "":
        family = "menace incertaine"
    var preview := {
        "species_id": species_id,
        "knowledge_level": level,
        "detail": "qualitative",
        "text": _qualitative_intent(family),
        "confirmed_facts": {},
        "exact_values": {}
    }
    if level >= 1:
        preview["detail"] = "observed"
        preview["text"] = "Intention probable : %s" % family.replace("_", " ")
    if level >= 2:
        preview["confirmed_facts"] = (knowledge.get("confirmed_facts", {}) as Dictionary).duplicate(true)
    if level >= 4:
        preview["detail"] = "mastered"
        preview["exact_values"] = (enemy.get("knowledge_exact_values", {}) as Dictionary).duplicate(true)
    return preview

static func confirmed_information(species_id: String) -> Dictionary:
    var knowledge := state(species_id)
    return {
        "species_id": species_id,
        "knowledge_level": int(knowledge.get("knowledge_level", 0)),
        "mastered": int(knowledge.get("knowledge_level", 0)) >= 4,
        "confirmed_facts": (knowledge.get("confirmed_facts", {}) as Dictionary).duplicate(true),
        "observed_intent_families": (knowledge.get("observed_intent_families", []) as Array).duplicate(true)
    }

static func _scar_id_for_species(species_id: String) -> String:
    for value: Variant in RemanenceRuntime.world_scars.values():
        if not (value is Dictionary):
            continue
        var scar: Dictionary = value
        if str(scar.get("type", "")) != KNOWLEDGE_SCAR_TYPE:
            continue
        var payload: Dictionary = scar.get("payload", {})
        if str(payload.get("species_id", "")) == species_id:
            return str(scar.get("id", ""))
    return ""

static func _persist_payload(scar_id: String, payload: Dictionary) -> void:
    if scar_id == "" or not RemanenceRuntime.world_scars.has(scar_id):
        return
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload.duplicate(true), "protected": true, "severity": "historical"})

static func _level_for_evidence_count(count: int) -> int:
    if count >= 12:
        return 5
    if count >= 8:
        return 4
    if count >= 5:
        return 3
    if count >= 3:
        return 2
    if count >= 1:
        return 1
    return 0

static func _qualitative_intent(family: String) -> String:
    match family:
        "attack", "strike", "melee":
            return "La créature semble préparer une attaque."
        "guard", "defend":
            return "La créature semble se refermer ou protéger sa position."
        "move", "reposition":
            return "La créature semble vouloir changer de position."
        "support", "heal":
            return "La créature prépare quelque chose pour un allié."
        _:
            return "L'intention reste incertaine, mais un changement de comportement est perceptible."
