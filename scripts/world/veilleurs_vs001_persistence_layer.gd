extends Node3D
class_name VeilleursVS001PersistenceLayer

const CORPSE_PROXY_SCRIPT := preload("res://scripts/world/veilleurs_vs001_corpse_proxy.gd")

@export var blockout_path: NodePath = NodePath("../Blockout")

var blockout: VeilleursVS001BlockoutBuilder = null

func _ready() -> void:
    blockout = get_node_or_null(blockout_path) as VeilleursVS001BlockoutBuilder
    if not RemanenceRuntime.remanence_changed.is_connected(_request_rebuild):
        RemanenceRuntime.remanence_changed.connect(_request_rebuild)
    var persistence: VeilleursVS001PersistenceBridge = VeilleursVS001PlayableBridge.persistence_bridge
    if persistence != null and not persistence.persistent_world_changed.is_connected(_request_rebuild):
        persistence.persistent_world_changed.connect(_request_rebuild)
    call_deferred("rebuild")
    call_deferred("_restore_saved_party_position")

func _request_rebuild() -> void:
    call_deferred("rebuild")

func _restore_saved_party_position() -> void:
    if not VeilleursVS001PlayableBridge.has_saved_party_position():
        return
    await get_tree().process_frame
    var parties: Array[Node] = get_tree().get_nodes_in_group("player_party")
    if parties.is_empty() or not (parties[0] is Node3D):
        return
    (parties[0] as Node3D).global_position = VeilleursVS001PlayableBridge.resume_world_position()

func rebuild() -> void:
    for child: Node in get_children():
        remove_child(child)
        child.queue_free()
    if blockout == null:
        blockout = get_node_or_null(blockout_path) as VeilleursVS001BlockoutBuilder
    if blockout == null:
        return
    var scars: Array[Dictionary] = VeilleursVS001PlayableBridge.persistence_bridge.active_corpse_scars()
    var per_marker_counts: Dictionary = {}
    for scar: Dictionary in scars:
        if str(scar.get("type", "")) != "persistent_corpse":
            continue
        if str(scar.get("zone_id", scar.get("payload", {}).get("zone_id", ""))) != VeilleursVS001WorldRuntime.ZONE_ID:
            continue
        var marker_id: String = _marker_id_for_scar(scar)
        var marker: Marker3D = blockout.marker_node(marker_id)
        if marker == null:
            continue
        var index: int = int(per_marker_counts.get(marker_id, 0))
        per_marker_counts[marker_id] = index + 1
        _spawn_corpse(scar, marker, index)

func corpse_count() -> int:
    return get_tree().get_nodes_in_group("veilleurs_vs001_persistent_corpse").size()

func _spawn_corpse(scar: Dictionary, marker: Marker3D, index: int) -> void:
    var proxy: VeilleursVS001CorpseProxy = CORPSE_PROXY_SCRIPT.new() as VeilleursVS001CorpseProxy
    proxy.configure(scar)
    add_child(proxy)
    var offset := _corpse_offset(str(scar.get("id", "")), index)
    proxy.global_position = marker.global_position + offset

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "CorpseBody"
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.42
    capsule.height = 1.75
    mesh_instance.mesh = capsule
    mesh_instance.rotation_degrees.z = 90.0
    mesh_instance.position.y = 0.42
    proxy.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    collision.name = "CorpseInteraction"
    var shape := CapsuleShape3D.new()
    shape.radius = 0.55
    shape.height = 1.9
    collision.shape = shape
    collision.rotation_degrees.z = 90.0
    collision.position.y = 0.45
    proxy.add_child(collision)

    var payload: Dictionary = scar.get("payload", {})
    proxy.set_meta("body_snapshot", payload.get("body_snapshot", {}).duplicate(true))
    proxy.set_meta("combat_id", str(payload.get("combat_id", "")))
    proxy.set_meta("age_stage", str(scar.get("age_stage", "fresh")))

func _marker_id_for_scar(scar: Dictionary) -> String:
    var payload: Dictionary = scar.get("payload", {})
    var explicit := str(payload.get("vs001_marker_id", ""))
    if not explicit.is_empty():
        return explicit
    var source_anchor := str(scar.get("anchor_id", ""))
    for anchor_value: Variant in blockout.physical_map.get("gameplay_anchors", []):
        if not (anchor_value is Dictionary):
            continue
        var anchor: Dictionary = anchor_value
        if str(anchor.get("source_anchor", "")) == source_anchor:
            return str(anchor.get("id", ""))
    return "s3_corpses"

func _corpse_offset(scar_id: String, index: int) -> Vector3:
    var signature: int = absi(scar_id.hash()) + index * 31
    var x: float = float((signature % 5) - 2) * 0.72
    var row: int = int(signature / 5) % 5
    var z: float = float(row - 2) * 0.62
    return Vector3(x, 0.0, z)
