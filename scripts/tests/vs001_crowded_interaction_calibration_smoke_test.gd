extends Node

const PLAYABLE_SCENE := preload("res://scenes/world/veilleurs/voices_under_sanctuary_playable.tscn")

var failures: Array[String] = []
var world: Node3D = null
var party: ExplorationPartyController = null
var proxies: Node = null

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    VeilleursVS001WorldRuntime.reset_new_game()
    world = PLAYABLE_SCENE.instantiate() as Node3D
    add_child(world)
    await get_tree().process_frame
    await get_tree().physics_frame

    party = world.get_node_or_null("VeilleursPartyProxy") as ExplorationPartyController
    proxies = world.get_node_or_null("InteractionProxies")
    _check(party != null, "real VS001 scene spawns the exploration party controller")
    _check(proxies != null, "real VS001 scene builds interaction proxies")
    if party == null or proxies == null:
        _finish()
        return

    party.set_physics_process(false)
    _check(proxies.get_child_count() == 16, "real VS001 exposes the expected 16 playable interaction anchors")
    _check(world.find_children("InteractionTargetIndicator", "", true, false).size() == 1, "real VS001 keeps exactly one world interaction indicator")

    await _assert_pair_focus(
        "s2_tripwire", "s2_salvage",
        "anchor:s2_tripwire", EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "S2 armed tripwire wins ambiguous focus over dormant salvage"
    )

    VeilleursVS001WorldRuntime.session.state["s2_tripwire"] = "disarmed"
    await _assert_pair_focus(
        "s2_tripwire", "s2_salvage",
        "anchor:s2_salvage", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "S2 salvage takes focus after the tripwire is neutralized"
    )

    VeilleursVS001WorldRuntime.cleared_encounters["vs001_s3_ghouls"] = false
    await _assert_pair_focus(
        "s3_combat", "s3_corpses",
        "anchor:s3_combat", EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "S3 unresolved combat wins focus over corpses"
    )

    VeilleursVS001WorldRuntime.cleared_encounters["vs001_s3_ghouls"] = true
    await _assert_pair_focus(
        "s3_combat", "s3_corpses",
        "anchor:s3_corpses", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "S3 corpses surface after combat while cleared combat recedes"
    )

    VeilleursVS001WorldRuntime.claimed_loot.erase("s4")
    await _assert_pair_focus(
        "s4_supplies", "s4_black_basin",
        "anchor:s4_supplies", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "S4 actionable supplies win ambiguous focus over the basin curio"
    )

    VeilleursVS001WorldRuntime.claimed_loot["s4"] = true
    await _assert_pair_focus(
        "s4_supplies", "s4_black_basin",
        "", EnvironmentInteractionContract.SALIENCE_INSPECT,
        "S4 resolved optional content leaves only a single discreet inspect focus"
    )

    VeilleursVS001WorldRuntime.claimed_loot.erase("s8")
    await _assert_pair_focus(
        "s8_archive", "s8_fragment",
        "anchor:s8_fragment", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "S8 collectible fragment wins ambiguous focus over archive reading"
    )

    _finish()

func _assert_pair_focus(
    anchor_a: String,
    anchor_b: String,
    expected_interaction_id: String,
    expected_salience: String,
    label: String
) -> void:
    var first := proxies.get_node_or_null("Interact_%s" % anchor_a) as Node3D
    var second := proxies.get_node_or_null("Interact_%s" % anchor_b) as Node3D
    _check(first != null and second != null, "%s: both real proxies exist" % label)
    if first == null or second == null:
        return

    var pose := _ambiguous_pose(first.global_position, second.global_position)
    party.global_position = pose.get("position", Vector3.ZERO)
    var midpoint: Vector3 = pose.get("midpoint", Vector3.ZERO)
    party.look_at(Vector3(midpoint.x, party.global_position.y, midpoint.z), Vector3.UP)
    party.velocity = Vector3.ZERO
    party._set_interaction_target(null, {})
    await get_tree().physics_frame

    var candidates: Array[Dictionary] = party._collect_interaction_candidates()
    var candidate_ids: Array[String] = []
    for candidate: Dictionary in candidates:
        var descriptor: Dictionary = candidate.get("descriptor", {})
        candidate_ids.append(str(descriptor.get("interaction_id", "")))
    _check(candidate_ids.has("anchor:%s" % anchor_a), "%s: first interaction is simultaneously in range" % label)
    _check(candidate_ids.has("anchor:%s" % anchor_b), "%s: second interaction is simultaneously in range" % label)

    party._refresh_interaction_target()
    var descriptor := party.get_interaction_descriptor()
    var selected_id := str(descriptor.get("interaction_id", ""))
    if not expected_interaction_id.is_empty():
        _check(selected_id == expected_interaction_id, "%s: expected %s, got %s" % [label, expected_interaction_id, selected_id])
    _check(str(descriptor.get("salience", "")) == expected_salience, "%s: selected salience is %s" % [label, expected_salience])

    var indicator := party.get_node_or_null("InteractionTargetIndicator") as InteractionTargetIndicator
    _check(indicator != null and indicator.visible, "%s: exactly one active marker remains visible" % label)
    if indicator != null:
        _check(indicator.get_salience() == expected_salience, "%s: marker presentation matches selected salience" % label)
        var selected_target := indicator.get_target()
        _check(selected_target == first or selected_target == second, "%s: marker stays attached to one of the competing real anchors" % label)

func _ambiguous_pose(first: Vector3, second: Vector3) -> Dictionary:
    var a := Vector3(first.x, 0.0, first.z)
    var b := Vector3(second.x, 0.0, second.z)
    var midpoint := (a + b) * 0.5
    var segment := b - a
    var separation := segment.length()
    var radius := 2.10
    var half := separation * 0.5
    var perpendicular := Vector3(-segment.z, 0.0, segment.x).normalized()
    var offset := sqrt(maxf(0.04, radius * radius - half * half))
    var position := midpoint + perpendicular * offset
    var proxy_y := (first.y + second.y) * 0.5
    var party_y := proxy_y - 0.25
    position.y = party_y
    midpoint.y = party_y
    return {"position": position, "midpoint": midpoint}

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VS001_CROWDED_INTERACTION_CALIBRATION_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("VS001_CROWDED_INTERACTION_CALIBRATION_FAIL: %s" % failure)
    get_tree().quit(1)
