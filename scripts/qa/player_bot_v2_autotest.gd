extends Node

const FIXED_SEEDS: Array[int] = [101, 202, 303, 404, 505]
const REPORT_PATH := "res://reports/player-bot-v2-autotest.json"
const MAX_ROOMS_PER_RUN := 24
const MAX_ACTIONS_PER_COMBAT := 180
const NO_PROGRESS_LIMIT := 18

var failures: Array[String] = []
var runs: Array[Dictionary] = []
var skill_usage: Dictionary = {}
var skill_effects: Dictionary = {}
var softlocks: Array[Dictionary] = []
var controller: Control

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var packed := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        push_error("PLAYER_BOT_V2: cannot load Main.tscn")
        get_tree().quit(1)
        return
    controller = packed.instantiate() as Control
    if controller == null:
        push_error("PLAYER_BOT_V2: cannot instantiate Main.tscn")
        get_tree().quit(1)
        return
    controller.visible = false
    add_child(controller)
    await get_tree().process_frame

    var started_ms := Time.get_ticks_msec()
    for seed_value: int in FIXED_SEEDS:
        runs.append(await _run_seed(seed_value))

    var unused_equipped: Array[String] = []
    var known: Dictionary = {}
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        for skill_id in HeroSkillManager.combat_loadout(hero):
            known[str(skill_id)] = true
    for skill_id in known.keys():
        if int(skill_usage.get(skill_id, 0)) == 0:
            unused_equipped.append(str(skill_id))

    var report := {
        "schema_version": 2,
        "suite": "player_bot_v2_autotest",
        "driver": "real_main_controller",
        "fixed_seeds": FIXED_SEEDS,
        "runs": runs,
        "skill_usage": skill_usage,
        "skill_effects": skill_effects,
        "unused_equipped_skills": unused_equipped,
        "softlocks": softlocks,
        "failures": failures,
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)

    if failures.is_empty():
        print("PLAYER_BOT_V2_OK runs=%d softlocks=%d skills=%d" % [runs.size(), softlocks.size(), skill_usage.size()])
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("PLAYER_BOT_V2: " + failure)
    get_tree().quit(1)

func _run_seed(seed_value: int) -> Dictionary:
    seed(seed_value)
    GameState.reset_new_game()
    EquipmentManager.reset_new_game(seed_value * 17 + 3)
    CreatureManager.reset_new_game(seed_value * 23 + 7)
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition(seed_value)
    _reset_controller_combat_state()

    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        failures.append("seed_%d_missing_runtime" % seed_value)
        return {"seed": seed_value, "status": "failed", "reason": "missing_runtime"}
    var layout: Array = ExpeditionManager.dungeon_layout()
    if layout.is_empty():
        failures.append("seed_%d_empty_layout" % seed_value)
        return {"seed": seed_value, "status": "failed", "reason": "empty_layout"}

    var current_id := ""
    var visited: Array[String] = []
    var rooms := 0
    var combats := 0
    var victories := 0
    var defeats := 0
    var captures_before := CreatureManager.captured_creatures.size()
    var cargo_before := _cargo_size(runtime)
    var total_actions := 0
    var total_rounds := 0
    var hp_lost := 0
    var gold_before := GameState.gold
    var essence_before := GameState.essence
    var completed := false

    while rooms < MAX_ROOMS_PER_RUN and ExpeditionManager.expedition_active:
        var next_room := _choose_next_room(layout, current_id, visited)
        if next_room.is_empty():
            completed = true
            break
        var room_id := str(next_room.get("id", ""))
        var entry: Dictionary = ExpeditionManager.enter_dungeon_room(room_id)
        if not bool(entry.get("success", false)):
            _record_softlock(seed_value, room_id, "enter_room_failed", rooms)
            failures.append("seed_%d_enter_room_failed_%s" % [seed_value, room_id])
            break
        current_id = room_id
        if not visited.has(room_id):
            visited.append(room_id)
        rooms += 1
        var room: Dictionary = entry.get("room", next_room)
        var room_type := str(room.get("type", "combat"))

        if room_type in ["combat", "elite", "ambush", "creature", "boss"]:
            combats += 1
            var hp_before := _party_hp_total()
            var combat_result: Dictionary = await _drive_real_combat(seed_value, room)
            hp_lost += maxi(0, hp_before - _party_hp_total())
            total_actions += int(combat_result.get("actions", 0))
            total_rounds += int(combat_result.get("rounds", 0))
            if bool(combat_result.get("victory", false)):
                victories += 1
            else:
                defeats += 1
                if str(combat_result.get("reason", "")) == "softlock":
                    failures.append("seed_%d_softlock_%s" % [seed_value, room_id])
                break
        else:
            controller._resolve_noncombat_room(room)
            controller._mark_current_room_cleared()
            await get_tree().process_frame

        if room_type == "boss" or GameState.alive_heroes().is_empty():
            completed = room_type == "boss" and not GameState.alive_heroes().is_empty()
            break

    var captures := CreatureManager.captured_creatures.size() - captures_before
    var cargo_delta := _cargo_size(runtime) - cargo_before
    var alive := GameState.alive_heroes().size()
    var status := "completed" if completed else ("defeat" if alive == 0 else "stopped")
    return {
        "seed": seed_value,
        "status": status,
        "rooms": rooms,
        "visited": visited,
        "combats": combats,
        "victories": victories,
        "defeats": defeats,
        "actions": total_actions,
        "rounds": total_rounds,
        "captures": captures,
        "cargo_delta": cargo_delta,
        "alive_heroes": alive,
        "hero_deaths": GameState.party.size() - alive,
        "party_hp_lost": hp_lost,
        "gold_delta": GameState.gold - gold_before,
        "essence_delta": GameState.essence - essence_before,
        "inventory_slots": ExpeditionManager.inventory_slots_used()
    }

func _drive_real_combat(seed_value: int, room: Dictionary) -> Dictionary:
    _reset_controller_combat_state()
    controller._start_roguelike_room_battle(room)
    await get_tree().process_frame
    if GameState.battle_enemies.is_empty():
        return {"victory": false, "reason": "no_enemies", "actions": 0, "rounds": 0}

    var room_id := str(room.get("id", "bot_room"))
    var actions := 0
    var no_progress := 0
    var last_hp_signature := _combat_hp_signature()
    var start_round := int(controller.combat_round_number)

    while not GameState.alive_heroes().is_empty() and not GameState.alive_enemies().is_empty() and actions < MAX_ACTIONS_PER_COMBAT:
        controller._ensure_combat_state()
        var hero: Dictionary = controller._active_combat_hero()
        if hero.is_empty():
            await get_tree().process_frame
            no_progress += 1
            if no_progress >= NO_PROGRESS_LIMIT:
                _record_softlock(seed_value, room_id, "no_active_hero", actions)
                return {"victory": false, "reason": "softlock", "actions": actions, "rounds": int(controller.combat_round_number) - start_round + 1}
            continue

        _select_lowest_hp_enemy()
        if ContentScopeDirector.is_unlocked("capture") and _has_capturable_weakened_enemy():
            var captured_before := CreatureManager.captured_creatures.size()
            controller._combat_capture()
            await get_tree().process_frame
            if CreatureManager.captured_creatures.size() > captured_before:
                actions += 1
                _record_skill("__capture__", 0, 0)
                continue

        var choice := _choose_real_skill(hero)
        var slot := int(choice.get("slot", 0))
        var skill_id := str(choice.get("skill_id", "basic_strike"))
        var enemy_hp_before := _enemy_hp_total()
        var party_hp_before := _party_hp_total()
        controller._use_combat_skill(slot)
        await get_tree().process_frame
        actions += 1
        var damage := maxi(0, enemy_hp_before - _enemy_hp_total())
        var healing := maxi(0, _party_hp_total() - party_hp_before)
        _record_skill(skill_id, damage, healing)

        var signature := _combat_hp_signature()
        if signature == last_hp_signature:
            no_progress += 1
        else:
            no_progress = 0
            last_hp_signature = signature
        if no_progress >= NO_PROGRESS_LIMIT:
            _record_softlock(seed_value, room_id, "no_hp_progress", actions)
            return {"victory": false, "reason": "softlock", "actions": actions, "rounds": int(controller.combat_round_number) - start_round + 1}

    if not GameState.alive_enemies().is_empty():
        var reason := "party_defeat" if GameState.alive_heroes().is_empty() else "action_cap"
        if reason == "action_cap":
            _record_softlock(seed_value, room_id, reason, actions)
        return {"victory": false, "reason": reason, "actions": actions, "rounds": int(controller.combat_round_number) - start_round + 1}
    return {"victory": true, "actions": actions, "rounds": int(controller.combat_round_number) - start_round + 1}

func _choose_real_skill(hero: Dictionary) -> Dictionary:
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    var injured_ratio := _lowest_party_hp_ratio()
    var best_slot := 0
    var best_score := -9999.0
    for slot in range(loadout.size()):
        var skill_id := str(loadout[slot])
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty():
            continue
        var effect := str(skill.get("effect", "attack"))
        var score := 0.0
        if effect in ["heal", "support", "medical"]:
            score = 95.0 if injured_ratio < 0.42 else 10.0
            score += float(skill.get("heal", 0))
        elif effect == "guard" or effect == "posture":
            score = 45.0 if injured_ratio < 0.65 else 15.0
        elif effect == "diagnostic":
            score = 24.0
        else:
            score = 50.0 + float(skill.get("power", 1.0)) * 20.0
            score += float(skill.get("critical_bonus", 0)) * 0.2
            score += float(skill.get("status_chance", 0)) * 0.1
        score += float((skill_id + ":" + str(hero.get("id", ""))).hash() % 11) * 0.01
        if score > best_score:
            best_score = score
            best_slot = slot
    return {"slot": best_slot, "skill_id": str(loadout[best_slot]) if best_slot < loadout.size() else "basic_strike"}

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

func _has_capturable_weakened_enemy() -> bool:
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        if not bool(enemy.get("recruitable", true)):
            continue
        var ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1)))
        if ratio <= 0.22:
            return true
    return false

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
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _room_priority(a) > _room_priority(b))
    return candidates[0].duplicate(true)

func _room_priority(room: Dictionary) -> int:
    return int({"boss":100,"camp":90,"treasure":80,"secret":75,"combat":60,"elite":58,"creature":55,"sanctuary":50,"ruins":45,"altar":40,"corpse":35,"trap":20}.get(str(room.get("type", "")), 30))

func _room_by_id(layout: Array, room_id: String) -> Dictionary:
    for room_value in layout:
        var room: Dictionary = room_value
        if str(room.get("id", "")) == room_id:
            return room
    return {}

func _reset_controller_combat_state() -> void:
    controller.combat_active_hero_id = ""
    controller.combat_acted_hero_ids.clear()
    controller.combat_round_number = 1
    controller.battle_locked = false
    controller.selected_enemy = 0

func _record_skill(skill_id: String, damage: int, healing: int) -> void:
    skill_usage[skill_id] = int(skill_usage.get(skill_id, 0)) + 1
    var row: Dictionary = skill_effects.get(skill_id, {"uses":0,"damage":0,"healing":0})
    row["uses"] = int(row.get("uses", 0)) + 1
    row["damage"] = int(row.get("damage", 0)) + damage
    row["healing"] = int(row.get("healing", 0)) + healing
    skill_effects[skill_id] = row

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

func _combat_hp_signature() -> String:
    return "%d:%d:%d:%d" % [_party_hp_total(), _enemy_hp_total(), GameState.alive_heroes().size(), GameState.alive_enemies().size()]

func _lowest_party_hp_ratio() -> float:
    var result := 1.0
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        result = minf(result, float(hero.get("hp", 0)) / maxf(1.0, float(hero.get("max_hp", 1))))
    return result

func _cargo_size(runtime: Node) -> int:
    if runtime == null:
        return 0
    return (runtime.active_run.get("cargo", []) as Array).size()

func _record_softlock(seed_value: int, room_id: String, reason: String, index: int) -> void:
    softlocks.append({"seed":seed_value,"room_id":room_id,"reason":reason,"index":index})

func _write_report(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        failures.append("report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
