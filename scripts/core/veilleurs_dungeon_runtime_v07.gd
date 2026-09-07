extends RefCounted
class_name VeilleursDungeonRuntimeV07

const ENCOUNTER_DIRECTOR_SCRIPT := preload("res://scripts/core/veilleurs_encounter_director.gd")

var content_db: Variant
var data: Dictionary = {}
var nodes_by_id: Dictionary = {}
var current_node := ""
var visited: Array[String] = []
var node_flags: Dictionary = {}
var active_encounter: Dictionary = {}
var encounter_director: VeilleursEncounterDirector
var run_seed := 0
var load_errors: Array[String] = []

func _init() -> void:
    encounter_director = ENCOUNTER_DIRECTOR_SCRIPT.new() as VeilleursEncounterDirector

func configure(db: Variant, dungeon_id: String) -> bool:
    content_db = db
    data = content_db.dungeon(dungeon_id) if content_db != null and content_db.has_method("dungeon") else {}
    nodes_by_id.clear()
    load_errors.clear()
    if data.is_empty():
        load_errors.append("missing_dungeon:%s" % dungeon_id)
        return false
    for value: Variant in data.get("nodes", []):
        if not (value is Dictionary):
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        var node_id := str(row.get("node_id", ""))
        if node_id == "" or nodes_by_id.has(node_id):
            load_errors.append("invalid_node:%s" % node_id)
            continue
        nodes_by_id[node_id] = row
    var entry := str(data.get("entry_node", ""))
    if not nodes_by_id.has(entry):
        load_errors.append("entry_missing")
    if not _terminal_reachable(entry):
        load_errors.append("terminal_unreachable")
    return load_errors.is_empty()

func start(seed: int = 0) -> Dictionary:
    if not load_errors.is_empty():
        return {"ok":false, "reason":"invalid_dungeon", "errors":load_errors.duplicate()}
    run_seed = seed if seed != 0 else posmod(str(data.get("dungeon_id", "dungeon")).hash(), 1000000) + 700000
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
        if str(node.get("kind", "")) == "boss":
            active_encounter = {"boss":true, "boss_id":str(node.get("boss_id", data.get("boss_id", ""))), "node_id":node_id, "dungeon_id":str(data.get("dungeon_id", ""))}
        else:
            active_encounter = encounter_director.next_encounter(str(node.get("family", "GOULES")), str(node.get("band", "LOW")), int(node.get("variant", 1)), _node_seed(node_id))
            active_encounter["node_id"] = node_id
            active_encounter["dungeon_id"] = str(data.get("dungeon_id", ""))
            active_encounter["memoriel_required"] = bool(node.get("memoriel_required", false))
        node["materialized_encounter"] = active_encounter.duplicate(true)
    return {"ok":true, "dungeon_id":str(data.get("dungeon_id", "")), "node":node, "visited":visited.duplicate(), "can_extract":bool(node.get("extraction", false))}

func complete_current(outcome: String = "cleared", context: Dictionary = {}) -> Dictionary:
    if current_node == "" or not nodes_by_id.has(current_node):
        return {"ok":false, "reason":"no_current_node"}
    var node: Dictionary = nodes_by_id[current_node]
    node_flags[current_node] = {"completed":true, "outcome":outcome, "context":context.duplicate(true)}
    var result := {"ok":true, "dungeon_id":str(data.get("dungeon_id", "")), "node_id":current_node, "outcome":outcome}
    if not active_encounter.is_empty() and not bool(active_encounter.get("boss", false)):
        var encounter_context := context.duplicate(true)
        encounter_context["region_id"] = str(data.get("dungeon_id", "")).to_lower()
        encounter_context["zone_id"] = current_node
        encounter_context["summary"] = str(context.get("summary", "%s — %s" % [str(node.get("title_fr", current_node)), outcome]))
        result["encounter_result"] = encounter_director.resolve_encounter(active_encounter, "victory" if outcome in ["cleared", "victory"] else outcome, "%s:%s" % [str(data.get("dungeon_id", "dungeon")), current_node], encounter_context)
    if str(node.get("kind", "")) in ["archive", "memory", "objective", "consequence", "boss"] and RemanenceRuntime != null:
        var severity := "major" if str(node.get("kind", "")) in ["objective", "boss", "consequence"] else "trace"
        result["scar_id"] = RemanenceRuntime.create_world_scar("%s:%s" % [str(data.get("dungeon_id", "dungeon")), current_node], "dungeon_%s" % str(node.get("kind", "room")), severity, {"region_id":str(data.get("dungeon_id", "")).to_lower(), "zone_id":current_node, "summary":"%s — %s" % [str(node.get("title_fr", current_node)), outcome], "protected":severity == "major"})
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

func current() -> Dictionary:
    return (nodes_by_id.get(current_node, {}) as Dictionary).duplicate(true)

func progress_summary() -> Dictionary:
    return {"dungeon_id":str(data.get("dungeon_id", "")), "current_node":current_node, "visited_count":visited.size(), "total_nodes":nodes_by_id.size(), "can_extract":can_extract(), "boss_id":str(data.get("boss_id", ""))}

func serialize() -> Dictionary:
    return {"version":"0.7.0", "dungeon_id":str(data.get("dungeon_id", "")), "run_seed":run_seed, "current_node":current_node, "visited":visited.duplicate(), "node_flags":node_flags.duplicate(true), "active_encounter":active_encounter.duplicate(true), "encounter_director":encounter_director.serialize()}

func deserialize(payload: Dictionary) -> bool:
    if str(payload.get("dungeon_id", "")) != str(data.get("dungeon_id", "")):
        return false
    run_seed = int(payload.get("run_seed", 0))
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

func _terminal_reachable(entry: String) -> bool:
    if entry == "":
        return false
    var queue: Array[String] = [entry]
    var seen: Dictionary = {}
    while not queue.is_empty():
        var node_id: String = queue.pop_front() as String
        if seen.has(node_id):
            continue
        seen[node_id] = true
        var node: Dictionary = nodes_by_id[node_id]
        if (node.get("next", []) as Array).is_empty() and str(node.get("kind", "")) in ["extraction", "consequence", "objective"]:
            return true
        for value: Variant in node.get("next", []):
            var next_id := str(value)
            if nodes_by_id.has(next_id) and not seen.has(next_id):
                queue.append(next_id)
    return false

func _node_seed(node_id: String) -> int:
    return run_seed + posmod(node_id.hash(), 100000)
