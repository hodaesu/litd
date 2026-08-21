extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    await get_tree().process_frame
    await get_tree().process_frame

    _check(DataLoader.heroes.size() >= 4, "DataLoader heroes not initialized")
    _check(not CampaignState.chapters().is_empty(), "Campaign data not initialized")
    _check(not EndgameState.perks().is_empty(), "Endgame data not initialized")
    if not failures.is_empty():
        _finish()
        return

    EndgameState.reset_profile_progress()
    GameState.reset_new_game()
    await get_tree().process_frame

    _check(CampaignState.current_chapter_id == "chapter_01_ashlands", "New game must start in Chapter I")
    _check(GameState.gold == 120, "New game gold must be 120")
    _check(GameState.essence == 18, "New game essence must be 18")
    _check(GameState.light == 75, "New game light must be 75")
    _check(GameState.supplies == 8, "New game supplies must be 8")
    _check(GameState.party.size() == DataLoader.heroes.size(), "New game party must contain every starter hero")
    _check(EndgameState.active_cycle == 0, "Fresh profile must start outside NG+")

    var main_scene := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    _check(main_scene != null, "Main scene must load")
    if main_scene != null:
        var main_instance := main_scene.instantiate()
        get_tree().root.add_child(main_instance)
        await get_tree().process_frame
        _check(is_instance_valid(main_instance), "Main scene must instantiate")
        main_instance.queue_free()
        await get_tree().process_frame

    var campaign_order := [
        "chapter_01_ashlands",
        "chapter_02_before_fall",
        "chapter_03_threshold",
        "chapter_04_first_rupture",
        "chapter_05_great_closure",
        "chapter_06_absent",
        "chapter_07_living_responsible",
        "chapter_08_outer_world",
        "chapter_09_veil_nature",
        "chapter_10_final_choice"
    ]

    for chapter_index in range(campaign_order.size() - 1):
        var expected_id := String(campaign_order[chapter_index])
        _check(CampaignState.current_chapter_id == expected_id, "Unexpected campaign chapter before quest completion: %s" % CampaignState.current_chapter_id)
        var chapter := CampaignState.current_chapter()
        var quests: Array = chapter.get("main_quests", [])
        _check(not quests.is_empty(), "Chapter %s must expose main quests" % expected_id)
        for quest_value in quests:
            var quest: Dictionary = quest_value
            var quest_id := String(quest.get("id", ""))
            _check(quest_id != "", "Chapter %s has an empty main quest id" % expected_id)
            if quest_id != "":
                _check(CampaignState.complete_main_quest(quest_id), "Main quest must be completable: %s" % quest_id)
        var next_id := String(campaign_order[chapter_index + 1])
        _check(CampaignState.current_chapter_id == next_id, "Campaign must advance from %s to %s" % [expected_id, next_id])

    _check(CampaignState.current_chapter_id == "chapter_10_final_choice", "Campaign must reach Chapter X")

    PoliticalState.trust = maxi(PoliticalState.trust, 60)
    PoliticalState.three_awakenings["spirit"] = maxi(int(PoliticalState.three_awakenings.get("spirit", 50)), 70)
    PoliticalState.three_awakenings["city"] = maxi(int(PoliticalState.three_awakenings.get("city", 50)), 70)
    CampaignState.metrics["creature_relations"] = maxi(int(CampaignState.metrics.get("creature_relations", 0)), 6)
    CampaignState.metrics["veil_knowledge"] = maxi(int(CampaignState.metrics.get("veil_knowledge", 0)), 80)
    PoliticalState.politics_changed.emit()
    CampaignState.campaign_changed.emit()

    var ending_ids: Array[String] = []
    for ending_value in Chapter10Runtime.final_choices():
        ending_ids.append(String((ending_value as Dictionary).get("id", "")))
    _check("stable_coexistence" in ending_ids, "Stable coexistence ending must be reachable with its canonical requirements")

    AshlandsRuntime.mark_encounter_cleared("c10_boss_final")
    ExpeditionManager.return_to_hub("e2e_smoke")
    GameState.request_screen("sanctuary")
    await get_tree().process_frame
    _check(Chapter10Runtime.choose_final_orientation("stable_coexistence"), "Chapter X final orientation must be selectable after the final boss")
    Chapter10Runtime.refresh_progress()
    _check(bool(CampaignState.chapter_flags.get("campaign_complete", false)), "Final orientation must mark the campaign complete")
    _check(EndgameState.is_postgame_unlocked(), "Campaign completion must unlock postgame")
    _check(EndgameState.ng_plus_unlocked(), "Campaign completion must immediately unlock NG+ without postgame operations")
    _check(EndgameState.can_begin_new_game_plus(""), "Player must be allowed to start NG+ immediately without a legacy perk")
    _check(EndgameState.operation_count() == 0, "Immediate NG+ availability must not depend on postgame operations")

    var chapter_before_continue := CampaignState.current_chapter_id
    var gold_before_continue := GameState.gold
    var essence_before_continue := GameState.essence
    var supplies_before_continue := GameState.supplies
    var party_size_before_continue := GameState.party.size()
    _check(EndgameState.choose_continue_postgame(), "Player must be able to choose to continue the finished save")
    _check(EndgameState.postgame_continuation_selected, "Continue choice must be persisted in endgame state")
    _check(EndgameState.active_cycle == 0, "Continuing postgame must not start NG+")
    _check(CampaignState.current_chapter_id == chapter_before_continue, "Continuing postgame must keep the finished campaign state")
    _check(GameState.gold == gold_before_continue, "Continuing postgame must keep current gold")
    _check(GameState.essence == essence_before_continue, "Continuing postgame must keep current essence")
    _check(GameState.supplies == supplies_before_continue, "Continuing postgame must keep current supplies")
    _check(GameState.party.size() == party_size_before_continue, "Continuing postgame must keep the current party")
    _check(EndgameState.ng_plus_unlocked(), "Choosing to continue must leave NG+ available for later")

    var campaign_snapshot := CampaignState.serialize()
    var chapter_ten_snapshot := Chapter10Runtime.serialize()
    var endgame_snapshot_before_ops := EndgameState.serialize()
    CampaignState.reset_new_game()
    Chapter10Runtime.reset_new_game()
    EndgameState.deserialize(endgame_snapshot_before_ops)
    CampaignState.deserialize(campaign_snapshot)
    Chapter10Runtime.deserialize(chapter_ten_snapshot)
    _check(EndgameState.is_postgame_unlocked(), "In-memory serialization roundtrip must preserve postgame unlock")
    _check(EndgameState.ng_plus_unlocked(), "Serialization roundtrip must preserve immediate NG+ availability")
    _check(EndgameState.postgame_continuation_selected, "Serialization roundtrip must preserve the decision to continue postgame")
    _check(Chapter10Runtime.final_orientation == "stable_coexistence", "Chapter X ending must survive serialization roundtrip")

    for operation_id in ["postgame_routes", "postgame_hearing", "postgame_memorial"]:
        _check(EndgameState.operation_available(operation_id), "Guaranteed postgame operation must be available: %s" % operation_id)
        _check(EndgameState.complete_operation(operation_id), "Guaranteed postgame operation must complete: %s" % operation_id)

    _check(EndgameState.operation_count() >= 3, "Three guaranteed postgame operations must complete")
    _check(EndgameState.ng_plus_unlocked(), "NG+ must remain available after optional postgame operations")
    _check(EndgameState.legacy_points >= 3, "Guaranteed postgame path must grant at least three legacy points")
    _check(EndgameState.perk_available("legacy_prepared"), "Prepared legacy perk must be purchasable on the guaranteed path")

    _check(EndgameState.begin_new_game_plus("legacy_prepared"), "NG+ must start with a valid optional legacy perk")
    await get_tree().process_frame
    _check(EndgameState.active_cycle == 1, "First NG+ cycle must be cycle 1")
    _check(not EndgameState.postgame_continuation_selected, "Starting NG+ must leave postgame continuation mode")
    _check(CampaignState.current_chapter_id == "chapter_01_ashlands", "NG+ must restart the campaign at Chapter I")
    _check(bool(CampaignState.chapter_flags.get("ng_plus_active", false)), "NG+ active flag must be set")
    _check(bool(CampaignState.chapter_flags.get("ng_plus_cycle_1", false)), "NG+ cycle flag must be set")
    _check(GameState.gold == 180, "Prepared legacy must start NG+ with 180 gold")
    _check(GameState.essence == 22, "Prepared legacy must start NG+ with 22 essence")
    _check(GameState.supplies == 11, "Prepared legacy must start NG+ with 11 supplies")
    _check(HeroSkillManager.multi_tree_enabled(), "Hero multi-tree allocation must unlock in NG+")
    _check(CreatureManager.multi_tree_enabled(), "Creature multi-tree allocation must unlock in NG+")
    _check(BossRecruitmentState.enabled(), "Boss recruitment must unlock in NG+")
    _check(not EndgameState.ending_history.is_empty(), "NG+ must preserve ending history")
    _check(not EndgameState.epilogue_archive.is_empty(), "NG+ must preserve epilogue archive")

    var scaled_enemy := {"hp":100,"max_hp":100,"damage":[10,20],"fear":10}
    EndgameState.apply_enemy_scaling(scaled_enemy)
    _check(int(scaled_enemy.get("hp", 0)) == 118, "Cycle 1 must scale enemy HP by 18 percent")
    _check((scaled_enemy.get("damage", []) as Array) == [11,22], "Cycle 1 must scale enemy damage by 12 percent")
    _check(int(scaled_enemy.get("fear", 0)) == 11, "Cycle 1 must scale enemy fear by 8 percent")
    var scaled_once := scaled_enemy.duplicate(true)
    EndgameState.apply_enemy_scaling(scaled_enemy)
    _check(scaled_enemy == scaled_once, "NG+ enemy scaling must be idempotent within a cycle")

    var campaign_ng_snapshot := CampaignState.serialize()
    var endgame_ng_snapshot := EndgameState.serialize()
    CampaignState.reset_new_game()
    EndgameState.reset_profile_progress()
    CampaignState.deserialize(campaign_ng_snapshot)
    EndgameState.deserialize(endgame_ng_snapshot)
    _check(EndgameState.active_cycle == 1, "NG+ cycle must survive serialization roundtrip")
    _check(bool(CampaignState.chapter_flags.get("ng_plus_active", false)), "NG+ campaign flag must survive serialization roundtrip")
    _check(HeroSkillManager.multi_tree_enabled(), "Hero multi-tree must remain enabled after serialization roundtrip")

    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("CAMPAIGN_E2E_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("E2E: " + failure)
    print("CAMPAIGN_E2E_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
