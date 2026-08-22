extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    await get_tree().process_frame
    EndgameState.reset_profile_progress()
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(424242)
    CreatureManager.reset_new_game(515151)
    await get_tree().process_frame

    _check_runtime_routes()
    _check_critical_scene_instantiation()
    _check_expedition_runtime()
    _check_equipment_capture_and_companion()
    _check_real_disk_save_roundtrip()
    _finish()

func _check_runtime_routes() -> void:
    var critical_zones := [
        "zone_01_faubourg_cendreux",
        "c02_old_road",
        "c03_abandoned_relay",
        "c04_first_rupture",
        "c05_black_glass_crypts",
        "c06_timeless_garden",
        "c07_engineer_refuge",
        "c08_varkhane_border",
        "c09_tree_node",
        "c10_world_council"
    ]
    # Preserve the existing canonical Chapter IV zone name if its router still
    # exposes the older buried-city identifier.
    critical_zones[3] = "c04_buried_city"
    for zone_id in critical_zones:
        _check(AshlandsSceneRouter.has_zone(String(zone_id)), "Critical campaign zone is not routable: %s" % zone_id)

    _check(DeepVestigeRuntime.index_entries().size() >= 7, "Seven Deep Vestiges must be indexed")
    for entry_value in DeepVestigeRuntime.index_entries():
        var entry: Dictionary = entry_value
        var vestige_id := String(entry.get("id", ""))
        var entry_zone := DeepVestigeRuntime.entry_zone_for(vestige_id)
        _check(entry_zone != "", "Deep Vestige has no entry zone: %s" % vestige_id)
        if entry_zone != "":
            _check(AshlandsSceneRouter.has_zone(entry_zone), "Deep Vestige entry zone is not routable: %s" % entry_zone)

func _check_critical_scene_instantiation() -> void:
    var scene_paths := [
        "res://scenes/Main.tscn",
        "res://scenes/world/terre_des_cendres/zone_01_faubourg_cendreux.tscn",
        "res://scenes/world/chapter_05/c05_black_glass_crypts.tscn",
        "res://scenes/world/chapter_10/c10_world_council.tscn",
        "res://scenes/world/deep_vestiges/generic_deep_vestige.tscn"
    ]
    for scene_path in scene_paths:
        var packed := ResourceLoader.load(String(scene_path)) as PackedScene
        _check(packed != null, "Critical scene cannot load: %s" % scene_path)
        if packed == null:
            continue
        var instance := packed.instantiate()
        _check(instance != null, "Critical scene cannot instantiate: %s" % scene_path)
        if instance != null:
            instance.free()

func _check_expedition_runtime() -> void:
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition(987654)
    _check(ExpeditionManager.expedition_active, "Expedition must become active")
    _check(ExpeditionManager.expedition_seed == 987654, "Explicit expedition seed must be preserved")

    AshlandsRuntime.begin_new_expedition()
    AshlandsRuntime.enter_zone("zone_01_faubourg_cendreux")
    _check(AshlandsRuntime.current_zone_id == "zone_01_faubourg_cendreux", "Entering a zone must update current_zone_id")
    _check(AshlandsRuntime.is_zone_discovered("zone_01_faubourg_cendreux"), "Entering a zone must discover it")
    _check("zone_01_faubourg_cendreux" in ExpeditionManager.zones_entered_this_run, "Expedition must record entered zones")

    var camp_result := ExpeditionManager.use_campfire()
    _check(bool(camp_result.get("success", false)), "A freshly supplied expedition must be able to use a campfire")
    if bool(camp_result.get("success", false)):
        AshlandsRuntime.use_campfire("zone_03_moulin_calcine")
        _check(AshlandsRuntime.was_campfire_used_this_run("zone_03_moulin_calcine"), "Campfire usage must be recorded for the expedition")

func _check_equipment_capture_and_companion() -> void:
    var reward := EquipmentManager.grant_random_party_weapon("rare", "runtime_player_smoke")
    _check(not reward.is_empty(), "A rare party weapon must be generated")
    if not reward.is_empty():
        var instance_id := String(reward.get("instance_id", ""))
        _check(instance_id != "", "Generated equipment must have an instance id")
        _check(EquipmentManager.has_instance(instance_id), "Generated equipment must enter inventory")
        _check(String(reward.get("rarity", "")) == "rare", "Generated smoke reward must retain rare rarity")

    AshlandsCombatBridge.active = true
    AshlandsCombatBridge.encounter_id = "runtime_player_smoke"
    AshlandsCombatBridge.encounter_type = "normal"
    AshlandsCombatBridge.return_zone_id = AshlandsRuntime.current_zone_id
    AshlandsCombatBridge._prepare_placeholder_enemies()
    _check(GameState.battle_enemies.size() == 4, "Normal campaign combat must create four enemies")
    if GameState.battle_enemies.size() == 4:
        var expected_ids := [1, 8, 1, 8]
        for index in range(expected_ids.size()):
            _check(int(GameState.battle_enemies[index].get("id", -1)) == expected_ids[index], "Normal campaign enemy %d must match the four-enemy contract" % index)
    if GameState.battle_enemies.is_empty():
        return

    var capture_target: Dictionary = GameState.battle_enemies[0]
    capture_target["max_hp"] = maxi(10, int(capture_target.get("max_hp", capture_target.get("hp", 10))))
    capture_target["hp"] = 1
    GameState.essence = 100
    var captured := false
    for _attempt in range(20):
        var result := CreatureManager.attempt_capture(capture_target)
        if bool(result.get("success", false)):
            captured = true
            break
        if not bool(result.get("consumed", false)):
            break
    _check(captured, "A weakened recruitable creature must be capturable with deterministic repeated attempts")
    _check(CreatureManager.captured_creatures.size() == 1, "Successful capture must add exactly one creature")
    _check(CreatureManager.active_instance_id != "", "First captured creature must become active")

    if captured and GameState.battle_enemies.size() > 1:
        var companion_target: Dictionary = GameState.battle_enemies[1]
        var hp_before := int(companion_target.get("hp", 0))
        var companion_result := CreatureManager.companion_turn(companion_target)
        _check(not companion_result.is_empty(), "Active captured creature must be able to take a companion turn")
        _check(int(companion_result.get("damage", 0)) > 0, "Companion turn must deal positive damage")
        _check(int(companion_target.get("hp", 0)) < hp_before, "Companion turn must reduce enemy HP")

func _check_real_disk_save_roundtrip() -> void:
    if GameState.party.is_empty():
        _check(false, "Party missing before save roundtrip")
        return

    GameState.gold = 321
    GameState.essence = 23
    GameState.light = 64
    GameState.supplies = 6
    var first_hero: Dictionary = GameState.party[0]
    first_hero["hp"] = maxi(1, int(first_hero.get("max_hp", 1)) - 7)
    var expected_hero_hp := int(first_hero.get("hp", 0))
    CampaignState.set_chapter_flag("runtime_player_smoke_flag")
    CampaignState.metrics["veil_knowledge"] = 37
    AshlandsRuntime.unlock_shortcut("runtime_player_smoke_shortcut")
    AshlandsRuntime.mark_encounter_cleared("runtime_player_smoke_encounter")

    var expected_item_id := ""
    if not EquipmentManager.items.is_empty():
        expected_item_id = String(EquipmentManager.items[0].get("instance_id", ""))
    var expected_creature_id := CreatureManager.active_instance_id
    var expected_capture_seed := CreatureManager.capture_seed
    var expected_expedition_seed := ExpeditionManager.expedition_seed

    _check(SaveManager.save_game(), "SaveManager must write a real save file")
    _check(FileAccess.file_exists(SaveManager.SAVE_PATH), "Save file must exist on disk after save_game")
    if FileAccess.file_exists(SaveManager.SAVE_PATH):
        var payload = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
        _check(typeof(payload) == TYPE_DICTIONARY, "Save file must contain valid JSON dictionary data")
        if typeof(payload) == TYPE_DICTIONARY:
            _check(String(payload.get("version", "")) == SaveManager.SAVE_VERSION, "Disk save must use current save version")

    GameState.gold = 1
    GameState.essence = 1
    GameState.light = 1
    GameState.supplies = 1
    first_hero["hp"] = 1
    EquipmentManager.reset_new_game(777)
    CreatureManager.reset_new_game(888)
    CampaignState.reset_new_game()
    AshlandsRuntime.reset_world_progression()
    ExpeditionManager.return_to_hub("runtime_smoke_mutation")
    AshlandsCombatBridge.active = false
    AshlandsCombatBridge.encounter_id = ""

    _check(SaveManager.load_game(), "SaveManager must load the real save file")
    _check(GameState.gold == 321, "Disk load must restore gold")
    _check(GameState.essence == 23, "Disk load must restore essence")
    _check(GameState.light == 64, "Disk load must restore light")
    _check(GameState.supplies == 6, "Disk load must restore supplies")
    _check(int(GameState.party[0].get("hp", 0)) == expected_hero_hp, "Disk load must restore hero HP")
    _check(bool(CampaignState.chapter_flags.get("runtime_player_smoke_flag", false)), "Disk load must restore campaign flags")
    _check(int(CampaignState.metrics.get("veil_knowledge", 0)) == 37, "Disk load must restore campaign metrics")
    _check(AshlandsRuntime.is_shortcut_unlocked("runtime_player_smoke_shortcut"), "Disk load must restore shortcuts")
    _check(AshlandsRuntime.is_encounter_cleared("runtime_player_smoke_encounter"), "Disk load must restore cleared encounters")
    _check(ExpeditionManager.expedition_active, "Disk load must restore active expedition state")
    _check(ExpeditionManager.expedition_seed == expected_expedition_seed, "Disk load must restore expedition seed")
    _check(AshlandsRuntime.current_zone_id == "zone_01_faubourg_cendreux", "Disk load must restore current exploration zone")
    _check(CreatureManager.capture_seed == expected_capture_seed, "Disk load must restore creature capture seed")
    _check(CreatureManager.active_instance_id == expected_creature_id, "Disk load must restore active companion")
    _check(CreatureManager.captured_creatures.size() == 1, "Disk load must restore captured creature roster")
    if expected_item_id != "":
        _check(EquipmentManager.has_instance(expected_item_id), "Disk load must restore generated equipment instance")
    _check(AshlandsCombatBridge.active, "Disk load must restore active combat bridge state")
    _check(AshlandsCombatBridge.encounter_id == "runtime_player_smoke", "Disk load must restore combat encounter id")

func _finish() -> void:
    AshlandsCombatBridge.active = false
    AshlandsCombatBridge.encounter_id = ""
    AshlandsCombatBridge.encounter_type = ""
    if failures.is_empty():
        print("RUNTIME_PLAYER_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("RUNTIME_PLAYER_SMOKE: " + failure)
    print("RUNTIME_PLAYER_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)