extends Node3D
class_name DeepVestigeBlockoutBuilder

const DATA_PATH := "res://data/levels/vestige_ashai_seven_resonances.json"
const PARTY_SCENE := preload("res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn")
const FRAGMENT_SCRIPT := preload("res://scripts/world/deep_vestige_fragment.gd")

@export var zone_id := "va01_threshold_gallery"
@export var spawn_player_placeholder := true
var data: Dictionary = {}
var zone: Dictionary = {}

func _ready() -> void:
    data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    for value in data.get("zones", []):
        if String(value.get("id", "")) == zone_id:
            zone = value
            break
    if zone.is_empty(): return
    AshlandsRuntime.enter_zone(zone_id)
    _floor(); _exits(); _encounters(); _fragments(); _campfire()
    if spawn_player_placeholder: _player()

func _floor() -> void:
    var s:Array = zone.get("size_m", [90,70]); var body:=StaticBody3D.new(); add_child(body)
    var mesh:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(float(s[0]),0.5,float(s[1])); mesh.mesh=box; mesh.position.y=-0.25; body.add_child(mesh)
    var c:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=box.size; c.shape=shape; c.position.y=-0.25; body.add_child(c)

func _exits() -> void:
    for value in zone.get("exits", []):
        var d:Dictionary=value; var gate:=ZoneTransitionGate.new(); gate.from_zone=zone_id; gate.to_zone=String(d.get("to","")); gate.gate_id="%s_to_%s" % [zone_id,gate.to_zone]; gate.position=_v(d.get("position",[0,0,0])); _area(gate,Vector3(3,2.5,3)); add_child(gate)

func _encounters() -> void:
    for value in zone.get("encounters", []):
        var d:Dictionary=value; var t:=EncounterTrigger.new(); t.encounter_id=String(d.get("id","")); t.encounter_type=String(d.get("type","normal")); t.position=_v(d.get("position",[0,0,0]));
        if d.has("name"): t.set_meta("miniboss",{"name":d.get("name"),"loot_tier":"major"})
        _area(t,Vector3(8,3,8) if t.encounter_type=="boss" else Vector3(5,2.5,5)); add_child(t)

func _fragments() -> void:
    var ids:Array=zone.get("fragments",[])
    for i in ids.size():
        var f:=FRAGMENT_SCRIPT.new() as DeepVestigeFragment; f.configure(String(ids[i])); f.position=Vector3(-16.0 + i*12.0,0,4.0); _area(f,Vector3(1.5,1.5,1.5)); add_child(f)

func _campfire() -> void:
    if not bool(zone.get("campfire",false)): return
    var c:=CampfireInteraction.new(); c.zone_id=zone_id; c.position=_v(zone.get("campfire_position",[0,0,0])); _area(c,Vector3(2.5,2,2.5)); add_child(c)

func _player() -> void:
    var p:=PARTY_SCENE.instantiate(); p.add_to_group("player_party"); p.position=_v(zone.get("entry",[0,0,0]))+Vector3.UP*0.1; add_child(p)

func _area(a:Area3D,size:Vector3)->void:
    var c:=CollisionShape3D.new(); var s:=BoxShape3D.new(); s.size=size; c.shape=s; c.position.y=size.y*0.5; a.add_child(c)

func _v(value:Variant)->Vector3:
    return Vector3(float(value[0]),float(value[1]),float(value[2])) if typeof(value)==TYPE_ARRAY and value.size()>=3 else Vector3.ZERO
