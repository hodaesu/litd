extends Area3D
class_name Chapter07Node

const WORLD_PATH := "res://data/levels/chapter_07_world.json"

var node_id := ""
var node_type := ""
var actor := ""
var consumed := false

func configure(id_value: String) -> void:
    node_id = id_value
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(WORLD_PATH))
    if typeof(parsed) != TYPE_DICTIONARY: return
    for value in parsed.get("nodes", []):
        var data: Dictionary = value
        if String(data.get("id", "")) != node_id: continue
        node_type = String(data.get("type", ""))
        actor = String(data.get("actor", ""))
        break
    consumed = _already_done()
    monitoring = not consumed
    visible = not consumed

func _already_done() -> bool:
    if node_type == "interview": return bool(Chapter07Runtime.interviews.get(actor, false))
    if node_type == "pilgrim_seal": return Chapter07Runtime.disabled_pilgrim_seals.has(node_id)
    if node_type == "counter_ritual": return Chapter07Runtime.counter_rituals.has(node_id)
    return false

func can_interact() -> bool:
    return node_id != "" and not consumed

func interact() -> void:
    if not can_interact(): return
    var success := false
    match node_type:
        "interview": success = Chapter07Runtime.interview_actor(actor)
        "pilgrim_seal": success = Chapter07Runtime.disable_pilgrim_seal(node_id)
        "counter_ritual": success = Chapter07Runtime.stabilize_counter_ritual(node_id)
    if success:
        consumed = true
        monitoring = false
        visible = false
