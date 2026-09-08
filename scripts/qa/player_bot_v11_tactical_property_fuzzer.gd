extends Node

const REPORT_PATH := "res://reports/player-bot-v11-tactical-property-fuzzer.json"
const POSITION_RULES := preload("res://scripts/core/combat_position_rules.gd")
const TARGETING_RULES := preload("res://scripts/core/combat_targeting_rules.gd")
const FIXED_SEEDS: Array[int] = [1101, 2202, 3303, 4404, 5505]
const CASES_PER_SEED := 1000
const MAX_REPROS := 50

var failures: Array[Dictionary] = []
var checks := 0

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var started_ms := Time.get_ticks_msec()
    for seed_value in FIXED_SEEDS:
        _run_seed(seed_value)
    var report := {
        "schema_version": 11,
        "suite": "player_bot_v11_tactical_property_fuzzer",
        "method": "deterministic_property_fuzzing",
        "fixed_seeds": FIXED_SEEDS,
        "cases_per_seed": CASES_PER_SEED,
        "cases": FIXED_SEEDS.size() * CASES_PER_SEED,
        "property_checks": checks,
        "failures": failures,
        "replay": "Rejouer avec seed + case_index présents dans failures.",
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)
    if failures.is_empty():
        print("PLAYER_BOT_V11_OK cases=%d checks=%d" % [FIXED_SEEDS.size() * CASES_PER_SEED, checks])
        get_tree().quit(0)
        return
    for failure in failures.slice(0, 10):
        push_error("PLAYER_BOT_V11: %s" % JSON.stringify(failure))
    get_tree().quit(1)

func _run_seed(seed_value: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    for case_index in range(CASES_PER_SEED):
        var hero := _random_hero(rng)
        var skill := _random_skill(rng)
        var enemies := _random_enemies(rng)
        TARGETING_RULES.ensure_enemy_positions(enemies)
        _check_position_contract(seed_value, case_index, hero, skill)
        _check_target_contract(seed_value, case_index, hero, skill, enemies)
        _check_dead_targets(seed_value, case_index, hero, skill, enemies)
        _check_enemy_positions(seed_value, case_index, enemies)
        _check_forced_movement(seed_value, case_index, hero, skill, enemies)

func _random_hero(rng: RandomNumberGenerator) -> Dictionary:
    var classes := ["breaker", "watcher", "inquisitor", "duelist", "vestal", "mystic", "ranger", "surgeon", "scout", "occultist", "unknown"]
    return {
        "id": "fuzz_hero",
        "class_id": classes[rng.randi_range(0, classes.size() - 1)],
        "combat_position": rng.randi_range(-2, 5),
        "hp": rng.randi_range(1, 200)
    }

func _random_skill(rng: RandomNumberGenerator) -> Dictionary:
    var ids := ["basic_strike", "heavy_blow", "guard_stance", "field_aid", "generated"]
    var effects := ["attack", "guard", "heal", "support", "diagnostic"]
    var stats := ["", "precision", "critical_chance", "break_chance", "stun_chance", "execute_percent", "bleed_chance"]
    var statuses := ["", "stun", "break", "bleed"]
    return {
        "id": ids[rng.randi_range(0, ids.size() - 1)],
        "effect": effects[rng.randi_range(0, effects.size() - 1)],
        "source_stat": stats[rng.randi_range(0, stats.size() - 1)],
        "status": statuses[rng.randi_range(0, statuses.size() - 1)],
        "branch": "special" if rng.randf() < 0.25 else "branch_%d" % rng.randi_range(0, 2)
    }

func _random_enemies(rng: RandomNumberGenerator) -> Array:
    var enemies: Array = []
    var count := rng.randi_range(1, 4)
    for index in range(count):
        enemies.append({
            "id": "fuzz_enemy_%d" % index,
            "combat_uid": "fuzz_%d" % index,
            "hp": 0 if rng.randf() < 0.15 else rng.randi_range(1, 180),
            "max_hp": 180,
            "combat_position": rng.randi_range(-1, 4)
        })
    return enemies

func _check_position_contract(seed_value: int, case_index: int, hero: Dictionary, skill: Dictionary) -> void:
    var allowed := POSITION_RULES.allowed_positions(hero, skill)
    var expected := allowed.has(clampi(int(hero.get("combat_position", 0)), 0, 3))
    var actual := POSITION_RULES.is_usable(hero, skill)
    checks += 1
    if actual != expected:
        _fail(seed_value, case_index, "position_contract", {"hero": hero, "skill": skill, "allowed": allowed, "expected": expected, "actual": actual})

func _check_target_contract(seed_value: int, case_index: int, hero: Dictionary, skill: Dictionary, enemies: Array) -> void:
    var targetable := TARGETING_RULES.targetable_indices(hero, skill, enemies)
    for index in range(enemies.size()):
        var expected := TARGETING_RULES.can_target(hero, skill, enemies[index], enemies)
        var actual := targetable.has(index)
        checks += 1
        if actual != expected:
            _fail(seed_value, case_index, "targetable_equivalence", {"hero": hero, "skill": skill, "enemy_index": index, "enemies": enemies, "expected": expected, "actual": actual})

func _check_dead_targets(seed_value: int, case_index: int, hero: Dictionary, skill: Dictionary, enemies: Array) -> void:
    for index in range(enemies.size()):
        var enemy: Dictionary = enemies[index]
        if int(enemy.get("hp", 0)) > 0:
            continue
        checks += 1
        if TARGETING_RULES.can_target(hero, skill, enemy, enemies):
            _fail(seed_value, case_index, "dead_enemy_targetable", {"hero": hero, "skill": skill, "enemy_index": index, "enemies": enemies})

func _check_enemy_positions(seed_value: int, case_index: int, enemies: Array) -> void:
    var used: Dictionary = {}
    for enemy_value in enemies:
        var enemy: Dictionary = enemy_value
        var position := int(enemy.get("combat_position", -1))
        checks += 2
        if position < 0 or position > 3:
            _fail(seed_value, case_index, "enemy_position_out_of_range", {"position": position, "enemies": enemies})
        if used.has(position):
            _fail(seed_value, case_index, "enemy_position_duplicate", {"position": position, "enemies": enemies})
        used[position] = true

func _check_forced_movement(seed_value: int, case_index: int, hero: Dictionary, skill: Dictionary, enemies: Array) -> void:
    if enemies.is_empty():
        return
    var living: Array = []
    for enemy_value in enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) > 0:
            living.append(enemy)
    if living.is_empty():
        return
    var target: Dictionary = living[0]
    var before_ids: Array[String] = []
    for enemy_value in enemies:
        before_ids.append(str((enemy_value as Dictionary).get("combat_uid", "")))
    var delta := TARGETING_RULES.forced_movement_delta(hero, skill)
    TARGETING_RULES.move_enemy(enemies, target, delta)
    var after_ids: Array[String] = []
    var used: Dictionary = {}
    for enemy_value in enemies:
        var enemy: Dictionary = enemy_value
        after_ids.append(str(enemy.get("combat_uid", "")))
        var position := int(enemy.get("combat_position", -1))
        checks += 2
        if position < 0 or position > 3:
            _fail(seed_value, case_index, "movement_position_out_of_range", {"delta": delta, "enemies": enemies})
        if used.has(position):
            _fail(seed_value, case_index, "movement_position_duplicate", {"delta": delta, "enemies": enemies})
        used[position] = true
    before_ids.sort()
    after_ids.sort()
    checks += 1
    if before_ids != after_ids:
        _fail(seed_value, case_index, "movement_changed_roster", {"delta": delta, "before": before_ids, "after": after_ids})

func _fail(seed_value: int, case_index: int, property_name: String, data: Dictionary) -> void:
    if failures.size() >= MAX_REPROS:
        return
    failures.append({"seed": seed_value, "case_index": case_index, "property": property_name, "data": data.duplicate(true)})

func _write_report(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        push_error("PLAYER_BOT_V11: report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
