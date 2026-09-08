extends "res://scripts/qa/player_bot_v5_longitudinal_campaign.gd"

const V6_REPORT_PATH := "res://reports/player-bot-v6-real-campaign.json"
const V6_CAMPAIGN_SEEDS: Array[int] = [7101, 7202, 7303]
const V6_MAX_EXPEDITIONS := 24
const V6_MAX_ROOMS_PER_EXPEDITION := 18
const V6_SAVE_INTERVAL := 3
const V6_LOW_HP_EXTRACT := 0.38
const V6_INVENTORY_EXTRACT_RATIO := 0.85

var v6_coverage := {
    "real_combat_controller": true,
    "real_dungeon_graph": true,
    "real_room_resolution": true,
    "real_extraction": true,
    "real_gold_essence": true,
    "real_inventory_consumption": true,
    "real_save_load": true,
    "real_persistent_injuries": true,
    "guild_stash": true,
    "market_purchase": false,
    "dead_hero_recruitment": false,
    "synthetic_xp": false,
    "synthetic_loot": false,
    "synthetic_injuries": false
}

func _run() -> void:
    await get_tree().process_frame
    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        push_error("PLAYER_BOT_V6: cannot load Main.tscn")
        get_tree().quit(1)
        return
    controller = packed.instantiate() as Control
    if controller == null:
        push_error("PLAYER_BOT_V6: cannot instantiate Main.tscn")
        get_tree().quit(1)
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    failures.clear()
    alerts.clear()
    campaigns.clear()
    var started_ms := Time.get_ticks_msec()
    for seed_value in V6_CAMPAIGN_SEEDS:
        campaigns.append(await _run_real_campaign(seed_value))

    _analyze_v6_campaigns()
    var report := {
        "schema_version": 6,
        "suite": "player_bot_v6_real_campaign",
        "driver": "real_main_controller",
        "campaign_seeds": V6_CAMPAIGN_SEEDS,
        "max_expeditions": V6_MAX_EXPEDITIONS,
        "max_rooms_per_expedition": V6_MAX_ROOMS_PER_EXPEDITION,
        "coverage": v6_coverage,
        "campaigns": campaigns,
        "alerts": alerts,
        "failures": failures,
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_v6_report(report)
    SaveManager.delete_qa_snapshot()
    if failures.is_empty():
        print("PLAYER_BOT_V6_OK campaigns=%d alerts=%d" % [campaigns.size(), alerts.size()])
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V6: " + str(failure))
    get_tree().quit(1)

func _run_real_campaign(seed_value: int) -> Dictionary:
    seed(seed_value)
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(seed_value * 17 + 3)
    CreatureManager.reset_new_game(seed_value * 23 + 7)
    ExpeditionManager.reset_new_game()
    SaveManager.delete_qa_snapshot()
    _prepare_real_initial_party(seed_value)

    var history: Array[Dictionary] = []
    var starting_gold := GameState.gold
    var starting_essence := GameState.essence
    var total_rooms := 0
    var total_combats := 0
    var total_victories := 0
    var total_defeats := 0
    var total_captures := 0
    var total_extractions := 0
    var total_boss_clears := 0
    var total_save_roundtrips := 0
    var total_stashed := 0
    var total_treated := 0
    var total_worsened := 0
    var production_xp_events := 0
    var recruitment_needed := 0

    for expedition_index in range(1, V6_MAX_EXPEDITIONS + 1):
        if GameState.alive_heroes().is_empty():
            break
        var expedition_seed := seed_value * 1000 + expedition_index
        ExpeditionManager.start_expedition(expedition_seed)
        _reset_controller_state()
        var layout := ExpeditionManager.dungeon_layout()
        if layout.is_empty():
            failures.append("seed_%d_exp_%d_empty_layout" % [seed_value, expedition_index])
            break

        var row := {
            "expedition": expedition_index,
            "seed": expedition_seed,
            "level_before": _average_level(),
            "gold_before": GameState.gold,
            "essence_before": GameState.essence,
            "inventory_before": ExpeditionManager.inventory.duplicate(true),
            "rooms": 0,
            "combats": 0,
            "victories": 0,
            "defeats": 0,
            "captures": 0,
            "decision": "continue",
            "extraction_reason": "",
            "reward_preview": {},
            "production_xp_delta": 0,
            "hero_deaths": 0
        }
        var level_signature_before := _level_xp_signature()
        var alive_before_expedition := GameState.alive_heroes().size()
        var current_id := ""
        var visited: Array[String] = []
        var boss_cleared := false

        while int(row["rooms"]) < V6_MAX_ROOMS_PER_EXPEDITION and ExpeditionManager.expedition_active:
            var next_room := _choose_real_next_room(layout, current_id, visited)
            if next_room.is_empty():
                row["decision"] = "extract"
                row["extraction_reason"] = "no_reachable_room"
                break
            if _should_extract_before_room(next_room, row):
                row["decision"] = "extract"
                row["extraction_reason"] = _extraction_reason()
                break

            var room_id := str(next_room.get("id", ""))
            var entry := ExpeditionManager.enter_dungeon_room(room_id)
            if not bool(entry.get("success", false)):
                failures.append("seed_%d_exp_%d_enter_%s" % [seed_value, expedition_index, room_id])
                row["decision"] = "extract"
                row["extraction_reason"] = "enter_room_failed"
                break
            current_id = room_id
            if not visited.has(room_id):
                visited.append(room_id)
            row["rooms"] = int(row["rooms"]) + 1
            total_rooms += 1
            var room: Dictionary = entry.get("room", next_room)
            var room_type := str(room.get("type", "combat"))

            if room_type in ["combat", "elite", "ambush", "creature", "boss"]:
                row["combats"] = int(row["combats"]) + 1
                total_combats += 1
                var captured_before := CreatureManager.captured_creatures.size()
                var level_before_combat := _level_xp_signature()
                var combat_result := await _drive_combat(seed_value, expedition_index, int(row["combats"]), room)
                if bool(combat_result.get("victory", false)):
                    row["victories"] = int(row["victories"]) + 1
                    total_victories += 1
                    if _level_xp_signature() != level_before_combat:
                        production_xp_events += 1
                        row["production_xp_delta"] = int(row["production_xp_delta"]) + 1
                    _unlock_progression_skills()
                    if room_type == "boss":
                        boss_cleared = true
                        total_boss_clears += 1
                else:
                    row["defeats"] = int(row["defeats"]) + 1
                    total_defeats += 1
                    row["decision"] = "extract"
                    row["extraction_reason"] = "combat_defeat"
                    break
                var captures_delta := CreatureManager.captured_creatures.size() - captured_before
                row["captures"] = int(row["captures"]) + captures_delta
                total_captures += captures_delta
            else:
                controller._resolve_noncombat_room(room)
                controller._mark_current_room_cleared()
                await get_tree().process_frame

            if boss_cleared:
                row["decision"] = "extract"
                row["extraction_reason"] = "boss_defeated"
                break
            if GameState.alive_heroes().is_empty():
                row["decision"] = "defeat"
                row["extraction_reason"] = "party_wipe"
                break

        row["reward_preview"] = ExpeditionManager.extraction_summary().duplicate(true)
        if ExpeditionManager.expedition_active:
            var reason := str(row["extraction_reason"])
            if reason == "":
                reason = "extracted"
            controller._extract_roguelike_run("boss_defeated" if boss_cleared else "extracted")
            await get_tree().process_frame
            total_extractions += 1

        var deaths_this_exp := maxi(0, alive_before_expedition - GameState.alive_heroes().size())
        row["hero_deaths"] = deaths_this_exp
        if deaths_this_exp > 0:
            recruitment_needed += deaths_this_exp

        var worsened := PersistentInjuryRuntime.close_expedition(GameState.party)
        total_worsened += worsened.size()
        var treatment := PersistentInjuryRuntime.treat_all_at_infirmary(GameState.party)
        total_treated += int(treatment.get("treated", 0)) + int(treatment.get("stabilized", 0))
        total_stashed += _manage_real_guild_stash()

        row["level_after"] = _average_level()
        row["gold_after"] = GameState.gold
        row["essence_after"] = GameState.essence
        row["inventory_after"] = ExpeditionManager.inventory.duplicate(true)
        row["inventory_consumption"] = _inventory_delta(row["inventory_before"], row["inventory_after"])
        row["alive_heroes"] = GameState.alive_heroes().size()
        row["injuries"] = _injury_count()
        row["captured_creatures"] = CreatureManager.captured_creatures.size()
        row["stash_items"] = EquipmentManager.guild_stash.size()
        row["level_state_changed"] = _level_xp_signature() != level_signature_before
        history.append(row)

        if expedition_index % V6_SAVE_INTERVAL == 0:
            if not _verify_save_roundtrip(seed_value, expedition_index):
                failures.append("seed_%d_v6_save_roundtrip_%d" % [seed_value, expedition_index])
                break
            total_save_roundtrips += 1

    return {
        "seed": seed_value,
        "expeditions": history.size(),
        "history": history,
        "rooms": total_rooms,
        "combats": total_combats,
        "victories": total_victories,
        "defeats": total_defeats,
        "captures": total_captures,
        "extractions": total_extractions,
        "boss_clears": total_boss_clears,
        "save_roundtrips": total_save_roundtrips,
        "stash_moves": total_stashed,
        "injuries_treated_or_stabilized": total_treated,
        "injuries_worsened": total_worsened,
        "production_xp_events": production_xp_events,
        "recruitment_needed": recruitment_needed,
        "starting_gold": starting_gold,
        "ending_gold": GameState.gold,
        "starting_essence": starting_essence,
        "ending_essence": GameState.essence,
        "final_average_level": _average_level(),
        "alive_heroes": GameState.alive_heroes().size(),
        "captured_creatures": CreatureManager.captured_creatures.size(),
        "equipment_items": EquipmentManager.items.size(),
        "stash_items": EquipmentManager.guild_stash.size()
    }

func _prepare_real_initial_party(seed_value: int) -> void:
    for hero_index in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[hero_index]
        HeroSkillManager.prepare_hero(hero)
        PersistentInjuryRuntime.prepare_character(hero)
        var branches := HeroSkillManager.branches_for(hero)
        if not branches.is_empty():
            hero["qa_preferred_branch"] = str(branches[(hero_index + seed_value) % branches.size()])
    _unlock_progression_skills()

func _choose_real_next_room(layout: Array, current_id: String, visited: Array[String]) -> Dictionary:
    if visited.is_empty():
        return (layout[0] as Dictionary).duplicate(true)
    var current := _room_by_id_v6(layout, current_id)
    if current.is_empty():
        return {}
    var candidates: Array[Dictionary] = []
    for connection_value in current.get("connections", []):
        var target_id := str(connection_value)
        if visited.has(target_id):
            continue
        var target := _room_by_id_v6(layout, target_id)
        if not target.is_empty():
            candidates.append(target)
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return _room_score_v6(a) > _room_score_v6(b)
    )
    return candidates[0].duplicate(true)

func _room_by_id_v6(layout: Array, room_id: String) -> Dictionary:
    for room_value in layout:
        var room: Dictionary = room_value
        if str(room.get("id", "")) == room_id:
            return room
    return {}

func _room_score_v6(room: Dictionary) -> int:
    var room_type := str(room.get("type", ""))
    return int({
        "camp": 100, "boss": 95, "treasure": 86, "secret": 82, "sanctuary": 80,
        "combat": 70, "creature": 68, "elite": 62, "ruins": 58, "altar": 55,
        "corpse": 52, "merchant": 50, "survivor": 48, "trap": 20, "anomaly": 18
    }.get(room_type, 40))

func _should_extract_before_room(next_room: Dictionary, row: Dictionary) -> bool:
    if int(row.get("rooms", 0)) <= 1:
        return false
    if _lowest_party_hp_ratio() <= V6_LOW_HP_EXTRACT:
        return true
    var capacity := maxi(1, ExpeditionManager.inventory_capacity())
    if float(ExpeditionManager.inventory_slots_used()) / float(capacity) >= V6_INVENTORY_EXTRACT_RATIO:
        return true
    if GameState.alive_heroes().size() <= maxi(1, int(ceil(float(GameState.party.size()) * 0.5))):
        return true
    var light := int(ExpeditionManager.inventory.get("light", 0))
    var food := int(ExpeditionManager.inventory.get("food", 0))
    if light <= 1 or food <= 0:
        return true
    return false

func _extraction_reason() -> String:
    if _lowest_party_hp_ratio() <= V6_LOW_HP_EXTRACT:
        return "low_party_hp"
    var capacity := maxi(1, ExpeditionManager.inventory_capacity())
    if float(ExpeditionManager.inventory_slots_used()) / float(capacity) >= V6_INVENTORY_EXTRACT_RATIO:
        return "inventory_pressure"
    if int(ExpeditionManager.inventory.get("light", 0)) <= 1:
        return "low_light"
    if int(ExpeditionManager.inventory.get("food", 0)) <= 0:
        return "no_food"
    return "survival_policy"

func _manage_real_guild_stash() -> int:
    var equipped_ids: Dictionary = {}
    for slots_value in EquipmentManager.equipped_by_hero.values():
        var slots: Dictionary = slots_value
        for instance_value in slots.values():
            equipped_ids[str(instance_value)] = true
    var moved := 0
    for item_value in EquipmentManager.items.duplicate(true):
        var item: Dictionary = item_value
        var instance_id := str(item.get("instance_id", ""))
        if instance_id == "" or equipped_ids.has(instance_id):
            continue
        if EquipmentManager.store_in_guild_stash(instance_id):
            moved += 1
    return moved

func _inventory_delta(before: Dictionary, after: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var keys: Dictionary = {}
    for key in before.keys(): keys[str(key)] = true
    for key in after.keys(): keys[str(key)] = true
    for key in keys.keys():
        result[str(key)] = int(after.get(key, 0)) - int(before.get(key, 0))
    return result

func _level_xp_signature() -> String:
    var parts: Array[String] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        parts.append("%s:%d:%d" % [str(hero.get("id", "")), int(hero.get("level", 1)), int(hero.get("xp", 0))])
    return "|".join(parts)

func _analyze_v6_campaigns() -> void:
    for campaign_value in campaigns:
        var campaign: Dictionary = campaign_value
        var seed_value := int(campaign.get("seed", 0))
        if int(campaign.get("rooms", 0)) > 0 and int(campaign.get("production_xp_events", 0)) == 0:
            alerts.append({"severity":"high","code":"production_xp_missing","seed":seed_value,"message":"Aucun XP de production observé malgré des combats réels."})
        if int(campaign.get("recruitment_needed", 0)) > 0:
            alerts.append({"severity":"medium","code":"recruitment_runtime_not_covered","seed":seed_value,"deaths":int(campaign.get("recruitment_needed", 0)),"message":"Des morts permanentes nécessitent un remplacement, mais aucun manager de recrutement public n'est exposé au bot."})
        if int(campaign.get("ending_gold", 0)) == int(campaign.get("starting_gold", 0)) and int(campaign.get("victories", 0)) > 0:
            alerts.append({"severity":"medium","code":"gold_flow_flat","seed":seed_value})
        if int(campaign.get("ending_essence", 0)) == int(campaign.get("starting_essence", 0)) and int(campaign.get("victories", 0)) > 0:
            alerts.append({"severity":"medium","code":"essence_flow_flat","seed":seed_value})
        if int(campaign.get("save_roundtrips", 0)) == 0 and int(campaign.get("expeditions", 0)) >= V6_SAVE_INTERVAL:
            alerts.append({"severity":"high","code":"save_roundtrip_missing","seed":seed_value})
        if int(campaign.get("extractions", 0)) == 0 and int(campaign.get("expeditions", 0)) > 0:
            alerts.append({"severity":"high","code":"extraction_never_completed","seed":seed_value})

func _write_v6_report(report: Dictionary) -> void:
    var file := FileAccess.open(V6_REPORT_PATH, FileAccess.WRITE)
    if file == null:
        failures.append("report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
