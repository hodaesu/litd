extends Node

const BLOCKOUT_SCENE := preload("res://scenes/world/veilleurs/voices_under_sanctuary_blockout.tscn")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var blockout: Node3D = BLOCKOUT_SCENE.instantiate() as Node3D
    _check(blockout != null, "VS001 physical blockout scene must instantiate")
    if blockout == null:
        _finish()
        return
    add_child(blockout)
    await get_tree().process_frame

    var summary: Dictionary = blockout.call("layout_summary")
    _check(bool(summary.get("ready", false)), "VS001 physical layout must build on ready")
    _check(int(summary.get("rooms", 0)) == 8, "VS001 physical layout must instantiate S1-S8")
    _check(int(summary.get("connections", 0)) == 7, "VS001 physical layout must instantiate seven logical connections")
    _check(int(summary.get("anchors", 0)) == 17, "VS001 physical layout must expose all seventeen authored gameplay anchors")
    _check(int(summary.get("mesh_instances", 999)) <= 180, "VS001 proxy geometry must stay inside the mobile mesh budget")
    _check(int(summary.get("collision_shapes", 999)) <= 180, "VS001 proxy collisions must stay inside the mobile collision budget")
    _check(bool(summary.get("physical_retreat_s7_to_s1", false)), "S7 must retain a physical retreat path to S1")
    _check(bool(summary.get("secret_connection_hidden", false)), "S7-S8 secret connection must begin hidden")

    var room_ids: Array[String] = [
        "s1_vestibule",
        "s2_rope_gallery",
        "s3_sleepers",
        "s4_forgotten_store",
        "s5_fractured_crypt",
        "s6_survivor",
        "s7_voice_chamber",
        "s8_lower_archive"
    ]
    for room_id: String in room_ids:
        var room: Node3D = blockout.call("room_node", room_id) as Node3D
        _check(room != null, "Physical room missing: %s" % room_id)
        if room == null:
            continue
        var floor: Node = room.get_node_or_null("Floor")
        _check(floor != null, "Physical room must have floor: %s" % room_id)
        if floor != null:
            _check(floor.find_child("CollisionShape", true, false) is CollisionShape3D, "Physical floor must have collision: %s" % room_id)
        _check(str(room.get_meta("blender_asset_slot", "")) != "", "Physical room must expose stable Blender slot: %s" % room_id)

    var s1: Node3D = blockout.call("room_node", "s1_vestibule") as Node3D
    var s4: Node3D = blockout.call("room_node", "s4_forgotten_store") as Node3D
    var s6: Node3D = blockout.call("room_node", "s6_survivor") as Node3D
    var s7: Node3D = blockout.call("room_node", "s7_voice_chamber") as Node3D
    var s8: Node3D = blockout.call("room_node", "s8_lower_archive") as Node3D
    if s1 != null:
        _check(s1.get_meta("dimensions_m", Vector3.ZERO) == Vector3(12.0, 4.0, 10.0), "S1 dimensions must stay 12x4x10 m")
        _check(s1.get_node_or_null("EastWall") == null, "S1 east wall must contain a physical doorway gap")
        _check(s1.get_node_or_null("EastWallNorth") != null and s1.get_node_or_null("EastWallSouth") != null, "S1 east doorway must retain side wall segments")
    if s4 != null:
        _check(bool(s4.get_meta("optional", false)), "S4 must remain an optional physical branch")
        _check(s4.get_node_or_null("SouthWall") != null, "S4 dead end must stay physically closed on the south side")
    if s6 != null:
        _check(bool(s6.get_meta("optional", false)), "S6 must remain an optional physical branch")
    if s7 != null:
        _check(s7.get_meta("dimensions_m", Vector3.ZERO) == Vector3(20.0, 6.0, 16.0), "S7 objective chamber must stay 20x6x16 m")
    if s8 != null:
        _check(bool(s8.get_meta("secret", false)), "S8 must remain a secret physical room")
        _check(is_equal_approx(s8.position.y, -4.0), "S8 must be physically four meters below the principal level")

    _check(bool(blockout.call("path_exists", "s7_voice_chamber", "s1_vestibule", false)), "Critical path must support backtracking from S7 to S1")
    _check(not bool(blockout.call("path_exists", "s1_vestibule", "s8_lower_archive", false)), "S8 must not be reachable before revealing the secret")
    _check(bool(blockout.call("path_exists", "s1_vestibule", "s8_lower_archive", true)), "S8 must become physically connected when secret traversal is allowed")

    var secret_connection: Node3D = blockout.call("connection_node", "c_s7_s8") as Node3D
    _check(secret_connection != null, "S7-S8 secret stair must exist physically")
    if secret_connection != null:
        _check(not secret_connection.visible, "Secret stair proxy must begin invisible")
        _check(bool(secret_connection.get_meta("secret", false)), "S7-S8 connection must carry secret metadata")
        _check(str(secret_connection.get_meta("locked_by", "")) == "s7_study_acoustic_device", "Secret stair must be locked by studying the S7 acoustic device")
        var middle_waypoint: Marker3D = secret_connection.get_node_or_null("Waypoint_02") as Marker3D
        _check(middle_waypoint != null and is_equal_approx(middle_waypoint.position.y, -2.0), "Secret stair must descend physically between S7 and S8")

    _check_marker(blockout, "s2_tripwire", "s2_rope_gallery", "hazard")
    _check_marker(blockout, "s3_combat", "s3_sleepers", "combat")
    _check_marker(blockout, "s5_scout_corpse", "s5_fractured_crypt", "corpse")
    _check_marker(blockout, "s6_survivor", "s6_survivor", "recruitment")
    _check_marker(blockout, "s7_acoustic_device", "s7_voice_chamber", "objective_device")
    _check_marker(blockout, "s7_secret_stair", "s7_voice_chamber", "secret_reveal")
    _check_marker(blockout, "s8_archive", "s8_lower_archive", "secret_archive")
    _check_marker(blockout, "s8_fragment", "s8_lower_archive", "knowledge")

    var navigation: Node = blockout.find_child("NavigationProxy", true, false)
    _check(navigation is NavigationRegion3D, "VS001 physical blockout must expose a NavigationRegion3D proxy")
    if navigation != null:
        _check(bool(navigation.get_meta("requires_bake_after_art_pass", false)), "Navigation proxy must explicitly require a final bake after art integration")

    blockout.queue_free()
    _finish()

func _check_marker(blockout: Node3D, marker_id: String, room_id: String, role: String) -> void:
    var marker: Marker3D = blockout.call("marker_node", marker_id) as Marker3D
    _check(marker != null, "Gameplay marker missing: %s" % marker_id)
    if marker == null:
        return
    _check(str(marker.get_meta("room_id", "")) == room_id, "Gameplay marker room mismatch: %s" % marker_id)
    _check(str(marker.get_meta("gameplay_role", "")) == role, "Gameplay marker role mismatch: %s" % marker_id)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_VS001_PHYSICAL_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_VS001_PHYSICAL_SMOKE: " + failure)
    print("VEILLEURS_VS001_PHYSICAL_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
