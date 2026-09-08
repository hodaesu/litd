extends Node

const REPORT_PATH := "res://reports/player-bot-v5-longitudinal-campaign.json"
const CAMPAIGN_SEEDS: Array[int] = [101, 202]
const MAX_EXPEDITIONS := 36
const COMBATS_PER_EXPEDITION := 3
const MAX_ACTIONS_PER_COMBAT := 180
const NO_PROGRESS_LIMIT := 18
const SAVE_INTERVAL := 4
const XP_PER_VICTORY_BASE := 260

var controller: Control
var failures: Array[String] = []
var alerts: Array[Dictionary] = []
var campaigns: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        push_error("PLAYER_BOT_V5: cannot load Main.tscn")
        get_tree().quit(1)
        return
    controller = packed.instantiate() as Control
    if controller == null:
        push_error("PLAYER_BOT_V5: cannot instantiate Main.tscn")
        get_tree().quit(1)
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    var started_ms := Time.get_ticks_msec()
    for seed_value in CAMPAIGN_SEEDS:
        campaigns.append(await _run_campaign(seed_value))

    _analyze_campaigns()
    var report := {
        "schema_version": 5,
        "suite": "player_bot_v5_longitudinal_campaign",
        "driver": "real_main_controller",
        "campaign_seeds": CAMPAIGN_SEEDS,
        "max_expeditions": MAX_EXPEDITIONS,
        "combats_per_expedition": COMBATS_PER_EXPEDITION,
        "campaigns": campaigns,
        "alerts": alerts,
        "failures": failures,
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)
    SaveManager.delete_qa_snapshot()
    if failures.is_empty():
        print("PLAYER_BOT_V5_OK campaigns=%d alerts=%d" % [campaigns.size(), alerts.size()])
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V5: " + str(failure))
    get_tree().quit(1)

func _run_campaign(seed_value: int) -> Dictionary:
    seed(seed_value)
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(seed_value * 17 + 3)
    CreatureManager.reset_new_game(seed_value * 23 + 7)
    ExpeditionManager.reset_to_full_resupply()
    SaveManager.delete_qa_snapshot()
    _prepare_initial_party(seed_value)

    var history: Array[Dictionary] = []
    var total_victories := 0
    var total_defeats := 0
    var total_deaths := 0
    var total_captures := 0
    var total_loot := 0
    var total_treated := 0
    var total_stabilized := 0
    var total_worsened := 0
    var save_roundtrips := 0
    var starting_gold := GameState.gold
    var starting_essence := GameState.essence
    var reached_50_at := -1

    for expedition_index in range(1, MAX_EXPEDITIONS + 1):
        if GameState.alive_heroes().is_empty():
            break
        ExpeditionManager.reset_to_full_resupply()
        ExpeditionManager.start_expedition(seed_value * 1000 + expedition_index)
        _reset_controller_state()

        var row := {
            "expedition": expedition_index,
            "level_before": _average_level(),
            "gold_before": GameState.gold,
            "essence_before": GameState.essence,
            "injuries_before": _injury_count(),
            "victories": 0,
            "defeats": 0,
            "captures": 0,
            "loot": 0,
            "actions": 0,
            "hero_deaths": 0
        }

        for combat_index in range(COMbats_per_expedition()):
            if GameState.alive_heroes().is_empty():
                break
            _restore_living_party_partial()
            var combat_type := "combat"
            if combat_index == COMBATS_PER_EXPEDITION - 1:
                combat_type = "elite" if expedition_index % 4 != 0 else "boss"
            var depth := 1 + int(floor(float(expedition_index - 1) / 6.0)) + combat_index
            var room := {
                "id": "v5_%d_%d_%d" % [seed_value, expedition_index, combat_index],
                "type": combat_type,
                "depth": depth
            }
            var captured_before := CreatureManager.captured_creatures.size()
            var result := await _drive_combat(seed_value, expedition_index, combat_index, room)
            row["actions"] = int(row["actions"]) + int(result.get("actions", 0))
            row["hero_deaths"] = int(row["hero_deaths"]) + int(result.get("deaths", 0))
            if bool(result.get("victory", false)):
                row["victories"] = int(row["victories"]) + 1
                total_victories += 1
                _grant_campaign_xp(expedition_index, combat_index)
                _unlock_progression_skills()
                var rarity := _rarity_for_expedition(expedition_index)
                var loot := EquipmentManager.grant_random_party_weapon(rarity, "v5_campaign_%d_%d_%d" % [seed_value, expedition_index, combat_index])
                if not loot.is_empty():
                    row["loot"] = int(row["loot"]) + 1
                    total_loot += 1
                    _auto_equip_if_better(loot)
            else:
                row["defeats"] = int(row["defeats"]) + 1
                total_defeats += 1
                break
            var captures_delta := CreatureManager.captured_creatures.size() - captured_before
            row["captures"] = int(row["captures"]) + captures_delta
            total_captures += captures_delta

        total_deaths += int(row["hero_deaths"])
        var worsened := PersistentInjuryRuntime.close_expedition(GameState.party)
        total_worsened += worsened.size()
        var treatment := PersistentInjuryRuntime.treat_all_at_infirmary(GameState.party)
        total_treated += int(treatment.get("treated", 0))
        total_stabilized += int(treatment.get("stabilized", 0))

        row["level_after"] = _average_level()
        row["max_level"] = _max_level()
        row["gold_after"] = GameState.gold
        row["essence_after"] = GameState.essence
        row["injuries_after"] = _injury_count()
        row["captured_creatures"] = CreatureManager.captured_creatures.size()
        row["equipment_items"] = EquipmentManager.items.size()
        row["alive_heroes"] = GameState.alive_heroes().size()
        row["worsened_injuries"] = worsened.size()
        history.append(row)

        if reached_50_at < 0 and _max_level() >= GameState.MAX_CHARACTER_LEVEL:
            reached_50_at = expedition_index

        if expedition_index % SAVE_INTERVAL == 0:
            if not _verify_save_roundtrip(seed_value, expedition_index):
                failures.append("seed_%d_save_roundtrip_%d" % [seed_value, expedition_index])
                break
            save_roundtrips += 1

        if _max_level() >= GameState.MAX_CHARACTER_LEVEL and expedition_index >= 8:
            break

    return {
        "seed": seed_value,
        "expeditions": history.size(),
        "history": history,
        "victories": total_victories,
        "defeats": total_defeats,
        "hero_deaths": total_deaths,
        "captures": total_captures,
        "loot_items": total_loot,
        "injuries_treated": total_treated,
        "injuries_stabilized": total_stabilized,
        "injuries_worsened": total_worsened,
        "save_roundtrips": save_roundtrips,
        "starting_gold": starting_gold,
        "ending_gold": GameState.gold,
        "starting_essence": starting_essence,
        "ending_essence": GameState.essence,
        "final_average_level": _average_level(),
        "final_max_level": _max_level(),
        "level_50_expedition": reached_50_at,
        "alive_heroes": GameState.alive_heroes().size(),
        "captured_creatures": CreatureManager.captured_creatures.size(),
        "equipment_items": EquipmentManager.items.size(),
        "persistent_injuries": _injury_count()
    }

func COMbats_per_expedition() -> int:
    return COMBATS_PER_EXPEDITION

func _prepare_initial_party(seed_value: int) -> void:
    for hero_index in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[hero_index]
        HeroSkillManager.prepare_hero(hero)
        PersistentInjuryRuntime.prepare_character(hero)
        var branches := HeroSkillManager.branches_for(hero)
        if not branches.is_empty():
            hero["qa_preferred_branch"] = str(branches[(hero_index + seed_value) % branches.size()])
        EquipmentManager.grant_test_level_bundle(hero_index, "common")
    _unlock_progression_skills()

func _grant_campaign_xp(expedition_index: int, combat_index: int) -> void:
    var amount := XP_PER_VICTORY_BASE + expedition_index * 18 + combat_index * 35
    for hero_value in GameState.alive_heroes():
        HeroSkillManager.grant_xp(hero_value as Dictionary, amount)
    CreatureManager.grant_active_xp(maxi(1, int(round(float(amount) * 0.55))))

func _unlock_progression_skills() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        HeroSkillManager.prepare_hero(hero)
        var branch := str(hero.get("specialization", hero.get("qa_preferred_branch", "")))
        if branch == "":
            var branches := HeroSkillManager.branches_for(hero)
            if branches.is_empty():
                continue
            branch = str(branches[0])
        var unlocked_one := true
        while unlocked_one:
            unlocked_one = false
            for node_value in HeroSkillManager.production_skill_nodes(hero, branch):
                var node: Dictionary = node_value
                var skill_id := str(node.get("id", ""))
                if skill_id != "" and HeroSkillManager.can_unlock(hero, skill_id):
                    HeroSkillManager.unlock(hero, skill_id)
                    unlocked_one = true
                    break
        _equip_best_known_skills(hero)

func _equip_best_known_skills(hero: Dictionary) -> void:
    var candidates: Array[Dictionary] = HeroSkillManager.known_combat_skills(hero)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return _skill_score(a) > _skill_score(b)
    )
    var used: Dictionary = {}
    var slot := 0
    for skill in candidates:
        var skill_id := str(skill.get("id", ""))
        if skill_id == "" or used.has(skill_id):
            continue
        if HeroSkillManager.equip_combat_skill(hero, slot, skill_id):
            used[skill_id] = true
            slot += 1
        if slot >= HeroSkillManager.COMBAT_LOADOUT_SIZE:
            break

func _skill_score(skill: Dictionary) -> float:
    var effect := str(skill.get("effect", "attack"))
    if effect in ["heal", "support", "medical"]:
        return 70.0 + float(skill.get("heal", 0))
    if effect in ["guard", "posture"]:
        return 45.0 + float(skill.get("guard_bonus", 0))
    if effect == "diagnostic":
        return 35.0
    return 60.0 + float(skill.get("power", 1.0)) * 25.0 + float(skill.get("status_chance", 0)) * 0.15

func _drive_combat(seed_value: int, expedition_index: int, combat_index: int, room: Dictionary) -> Dictionary:
    _reset_controller_state()
    controller._start_roguelike_room_battle(room)
    await get_tree().process_frame
    if GameState.battle_enemies.is_empty():
        return {"victory": false, "reason": "no_enemies", "actions": 0, "deaths": 0}
    var alive_before := GameState.alive_heroes().size()
    var actions := 0
    var no_progress := 0
    var last_signature := _hp_signature()

    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and actions < MAX_ACTIONS_PER_COMBAT:
        controller._ensure_combat_state()
        var hero: Dictionary = controller._active_combat_hero()
        if hero.is_empty():
            await get_tree().process_frame
            no_progress += 1
            if no_progress >= NO_PROGRESS_LIMIT:
                failures.append("seed_%d_exp_%d_combat_%d_no_active_hero" % [seed_value, expedition_index, combat_index])
                break
            continue
        _select_lowest_hp_enemy()
        if ContentScopeDirector.is_unlocked("capture") and _try_real_capture():
            actions += 1
            await get_tree().process_frame
            continue
        var choice := _choose_campaign_skill(hero)
        controller._use_combat_skill(int(choice.get("slot", 0)))
        await get_tree().process_frame
        actions += 1
        var signature := _hp_signature()
        if signature == last_signature:
            no_progress += 1
        else:
            no_progress = 0
            last_signature = signature
        if no_progress >= NO_PROGRESS_LIMIT:
            failures.append("seed_%d_exp_%d_combat_%d_no_progress" % [seed_value, expedition_index, combat_index])
            break

    if actions >= MAX_ACTIONS_PER_COMBAT and not GameState.alive_enemies().is_empty():
        failures.append("seed_%d_exp_%d_combat_%d_action_cap" % [seed_value, expedition_index, combat_index])
    return {
        "victory": GameState.alive_enemies().is_empty(),
        "actions": actions,
        "deaths": maxi(0, alive_before - GameState.alive_heroes().size()),
        "party_hp_remaining": _party_hp_total()
    }

func _choose_campaign_skill(hero: Dictionary) -> Dictionary:
    var loadout := HeroSkillManager.combat_loadout(hero)
    var lowest_ratio := _lowest_party_hp_ratio()
    var best_slot := 0
    var best_score := -99999.0
    for slot in range(loadout.size()):
        var skill_id := str(loadout[slot])
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty():
            continue
        var score := _skill_score(skill)
        var effect := str(skill.get("effect", "attack"))
        if effect in ["heal", "support", "medical"]:
            score += 80.0 if lowest_ratio < 0.45 else -25.0
        elif effect in ["guard", "posture"] and lowest_ratio < 0.62:
            score += 30.0
        if score > best_score:
            best_score = score
            best_slot = slot
    return {"slot": best_slot, "skill_id": str(loadout[best_slot]) if best_slot < loadout.size() else "basic_strike"}

func _try_real_capture() -> bool:
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        var readiness := CreatureManager.capture_readiness(enemy)
        if bool(readiness.get("ready", false)):
            controller.selected_enemy = index
            var before := CreatureManager.captured_creatures.size()
            controller._combat_capture()
            return CreatureManager.captured_creatures.size() > before
    return false

func _rarity_for_expedition(expedition_index: int) -> String:
    if expedition_index >= 28:
        return "legendary"
    if expedition_index >= 20:
        return "epic"
    if expedition_index >= 12:
        return "rare"
    if expedition_index >= 6:
        return "uncommon"
    return "common"

func _auto_equip_if_better(item: Dictionary) -> void:
    var class_id := str(item.get("class_id", ""))
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("class_id", "")) != class_id:
            continue
        EquipmentManager.equip(str(hero.get("id", "")), str(item.get("instance_id", "")))
        return

func _verify_save_roundtrip(seed_value: int, expedition_index: int) -> bool:
    var before := _campaign_signature()
    if not SaveManager.save_qa_snapshot():
        return false
    GameState.gold += 777
    GameState.essence += 333
    if not GameState.party.is_empty():
        (GameState.party[0] as Dictionary)["hp"] = 1
    if not SaveManager.load_qa_snapshot():
        return false
    var after := _campaign_signature()
    if before != after:
        alerts.append({"severity":"high","code":"save_roundtrip_drift","seed":seed_value,"expedition":expedition_index,"before":before,"after":after})
        return false
    return true

func _campaign_signature() -> String:
    var hero_parts: Array[String] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        hero_parts.append("%s:%d:%d:%d:%d" % [str(hero.get("id", "")), int(hero.get("level",1)), int(hero.get("xp",0)), int(hero.get("hp",0)), (hero.get("persistent_injuries",[]) as Array).size()])
    return "%d|%d|%s|%d|%d" % [GameState.gold, GameState.essence, ";".join(hero_parts), EquipmentManager.items.size(), CreatureManager.captured_creatures.size()]

func _analyze_campaigns() -> void:
    for campaign in campaigns:
        var seed_value := int(campaign.get("seed", 0))
        var expeditions := int(campaign.get("expeditions", 0))
        var max_level := int(campaign.get("final_max_level", 1))
        if expeditions >= MAX_EXPEDITIONS and max_level < 40:
            alerts.append({"severity":"high","code":"progression_too_slow","seed":seed_value,"expeditions":expeditions,"max_level":max_level})
        if int(campaign.get("level_50_expedition", -1)) > 0 and int(campaign.get("level_50_expedition", -1)) < 8:
            alerts.append({"severity":"medium","code":"progression_too_fast","seed":seed_value,"level_50_expedition":int(campaign.get("level_50_expedition", -1))})
        if int(campaign.get("alive_heroes", 0)) == 0:
            alerts.append({"severity":"high","code":"campaign_party_wipe","seed":seed_value})
        if int(campaign.get("victories", 0)) >= 12 and int(campaign.get("captures", 0)) == 0:
            alerts.append({"severity":"medium","code":"capture_never_realized","seed":seed_value})
        if int(campaign.get("victories", 0)) >= 12 and int(campaign.get("injuries_treated", 0)) + int(campaign.get("injuries_stabilized", 0)) + int(campaign.get("injuries_worsened", 0)) == 0:
            alerts.append({"severity":"medium","code":"persistent_injury_never_exercised","seed":seed_value})
        var gold_delta := int(campaign.get("ending_gold", 0)) - int(campaign.get("starting_gold", 0))
        if gold_delta > 5000:
            alerts.append({"severity":"medium","code":"gold_inflation","seed":seed_value,"delta":gold_delta})
        if int(campaign.get("save_roundtrips", 0)) == 0:
            alerts.append({"severity":"high","code":"save_roundtrip_not_exercised","seed":seed_value})

func _restore_living_party_partial() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        var max_hp := maxi(1, int(hero.get("max_hp", 1)))
        var floor_hp := int(round(float(max_hp) * 0.70))
        hero["hp"] = maxi(int(hero.get("hp", 0)), floor_hp)
        hero["guarding"] = false

func _reset_controller_state() -> void:
    controller.combat_active_hero_id = ""
    controller.combat_acted_hero_ids.clear()
    controller.combat_round_number = 1
    controller.battle_locked = false
    controller.selected_enemy = 0
    GameState.battle_enemies = []

func _select_lowest_hp_enemy() -> void:
    var best_index := -1
    var best_hp := 2147483647
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        var hp := int(enemy.get("hp", 0))
        if hp > 0 and hp < best_hp:
            best_hp = hp
            best_index = index
    if best_index >= 0:
        controller.selected_enemy = best_index

func _party_hp_total() -> int:
    var total := 0
    for hero_value in GameState.party:
        total += maxi(0, int((hero_value as Dictionary).get("hp", 0)))
    return total

func _enemy_hp_total() -> int:
    var total := 0
    for enemy_value in GameState.battle_enemies:
        total += maxi(0, int((enemy_value as Dictionary).get("hp", 0)))
    return total

func _hp_signature() -> String:
    return "%d:%d:%d:%d" % [_party_hp_total(), _enemy_hp_total(), GameState.alive_heroes().size(), GameState.alive_enemies().size()]

func _lowest_party_hp_ratio() -> float:
    var result := 1.0
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        result = minf(result, float(hero.get("hp",0)) / maxf(1.0, float(hero.get("max_hp",1))))
    return result

func _average_level() -> float:
    if GameState.party.is_empty():
        return 0.0
    var total := 0
    for hero_value in GameState.party:
        total += int((hero_value as Dictionary).get("level", 1))
    return float(total) / float(GameState.party.size())

func _max_level() -> int:
    var result := 1
    for hero_value in GameState.party:
        result = maxi(result, int((hero_value as Dictionary).get("level", 1)))
    return result

func _injury_count() -> int:
    var total := 0
    for hero_value in GameState.party:
        total += ((hero_value as Dictionary).get("persistent_injuries", []) as Array).size()
    return total

func _write_report(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        failures.append("report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
