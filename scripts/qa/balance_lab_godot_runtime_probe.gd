extends SceneTree

const RUNTIME_SCRIPT := preload("res://scripts/qa/veilleurs_balance_runtime_v01.gd")
const WATCHERS: Array[String] = [
    "ENT_WATCHER_NAYRA",
    "ENT_WATCHER_TAREK",
    "ENT_WATCHER_AISHA",
    "ENT_WATCHER_IDRIS"
]
const ENEMIES: Array[String] = [
    "ENT_ENEMY_GOULE_AFFAMEE",
    "ENT_ENEMY_FOUISSEUSE",
    "ENT_ENEMY_GUETTEUR"
]
const DAMAGE_ACTIONS: Array[String] = ["attack", "attack_move"]
const CONTROL_ACTIONS: Array[String] = ["control", "psychological", "observe"]
const MAX_ROUNDS := 12

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var runs := int(OS.get_environment("BALANCE_GODOT_RUNS"))
    if runs <= 0:
        runs = 10000
    var base_seed := int(OS.get_environment("BALANCE_GODOT_SEED"))
    if base_seed == 0:
        base_seed = 41003

    var aggregate := _empty_metrics()
    var runtime := RUNTIME_SCRIPT.new() as VeilleursBalanceRuntimeV01
    var first_signature := ""
    var first_seed := base_seed
    for index in range(runs):
        var seed := base_seed + index * 7919
        var run := _simulate_once(runtime, seed)
        _merge_metrics(aggregate, run)
        if index == 0:
            first_signature = str(run.get("signature", ""))

    var replay_runtime := RUNTIME_SCRIPT.new() as VeilleursBalanceRuntimeV01
    var replay := _simulate_once(replay_runtime, first_seed)
    var deterministic_replay := first_signature != "" and first_signature == str(replay.get("signature", ""))

    var report := _build_report(aggregate, runs, base_seed, deterministic_replay)
    var reports_dir := ProjectSettings.globalize_path("res://reports")
    DirAccess.make_dir_recursive_absolute(reports_dir)
    var report_path := ProjectSettings.globalize_path("res://reports/balance-lab-godot-runtime.json")
    var file := FileAccess.open(report_path, FileAccess.WRITE)
    if file == null:
        push_error("BALANCE_GODOT_REPORT_WRITE_FAILED")
        quit(2)
        return
    file.store_string(JSON.stringify(report, "  ") + "\n")
    file.close()

    print("BALANCE_GODOT_RUNTIME runs=%d seed=%d" % [runs, base_seed])
    print("BALANCE_GODOT_OUTCOMES " + JSON.stringify(report.get("outcomes", {})))
    print("BALANCE_GODOT_COMBAT " + JSON.stringify(report.get("combat", {})))
    print("BALANCE_GODOT_BODY " + JSON.stringify(report.get("body", {})))
    print("BALANCE_GODOT_DETERMINISTIC_REPLAY %s" % str(deterministic_replay))
    print("BALANCE_GODOT_REPORT " + report_path)

    var ok := deterministic_replay and int(aggregate.get("setup_failures", 0)) == 0 and int(aggregate.get("invalid_actions", 0)) == 0
    quit(0 if ok else 1)

func _simulate_once(runtime: VeilleursBalanceRuntimeV01, seed: int) -> Dictionary:
    runtime.configure_balance_seed(seed)
    var setup: Dictionary = runtime.setup_first_combat(ENEMIES)
    var metrics := _empty_metrics()
    if not bool(setup.get("ok", false)):
        metrics["setup_failures"] = 1
        metrics["signature"] = "setup_failure:%s" % str(setup.get("reason", "unknown"))
        return metrics

    for round_no in range(1, MAX_ROUNDS + 1):
        metrics["rounds"] = round_no
        for watcher_id: String in WATCHERS:
            if not _is_alive(runtime, watcher_id):
                continue
            var watcher_result := _watcher_turn(runtime, watcher_id)
            _consume_result(metrics, watcher_result)
            if runtime.alive_ids("enemy").is_empty():
                metrics["hero_wins"] = 1
                metrics["signature"] = _signature(runtime, metrics)
                return metrics

        var enemy_ids: Array[String] = runtime.alive_ids("enemy")
        for enemy_id: String in enemy_ids:
            if not _is_alive(runtime, enemy_id):
                continue
            var enemy_result: Dictionary = runtime.enemy_step(enemy_id)
            _consume_result(metrics, enemy_result)
            if runtime.alive_ids("watcher").is_empty():
                metrics["enemy_wins"] = 1
                metrics["signature"] = _signature(runtime, metrics)
                return metrics

        runtime.next_round()

    if runtime.alive_ids("enemy").is_empty():
        metrics["hero_wins"] = 1
    elif runtime.alive_ids("watcher").is_empty():
        metrics["enemy_wins"] = 1
    else:
        metrics["draws"] = 1
    metrics["signature"] = _signature(runtime, metrics)
    return metrics

func _watcher_turn(runtime: VeilleursBalanceRuntimeV01, watcher_id: String) -> Dictionary:
    var target_id := _nearest_enemy(runtime, watcher_id)
    if target_id == "":
        return {"ok":true, "action":"hold", "reason":"no_enemy"}
    var distance := runtime.grid.distance(watcher_id, target_id)
    var skill := _best_available_skill(runtime, watcher_id, distance)
    if not skill.is_empty():
        return runtime.resolve_skill(watcher_id, target_id, str(skill.get("skill_id", "")), "torso", -1)
    if _move_toward(runtime, watcher_id, target_id):
        return {"ok":true, "action":"move", "attacker":watcher_id, "target":target_id, "moved":1}
    return {"ok":true, "action":"hold", "attacker":watcher_id, "target":target_id, "reason":"blocked"}

func _best_available_skill(runtime: VeilleursBalanceRuntimeV01, watcher_id: String, distance: int) -> Dictionary:
    var fallback_control: Dictionary = {}
    for value: Variant in runtime.content_db.skills_for(watcher_id):
        if not (value is Dictionary):
            continue
        var skill: Dictionary = value
        if int(skill.get("skill_index", 99)) > 5:
            continue
        var action := str(runtime.skill_behavior.effective_action(skill))
        var required_range := int(runtime.skill_behavior.range_for(skill))
        if DAMAGE_ACTIONS.has(action) and distance >= 0 and distance <= required_range:
            return skill
        if fallback_control.is_empty() and CONTROL_ACTIONS.has(action) and distance >= 0 and distance <= required_range:
            fallback_control = skill
    return fallback_control

func _nearest_enemy(runtime: VeilleursBalanceRuntimeV01, watcher_id: String) -> String:
    var best_id := ""
    var best_distance := 999
    var best_hp := 999999
    for enemy_id: String in runtime.alive_ids("enemy"):
        var distance := runtime.grid.distance(watcher_id, enemy_id)
        var row: Dictionary = runtime.combatants.get(enemy_id, {})
        var hp := int(row.get("hp", 999999))
        if distance < best_distance or (distance == best_distance and hp < best_hp):
            best_id = enemy_id
            best_distance = distance
            best_hp = hp
    return best_id

func _move_toward(runtime: VeilleursBalanceRuntimeV01, actor_id: String, target_id: String) -> bool:
    var current := runtime.grid.position_of(actor_id)
    var target := runtime.grid.position_of(target_id)
    if current.x < 0 or target.x < 0:
        return false
    var candidates: Array[Vector2i] = []
    if current.x != target.x:
        candidates.append(current + Vector2i(1 if target.x > current.x else -1, 0))
    if current.y != target.y:
        candidates.append(current + Vector2i(0, 1 if target.y > current.y else -1))
    for cell: Vector2i in candidates:
        if runtime.can_move_to(cell) and runtime.grid.move(actor_id, cell):
            return true
    return false

func _consume_result(metrics: Dictionary, result: Dictionary) -> void:
    if not bool(result.get("ok", false)):
        metrics["invalid_actions"] = int(metrics.get("invalid_actions", 0)) + 1
        return
    var action := str(result.get("action", ""))
    if action in ["move", "flee"] or int(result.get("moved", 0)) > 0:
        metrics["moves"] = int(metrics.get("moves", 0)) + maxi(1, int(result.get("moved", 0)))
    if result.has("forced_move"):
        metrics["forced_moves"] = int(metrics.get("forced_moves", 0)) + int(result.get("forced_move", 0))
    if result.has("hit"):
        metrics["attacks"] = int(metrics.get("attacks", 0)) + 1
        if bool(result.get("hit", false)):
            metrics["hits"] = int(metrics.get("hits", 0)) + 1
            metrics["damage"] = int(metrics.get("damage", 0)) + int(result.get("damage", 0))
    var body_value: Variant = result.get("body", {})
    if body_value is Dictionary:
        var body: Dictionary = body_value
        if bool(body.get("ok", false)):
            var state := str(body.get("state", "L0"))
            var body_states: Dictionary = metrics.get("body_states", {})
            body_states[state] = int(body_states.get(state, 0)) + 1
            metrics["body_states"] = body_states
            if bool(body.get("severed", false)):
                metrics["severed"] = int(metrics.get("severed", 0)) + 1
            if bool(body.get("dead", false)):
                metrics["body_deaths"] = int(metrics.get("body_deaths", 0)) + 1

func _is_alive(runtime: VeilleursBalanceRuntimeV01, entity_id: String) -> bool:
    if not runtime.combatants.has(entity_id):
        return false
    return int((runtime.combatants[entity_id] as Dictionary).get("hp", 0)) > 0

func _signature(runtime: VeilleursBalanceRuntimeV01, metrics: Dictionary) -> String:
    var payload := {
        "state":runtime.serialize(),
        "outcome":[metrics.get("hero_wins", 0), metrics.get("enemy_wins", 0), metrics.get("draws", 0)],
        "rounds":metrics.get("rounds", 0),
        "attacks":metrics.get("attacks", 0),
        "hits":metrics.get("hits", 0)
    }
    return str(JSON.stringify(payload).hash())

func _empty_metrics() -> Dictionary:
    return {
        "hero_wins":0,
        "enemy_wins":0,
        "draws":0,
        "rounds":0,
        "attacks":0,
        "hits":0,
        "damage":0,
        "moves":0,
        "forced_moves":0,
        "body_states":{},
        "severed":0,
        "body_deaths":0,
        "invalid_actions":0,
        "setup_failures":0,
        "signature":""
    }

func _merge_metrics(total: Dictionary, row: Dictionary) -> void:
    for key: String in ["hero_wins", "enemy_wins", "draws", "rounds", "attacks", "hits", "damage", "moves", "forced_moves", "severed", "body_deaths", "invalid_actions", "setup_failures"]:
        total[key] = int(total.get(key, 0)) + int(row.get(key, 0))
    var total_states: Dictionary = total.get("body_states", {})
    var row_states: Dictionary = row.get("body_states", {})
    for state_value: Variant in row_states.keys():
        var state := str(state_value)
        total_states[state] = int(total_states.get(state, 0)) + int(row_states.get(state, 0))
    total["body_states"] = total_states

func _build_report(metrics: Dictionary, runs: int, seed: int, deterministic_replay: bool) -> Dictionary:
    var attacks := maxi(1, int(metrics.get("attacks", 0)))
    return {
        "system":"litd_balance_lab",
        "model_version":"0.4-godot-runtime-probe",
        "model_status":"godot_runtime_measured_proxy",
        "scenario":"SIM_001_RUNTIME_PROXY",
        "scenario_note":"Closest current runtime composition: Goule affamee + Fouisseuse + Guetteur. The current runtime cannot instantiate duplicate entity IDs, so this is not yet the exact two-Ghouls-plus-Disruptor SIM_001.",
        "runs":runs,
        "seed":seed,
        "deterministic_replay":deterministic_replay,
        "outcomes":{
            "hero_wins":int(metrics.get("hero_wins", 0)),
            "enemy_wins":int(metrics.get("enemy_wins", 0)),
            "draws":int(metrics.get("draws", 0)),
            "hero_win_rate":float(metrics.get("hero_wins", 0)) / float(runs)
        },
        "combat":{
            "average_rounds":float(metrics.get("rounds", 0)) / float(runs),
            "attacks":int(metrics.get("attacks", 0)),
            "hit_rate":float(metrics.get("hits", 0)) / float(attacks),
            "average_damage_events_value":float(metrics.get("damage", 0)) / float(attacks),
            "moves_per_combat":float(metrics.get("moves", 0)) / float(runs),
            "forced_moves_per_combat":float(metrics.get("forced_moves", 0)) / float(runs)
        },
        "body":{
            "states":metrics.get("body_states", {}),
            "severed_per_combat":float(metrics.get("severed", 0)) / float(runs),
            "body_deaths_per_combat":float(metrics.get("body_deaths", 0)) / float(runs)
        },
        "integrity":{
            "setup_failures":int(metrics.get("setup_failures", 0)),
            "invalid_actions":int(metrics.get("invalid_actions", 0))
        },
        "limitations":[
            "This probe uses the real Godot tactical runtime and body resolver but a minimal QA autopilot.",
            "Movement by the QA autopilot uses validated grid movement directly when no legal low-tier skill is in range.",
            "Human playtests remain required for readability, tension and decision quality."
        ]
    }
