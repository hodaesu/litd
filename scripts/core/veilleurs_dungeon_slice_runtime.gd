extends RefCounted
class_name VeilleursDungeonSliceRuntime

const SLICE_PATH := "res://data/veilleurs/v06/dungeon_slice_01_khar_sen.json"
const ENCOUNTER_DIRECTOR_SCRIPT := preload("res://scripts/core/veilleurs_encounter_director.gd")

var data: Dictionary = {}
var nodes_by_id: Dictionary = {}
var current_node := ""
var visited: Array[String] = []
var node_flags: Dictionary = {}
var active_encounter: Dictionary = {}
var encounter_director: VeilleursEncounterDirector
var load_errors: Array[String] = []

func _init() -> void:
    encounter_director = ENCOUNTER_DIRECTOR_SCRIPT.new() as VeilleursEncounterDirector
    _load()

func start() -> Dictionary:
    if not load_errors.is_empty():
        return {"ok":false, "reason":"invalid_slice", "errors":load_errors.duplicate()}
    current_node = str(data.get("entry_node", ""))
    visited.clear()
    node_flags.clear()
    active_encounter.clear()
    return enter(current_node)

func enter(node_id: String) -> Dictionary:
    if not nodes_by_id.has(node_id):
        return {"ok":false, "reason":"unknown_node", "node_id":node_id}
    current_node = node_id
    if not visited.has(node_id):
        visited.append(node_id)
    var node: Dictionary = (nodes_by_id[node_id] as Dictionary).duplicate(true)
    active_encounter.clear()
    if bool(node.get("encounter", false)):
        active_encounter = encounter_director.next_encounter(str(node.get("family", "GOULES")), str(node.get("band", "LOW")), int(node.get("variant", 1)), _node_seed(node_id))
        active_encounter["slice_node_id"] = node_id
        active_encounter["memoriel_required"] = bool(node.get("memoriel_required", false))
        node["materialized_encounter"] = active_encounter.duplicate(true)
    return {"ok":true, "node":node, "visited":visited.duplicate(), "can_extract":bool(node.get("extraction", false))}

func complete_current(outcome: String = "cleared", context: Dictionary = {}) -> Dictionary:
    if current_node == "" or not nodes_by_id.has(current_node):
        return {"ok":false, "reason":"no_current_node"}
    var node: Dictionary = nodes_by_id[current_node]
    node_flags[current_node] = {"completed":true, "outcome":outcome}
    var result := {"ok":true, "node_id":current_node, "outcome":outcome}
    if not active_encounter.is_empty():
        var remanence_outcome := "victory" if outcome in ["cleared", "victory"] else outcome
        var encounter_result := encounter_director.resolve_encounter(active_encounter, remanence_outcome, "%s:%s" % [str(data.get("slice_id", "slice")), current_node], {
            "region_id":"khar_sen",
            "zone_id":current_node,
            "summary":"Khar-Sen %s — %s" % [str(node.get("title_fr", current_node)), outcome]
        })
        result["encounter_result"] = encounter_result
    if str(node.get("kind", "")) in ["archive", "memory", "objective"]:
        var scar_id := RemanenceRuntime.create_world_scar("%s:%s" % [str(data.get("slice_id", "slice")), current_node], "dungeon_%s" % str(node.get("kind", "room")), "trace" if str(node.get("kind", "")) != "objective" else "major", {
            "region_id":"khar_sen",
            "zone_id":current_node,
            "summary":"%s — %s" % [str(node.get("title_fr", current_node)), outcome],
            "protected":str(node.get("kind", "")) == "objective"
        })
        result["scar_id"] = scar_id
    active_encounter.clear()
    return result

func available_next() -> Array[String]:
    if current_node == "" or not nodes_by_id.has(current_node):
        return []
    var result: Array[String] = []
    for value: Variant in (nodes_by_id[current_node] as Dictionary).get("next", []):
        result.append(str(value))
    return result

func choose_next(node_id: String) -> Dictionary:
    if not available_next().has(node_id):
        return {"ok":false, "reason":"invalid_transition", "from":current_node, "to":node_id}
    return enter(node_id)

func can_extract() -> bool:
    return current_node != "" and nodes_by_id.has(current_node) and bool((nodes_by_id[current_node] as Dictionary).get("extraction", false))

func progress_summary() -> Dictionary:
    return {
        "slice_id":str(data.get("slice_id", "")),
        "current_node":current_node,
        "visited_count":visited.size(),
        "total_nodes":nodes_by_id.size(),
        "objective_reached":visited.has("KHAR_09"),
        "can_extract":can_extract(),
        "world_scars":RemanenceRuntime.world_scars.size()
    }

func serialize() -> Dictionary:
    return {
        "version":"0.6.1",
        "slice_id":str(data.get("slice_id", "")),
        "current_node":current_node,
        "visited":visited.duplicate(),
        "node_flags":node_flags.duplicate(true),
        "active_encounter":active_encounter.duplicate(true),
        "encounter_director":encounter_director.serialize()
    }

func deserialize(payload: Dictionary) -> bool:
    if str(payload.get("slice_id", "")) != str(data.get("slice_id", "")):
        return false
    current_node = str(payload.get("current_node", ""))
    if current_node != "" and not nodes_by_id.has(current_node):
        return false
    visited.clear()
    for value: Variant in payload.get("visited", []):
        var node_id := str(value)
        if nodes_by_id.has(node_id):
            visited.append(node_id)
    node_flags = (payload.get("node_flags", {}) as Dictionary).duplicate(true)
    active_encounter = (payload.get("active_encounter", {}) as Dictionary).duplicate(true)
    encounter_director.deserialize(payload.get("encounter_director", {}))
    return true

func _load() -> void:
    if not FileAccess.file_exists(SLICE_PATH):
        load_errors.append("missing_slice")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLICE_PATH))
    if not (parsed is Dictionary):
        load_errors.append("invalid_json")
        return
    data = parsed as Dictionary
    nodes_by_id.clear()
    for value: Variant in data.get("nodes", []):
        if not (value is Dictionary):
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        var node_id := str(row.get("node_id", ""))
        if node_id == "" or nodes_by_id.has(node_id):
            load_errors.append("duplicate_or_empty_node:%s" % node_id)
            continue
        nodes_by_id[node_id] = row
    if nodes_by_id.size() != 9:
        load_errors.append("node_count:%d" % nodes_by_id.size())
    var entry := str(data.get("entry_node", ""))
    if not nodes_by_id.has(entry):
        load_errors.append("entry_missing")
    for node_id_value: Variant in nodes_by_id.keys():
        var node_id := str(node_id_value)
        for next_value: Variant in (nodes_by_id[node_id] as Dictionary).get("next", []):
            if not nodes_by_id.has(str(next_value)):
                load_errors.append("bad_edge:%s:%s" % [node_id, str(next_value)])
    if not _objective_reachable(entry):
        load_errors.append("objective_unreachable")

func _objective_reachable(entry: String) -> bool:
    if entry == "":
        return false
    var queue: Array[String] = [entry]
    var seen: Dictionary = {}
    while not queue.is_empty():
        var node_id := queue.pop_front()
        if seen.has(node_id):
            continue
        seen[node_id] = true
        if str((nodes_by_id[node_id] as Dictionary).get("kind", "")) == "objective":
            return true
        for value: Variant in (nodes_by_id[node_id] as Dictionary).get("next", []):
            var next_id := str(value)
            if nodes_by_id.has(next_id) and not seen.has(next_id):
                queue.append(next_id)
    return false

func _node_seed(node_id: String) -> int:
    return int(data.get("seed", 606101)) + posmod(node_id.hash(), 100000)
