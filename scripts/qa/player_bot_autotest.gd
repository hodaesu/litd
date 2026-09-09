extends Node

const FIXED_SEEDS: Array[int] = [101, 202, 303, 404, 505]
const REPORT_PATH := "res://reports/player-bot-autotest.json"
const MAX_ROOMS_PER_RUN := 24
const MAX_COMBAT_ROUNDS := 60

var failures: Array[String] = []
var runs: Array[Dictionary] = []
var skill_usage: Dictionary = {}
var softlocks: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var started_ms := Time.get_ticks_msec()
    for seed_value: int in FIXED_SEEDS:
        runs.append(_run_seed(seed_value))
    var report := {
        "schema_version": 1,
        "suite": "player_bot_autotest",
        "fixed_seeds": FIXED_SEEDS,
        "runs": runs,
        "skill_usage": skill_usage,
        "softlocks": softlocks,
        "failures": failures,
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)
    if failures.is_empty():
        print("PLAYER_BOT_AUTOTEST_OK runs=%d softlocks=%d" % [runs.size(), softlocks.size()])
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("PLAYER_BOT_AUTOTEST: " + failure)
    get_tree().quit(1)

func _run_seed(seed_value: int) -> Dictionary:
    seed(seed_value)
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(seed_value * 17 + 3)
    CreatureManager.reset_new_game(seed_value * 23 + 7)
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition(seed_value)
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        failures.append("seed_%d_missing_roguelike_runtime" % seed_value)
        return {"seed": seed_value, "status": "failed", "reason": "missing_runtime"}

    var layout: Array = ExpeditionManager.dungeon_layout()
    if layout.is_empty():
        failures.append("seed_%d_empty_layout" % seed_value)
        return {"seed": seed_value, "status": "failed", "reason": "empty_layout"}

    var current_id := ""
    var visited: Array[String] = []
    var combats := 0
    var victories := 0
    var captures := 0
    var loot_items := 0
    var rooms_processed := 0
    var extracted := false

    while rooms_processed < MAX_ROOMS_PER_RUN:
        var next_room := _choose_next_room(layout, current_id, visited)
        if next_room.is_empty():
            extracted = true
            break
        var room_id := str(next_room.get("id", ""))
        var entry := ExpeditionManager.enter_dungeon_room(room_id)
        if not bool(entry.get("success", false)):
            _record_softlock(seed_value, room_id, "enter_room_failed", rooms_processed)
            failures.append("seed_%d_enter_room_failed_%s" % [seed_value, room_id])
            break
        current_id = room_id
        if not visited.has(room_id):
            visited.append(room_id)
        rooms_processed += 1
        var room: Dictionary = entry.get("room", next_room)
        var room_type := str(room.get("type", "combat"))
        if room_type in ["combat", "elite", "ambush", "creature", "boss"]:
            combats += 1
            var combat_result := _resolve_combat(seed_value, room)
            if bool(combat_result.get("victory", false)):
                victories += 1
                captures += int(combat_result.get("captures", 0))
                loot_items += int(combat_result.get("loot_items", 0))
            else:
                _record_softlock(seed_value, room_id, str(combat_result.get("reason", "combat_failed")), rooms_processed)
                break
        else:
            loot_items += _resolve_noncombat(room)
        _mark_room_cleared(runtime, room_id)
        if room_type == "boss":
            extracted = true
            break
        if GameState.alive_heroes().is_empty():
            break

    var alive := GameState.alive_heroes().size()
    var status := "completed" if extracted else ("defeat" if alive == 0 else "stopped")
    return {
        "seed": seed_value,
        "status": status,
        "rooms": rooms_processed,
        "visited": visited,
        "combats": combats,
        "victories": victories,
        "captures": captures,
        "loot_items": loot_items,
        "alive_heroes": alive,
        "gold": GameState.gold,
        "essence": GameState.essence,
        "inventory_slots": ExpeditionManager.inventory_slots_used()
    }

func _choose_next_room(layout: Array, current_id: String, visited: Array[String]) -> Dictionary:
    if visited.is_empty():
        return (layout[0] as Dictionary).duplicate(true)
    var current := _room_by_id(layout, current_id)
    if current.is_empty():
        return {}
    var candidates: Array[Dictionary] = []
    for connection_value in current.get("connections", []):
        var target_id := str(connection_value)
        if visited.has(target_id):
            continue
        var target := _room_by_id(layout, target_id)
        if not target.is_empty():
            candidates.append(target)
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return _room_priority(a) > _room_priority(b)
    )
    return candidates[0].duplicate(true)

func _room_priority(room: Dictionary) -> int:
    var room_type := str(room.get("type", ""))
    return int({"boss":100,"camp":90,"treasure":80,"secret":75,"combat":60,"elite":58,"creature":55,"sanctuary":50,"ruins":45,"altar":40,"corpse":35,"trap":20}.get(room_type, 30))

func _room_by_id(layout: Array, room_id: String) -> Dictionary:
    for room_value in layout:
        var room: Dictionary = room_value
        if str(room.get("id", "")) == room_id:
            return room
    return {}

func _resolve_combat(seed_value: int, room: Dictionary) -> Dictionary:
    var room_type := str(room.get("type", "combat"))
    var room_id := str(room.get("id", "bot_room"))
    AshlandsCombatBridge.active = true
    AshlandsCombatBridge.encounter_id = "bot_%d_%s" % [seed_value, room_id]
    AshlandsCombatBridge.encounter_type = "boss" if room_type == "boss" else ("elite" if room_type == "elite" else "normal")
    AshlandsCombatBridge.return_zone_id = AshlandsRuntime.current_zone_id
    AshlandsCombatBridge._prepare_placeholder_enemies()
    var captures := 0
    var round_index := 0
    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and round_index < MAX_COMBAT_ROUNDS:
        round_index += 1
        for hero_value in GameState.party:
            var hero: Dictionary = hero_value
            if int(hero.get("hp", 0)) <= 0 or GameState.alive_enemies().is_empty():
                continue
            _bot_hero_turn(hero)
        if GameState.alive_enemies().is_empty():
            break
        _bot_enemy_turn()
        if round_index == 2 and ContentScopeDirector.is_unlocked("capture"):
            captures += _try_capture_weakened_enemy()
    if not GameState.alive_enemies().is_empty():
        return {"victory": false, "reason": "combat_round_cap", "rounds": round_index, "captures": captures}
    var loot := AshlandsCombatBridge.resolve_victory()
    var loot_items := 1 if not (loot.get("equipment", {}) as Dictionary).is_empty() else 0
    return {"victory": true, "rounds": round_index, "captures": captures, "loot_items": loot_items}

func _bot_hero_turn(hero: Dictionary) -> void:
    var injured := _most_injured_ally()
    var skill_id := "basic_strike"
    if not injured.is_empty() and float(injured.get("hp", 0)) / maxf(1.0, float(injured.get("max_hp", 1))) < 0.40:
        skill_id = "field_aid"
    else:
        var loadout := HeroSkillManager.combat_loadout(hero)
        if loadout.has("heavy_blow"):
            skill_id = "heavy_blow"
    skill_usage[skill_id] = int(skill_usage.get(skill_id, 0)) + 1
    var skill := HeroSkillManager.combat_skill(hero, skill_id)
    if skill.is_empty():
        skill = HeroSkillManager.combat_skill(hero, "basic_strike")
    var effect := str(skill.get("effect", "attack"))
    if effect in ["heal", "support"]:
        var target := injured if not injured.is_empty() else hero
        var amount := maxi(1, int(skill.get("heal", 8)))
        target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + amount)
        return
    if effect == "guard":
        hero["guarding"] = true
        hero["guard_bonus"] = int(skill.get("guard_bonus", 10))
        return
    var enemies := GameState.alive_enemies()
    if enemies.is_empty():
        return
    var target: Dictionary = enemies[0]
    for enemy_value in enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) < int(target.get("hp", 0)):
            target = enemy
    var damage_values: Array = hero.get("damage", [5, 8])
    var base_damage := 6
    if damage_values.size() >= 2:
        base_damage = int(round((float(damage_values[0]) + float(damage_values[1])) * 0.5))
    var power := float(skill.get("power", 1.0))
    var damage := maxi(1, int(round(float(base_damage) * power)))
    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)

func _bot_enemy_turn() -> void:
    for enemy_value in GameState.alive_enemies():
        if GameState.alive_heroes().is_empty():
            return
        var enemy: Dictionary = enemy_value
        var heroes := GameState.alive_heroes()
        var target: Dictionary = heroes[0]
        for hero_value in heroes:
            var hero: Dictionary = hero_value
            if int(hero.get("hp", 0)) < int(target.get("hp", 0)):
                target = hero
        var damage_values: Array = enemy.get("damage", [4, 7])
        var damage := 5
        if damage_values.size() >= 2:
            damage = maxi(1, int(round((float(damage_values[0]) + float(damage_values[1])) * 0.5)))
        if bool(target.get("guarding", false)):
            damage = maxi(1, damage - int(target.get("guard_bonus", 8)))
            target["guarding"] = false
        target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)

func _most_injured_ally() -> Dictionary:
    var result: Dictionary = {}
    var ratio := 2.0
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        var current := float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("max_hp", 1)))
        if current < ratio:
            ratio = current
            result = hero
    return result

func _try_capture_weakened_enemy() -> int:
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        if not bool(enemy.get("recruitable", true)):
            continue
        var ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1)))
        if ratio > 0.25:
            continue
        var result := CreatureManager.attempt_capture(enemy)
        if bool(result.get("success", false)):
            enemy["hp"] = 0
            return 1
    return 0

func _resolve_noncombat(room: Dictionary) -> int:
    var room_type := str(room.get("type", ""))
    var depth := int(room.get("depth", 1))
    match room_type:
        "camp":
            ExpeditionManager.use_campfire()
            return 0
        "treasure", "secret", "anomaly", "ruins", "altar", "corpse":
            var item := ExpeditionManager.generate_roguelike_loot(depth, room_type, int(room.get("index", 0)))
            if not item.is_empty() and ExpeditionManager.add_loot_to_expedition(item):
                return 1
        "trap":
            ExpeditionManager.apply_pressure(7 + depth, "player_bot_trap")
    return 0

func _mark_room_cleared(runtime: Node, room_id: String) -> void:
    if runtime == null:
        return
    var active_run: Dictionary = runtime.active_run
    var cleared: Array = active_run.get("cleared", [])
    if not cleared.has(room_id):
        cleared.append(room_id)
        active_run["cleared"] = cleared
    runtime.active_run = active_run

func _record_softlock(seed_value: int, room_id: String, reason: String, room_index: int) -> void:
    softlocks.append({"seed": seed_value, "room_id": room_id, "reason": reason, "room_index": room_index})

func _write_report(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        failures.append("report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
