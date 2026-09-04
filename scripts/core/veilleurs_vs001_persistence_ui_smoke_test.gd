extends Node

const PLAYABLE_SCENE := preload("res://scenes/world/veilleurs/voices_under_sanctuary_playable.tscn")
const MAP_VIEW_SCRIPT := preload("res://scripts/ui/veilleurs_vs001_map_view.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    SaveManager.delete_qa_snapshot()
    GameState.reset_new_game()
    await get_tree().process_frame

    var original_ids := _party_ids(GameState.party)
    _check(original_ids.size() == 4, "Smoke requires the four prototype combat shells")

    VeilleursVS001PlayableBridge.activate_watchers_party()
    VeilleursVS001WorldRuntime.start_new_session()
    _check(_party_ids(GameState.party) == ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"], "VS001 must start with the canonical four Watchers")
    _check(not _party_ids(GameState.party).has("aurelien"), "Aurélien must never enter the Watcher party")

    _check(bool(VeilleursVS001WorldRuntime.enter_room("s2_rope_gallery").get("success", false)), "S1→S2 must remain reachable")
    _check(bool(VeilleursVS001WorldRuntime.enter_room("s3_sleepers").get("success", false)), "S2→S3 must remain reachable")

    VeilleursVS001WorldRuntime.call("_prepare_vs001_enemies", "vs001_s3_ghouls")
    _check(GameState.battle_enemies.size() == 3, "S3 authored encounter must contain three Ghouls")
    for enemy_value: Variant in GameState.battle_enemies:
        if enemy_value is Dictionary:
            (enemy_value as Dictionary)["hp"] = 0
    var persistence: VeilleursVS001PersistenceBridge = VeilleursVS001PlayableBridge.persistence_bridge
    persistence.call("_persist_authored_corpses", "vs001_s3_ghouls")
    var corpse_scars := persistence.active_corpse_scars()
    _check(corpse_scars.size() == 3, "S3 victory must create three persistent corpse WorldScars")
    _check(_all_scars_are_remanence_backed(corpse_scars), "Every VS001 corpse must exist in RemanenceRuntime")

    var nayra: Dictionary = GameState.party[0]
    var wound := PersistentInjuryRuntime.apply_injury(nayra, "deep_wound", "serious")
    _check(not wound.is_empty(), "Nayra must receive a persistent serious wound for the smoke")
    persistence.call("_record_party_wounds", "vs001_s3_ghouls", "s3_sleepers")
    _check(not persistence.wound_history.is_empty(), "Persistent Watcher wounds must create VS001 wound history")
    _check(_has_injury(nayra, "deep_wound"), "Watcher persistent injury must remain on the character dictionary")

    _check(bool(VeilleursVS001WorldRuntime.enter_room("s5_fractured_crypt").get("success", false)), "S3→S5 must remain reachable")
    _check(bool(VeilleursVS001WorldRuntime.enter_room("s6_survivor").get("success", false)), "S5→S6 must remain reachable")
    var recruit: Dictionary = persistence.call("_register_s6_survivor")
    _check(not recruit.is_empty(), "S6 successful recruitment must create a real CreatureManager creature")
    var recruit_id := str(recruit.get("instance_id", ""))
    _check(not recruit_id.is_empty(), "S6 recruit must own a persistent instance id")
    _check(str(recruit.get("species_id", "")) == "hungry_ghoul", "S6 recruit must use the global hungry_ghoul species")
    _check(bool(recruit.get("vs001_recruit", false)), "S6 creature must retain its VS001 origin tag")
    _check(bool(recruit.get("anatomy_recovery_locked", false)), "Wounded S6 recruit must begin in convalescence")
    _check(_has_injury(recruit, "fracture_leg"), "S6 recruit must retain its critical leg fracture")
    _check(CreatureManager.get_creature(recruit_id).get("instance_id", "") == recruit_id, "S6 recruit must be stored by CreatureManager")
    var remanence_id := str(recruit.get("source_enemy_remanence_id", ""))
    _check(not remanence_id.is_empty(), "S6 recruit must preserve its enemy Remanence identity")
    _check(str(RemanenceRuntime.entity_state(remanence_id).get("status", "")) == "recruited", "S6 Remanence entity must become recruited")

    _check(bool(VeilleursVS001WorldRuntime.enter_room("s5_fractured_crypt").get("success", false)), "S6→S5 physical return must remain possible")
    var expected_room := VeilleursVS001WorldRuntime.current_room()

    var playable: Node3D = PLAYABLE_SCENE.instantiate() as Node3D
    _check(playable != null, "Playable VS001 scene must instantiate with persistence layer")
    if playable == null:
        _finish(original_ids)
        return
    add_child(playable)
    await get_tree().process_frame
    await get_tree().physics_frame
    await get_tree().process_frame

    var parties := get_tree().get_nodes_in_group("player_party")
    _check(parties.size() == 1, "Playable scene must expose one physical player party")
    var expected_position := Vector3(52.3, 0.7, 1.4)
    if not parties.is_empty() and parties[0] is Node3D:
        (parties[0] as Node3D).global_position = expected_position

    var persistent_world: VeilleursVS001PersistenceLayer = playable.get_node_or_null("PersistentWorld") as VeilleursVS001PersistenceLayer
    _check(persistent_world != null, "Playable scene must include the PersistentWorld layer")
    if persistent_world != null:
        persistent_world.rebuild()
        await get_tree().process_frame
        _check(persistent_world.corpse_count() == 3, "Three S3 WorldScars must materialize as three physical corpse proxies")

    var map_view: VeilleursVS001MapView = MAP_VIEW_SCRIPT.new() as VeilleursVS001MapView
    map_view.size = Vector2(800.0, 500.0)
    add_child(map_view)
    map_view.set_map_state((playable.get_node("Blockout") as VeilleursVS001BlockoutBuilder).physical_map, VeilleursVS001WorldRuntime.snapshot())
    _check(map_view.known_room_count() >= 4, "Knowledge map must count only rooms actually visited")
    _check(not map_view.secret_visible(), "S8 must remain hidden on the map before it is learned")
    var revealed_state := VeilleursVS001WorldRuntime.snapshot()
    revealed_state["s8_unlocked"] = true
    map_view.set_map_state((playable.get_node("Blockout") as VeilleursVS001BlockoutBuilder).physical_map, revealed_state)
    _check(map_view.secret_visible(), "Knowledge map must reveal S8 only after the secret is learned")
    map_view.queue_free()

    _check(SaveManager.save_qa_snapshot(), "VS001 must save a complete QA snapshot")
    _check(VeilleursVS001PlayableBridge.has_saved_party_position(), "Saving VS001 must capture the physical party position")
    var saved_position := VeilleursVS001PlayableBridge.resume_world_position()
    _check(saved_position.distance_to(expected_position) < 0.05, "Saved physical position must match the live party position")
    var saved_corpse_ids := persistence.corpse_scar_ids.duplicate()
    var saved_wound_count := persistence.wound_history.size()

    playable.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    GameState.reset_new_game()
    await get_tree().process_frame
    _check(not VeilleursVS001WorldRuntime.is_active(), "Reset between save and load must clear active VS001 state")
    _check(CreatureManager.get_creature(recruit_id).is_empty(), "Reset must clear the recruit before reload")

    _check(SaveManager.load_qa_snapshot(), "Saved VS001 QA snapshot must reload")
    _check(VeilleursVS001WorldRuntime.is_active(), "Reload must restore active VS001 session")
    _check(VeilleursVS001WorldRuntime.current_room() == expected_room, "Reload must restore the exact VS001 room")
    _check(VeilleursVS001PlayableBridge.is_watcher_party_active(), "Reload must restore the Watcher party")
    _check(_party_ids(GameState.party) == ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"], "Reloaded party identities must remain canonical")
    _check(CreatureManager.get_creature(recruit_id).get("instance_id", "") == recruit_id, "Reload must restore the S6 CreatureManager recruit")
    _check(str(RemanenceRuntime.entity_state(remanence_id).get("status", "")) == "recruited", "Reload must restore recruited Remanence identity")
    _check(VeilleursVS001PlayableBridge.persistence_bridge.corpse_scar_ids == saved_corpse_ids, "Reload must restore persistent corpse scar references")
    _check(VeilleursVS001PlayableBridge.persistence_bridge.wound_history.size() == saved_wound_count, "Reload must restore Watcher wound history")
    _check(VeilleursVS001PlayableBridge.has_saved_party_position(), "Reload must restore physical party position metadata")

    var resumed: Node3D = PLAYABLE_SCENE.instantiate() as Node3D
    add_child(resumed)
    await get_tree().process_frame
    await get_tree().physics_frame
    await get_tree().process_frame
    await get_tree().process_frame
    var resumed_parties := get_tree().get_nodes_in_group("player_party")
    _check(resumed_parties.size() == 1, "Resumed playable scene must expose one player party")
    if not resumed_parties.is_empty() and resumed_parties[0] is Node3D:
        _check((resumed_parties[0] as Node3D).global_position.distance_to(expected_position) < 0.15, "Resume must restore the exact saved physical party position")
    var resumed_world: VeilleursVS001PersistenceLayer = resumed.get_node_or_null("PersistentWorld") as VeilleursVS001PersistenceLayer
    _check(resumed_world != null, "Resumed scene must restore PersistentWorld")
    if resumed_world != null:
        resumed_world.rebuild()
        await get_tree().process_frame
        _check(resumed_world.corpse_count() == 3, "Reloaded WorldScars must rematerialize corpse proxies")

    resumed.queue_free()
    await get_tree().process_frame
    _finish(original_ids)

func _party_ids(party_value: Array) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in party_value:
        if value is Dictionary:
            result.append(str((value as Dictionary).get("id", "")))
    return result

func _has_injury(character: Dictionary, injury_id: String) -> bool:
    for injury_value: Variant in character.get("persistent_injuries", []):
        if injury_value is Dictionary and str((injury_value as Dictionary).get("id", "")) == injury_id:
            return true
    return false

func _all_scars_are_remanence_backed(scars: Array[Dictionary]) -> bool:
    for scar: Dictionary in scars:
        var scar_id := str(scar.get("id", ""))
        if scar_id.is_empty() or not RemanenceRuntime.world_scars.has(scar_id):
            return false
    return true

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish(original_ids: Array[String]) -> void:
    SaveManager.delete_qa_snapshot()
    if VeilleursVS001PlayableBridge.is_watcher_party_active():
        VeilleursVS001PlayableBridge.restore_previous_party()
    if not original_ids.is_empty() and _party_ids(GameState.party) != original_ids:
        failures.append("Smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_VS001_PERSISTENCE_UI_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_VS001_PERSISTENCE_UI_SMOKE: " + failure)
    print("VEILLEURS_VS001_PERSISTENCE_UI_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
