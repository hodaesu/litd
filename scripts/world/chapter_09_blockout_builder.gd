extends Node3D
class_name Chapter09BlockoutBuilder

const WORLD_PATH := "res://data/levels/chapter_09_world.json"
const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")
const OBS_SCRIPT := preload("res://scripts/world/chapter_09_observation.gd")
const NODE_SCRIPT := preload("res://scripts/world/chapter_09_node.gd")

@export var zone_id := "c09_tree_node"
@export var spawn_player_placeholder := true

var world: Dictionary = {}
var zone: Dictionary = {}

func _ready() -> void:
    build_zone()

func build_zone() -> void:
    world = _load_json(WORLD_PATH)
    zone = _find_zone(zone_id)
    if zone.is_empty():
        push_error("Chapter09BlockoutBuilder: zone inconnue %s" % zone_id)
        return
    AshlandsRuntime.enter_zone(zone_id)
    _floor(); _boundaries(); _exits(); _encounters(); _observations(); _nodes(); _campfire()
    if spawn_player_placeholder: _player()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _find_zone(id_value: String) -> Dictionary:
    for value in world.get("zones", []):
        var entry: Dictionary = value
        if String(entry.get("id", "")) == id_value: return entry
    return {}

func _root() -> Node3D:
    var root := get_node_or_null("GeneratedChapter09") as Node3D
    if root == null:
        root = Node3D.new(); root.name = "GeneratedChapter09"; add_child(root)
    return root

func _floor() -> void:
    var size: Array = zone.get("size_m", [110,90])
    var body := StaticBody3D.new(); body.name = "Floor"; _root().add_child(body)
    var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(float(size[0]),0.5,float(size[1])); mesh.mesh = box; mesh.position.y = -0.25; body.add_child(mesh)
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = box.size; collision.shape = shape; collision.position.y = -0.25; body.add_child(collision)

func _boundaries() -> void:
    var size: Array = zone.get("size_m", [110,90]); var w := float(size[0]); var d := float(size[1])
    _wall(Vector3(0,1,-d/2),Vector3(w,2,1)); _wall(Vector3(0,1,d/2),Vector3(w,2,1)); _wall(Vector3(-w/2,1,0),Vector3(1,2,d)); _wall(Vector3(w/2,1,0),Vector3(1,2,d))

func _wall(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new(); body.position = pos; _root().add_child(body)
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; body.add_child(collision)

func _exits() -> void:
    for value in zone.get("exits", []):
        var d: Dictionary = value
        var gate := ZoneTransitionGate.new(); gate.from_zone = zone_id; gate.to_zone = String(d.get("to", "")); gate.gate_id = "%s_to_%s" % [zone_id,gate.to_zone]; gate.position = _v(d.get("position",[0,0,0])); _area(gate,Vector3(3,2.5,3)); _root().add_child(gate)

func _encounters() -> void:
    for value in zone.get("encounters", []):
        var d: Dictionary = value
        var trigger := EncounterTrigger.new(); trigger.encounter_id = String(d.get("id", "")); trigger.encounter_type = String(d.get("type", "normal")); trigger.position = _v(d.get("position", [0,0,0]))
        if d.has("name"): trigger.set_meta("miniboss", {"name":d.get("name"),"loot_tier":"major"})
        _area(trigger,Vector3(8,3,8) if trigger.encounter_type == "boss" else Vector3(5,2.5,5)); _root().add_child(trigger)

func _observations() -> void:
    var ids: Array = zone.get("observations", [])
    for i in ids.size():
        var item := OBS_SCRIPT.new() as Chapter09Observation
        item.name = String(ids[i]); item.position = Vector3(-24.0 + float(i % 4) * 16.0,0,-12.0 + float(i / 4) * 20.0); item.configure(String(ids[i])); _area(item,Vector3(1.6,1.6,1.6)); _root().add_child(item)

func _nodes() -> void:
    for node_id_value in zone.get("nodes", []):
        var node_id := String(node_id_value); var data := _node_data(node_id)
        if data.is_empty(): continue
        var node := NODE_SCRIPT.new() as Chapter09Node; node.name = node_id; node.position = _v(data.get("position",[0,0,0])); node.configure(node_id); _area(node,Vector3(2.2,2.2,2.2)); _root().add_child(node)

func _node_data(node_id: String) -> Dictionary:
    for value in world.get("nodes", []):
        var data: Dictionary = value
        if String(data.get("id", "")) == node_id: return data
    return {}

func _campfire() -> void:
    if not bool(zone.get("campfire", false)): return
    var camp := CampfireInteraction.new(); camp.zone_id = zone_id; camp.position = _v(zone.get("campfire_position",[0,0,0])); _area(camp,Vector3(2.5,2,2.5)); _root().add_child(camp)

func _player() -> void:
    var party := PARTY_SCENE.instantiate(); party.name = "Chapter09PartyRuntime"; party.position = _v(zone.get("entry",[0,0,0])) + Vector3.UP * 0.1; _root().add_child(party)

func _area(area: Area3D, size: Vector3) -> void:
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; collision.position.y = size.y * 0.5; area.add_child(collision)

func _v(value: Variant) -> Vector3:
    return Vector3(float(value[0]),float(value[1]),float(value[2])) if typeof(value) == TYPE_ARRAY and value.size() >= 3 else Vector3.ZERO
