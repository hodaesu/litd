extends Node

const REPORT_PATH := "res://reports/player-bot-v3-build-matrix.json"
const SEEDS: Array[int] = [101, 202, 303]
const SCENARIOS: Array[Dictionary] = [
    {"id":"normal_d1","type":"combat","depth":1},
    {"id":"elite_d3","type":"elite","depth":3},
    {"id":"boss_d5","type":"boss","depth":5}
]
const MAX_ACTIONS := 180
const NO_PROGRESS_LIMIT := 18
const DOMINANCE_GAP := 0.20
const UNDERPERFORM_GAP := 0.20

var controller: Control
var results: Array[Dictionary] = []
var alerts: Array[Dictionary] = []
var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        push_error("PLAYER_BOT_V3: cannot load Main.tscn")
        get_tree().quit(1)
        return
    controller = packed.instantiate() as Control
    if controller == null:
        push_error("PLAYER_BOT_V3: cannot instantiate Main.tscn")
        get_tree().quit(1)
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    var started_ms := Time.get_ticks_msec()
    var builds := _build_matrix()
    for build in builds:
        for seed_value in SEEDS:
            results.append(await _run_build_seed(build, seed_value))

    var summary := _summarize(builds)
    _detect_balance_alerts(summary)
    var report := {
        "schema_version": 3,
        "suite": "player_bot_v3_build_matrix",
        "driver": "real_main_controller",
        "seeds": SEEDS,
        "scenarios": SCENARIOS,
        "builds": builds,
        "results": results,
        "summary": summary,
        "alerts": alerts,
        "failures": failures,
        "thresholds": {"dominance_gap":DOMINANCE_GAP,"underperform_gap":UNDERPERFORM_GAP},
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)
    if failures.is_empty():
        print("PLAYER_BOT_V3_OK builds=%d runs=%d alerts=%d" % [builds.size(), results.size(), alerts.size()])
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V3: " + str(failure))
    get_tree().quit(1)

func _build_matrix() -> Array[Dictionary]:
    GameState.reset_new_game()
    var branch_sets: Array[Array] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        branch_sets.append(HeroSkillManager.branches_for(hero))
    var builds: Array[Dictionary] = []
    for branch_index in range(3):
        var choices: Dictionary = {}
        for hero_index in range(GameState.party.size()):
            var hero: Dictionary = GameState.party[hero_index]
            var branches: Array = branch_sets[hero_index]
            if not branches.is_empty():
                choices[str(hero.get("id", hero_index))] = str(branches[mini(branch_index, branches.size() - 1)])
        builds.append({"id":"uniform_branch_%d" % branch_index,"choices":choices})
    var mixed: Dictionary = {}
    for hero_index in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[hero_index]
        var branches: Array = branch_sets[hero_index]
        if not branches.is_empty():
            mixed[str(hero.get("id", hero_index))] = str(branches[hero_index % branches.size()])
    builds.append({"id":"mixed_rotation","choices":mixed})
    return builds

func _run_build_seed(build: Dictionary, seed_value: int) -> Dictionary:
    seed(seed_value)
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(seed_value * 17 + 3)
    CreatureManager.reset_new_game(seed_value * 23 + 7)
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition(seed_value)
    _apply_build(build)

    var wins := 0
    var losses := 0
    var actions := 0
    var rounds := 0
    var deaths := 0
    var damage := 0
    var healing := 0
    var skill_usage: Dictionary = {}
    var scenario_rows: Array[Dictionary] = []

    for scenario in SCENARIOS:
        _restore_party_for_scenario()
        var result := await _drive_scenario(seed_value, build, scenario, skill_usage)
        scenario_rows.append(result)
        wins += 1 if bool(result.get("victory", false)) else 0
        losses += 0 if bool(result.get("victory", false)) else 1
        actions += int(result.get("actions", 0))
        rounds += int(result.get("rounds", 0))
        deaths += int(result.get("deaths", 0))
        damage += int(result.get("damage", 0))
        healing += int(result.get("healing", 0))

    return {
        "build_id": str(build.get("id", "build")),
        "seed": seed_value,
        "wins": wins,
        "losses": losses,
        "win_rate": float(wins) / float(SCENARIOS.size()),
        "actions": actions,
        "rounds": rounds,
        "deaths": deaths,
        "damage": damage,
        "healing": healing,
        "skill_usage": skill_usage,
        "scenarios": scenario_rows
    }

func _apply_build(build: Dictionary) -> void:
    var choices: Dictionary = build.get("choices", {})
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        HeroSkillManager.prepare_hero(hero)
        hero["level"] = 50
        hero["skill_points"] = 999
        hero["xp"] = 0
        hero["unlocked_skills"] = []
        hero["specialization"] = ""
        var hero_id := str(hero.get("id", ""))
        var branch := str(choices.get(hero_id, ""))
        if branch == "":
            continue
        for node_value in HeroSkillManager.production_skill_nodes(hero, branch):
            var node: Dictionary = node_value
            var skill_id := str(node.get("id", ""))
            if skill_id != "":
                HeroSkillManager.unlock(hero, skill_id)
        var candidates: Array[String] = []
        for skill_value in HeroSkillManager.known_combat_skills(hero):
            var skill: Dictionary = skill_value
            if str(skill.get("branch", branch)) == branch and str(skill.get("id", "")) != "":
                candidates.append(str(skill.get("id", "")))
        var slot := 0
        for skill_id in candidates:
            if slot >= HeroSkillManager.COMBAT_LOADOUT_SIZE:
                break
            if HeroSkillManager.equip_combat_skill(hero, slot, skill_id):
                slot += 1
        HeroSkillManager.prepare_hero(hero)

func _restore_party_for_scenario() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var max_hp := maxi(1, int(hero.get("max_hp", hero.get("hp", 1))))
        hero["hp"] = max_hp
        hero["guarding"] = false
    GameState.battle_enemies = []
    controller.combat_active_hero_id = ""
    controller.combat_acted_hero_ids.clear()
    controller.combat_round_number = 1
    controller.battle_locked = false
    controller.selected_enemy = 0

func _drive_scenario(seed_value: int, build: Dictionary, scenario: Dictionary, skill_usage: Dictionary) -> Dictionary:
    var room := {"id":"v3_%s_%s_%d" % [str(build.get("id", "build")), str(scenario.get("id", "scenario")), seed_value], "type":str(scenario.get("type", "combat")), "depth":int(scenario.get("depth", 1))}
    controller._start_roguelike_room_battle(room)
    await get_tree().process_frame
    var start_round := int(controller.combat_round_number)
    var actions := 0
    var no_progress := 0
    var last_signature := _hp_signature()
    var damage_total := 0
    var healing_total := 0

    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and actions < MAX_ACTIONS:
        controller._ensure_combat_state()
        var hero: Dictionary = controller._active_combat_hero()
        if hero.is_empty():
            await get_tree().process_frame
            no_progress += 1
            if no_progress >= NO_PROGRESS_LIMIT:
                failures.append("softlock_%s_%s_%d" % [str(build.get("id", "build")), str(scenario.get("id", "scenario")), seed_value])
                break
            continue
        _select_lowest_hp_enemy()
        var choice := _choose_skill(hero)
        var skill_id := str(choice.get("skill_id", "basic_strike"))
        var before_enemy := _enemy_hp_total()
        var before_party := _party_hp_total()
        controller._use_combat_skill(int(choice.get("slot", 0)))
        await get_tree().process_frame
        actions += 1
        skill_usage[skill_id] = int(skill_usage.get(skill_id, 0)) + 1
        damage_total += maxi(0, before_enemy - _enemy_hp_total())
        healing_total += maxi(0, _party_hp_total() - before_party)
        var signature := _hp_signature()
        if signature == last_signature:
            no_progress += 1
        else:
            no_progress = 0
            last_signature = signature
        if no_progress >= NO_PROGRESS_LIMIT:
            failures.append("no_progress_%s_%s_%d" % [str(build.get("id", "build")), str(scenario.get("id", "scenario")), seed_value])
            break

    return {
        "scenario_id": str(scenario.get("id", "scenario")),
        "victory": GameState.alive_enemies().is_empty(),
        "actions": actions,
        "rounds": maxi(1, int(controller.combat_round_number) - start_round + 1),
        "deaths": GameState.party.size() - GameState.alive_heroes().size(),
        "damage": damage_total,
        "healing": healing_total,
        "party_hp_remaining": _party_hp_total()
    }

func _choose_skill(hero: Dictionary) -> Dictionary:
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    var lowest_ratio := 1.0
    for hero_value in GameState.alive_heroes():
        var ally: Dictionary = hero_value
        lowest_ratio = minf(lowest_ratio, float(ally.get("hp", 0)) / maxf(1.0, float(ally.get("max_hp", 1))))
    var best_slot := 0
    var best_score := -99999.0
    for slot in range(loadout.size()):
        var skill_id := str(loadout[slot])
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty():
            continue
        var effect := str(skill.get("effect", "attack"))
        var score := 0.0
        if effect in ["heal", "support", "medical"]:
            score = (100.0 if lowest_ratio < 0.45 else 12.0) + float(skill.get("heal", 0))
        elif effect in ["guard", "posture"]:
            score = 48.0 if lowest_ratio < 0.65 else 18.0
        elif effect == "diagnostic":
            score = 28.0
        else:
            score = 55.0 + float(skill.get("power", 1.0)) * 20.0 + float(skill.get("status_chance", 0)) * 0.1
        if score > best_score:
            best_score = score
            best_slot = slot
    return {"slot":best_slot,"skill_id":str(loadout[best_slot]) if best_slot < loadout.size() else "basic_strike"}

func _summarize(builds: Array[Dictionary]) -> Dictionary:
    var summary: Dictionary = {}
    for build in builds:
        var build_id := str(build.get("id", "build"))
        var rows: Array = []
        for row in results:
            if str((row as Dictionary).get("build_id", "")) == build_id:
                rows.append(row)
        var wins := 0
        var attempts := 0
        var actions := 0
        var deaths := 0
        var damage := 0
        var healing := 0
        var usage: Dictionary = {}
        for row_value in rows:
            var row: Dictionary = row_value
            wins += int(row.get("wins", 0))
            attempts += SCENARIOS.size()
            actions += int(row.get("actions", 0))
            deaths += int(row.get("deaths", 0))
            damage += int(row.get("damage", 0))
            healing += int(row.get("healing", 0))
            for skill_id in (row.get("skill_usage", {}) as Dictionary).keys():
                usage[str(skill_id)] = int(usage.get(str(skill_id), 0)) + int((row.get("skill_usage", {}) as Dictionary).get(skill_id, 0))
        summary[build_id] = {
            "win_rate": float(wins) / maxf(1.0, float(attempts)),
            "avg_actions": float(actions) / maxf(1.0, float(rows.size())),
            "avg_deaths": float(deaths) / maxf(1.0, float(rows.size())),
            "avg_damage": float(damage) / maxf(1.0, float(rows.size())),
            "avg_healing": float(healing) / maxf(1.0, float(rows.size())),
            "skill_usage": usage
        }
    return summary

func _detect_balance_alerts(summary: Dictionary) -> void:
    if summary.is_empty():
        return
    var rates: Array[float] = []
    for value in summary.values():
        rates.append(float((value as Dictionary).get("win_rate", 0.0)))
    var mean := 0.0
    for rate in rates:
        mean += rate
    mean /= maxf(1.0, float(rates.size()))
    for build_id in summary.keys():
        var row: Dictionary = summary[build_id]
        var rate := float(row.get("win_rate", 0.0))
        if rate - mean >= DOMINANCE_GAP:
            alerts.append({"severity":"high","code":"dominant_build","build_id":str(build_id),"win_rate":rate,"mean":mean})
        elif mean - rate >= UNDERPERFORM_GAP:
            alerts.append({"severity":"medium","code":"underperforming_build","build_id":str(build_id),"win_rate":rate,"mean":mean})
        var usage: Dictionary = row.get("skill_usage", {})
        for skill_id in usage.keys():
            if int(usage.get(skill_id, 0)) <= 1:
                alerts.append({"severity":"low","code":"rarely_used_skill","build_id":str(build_id),"skill_id":str(skill_id),"uses":int(usage.get(skill_id, 0))})

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

func _write_report(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        failures.append("report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
