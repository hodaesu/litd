extends Node

const PLAYABLE_SCENE := preload("res://scenes/world/veilleurs/voices_under_sanctuary_playable.tscn")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GameState.reset_new_game()
    var original_ids := _party_ids(GameState.party)
    _check(original_ids.size() == 4, "Prototype party must contain four reusable combat shells")

    var watchers: Array = VeilleursVS001PlayableBridge.activate_watchers_party()
    var watcher_ids := _party_ids(watchers)
    _check(watcher_ids == ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"], "VS001 must use the four canonical Watcher identities")
    _check(not watcher_ids.has("aurelien"), "Aurélien must never be a Watcher in VS001")
    _check(_party_names(watchers) == ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"], "Watcher display names must stay locked")
    for hero_value: Variant in watchers:
        var hero: Dictionary = hero_value
        _check(bool(hero.get("vs001_watcher", false)), "Every VS001 party member must be tagged as a Watcher")
        _check(str(hero.get("race_id", "")) == "human", "The four Watchers must remain human")

    VeilleursVS001WorldRuntime.start_new_session()
    _check(VeilleursVS001PlayableBridge.is_watcher_party_active(), "Starting VS001 must preserve the Watcher party")
    _check(AshlandsSceneRouter.zone_scene_paths.get(VeilleursVS001WorldRuntime.ZONE_ID, "") == VeilleursVS001WorldRuntime.SCENE_PATH, "VS001 playable scene must be registered with the shared scene router")

    var playable: Node3D = PLAYABLE_SCENE.instantiate() as Node3D
    _check(playable != null, "VS001 playable scene must instantiate")
    if playable == null:
        _finish(original_ids)
        return
    add_child(playable)
    await get_tree().process_frame
    await get_tree().physics_frame

    var parties := get_tree().get_nodes_in_group("player_party")
    _check(parties.size() == 1, "Playable VS001 must spawn exactly one exploration party")
    if not parties.is_empty():
        _check(parties[0] is ExplorationPartyController, "Playable VS001 must reuse the shared keyboard/touch exploration controller")

    var sensors := get_tree().get_nodes_in_group("veilleurs_vs001_room_sensor")
    var interactables := get_tree().get_nodes_in_group("veilleurs_vs001_interactable")
    _check(sensors.size() == 8, "Playable VS001 must expose one physical room sensor for each S1-S8 room")
    _check(interactables.size() == 16, "Playable VS001 must expose every authored interaction except the spawn marker")

    var blockout: VeilleursVS001BlockoutBuilder = playable.get_node_or_null("Blockout") as VeilleursVS001BlockoutBuilder
    _check(blockout != null, "Playable scene must reuse the validated VS001 blockout")
    if blockout != null:
        _check(blockout.secret_connection_locked(), "S8 secret path must begin invisible and physically non-colliding")
        _check(not blockout.secret_connection_open(), "S8 secret path must not begin open")

    var initial_state: Dictionary = VeilleursVS001WorldRuntime.snapshot()
    _check(str(initial_state.get("current_room", "")) == "s1_vestibule", "Playable VS001 must begin in S1")
    var inspect_fresco: Dictionary = VeilleursVS001WorldRuntime.preview_anchor("s1_fresco")
    _check(bool((inspect_fresco.get("options", [])[0] as Dictionary).get("irreversible", true)) == false, "Information-only inspection must never be irreversible")
    _check(VeilleursVS001WorldRuntime.snapshot() == initial_state, "Previewing information must not mutate authoritative session state")

    var to_s2: Dictionary = VeilleursVS001WorldRuntime.enter_room("s2_rope_gallery")
    _check(bool(to_s2.get("success", false)), "Physical route S1→S2 must update the session")
    var before_tripwire: Dictionary = VeilleursVS001WorldRuntime.snapshot()
    var tripwire_preview: Dictionary = VeilleursVS001WorldRuntime.preview_anchor("s2_tripwire")
    _check(VeilleursVS001WorldRuntime.snapshot() == before_tripwire, "Looking at S2 tripwire must not trigger it")
    _check(_option_irreversible(tripwire_preview, "trigger_tripwire"), "Forcing the tripwire must be explicitly marked irreversible")
    var disarm: Dictionary = VeilleursVS001WorldRuntime.execute_anchor_action("s2_tripwire", "disarm_tripwire")
    _check(bool(disarm.get("success", false)), "S2 tripwire must be disarmable through the playable interaction contract")
    _check(str(VeilleursVS001WorldRuntime.snapshot().get("s2_tripwire", "")) == "disarmed", "S2 disarm must persist in session state")

    _check(bool(VeilleursVS001WorldRuntime.enter_room("s3_sleepers").get("success", false)), "S2→S3 route must be playable")
    var s3_preview: Dictionary = VeilleursVS001WorldRuntime.preview_anchor("s3_combat")
    _check(_option_irreversible(s3_preview, "fight_s3"), "S3 combat must require explicit validation")
    VeilleursVS001WorldRuntime.call("_prepare_vs001_enemies", "vs001_s3_ghouls")
    _check(GameState.battle_enemies.size() == 3, "S3 must create exactly three authored Ghoul opponents")
    _check(_enemy_profiles(GameState.battle_enemies) == ["hungry_standard", "hungry_standard", "hungry_scout"], "S3 must be two standard Ghouls plus one scout")

    _check(bool(VeilleursVS001WorldRuntime.enter_room("s5_fractured_crypt").get("success", false)), "S3→S5 route must be playable")
    _check(bool(VeilleursVS001WorldRuntime.enter_room("s6_survivor").get("success", false)), "S5→S6 optional branch must be playable")
    var s6_before: Dictionary = VeilleursVS001WorldRuntime.snapshot().get("s6_state", {}).duplicate(true)
    var s6_preview: Dictionary = VeilleursVS001WorldRuntime.preview_anchor("s6_survivor")
    _check(VeilleursVS001WorldRuntime.snapshot().get("s6_state", {}) == s6_before, "Opening S6 recruitment UI must not alter the creature")
    _check(_option_irreversible(s6_preview, "s6_recruit"), "Attempting the S6 bond must require explicit validation")
    _check(bool(VeilleursVS001WorldRuntime.execute_anchor_action("s6_survivor", "s6_observe").get("success", false)), "S6 Observe must be playable")
    _check(bool(VeilleursVS001WorldRuntime.execute_anchor_action("s6_survivor", "s6_lower_guard").get("success", false)), "Nayra S6 action must be playable")
    _check(bool(VeilleursVS001WorldRuntime.execute_anchor_action("s6_survivor", "s6_diagnose").get("success", false)), "Aïsha diagnosis must be playable")
    _check(bool(VeilleursVS001WorldRuntime.execute_anchor_action("s6_survivor", "s6_deescalate").get("success", false)), "Idris de-escalation must be playable")
    var s6_after: Dictionary = VeilleursVS001WorldRuntime.snapshot().get("s6_state", {})
    _check(int(s6_after.get("fear", 100)) < int(s6_before.get("fear", 0)), "Careful S6 interaction must lower fear")
    _check(int(s6_after.get("trust", 0)) > int(s6_before.get("trust", 100)), "Careful S6 interaction must raise trust")

    _check(bool(VeilleursVS001WorldRuntime.enter_room("s5_fractured_crypt").get("success", false)), "S6 must allow physical return to S5")
    _check(bool(VeilleursVS001WorldRuntime.enter_room("s7_voice_chamber").get("success", false)), "S5→S7 objective route must be playable")
    VeilleursVS001WorldRuntime.call("_prepare_vs001_enemies", "vs001_s7_ghouls")
    _check(_enemy_profiles(GameState.battle_enemies) == ["voracious_evolved", "hungry_standard", "hungry_standard"], "S7 must use the authored Voracious + two standard Ghoul composition")

    VeilleursVS001WorldRuntime.cleared_encounters["vs001_s7_ghouls"] = true
    var device_preview: Dictionary = VeilleursVS001WorldRuntime.preview_anchor("s7_acoustic_device")
    _check(_has_option(device_preview, "study_device"), "S7 device must expose study after combat")
    var study: Dictionary = VeilleursVS001WorldRuntime.execute_anchor_action("s7_acoustic_device", "study_device")
    _check(bool(study.get("success", false)), "Studying S7 device must resolve the objective")
    _check(bool(VeilleursVS001WorldRuntime.snapshot().get("s8_unlocked", false)), "Studying S7 must unlock S8")
    if blockout != null:
        _check(blockout.secret_connection_open(), "Unlocking S8 must visibly and physically open its connector")
        _check(not blockout.secret_connection_locked(), "Unlocked S8 connector must no longer be physically locked")
    _check(bool(VeilleursVS001WorldRuntime.enter_room("s8_lower_archive").get("success", false)), "Unlocked S8 must become an actual traversable session room")
    _check(bool(VeilleursVS001WorldRuntime.snapshot().get("s8_discovered", false)), "Entering physical S8 must persist discovery")

    playable.queue_free()
    await get_tree().process_frame
    VeilleursVS001PlayableBridge.restore_previous_party()
    _check(_party_ids(GameState.party) == original_ids, "Leaving VS001 must restore the previous game party exactly")
    _check(not VeilleursVS001PlayableBridge.is_watcher_party_active(), "Watcher party must not leak outside VS001")
    _finish(original_ids)

func _party_ids(party_value: Array) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in party_value:
        if value is Dictionary:
            result.append(str((value as Dictionary).get("id", "")))
    return result

func _party_names(party_value: Array) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in party_value:
        if value is Dictionary:
            result.append(str((value as Dictionary).get("name", "")))
    return result

func _enemy_profiles(enemies: Array) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in enemies:
        if value is Dictionary:
            result.append(str((value as Dictionary).get("vs001_profile", "")))
    return result

func _has_option(preview: Dictionary, action_id: String) -> bool:
    for option_value: Variant in preview.get("options", []):
        if value_is_option(option_value, action_id):
            return true
    return false

func _option_irreversible(preview: Dictionary, action_id: String) -> bool:
    for option_value: Variant in preview.get("options", []):
        if value_is_option(option_value, action_id):
            return bool((option_value as Dictionary).get("irreversible", false))
    return false

func value_is_option(value: Variant, action_id: String) -> bool:
    return value is Dictionary and str((value as Dictionary).get("id", "")) == action_id

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish(original_ids: Array[String]) -> void:
    if VeilleursVS001PlayableBridge.is_watcher_party_active():
        VeilleursVS001PlayableBridge.restore_previous_party()
    if not original_ids.is_empty() and _party_ids(GameState.party) != original_ids:
        failures.append("Smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_VS001_PLAYABLE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_VS001_PLAYABLE_SMOKE: " + failure)
    print("VEILLEURS_VS001_PLAYABLE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
