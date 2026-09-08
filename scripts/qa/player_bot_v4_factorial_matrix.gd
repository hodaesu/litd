extends Node

const REPORT_PATH := "res://reports/player-bot-v4-factorial-matrix.json"
const LEVELS: Array[int] = [1, 16, 32, 48, 50]
const RARITIES: Array[String] = ["common", "rare", "legendary"]
const POLICIES: Array[String] = ["aggressive", "balanced", "survival"]
const COMPANION_STATES: Array[bool] = [false, true]
const SEEDS: Array[int] = [101, 303]
const SCENARIOS: Array[Dictionary] = [
    {"id":"normal_d1","type":"combat","depth":1},
    {"id":"boss_d5","type":"boss","depth":5}
]
const MAX_ACTIONS := 180
const NO_PROGRESS_LIMIT := 18
const DOMINANCE_GAP := 0.20
const DIFFICULTY_HIGH := 0.35
const DIFFICULTY_LOW := 0.90

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
        push_error("PLAYER_BOT_V4: cannot load Main.tscn")
        get_tree().quit(1)
        return
    controller = packed.instantiate() as Control
    if controller == null:
        push_error("PLAYER_BOT_V4: cannot instantiate Main.tscn")
        get_tree().quit(1)
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    var started_ms := Time.get_ticks_msec()
    var builds := _build_profiles()
    var cases := _factorial_cases(builds)
    for case_value in cases:
        var case: Dictionary = case_value
        for seed_value in SEEDS:
            results.append(await _run_case(case, seed_value))

    var summary := _summarize()
    _detect_alerts(summary)
    var report := {
        "schema_version": 4,
        "suite": "player_bot_v4_factorial_matrix",
        "driver": "real_main_controller",
        "levels": LEVELS,
        "rarities": RARITIES,
        "policies": POLICIES,
        "companion_states": COMPANION_STATES,
        "seeds": SEEDS,
        "scenarios": SCENARIOS,
        "cases": cases,
        "results": results,
        "summary": summary,
        "alerts": alerts,
        "failures": failures,
        "thresholds": {
            "dominance_gap": DOMINANCE_GAP,
            "boss_too_hard_below": DIFFICULTY_HIGH,
            "boss_too_easy_above": DIFFICULTY_LOW
        },
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)
    if failures.is_empty():
        print("PLAYER_BOT_V4_OK cases=%d runs=%d alerts=%d" % [cases.size(), results.size(), alerts.size()])
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V4: " + str(failure))
    get_tree().quit(1)

func _build_profiles() -> Array[Dictionary]:
    GameState.reset_new_game()
    var result: Array[Dictionary] = []
    for branch_index in range(3):
        var choices: Dictionary = {}
        for hero_value in GameState.party:
            var hero: Dictionary = hero_value
            var branches := HeroSkillManager.branches_for(hero)
            if not branches.is_empty():
                choices[str(hero.get("id", "hero"))] = str(branches[mini(branch_index, branches.size() - 1)])
        result.append({"id":"uniform_%d" % branch_index, "choices":choices})
    var mixed: Dictionary = {}
    for index in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[index]
        var branches := HeroSkillManager.branches_for(hero)
        if not branches.is_empty():
            mixed[str(hero.get("id", "hero"))] = str(branches[index % branches.size()])
    result.append({"id":"mixed_rotation", "choices":mixed})
    return result

func _factorial_cases(builds: Array[Dictionary]) -> Array[Dictionary]:
    var cases: Array[Dictionary] = []
    # Pairwise-complete CI matrix: every value of every factor appears repeatedly,
    # while avoiding the 4*5*3*2*3 full Cartesian explosion on every push.
    # The rotation still crosses build, level, rarity, companion and policy.
    var index := 0
    for build in builds:
        for level in LEVELS:
            for policy in POLICIES:
                var rarity := RARITIES[(index + level + policy.hash()) % RARITIES.size()]
                var companion := COMPANION_STATES[(index + level) % COMPANION_STATES.size()]
                cases.append({
                    "id":"%s_l%d_%s_%s_%s" % [str(build.get("id", "build")), level, rarity, "companion" if companion else "solo", policy],
                    "build": build,
                    "level": level,
                    "rarity": rarity,
                    "companion": companion,
                    "policy": policy
                })
                index += 1
    return cases

func _run_case(case: Dictionary, seed_value: int) -> Dictionary:
    seed(seed_value)
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(seed_value * 31 + int(case.get("level", 1)))
    CreatureManager.reset_new_game(seed_value * 47 + 9)
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition(seed_value)
    _apply_case(case)

    var scenario_rows: Array[Dictionary] = []
    var wins := 0
    var actions := 0
    var deaths := 0
    var damage := 0
    var healing := 0
    var companion_damage := 0
    var usage: Dictionary = {}
    for scenario_value in SCENARIOS:
        var scenario: Dictionary = scenario_value
        _restore_party()
        var row := await _drive_scenario(case, seed_value, scenario, usage)
        scenario_rows.append(row)
        wins += 1 if bool(row.get("victory", false)) else 0
        actions += int(row.get("actions", 0))
        deaths += int(row.get("deaths", 0))
        damage += int(row.get("damage", 0))
        healing += int(row.get("healing", 0))
        companion_damage += int(row.get("companion_damage", 0))
    return {
        "case_id": str(case.get("id", "case")),
        "build_id": str((case.get("build", {}) as Dictionary).get("id", "build")),
        "level": int(case.get("level", 1)),
        "rarity": str(case.get("rarity", "common")),
        "companion": bool(case.get("companion", false)),
        "policy": str(case.get("policy", "balanced")),
        "seed": seed_value,
        "wins": wins,
        "win_rate": float(wins) / float(SCENARIOS.size()),
        "actions": actions,
        "deaths": deaths,
        "damage": damage,
        "healing": healing,
        "companion_damage": companion_damage,
        "skill_usage": usage,
        "scenarios": scenario_rows
    }

func _apply_case(case: Dictionary) -> void:
    var level := int(case.get("level", 1))
    var build: Dictionary = case.get("build", {})
    var choices: Dictionary = build.get("choices", {})
    for hero_index in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[hero_index]
        hero["level"] = level
        hero["xp"] = 0
        hero["skill_points"] = 999
        hero["unlocked_skills"] = []
        hero["specialization"] = ""
        HeroSkillManager.prepare_hero(hero)
        var branch := str(choices.get(str(hero.get("id", "")), ""))
        if branch != "":
            for node_value in HeroSkillManager.production_skill_nodes(hero, branch):
                var node: Dictionary = node_value
                if int(node.get("required_level", 999)) <= level:
                    HeroSkillManager.unlock(hero, str(node.get("id", "")))
            _equip_branch_loadout(hero, branch)
        EquipmentManager.grant_test_level_bundle(hero_index, str(case.get("rarity", "common")))
    if bool(case.get("companion", false)):
        _grant_test_companion(level)

func _equip_branch_loadout(hero: Dictionary, branch: String) -> void:
    var candidates: Array[String] = []
    for skill_value in HeroSkillManager.known_combat_skills(hero):
        var skill: Dictionary = skill_value
        var skill_id := str(skill.get("id", ""))
        if skill_id != "" and str(skill.get("branch", branch)) == branch:
            candidates.append(skill_id)
    var slot := 0
    for skill_id in candidates:
        if slot >= HeroSkillManager.COMBAT_LOADOUT_SIZE:
            break
        if HeroSkillManager.equip_combat_skill(hero, slot, skill_id):
            slot += 1
    HeroSkillManager.prepare_hero(hero)

func _grant_test_companion(level: int) -> void:
    if DataLoader.capturable_creatures.is_empty():
        return
    var definition: Dictionary = DataLoader.capturable_creatures[0]
    var creature := CreatureManager._create_creature(definition)
    if creature.is_empty():
        return
    creature["level"] = level
    creature["xp"] = 0
    CreatureManager.captured_creatures.append(creature)
    CreatureManager.active_instance_id = str(creature.get("instance_id", ""))

func _restore_party() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        hero["hp"] = maxi(1, int(hero.get("max_hp", hero.get("hp", 1))))
        hero["guarding"] = false
    GameState.battle_enemies = []
    controller.combat_active_hero_id = ""
    controller.combat_acted_hero_ids.clear()
    controller.combat_round_number = 1
    controller.battle_locked = false
    controller.selected_enemy = 0

func _drive_scenario(case: Dictionary, seed_value: int, scenario: Dictionary, usage: Dictionary) -> Dictionary:
    var room := {
        "id":"v4_%s_%s_%d" % [str(case.get("id", "case")), str(scenario.get("id", "scenario")), seed_value],
        "type":str(scenario.get("type", "combat")),
        "depth":int(scenario.get("depth", 1))
    }
    controller._start_roguelike_room_battle(room)
    await get_tree().process_frame
    var actions := 0
    var no_progress := 0
    var last_signature := _hp_signature()
    var damage_total := 0
    var healing_total := 0
    var companion_damage_total := 0

    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and actions < MAX_ACTIONS:
        controller._ensure_combat_state()
        var hero: Dictionary = controller._active_combat_hero()
        if hero.is_empty():
            await get_tree().process_frame
            no_progress += 1
            if no_progress >= NO_PROGRESS_LIMIT:
                failures.append("softlock_%s_%s_%d" % [str(case.get("id", "case")), str(scenario.get("id", "scenario")), seed_value])
                break
            continue
        _select_lowest_hp_enemy()
        var choice := _choose_skill(hero, str(case.get("policy", "balanced")))
        var skill_id := str(choice.get("skill_id", "basic_strike"))
        var before_enemy := _enemy_hp_total()
        var before_party := _party_hp_total()
        controller._use_combat_skill(int(choice.get("slot", 0)))
        await get_tree().process_frame
        actions += 1
        usage[skill_id] = int(usage.get(skill_id, 0)) + 1
        damage_total += maxi(0, before_enemy - _enemy_hp_total())
        healing_total += maxi(0, _party_hp_total() - before_party)

        if bool(case.get("companion", false)) and not GameState.alive_enemies().is_empty() and CreatureManager.active_instance_id != "":
            var target: Dictionary = GameState.alive_enemies()[0]
            var hp_before := int(target.get("hp", 0))
            var companion_result := CreatureManager.companion_turn(target)
            if not companion_result.is_empty():
                companion_damage_total += maxi(0, hp_before - int(target.get("hp", 0)))

        var signature := _hp_signature()
        if signature == last_signature:
            no_progress += 1
        else:
            no_progress = 0
            last_signature = signature
        if no_progress >= NO_PROGRESS_LIMIT:
            failures.append("no_progress_%s_%s_%d" % [str(case.get("id", "case")), str(scenario.get("id", "scenario")), seed_value])
            break

    return {
        "scenario_id":str(scenario.get("id", "scenario")),
        "victory":GameState.alive_enemies().is_empty(),
        "actions":actions,
        "deaths":GameState.party.size() - GameState.alive_heroes().size(),
        "damage":damage_total,
        "healing":healing_total,
        "companion_damage":companion_damage_total,
        "party_hp_remaining":_party_hp_total()
    }

func _choose_skill(hero: Dictionary, policy: String) -> Dictionary:
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    var lowest_ratio := _lowest_hp_ratio()
    var best_slot := 0
    var best_score := -99999.0
    for slot in range(loadout.size()):
        var skill_id := str(loadout[slot])
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty():
            continue
        var effect := str(skill.get("effect", "attack"))
        var attack_score := 55.0 + float(skill.get("power", 1.0)) * 20.0 + float(skill.get("status_chance", 0)) * 0.1
        var heal_score := (100.0 if lowest_ratio < 0.45 else 12.0) + float(skill.get("heal", 0))
        var defense_score := 48.0 if lowest_ratio < 0.65 else 18.0
        var score := attack_score
        if effect in ["heal", "support", "medical"]:
            score = heal_score
        elif effect in ["guard", "posture"]:
            score = defense_score
        elif effect == "diagnostic":
            score = 28.0
        if policy == "aggressive":
            score += 35.0 if effect == "attack" else -12.0
        elif policy == "survival":
            score += 35.0 if effect in ["heal", "support", "medical", "guard", "posture"] else 0.0
        if score > best_score:
            best_score = score
            best_slot = slot
    return {"slot":best_slot,"skill_id":str(loadout[best_slot]) if best_slot < loadout.size() else "basic_strike"}

func _summarize() -> Dictionary:
    var dimensions := {"build":{}, "level":{}, "rarity":{}, "companion":{}, "policy":{}, "scenario":{}}
    for row_value in results:
        var row: Dictionary = row_value
        _accumulate_dimension(dimensions["build"], str(row.get("build_id", "build")), int(row.get("wins", 0)), SCENARIOS.size())
        _accumulate_dimension(dimensions["level"], str(row.get("level", 1)), int(row.get("wins", 0)), SCENARIOS.size())
        _accumulate_dimension(dimensions["rarity"], str(row.get("rarity", "common")), int(row.get("wins", 0)), SCENARIOS.size())
        _accumulate_dimension(dimensions["companion"], "with" if bool(row.get("companion", false)) else "without", int(row.get("wins", 0)), SCENARIOS.size())
        _accumulate_dimension(dimensions["policy"], str(row.get("policy", "balanced")), int(row.get("wins", 0)), SCENARIOS.size())
        for scenario_value in row.get("scenarios", []):
            var scenario: Dictionary = scenario_value
            _accumulate_dimension(dimensions["scenario"], "%s@L%d" % [str(scenario.get("scenario_id", "scenario")), int(row.get("level", 1))], 1 if bool(scenario.get("victory", false)) else 0, 1)
    for dimension_value in dimensions.values():
        var dimension: Dictionary = dimension_value
        for key in dimension.keys():
            var cell: Dictionary = dimension[key]
            cell["win_rate"] = float(cell.get("wins", 0)) / maxf(1.0, float(cell.get("attempts", 0)))
            dimension[key] = cell
    return dimensions

func _accumulate_dimension(dimension: Dictionary, key: String, wins: int, attempts: int) -> void:
    var cell: Dictionary = dimension.get(key, {"wins":0,"attempts":0})
    cell["wins"] = int(cell.get("wins", 0)) + wins
    cell["attempts"] = int(cell.get("attempts", 0)) + attempts
    dimension[key] = cell

func _detect_alerts(summary: Dictionary) -> void:
    _detect_dimension_gap(summary.get("build", {}), "build")
    _detect_dimension_gap(summary.get("rarity", {}), "rarity")
    _detect_dimension_gap(summary.get("companion", {}), "companion")
    _detect_dimension_gap(summary.get("policy", {}), "policy")
    var scenarios: Dictionary = summary.get("scenario", {})
    for key in scenarios.keys():
        var rate := float((scenarios[key] as Dictionary).get("win_rate", 0.0))
        if str(key).begins_with("boss_d5") and rate < DIFFICULTY_HIGH:
            alerts.append({"severity":"high","code":"boss_too_hard_for_level","scenario":str(key),"win_rate":rate})
        elif str(key).begins_with("boss_d5") and rate > DIFFICULTY_LOW:
            alerts.append({"severity":"medium","code":"boss_too_easy_for_level","scenario":str(key),"win_rate":rate})

func _detect_dimension_gap(dimension: Dictionary, dimension_name: String) -> void:
    if dimension.size() < 2:
        return
    var min_key := ""
    var max_key := ""
    var min_rate := 2.0
    var max_rate := -1.0
    for key in dimension.keys():
        var rate := float((dimension[key] as Dictionary).get("win_rate", 0.0))
        if rate < min_rate:
            min_rate = rate
            min_key = str(key)
        if rate > max_rate:
            max_rate = rate
            max_key = str(key)
    if max_rate - min_rate >= DOMINANCE_GAP:
        alerts.append({"severity":"high","code":"factor_gap","dimension":dimension_name,"best":max_key,"best_rate":max_rate,"worst":min_key,"worst_rate":min_rate,"gap":max_rate-min_rate})

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

func _lowest_hp_ratio() -> float:
    var ratio := 1.0
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        ratio = minf(ratio, float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("max_hp", 1))))
    return ratio

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
