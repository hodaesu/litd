extends RefCounted
class_name VeilleursArchivesRuntime

var rules: Dictionary = {}
var entries: Dictionary = {}

func configure(value: Dictionary) -> void:
    rules = value.duplicate(true)

func ensure_entry(entry_id: String, entry_type: String, display_name: String = "") -> Dictionary:
    if entry_id == "":
        return {}
    if not entries.has(entry_id):
        entries[entry_id] = {
            "entry_id": entry_id,
            "entry_type": entry_type,
            "display_name": display_name,
            "knowledge_level": 0,
            "identity": {},
            "body": {},
            "combat": {},
            "history": [],
            "traces": [],
            "observations": [],
            "relations": [],
            "adaptations": []
        }
    return (entries[entry_id] as Dictionary).duplicate(true)

func record_identity(entry_id: String, entry_type: String, payload: Dictionary) -> Dictionary:
    var row := ensure_entry(entry_id, entry_type, str(payload.get("name", payload.get("display_name", ""))))
    row["identity"] = _merge_dict(row.get("identity", {}), payload)
    row["knowledge_level"] = maxi(int(row.get("knowledge_level", 0)), 1)
    entries[entry_id] = row
    return row.duplicate(true)

func record_body(entry_id: String, payload: Dictionary) -> Dictionary:
    if not entries.has(entry_id):
        ensure_entry(entry_id, "enemy")
    var row: Dictionary = entries[entry_id]
    row["body"] = _merge_dict(row.get("body", {}), payload)
    if payload.has("missing_parts") or payload.has("persistent_injuries"):
        row["knowledge_level"] = maxi(int(row.get("knowledge_level", 0)), 2)
    entries[entry_id] = row
    return row.duplicate(true)

func record_combat_observation(entry_id: String, observation: Dictionary) -> Dictionary:
    if not entries.has(entry_id):
        ensure_entry(entry_id, "enemy")
    var row: Dictionary = entries[entry_id]
    var observations: Array = (row.get("observations", []) as Array).duplicate(true)
    observations.append(observation.duplicate(true))
    observations = _bounded(observations, _bound("important_tactical_observations_per_entity", 8))
    row["observations"] = observations
    var combat: Dictionary = (row.get("combat", {}) as Dictionary).duplicate(true)
    var key := str(observation.get("skill_id", observation.get("pattern", "observation_%d" % observations.size())))
    combat[key] = observation.duplicate(true)
    row["combat"] = combat
    row["knowledge_level"] = maxi(int(row.get("knowledge_level", 0)), 1)
    entries[entry_id] = row
    return row.duplicate(true)

func record_history_event(entry_id: String, event: Dictionary) -> Dictionary:
    if not entries.has(entry_id):
        ensure_entry(entry_id, "enemy")
    var row: Dictionary = entries[entry_id]
    var history: Array = (row.get("history", []) as Array).duplicate(true)
    history.append(event.duplicate(true))
    history = _bounded(history, _bound("personal_events_per_entity", 6))
    row["history"] = history
    entries[entry_id] = row
    return row.duplicate(true)

func record_trace(entry_id: String, trace: Dictionary) -> Dictionary:
    if not entries.has(entry_id):
        ensure_entry(entry_id, "enemy")
    var row: Dictionary = entries[entry_id]
    var traces: Array = (row.get("traces", []) as Array).duplicate(true)
    traces.append(trace.duplicate(true))
    row["traces"] = _dedupe_by_id(traces, "trace_id")
    row["knowledge_level"] = maxi(int(row.get("knowledge_level", 0)), 2)
    entries[entry_id] = row
    return row.duplicate(true)

func record_relation(entry_id: String, relation: Dictionary) -> Dictionary:
    if not entries.has(entry_id):
        ensure_entry(entry_id, "enemy")
    var row: Dictionary = entries[entry_id]
    var relations: Array = (row.get("relations", []) as Array).duplicate(true)
    relations.append(relation.duplicate(true))
    row["relations"] = _bounded(_dedupe_by_id(relations, "relation_id"), _bound("relations_per_entity", 4))
    entries[entry_id] = row
    return row.duplicate(true)

func record_adaptation(entry_id: String, adaptation: Dictionary) -> Dictionary:
    if not entries.has(entry_id):
        ensure_entry(entry_id, "enemy")
    var row: Dictionary = entries[entry_id]
    var adaptations: Array = (row.get("adaptations", []) as Array).duplicate(true)
    adaptations.append(adaptation.duplicate(true))
    row["adaptations"] = _bounded(_dedupe_by_id(adaptations, "adaptation_id"), _bound("active_adaptations_per_entity", 4))
    row["knowledge_level"] = maxi(int(row.get("knowledge_level", 0)), 3)
    entries[entry_id] = row
    return row.duplicate(true)

func reveal_recruitment_clue(entry_id: String, clue: String) -> Dictionary:
    if not entries.has(entry_id):
        ensure_entry(entry_id, "enemy")
    var row: Dictionary = entries[entry_id]
    var identity: Dictionary = (row.get("identity", {}) as Dictionary).duplicate(true)
    var clues: Array = (identity.get("recruitment_clues", []) as Array).duplicate()
    if clue != "" and not clues.has(clue):
        clues.append(clue)
    identity["recruitment_clues"] = clues
    row["identity"] = identity
    row["knowledge_level"] = maxi(int(row.get("knowledge_level", 0)), 2)
    entries[entry_id] = row
    return row.duplicate(true)

func dossier(entry_id: String) -> Dictionary:
    return (entries.get(entry_id, {}) as Dictionary).duplicate(true)

func serialize() -> Dictionary:
    return {"entries": entries.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    entries = (payload.get("entries", {}) as Dictionary).duplicate(true)

func _bound(key: String, fallback: int) -> int:
    return int((rules.get("bounded_storage", {}) as Dictionary).get(key, fallback))

func _bounded(values: Array, maximum: int) -> Array:
    var result := values.duplicate(true)
    while result.size() > maximum:
        result.remove_at(0)
    return result

func _dedupe_by_id(values: Array, id_key: String) -> Array:
    var result: Array = []
    var seen: Dictionary = {}
    for value: Variant in values:
        if not (value is Dictionary):
            continue
        var row: Dictionary = value
        var key := str(row.get(id_key, ""))
        if key == "":
            result.append(row.duplicate(true))
            continue
        if seen.has(key):
            for index in range(result.size()):
                if str((result[index] as Dictionary).get(id_key, "")) == key:
                    result[index] = row.duplicate(true)
                    break
        else:
            seen[key] = true
            result.append(row.duplicate(true))
    return result

func _merge_dict(base_value: Variant, patch: Dictionary) -> Dictionary:
    var result: Dictionary = base_value.duplicate(true) if base_value is Dictionary else {}
    for key: Variant in patch.keys():
        result[key] = patch[key]
    return result
