extends Node3D
class_name Chapter04BlockoutBuilder

const WORLD_PATH := "res://data/levels/chapter_04_world.json"
const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")
const FRAGMENT_SCRIPT := preload("res://scripts/world/chapter_04_fragment.gd")

@export var zone_id := "c04_buried_city"
@export var spawn_player_placeholder := true

var world: Dictionary = {}
var zone: Dictionary = {}

func _ready() -> void:
    build_zone()

func build_zone() -> void:
    world = _load_json(WORLD_PATH)
    zone = _find_zone(zone_id)
    if zone.is_empty():
        push_error("Chapter04BlockoutBuilder: zone inconnue %s" % zone_id)
        return
    AshlandsRuntime.enter_zone(zone_id)
    _build_floor()
    _build_boundaries()
    _build_exits()
    _build_encounters()
    _build_fragments()
    _build_campfire()
    if spawn_player_placeholder:
        _build_player()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _find_zone(id_value: String) -> Dictionary:
    for value in world.get("zones", []):
        var z: Dictionary = value
        if String(z.get("id", "")) == id_value: return z
    return {}

func _root() -> Node3D:
    var root := get_node_or_null("GeneratedChapter04") as Node3D
    if root == null:
        root = Node3D.new(); root.name = "GeneratedChapter04"; add_child(root)
    return root

func _build_floor() -> void:
    var size: Array = zone.get("size_m", [100,100])
    var body := StaticBody3D.new(); body.name = "Floor"; _root().add_child(body)
    var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(float(size[0]),0.5,float(size[1])); mesh.mesh = box; mesh.position.y = -0.25; body.add_child(mesh)
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = box.size; collision.shape = shape; collision.position.y = -0.25; body.add_child(collision)

func _build_boundaries() -> void:
    var size: Array = zone.get("size_m", [100,100]); var w := float(size[0]); var d := float(size[1])
    _wall(Vector3(0,1,-d/2),Vector3(w,2,1)); _wall(Vector3(0,1,d/2),Vector3(w,2,1)); _wall(Vector3(-w/2,1,0),Vector3(1,2,d)); _wall(Vector3(w/2,1,0),Vector3(1,2,d))

func _wall(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new(); body.position = pos; _root().add_child(body)
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; body.add_child(collision)

func _build_exits() -> void:
    for exit_value in zone.get("exits", []):
        var data: Dictionary = exit_value; var gate := ZoneTransitionGate.new(); gate.from_zone = zone_id; gate.to_zone = String(data.get("to", "")); gate.gate_id = "%s_to_%s" % [zone_id,gate.to_zone]; gate.position = _vec3(data.get("position", [0,0,0])); _area_box(gate,Vector3(3,2.5,3)); _root().add_child(gate)

func _build_encounters() -> void:
    for encounter_value in zone.get("encounters", []):
        var data: Dictionary = encounter_value; var trigger := EncounterTrigger.new(); trigger.encounter_id = String(data.get("id", "")); trigger.encounter_type = String(data.get("type", "normal")); trigger.position = _vec3(data.get("position", [0,0,0]));
        if data.has("name"): trigger.set_meta("miniboss", {"name":data.get("name"),"loot_tier":"major"})
        _area_box(trigger, Vector3(8,3,8) if trigger.encounter_type == "boss" else Vector3(5,2.5,5)); _root().add_child(trigger)

func _build_fragments() -> void:
    var ids: Array = zone.get("fragments", [])
    for i in ids.size():
        var fragment := FRAGMENT_SCRIPT.new() as Chapter04Fragment; fragment.name = String(ids[i]); fragment.position = _fragment_position(i,ids.size()); fragment.configure(String(ids[i])); _area_box(fragment,Vector3(1.6,1.6,1.6)); _root().add_child(fragment)

func _fragment_position(index: int, count: int) -> Vector3:
    var angle: float = TAU * float(index) / maxf(1.0,float(count)); return Vector3(cos(angle)*18.0,0,sin(angle)*18.0)

func _build_campfire() -> void:
    if not bool(zone.get("campfire", false)): return
    var camp := CampfireInteraction.new(); camp.zone_id = zone_id; camp.position = _vec3(zone.get("campfire_position", [0,0,0])); _area_box(camp,Vector3(2.5,2,2.5)); _root().add_child(camp)

func _build_player() -> void:
    var party := PARTY_SCENE.instantiate(); party.name = "Chapter04PartyRuntime"; party.position = _vec3(zone.get("entry", [0,0,0])) + Vector3.UP*0.1; _root().add_child(party)

func _area_box(area: Area3D, size: Vector3) -> void:
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; collision.position.y = size.y*0.5; area.add_child(collision)

func _vec3(value: Variant) -> Vector3:
    if typeof(value) != TYPE_ARRAY or value.size() < 3: return Vector3.ZERO
    return Vector3(float(value[0]),float(value[1]),float(value[2]))
