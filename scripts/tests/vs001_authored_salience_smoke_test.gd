extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    VeilleursVS001WorldRuntime.start_new_session()
    _check_initial_hierarchy()
    _check_tripwire_transition()
    _check_combat_and_loot_transitions()
    _check_optional_content_transitions()
    _check_objective_and_secret_transitions()
    _finish()

func _check_initial_hierarchy() -> void:
    var expected := {
        "extraction_gate": EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "s1_fresco": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s2_tripwire": EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "s2_salvage": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s3_combat": EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "s3_corpses": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s4_supplies": EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "s4_black_basin": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s5_scout_corpse": EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "s5_wall_voice": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s6_survivor": EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "s7_combat": EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "s7_acoustic_device": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s7_secret_stair": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s8_archive": EnvironmentInteractionContract.SALIENCE_INSPECT,
        "s8_fragment": EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
    }
    for anchor_id: String in expected.keys():
        _expect_salience(anchor_id, str(expected[anchor_id]), "initial %s" % anchor_id)

func _check_tripwire_transition() -> void:
    _patch_session({"s2_tripwire": "disarmed"})
    _expect_salience("s2_tripwire", EnvironmentInteractionContract.SALIENCE_INSPECT, "neutralized tripwire stops demanding attention")
    _expect_salience("s2_salvage", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL, "salvage becomes contextual only when recoverable")
    VeilleursVS001WorldRuntime.claimed_loot["s2_salvage"] = true
    _expect_salience("s2_salvage", EnvironmentInteractionContract.SALIENCE_INSPECT, "claimed salvage falls back to inspection")

func _check_combat_and_loot_transitions() -> void:
    VeilleursVS001WorldRuntime.cleared_encounters["vs001_s3_ghouls"] = true
    _expect_salience("s3_combat", EnvironmentInteractionContract.SALIENCE_INSPECT, "cleared S3 combat no longer steals focus")
    _expect_salience("s3_corpses", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL, "S3 corpses surface after combat")
    VeilleursVS001WorldRuntime.claimed_loot["s3"] = true
    _expect_salience("s3_corpses", EnvironmentInteractionContract.SALIENCE_INSPECT, "searched S3 corpses return to inspection")

func _check_optional_content_transitions() -> void:
    _expect_salience("s4_supplies", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL, "unclaimed optional supplies remain contextual")
    VeilleursVS001WorldRuntime.claimed_loot["s4"] = true
    _expect_salience("s4_supplies", EnvironmentInteractionContract.SALIENCE_INSPECT, "claimed optional supplies stop competing for focus")

    _expect_salience("s5_scout_corpse", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL, "unsearched scout corpse remains contextual")
    VeilleursVS001WorldRuntime.claimed_loot["s5"] = true
    _expect_salience("s5_scout_corpse", EnvironmentInteractionContract.SALIENCE_INSPECT, "searched scout corpse becomes inspect-only")

    _expect_salience("s6_survivor", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL, "unresolved optional recruitment remains contextual")
    _patch_session({"s6_outcome": "left_alive"})
    _expect_salience("s6_survivor", EnvironmentInteractionContract.SALIENCE_INSPECT, "resolved recruitment no longer competes for attention")

    _expect_salience("s8_fragment", EnvironmentInteractionContract.SALIENCE_CONTEXTUAL, "unclaimed secret fragment remains contextual")
    VeilleursVS001WorldRuntime.claimed_loot["s8"] = true
    _expect_salience("s8_fragment", EnvironmentInteractionContract.SALIENCE_INSPECT, "claimed secret fragment becomes inspect-only")

func _check_objective_and_secret_transitions() -> void:
    VeilleursVS001WorldRuntime.cleared_encounters["vs001_s7_ghouls"] = true
    _expect_salience("s7_combat", EnvironmentInteractionContract.SALIENCE_INSPECT, "cleared final combat stops demanding attention")
    _expect_salience("s7_acoustic_device", EnvironmentInteractionContract.SALIENCE_IMMEDIATE, "objective device becomes immediate when safe to resolve")

    _patch_session({"s7_device": "studied", "s8_unlocked": true, "s8_discovered": false})
    _expect_salience("s7_acoustic_device", EnvironmentInteractionContract.SALIENCE_INSPECT, "resolved objective device returns to inspection")
    _expect_salience("s7_secret_stair", EnvironmentInteractionContract.SALIENCE_IMMEDIATE, "newly revealed secret route earns immediate attention")

    _patch_session({"s8_discovered": true})
    _expect_salience("s7_secret_stair", EnvironmentInteractionContract.SALIENCE_INSPECT, "known secret route stops competing after discovery")

func _patch_session(patch: Dictionary) -> void:
    var state_value: Dictionary = VeilleursVS001WorldRuntime.snapshot()
    for key: Variant in patch.keys():
        state_value[key] = patch[key]
    var accepted := bool(VeilleursVS001WorldRuntime.session.call("deserialize", state_value))
    _check(accepted, "session patch accepted")

func _expect_salience(anchor_id: String, expected: String, context: String) -> void:
    var proxy := VeilleursVS001InteractionProxy.new()
    proxy.anchor_id = anchor_id
    proxy.interaction_prompt = VeilleursVS001WorldRuntime.interaction_prompt(anchor_id)
    add_child(proxy)
    var descriptor := proxy.interaction_descriptor(self)
    var actual := str(descriptor.get("salience", ""))
    _check(actual == expected, "%s: expected %s, got %s" % [context, expected, actual])
    remove_child(proxy)
    proxy.free()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VS001_AUTHORED_SALIENCE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("VS001_AUTHORED_SALIENCE_FAIL: %s" % failure)
    get_tree().quit(1)
