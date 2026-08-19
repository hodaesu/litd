extends Node3D
class_name Chapter03BlockoutBuilder

const WORLD_PATH := "res://data/levels/chapter_03_world.json"
const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")
const EVIDENCE_SCRIPT := preload("res://scripts/world/chapter_03_evidence.gd")

@export var zone_id := "c03_abandoned_relay"
@export var spawn_player_placeholder := true
var world: Dictionary = {}
var zone: Dictionary = {}

func _ready() -> void:
    build_zone()

func build_zone() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(WORLD_PATH))
    world = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
    zone = _find_zone(zone_id)
    if zone.is_empty():
        push_error("Chapter03BlockoutBuilder: zone inconnue %s" % zone_id)
        return
    AshlandsRuntime.enter_zone(zone_id)
    _build_floor()
    _build_boundaries()
    _build_exits()
    _build_encounters()
    _build_evidence()
    _build_campfire()
    if spawn_player_placeholder:
        _build_player()

func _find_zone(id_value: String) -> Dictionary:
    for value in world.get("zones", []):
        var z: Dictionary = value
        if String(z.get("id", "")) == id_value:
            return z
    return {}

func _root() -> Node3D:
    var root := get_node_or_null("GeneratedChapter03") as Node3D
    if root == null:
        root = Node3D.new()
        root.name = "GeneratedChapter03"
        add_child(root)
    return root

func _build_floor() -> void:
    var size: Array = zone.get("size_m", [100,100])
    var body := StaticBody3D.new()
    _root().add_child(body)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(float(size[0]),0.5,float(size[1]))
    mesh.mesh = box
    mesh.position.y = -0.25
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box.size
    collision.shape = shape
    collision.position.y = -0.25
    body.add_child(collision)

func _build_boundaries() -> void:
    var size: Array = zone.get("size_m", [100,100])
    var w := float(size[0]); var d := float(size[1])
    _wall(Vector3(0,1,-d/2),Vector3(w,2,1)); _wall(Vector3(0,1,d/2),Vector3(w,2,1))
    _wall(Vector3(-w/2,1,0),Vector3(1,2,d)); _wall(Vector3(w/2,1,0),Vector3(1,2,d))

func _wall(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new(); body.position = pos; _root().add_child(body)
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; body.add_child(collision)

func _build_exits() -> void:
    var parent := Node3D.new(); parent.name = "Exits"; _root().add_child(parent)
    for value in zone.get("exits", []):
        var d: Dictionary = value
        var gate := ZoneTransitionGate.new(); gate.from_zone = zone_id; gate.to_zone = String(d.get("to","")); gate.gate_id = "%s_to_%s" % [zone_id,gate.to_zone]; gate.position = _vec3(d.get("position",[0,0,0])); _area(gate,Vector3(3,2.5,3)); parent.add_child(gate)

func _build_encounters() -> void:
    var parent := Node3D.new(); parent.name = "Encounters"; _root().add_child(parent)
    for value in zone.get("encounters", []):
        var d: Dictionary = value
        var trigger := EncounterTrigger.new(); trigger.encounter_id = String(d.get("id","")); trigger.encounter_type = String(d.get("type","normal")); trigger.position = _vec3(d.get("position",[0,0,0]))
        if trigger.encounter_id == "c03_threshold_sentinel": trigger.set_meta("miniboss", {"name":"La Sentinelle du Seuil","loot_tier":"major"})
        _area(trigger, Vector3(8,3,8) if trigger.encounter_type == "boss" else Vector3(5,2.5,5)); parent.add_child(trigger)

func _build_evidence() -> void:
    var parent := Node3D.new(); parent.name = "Evidence"; _root().add_child(parent)
    var ids: Array = zone.get("evidence", [])
    for i in ids.size():
        var node := EVIDENCE_SCRIPT.new() as Chapter03Evidence
        node.name = String(ids[i]); node.position = _evidence_position(i,ids.size()); node.configure(String(ids[i])); _area(node,Vector3(1.6,1.6,1.6)); parent.add_child(node)

func _evidence_position(index: int, count: int) -> Vector3:
    var angle: float = TAU * float(index) / maxf(1.0,float(count)); return Vector3(cos(angle)*18.0,0,sin(angle)*18.0)

func _build_campfire() -> void:
    if not bool(zone.get("campfire",false)): return
    var camp := CampfireInteraction.new(); camp.zone_id = zone_id; camp.position = Vector3.ZERO; _area(camp,Vector3(2.5,2,2.5)); _root().add_child(camp)

func _build_player() -> void:
    var party := PARTY_SCENE.instantiate(); party.name = "Chapter03PartyRuntime"; party.position = _vec3(zone.get("entry",[0,0,0])) + Vector3.UP*0.1; _root().add_child(party)

func _area(area: Area3D, size: Vector3) -> void:
    var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; collision.position.y = size.y*0.5; area.add_child(collision)

func _vec3(value: Variant) -> Vector3:
    if typeof(value) != TYPE_ARRAY or value.size() < 3: return Vector3.ZERO
    return Vector3(float(value[0]),float(value[1]),float(value[2]))
