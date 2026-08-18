extends Area3D
class_name Chapter06ResonanceNode

const WORLD_PATH := "res://data/levels/chapter_06_world.json"

var node_id := ""
var node_type := ""
var label := ""
var consumed := false

func configure(id_value: String) -> void:
    node_id = id_value
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(WORLD_PATH))
    if typeof(parsed) != TYPE_DICTIONARY: return
    for value in parsed.get("nodes", []):
        var data: Dictionary = value
        if String(data.get("id", "")) != node_id: continue
        node_type = String(data.get("type", ""))
        label = String(data.get("label", node_id))
        break
    consumed = _already_done()
    monitoring = not consumed
    visible = not consumed

func _already_done() -> bool:
    if node_type == "anchor": return Chapter06Runtime.stabilized_anchors.has(node_id)
    if node_type == "creature_resonance": return Chapter06Runtime.reaction_records.has(node_id)
    if node_type == "contact": return Chapter06Runtime.saen_contact
    return false

func can_interact() -> bool:
    return node_id != "" and not consumed

func interact() -> void:
    if not can_interact(): return
    var success := false
    match node_type:
        "anchor": success = Chapter06Runtime.stabilize_anchor(node_id)
        "creature_resonance": success = Chapter06Runtime.record_creature_reaction(node_id)
        "contact": success = Chapter06Runtime.establish_saen_contact()
    if success:
        consumed = true
        monitoring = false
        visible = false
