extends Node
class_name VeilleursGE01PlayableBridge

signal session_started(snapshot: Dictionary)
signal room_entered(room_id: String, snapshot: Dictionary)
signal enemy_escape_recorded(entity_id: String, remanence_event: Dictionary)
signal refuge_resolved(choice: String, result: Dictionary)
signal combat_started(encounter_id: String, room_id: String, encounter: Dictionary)
signal combat_resolved(encounter_id: String, room_id: String, victory: bool)
signal extraction_completed(summary: Dictionary)

const SESSION_RUNTIME := preload("res://scripts/core/veilleurs_ge01_session_runtime.gd")
const DEF := preload("res://scripts/core/veilleurs_ge01_definition.gd")
const EXPEDITION_ID := "VS01_GALERIES_ETEINTES"
const REGION_ID := "galeries_eteintes"
const RETURN_SCENE := "res://scenes/world/veilleurs/galeries_eteintes_playable.tscn"

const UNIT_TEMPLATES := {
    "ghoul_hungry": {"enemy_id": 1, "name": "Goule affamée", "species_id": "ghoul_hungry", "hp": 34, "damage": [4, 7], "archetype": "undead"},
    "emaciated": {"enemy_id": 1, "name": "Décharné", "species_id": "emaciated", "hp": 24, "damage": [3, 5], "archetype": "undead"},
    "ash_roamer": {"enemy_id": 8, "name": "Rôdeur des Cendres", "species_id": "ash_roamer", "hp": 30, "damage": [4, 6], "archetype": "undead"},
    "ash_bearer": {"enemy_id": 8, "name": "Porte-Cendre", "species_id": "ash_bearer", "hp": 38, "damage": [3, 6], "archetype": "undead"},
    "ghoul_voracious": {"enemy_id": 10, "name": "Goule vorace", "species_id": "ghoul_voracious", "hp": 58, "damage": [6, 10], "archetype": "undead"},
    "mutilated_guardian": {"enemy_id": 30, "name": "Gardien mutilé", "species_id": "mutilated_guardian", "hp": 76, "damage": [7, 11], "archetype": "undead"}
}

var session: RefCounted = SESSION_RUNTIME.new()
var pending_combat: Dictionary = {}
var cleared_encounters: Dictionary = {}
var tactical_corpses: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if not AshlandsCombatBridge.ashlands_combat_finished.is_connected(_on_combat_finished):
        AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)

func make_persistent_root() -> void:
    if get_parent() == get_tree().root:
        return
    reparent(get_tree().root)
    name = "GE01Runtime"

func start(seed_value: String = EXPEDITION_ID) -> Dictionary:
    var existing := snapshot()
    if bool(existing.get("active", false)):
        _sync_exploration_light(existing)
        return existing
    if not ExpeditionManager.expedition_active:
        ExpeditionManager.start_expedition(seed_value.hash(), EXPEDITION_ID)
    var state_value: Dictionary = session.call("start", seed_value)
    ExplorationDirector.begin_expedition()
    ExplorationDirector.enter_room(str(state_value.get("current_room", "ge_01")))
    _sync_exploration_light(state_value)
    session_started.emit(state_value.duplicate(true))
    return state_value

func snapshot() -> Dictionary:
    return session.call("snapshot")

func current_room() -> String:
    return str(session.call("current_room"))

func enter_room(room_id: String) -> Dictionary:
    var result: Dictionary = session.call("enter_room", room_id)
    if not bool(result.get("success", false)):
        return result
    var state_value: Dictionary = result.get("state", snapshot())
    ExplorationDirector.enter_room(room_id)
    _sync_exploration_light(state_value)
    room_entered.emit(room_id, state_value.duplicate(true))
    return result

func spend_light(action_id: String) -> Dictionary:
    var normalized := action_id
    match action_id:
        "simple_observation": normalized = "observe_simple"
        "deep_observation": normalized = "observe_deep"
        "anatomy_inspection": normalized = "anatomy_deep"
    var result: Dictionary = session.call("spend_light", normalized)
    if bool(result.get("success", false)):
        _sync_exploration_light(result.get("state", snapshot()))
    return result

func reveal_secret(source: String = "observation") -> Dictionary:
    var result: Dictionary = session.call("reveal_secret", source)
    if bool(result.get("success", false)):
        ExplorationDirector.record_discovery("ge_14_secret", "shortcut", {"room_id": "ge_14", "source": source})
    return result

func resolve_refuge(choice: String) -> Dictionary:
    var result: Dictionary = session.call("resolve_refuge", choice)
    if not bool(result.get("success", false)):
        return result
    if choice == "field_care":
        result["field_care"] = _stabilize_one_party_injury()
    elif choice == "scout":
        result["scout"] = ExplorationDirector.perceive("presence", "ge_09_ge_10", 25, {"channels": ["sons", "traces", "architecture"]})
    _sync_exploration_light(result.get("state", snapshot()))
    refuge_resolved.emit(choice, result.duplicate(true))
    return result

func combat_available(room_id: String = current_room()) -> bool:
    if room_id not in ["ge_04", "ge_09", "ge_11", "ge_12"]:
        return false
    return not bool(cleared_encounters.get(_encounter_id(room_id), false)) and pending_combat.is_empty()

func begin_room_combat(room_id: String = current_room(), roll_0_99: int = -1) -> Dictionary:
    if not combat_available(room_id):
        return {"success": false, "reason": "combat_unavailable", "room_id": room_id}
    var roll := roll_0_99
    if roll < 0:
        roll = abs((str(snapshot().get("seed", "")) + "|" + room_id + "|" + str((snapshot().get("visited_rooms", {}) as Dictionary).get(room_id, 1))).hash()) % 100
    var encounter: Dictionary = session.call("encounter_for", room_id, roll)
    if str(encounter.get("event", "")) == "rare_non_combat":
        cleared_encounters[_encounter_id(room_id)] = true
        ExplorationDirector.record_discovery("ge12_rare_event", "fall_truth", {"room_id": room_id})
        return {"success": true, "combat_started": false, "rare_event": true, "room_id": room_id}

    if room_id == "ge_09":
        _ensure_ossuary_corpses()

    var enemies := _build_encounter_enemies(encounter, room_id)
    if enemies.is_empty():
        return {"success": false, "reason": "encounter_empty", "room_id": room_id, "encounter": encounter}

    var encounter_id := _encounter_id(room_id)
    pending_combat = {"encounter_id": encounter_id, "room_id": room_id, "encounter": encounter.duplicate(true)}
    AshlandsRuntime.enter_zone("veilleurs_ge01_galeries_eteintes")
    AshlandsCombatBridge.begin(encounter_id, "elite" if room_id == "ge_12" else "normal")
    GameState.battle_enemies = enemies
    combat_started.emit(encounter_id, room_id, encounter.duplicate(true))
    return {"success": true, "combat_started": true, "encounter_id": encounter_id, "room_id": room_id, "enemies": enemies.size(), "encounter": encounter}

func record_enemy_escape(enemy: Dictionary, body_state: Dictionary = {}) -> Dictionary:
    if enemy.is_empty():
        return {"success": false, "reason": "missing_enemy"}
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, REGION_ID)
    RemanenceRuntime.note_encounter(enemy, REGION_ID, {"room_id": current_room(), "summary": "Créature rencontrée dans Les Galeries Éteintes."})
    var event: Dictionary = RemanenceRuntime.record_enemy_event(enemy, "escaped", {
        "region_id": REGION_ID,
        "room_id": current_room(),
        "summary": "La créature a fui et peut revenir lors d'une expédition future."
    })
    if not body_state.is_empty():
        enemy["body_state"] = body_state.duplicate(true)
    RemanenceRuntime.sync_body_snapshot(enemy)
    var local_result: Dictionary = session.call("register_enemy_escape", entity_id, str(enemy.get("species_id", enemy.get("id", "unknown"))), body_state)
    enemy_escape_recorded.emit(entity_id, event.duplicate(true))
    return {"success": bool(local_result.get("success", false)), "entity_id": entity_id, "remanence_event": event, "session": local_result}

func try_flee_enemy(enemy: Dictionary, roll_0_99: int) -> Dictionary:
    if enemy.is_empty() or not pending_combat.has("room_id"):
        return {"success": false, "reason": "no_active_ge01_combat"}
    var hp_ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", enemy.get("hp", 1))))
    var limb_lost := not (enemy.get("dismembered_parts", []) as Array).is_empty()
    var allies_dead := false
    for other_value: Variant in GameState.battle_enemies:
        var other: Dictionary = other_value
        if other == enemy:
            continue
        if int(other.get("hp", 0)) <= 0:
            allies_dead = true
            break
    if not bool(session.call("can_enemy_attempt_flee", str(enemy.get("species_id", "")), hp_ratio, limb_lost, allies_dead, true, false)):
        return {"success": false, "reason": "flee_conditions_not_met"}
    if not bool(session.call("flee_succeeds", str(enemy.get("species_id", "")), roll_0_99)):
        return {"success": false, "reason": "flee_roll_failed"}
    var result := record_enemy_escape(enemy, {
        "hp": int(enemy.get("hp", 0)),
        "max_hp": int(enemy.get("max_hp", 0)),
        "dismembered_parts": (enemy.get("dismembered_parts", []) as Array).duplicate(true),
        "anatomy_injuries": (enemy.get("anatomy_injuries", {}) as Dictionary).duplicate(true)
    })
    enemy["ge01_fled"] = true
    enemy["captured"] = true
    enemy["hp"] = 0
    GameState.state_changed.emit()
    return result

func tactical_corpse_context() -> Dictionary:
    return tactical_corpses.duplicate(true)

func mark_objective_complete(source: String = "corpse_examined") -> Dictionary:
    var result: Dictionary = session.call("mark_objective_complete", source)
    if bool(result.get("success", false)):
        ExplorationDirector.record_discovery("ge01_objective", "fall_truth", {"source": source, "room_id": current_room()})
    return result

func extract(reason: String = "voluntary") -> Dictionary:
    var summary: Dictionary = session.call("extract", reason)
    if not bool(summary.get("success", false)):
        return summary
    if ExpeditionManager.expedition_active:
        summary["first_descent"] = ExpeditionManager.return_to_hub(reason)
    extraction_completed.emit(summary.duplicate(true))
    return summary

func serialize() -> Dictionary:
    return {"session": session.call("serialize"), "cleared_encounters": cleared_encounters.duplicate(true), "tactical_corpses": tactical_corpses.duplicate(true)}

func deserialize(data: Dictionary) -> bool:
    var payload: Dictionary = data.get("session", data)
    var ok: bool = bool(session.call("deserialize", payload))
    if ok:
        cleared_encounters = data.get("cleared_encounters", {}).duplicate(true)
        tactical_corpses = data.get("tactical_corpses", {}).duplicate(true)
        _sync_exploration_light(snapshot())
    return ok

func _on_combat_finished(encounter_id: String, victory: bool, _loot: Dictionary) -> void:
    if pending_combat.is_empty() or str(pending_combat.get("encounter_id", "")) != encounter_id:
        return
    var room_id := str(pending_combat.get("room_id", ""))
    if victory:
        cleared_encounters[encounter_id] = true
        var cost_action := "combat_long" if room_id == "ge_12" else "combat_standard"
        spend_light(cost_action)
    combat_resolved.emit(encounter_id, room_id, victory)
    pending_combat.clear()
    if victory:
        call_deferred("_return_to_ge01")

func _return_to_ge01() -> void:
    await get_tree().process_frame
    get_tree().change_scene_to_file(RETURN_SCENE)

func _build_encounter_enemies(encounter: Dictionary, room_id: String) -> Array:
    var result: Array = []
    if bool(encounter.get("persistent", false)):
        var persistent := _persistent_enemy(str(encounter.get("entity_id", "")))
        if not persistent.is_empty():
            result.append(persistent)
        return result
    for unit_value: Variant in encounter.get("units", []):
        var unit_id := str(unit_value)
        if unit_id == "persistent_candidate":
            var candidates: Dictionary = snapshot().get("persistent_candidates", {})
            if not candidates.is_empty():
                var keys := candidates.keys()
                keys.sort()
                var persistent := _persistent_enemy(str(keys[0]))
                if not persistent.is_empty(): result.append(persistent)
            else:
                result.append(_build_unit("ghoul_hungry"))
        elif unit_id == "preexisting_veteran":
            var veteran := _build_unit("mutilated_guardian")
            veteran["name"] = "Le Balafré des Galeries"
            veteran["remanence_protected"] = true
            veteran["ge01_preexisting_veteran"] = true
            result.append(veteran)
        elif unit_id == "elite_group":
            result.append(_build_unit("ghoul_voracious"))
            result.append(_build_unit("ash_bearer"))
            result.append(_build_unit("ash_roamer"))
        else:
            var built := _build_unit(unit_id)
            if not built.is_empty(): result.append(built)
    for enemy_value: Variant in result:
        var enemy: Dictionary = enemy_value
        enemy["ge01_room_id"] = room_id
        enemy["ge01_can_flee"] = room_id == "ge_04"
        RemanenceRuntime.prepare_enemy(enemy, REGION_ID)
    return result

func _build_unit(unit_id: String) -> Dictionary:
    var spec: Dictionary = UNIT_TEMPLATES.get(unit_id, {})
    if spec.is_empty(): return {}
    var enemy: Dictionary = DataLoader.find_by_id(DataLoader.enemies, int(spec.get("enemy_id", 1))).duplicate(true)
    if enemy.is_empty(): enemy = {}
    enemy["name"] = str(spec.get("name", unit_id))
    enemy["species_id"] = str(spec.get("species_id", unit_id))
    enemy["hp"] = int(spec.get("hp", 30))
    enemy["max_hp"] = int(spec.get("hp", 30))
    enemy["damage"] = (spec.get("damage", [3, 6]) as Array).duplicate(true)
    enemy["archetype"] = str(spec.get("archetype", "undead"))
    enemy["guarding"] = false
    return enemy

func _persistent_enemy(entity_id: String) -> Dictionary:
    if not RemanenceRuntime.entities.has(entity_id): return {}
    var record: Dictionary = RemanenceRuntime.entities[entity_id]
    var enemy := _build_unit(str(record.get("species_id", "ghoul_hungry")))
    if enemy.is_empty(): enemy = _build_unit("ghoul_hungry")
    enemy["remanence_id"] = entity_id
    enemy["name"] = str(record.get("name", enemy.get("name", "Créature familière")))
    enemy["remanence_stage"] = str(record.get("stage", "normal"))
    var body: Dictionary = record.get("body_snapshot", {})
    for key: String in ["persistent_injuries", "body_state", "dismembered_parts", "anatomy_injuries", "anatomy_part_states", "anatomy_part_trauma"]:
        if body.has(key): enemy[key] = body.get(key).duplicate(true) if body.get(key) is Array or body.get(key) is Dictionary else body.get(key)
    if int(body.get("hp", 0)) > 0: enemy["hp"] = mini(int(enemy.get("max_hp", 1)), int(body.get("hp", enemy.get("hp", 1))))
    return enemy

func _ensure_ossuary_corpses() -> void:
    if not tactical_corpses.is_empty(): return
    for index in range(2):
        var scar_id := RemanenceRuntime.create_world_scar("ge09_corpse_%d" % index, "persistent_corpse", "trace", {
            "region_id": REGION_ID,
            "zone_id": "veilleurs_ge01_galeries_eteintes",
            "summary": "Un ancien cadavre encombre l'Ossuaire.",
            "owner_name": "Cadavre ancien %d" % (index + 1),
            "corpse_state": "intact",
            "room_id": "ge_09",
            "body_snapshot": {},
            "prepared_as_cover": false
        })
        tactical_corpses[scar_id] = {"room_id": "ge_09", "cover_available": true}

func _encounter_id(room_id: String) -> String:
    return "ge01_%s" % room_id.trim_prefix("ge_")

func _sync_exploration_light(state_value: Dictionary) -> void:
    var light_value := clampf(float(state_value.get("light", 0)) / 100.0, 0.0, 1.0)
    ExplorationDirector.set_light_level(light_value, "galeries_eteintes")
    if ExpeditionManager.inventory.has("light"):
        ExpeditionManager.inventory["light"] = int(state_value.get("light", 0))
        ExpeditionManager.inventory_changed.emit(ExpeditionManager.inventory.duplicate(true))

func _stabilize_one_party_injury() -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        for injury_value: Variant in hero.get("persistent_injuries", []):
            var injury: Dictionary = injury_value
            if bool(injury.get("stabilized", false)): continue
            var injury_id := str(injury.get("id", ""))
            if injury_id != "" and PersistentInjuryRuntime.stabilize_in_field(hero, injury_id):
                return {"success": true, "hero_id": str(hero.get("id", "")), "injury_id": injury_id}
    return {"success": false, "reason": "no_unstabilized_injury"}
