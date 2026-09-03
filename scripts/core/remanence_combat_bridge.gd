extends Node

var combat_active := false
var enemy_snapshots: Dictionary = {}
var hero_alive: Dictionary = {}
var last_enemy_actor_entity_id := ""
var last_defeated_major_entity_id := ""
var capture_attempt_counter_seen := 0
var captured_count_seen := 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_connect_sources")

func _connect_sources() -> void:
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not CombatBodyPresentation.proxy_action_started.is_connected(_on_proxy_action_started):
        CombatBodyPresentation.proxy_action_started.connect(_on_proxy_action_started)
    if not CreatureManager.creature_captured.is_connected(_on_creature_captured):
        CreatureManager.creature_captured.connect(_on_creature_captured)
    var first_descent: Node = ExpeditionManager.first_descent_runtime as Node
    if first_descent != null and first_descent.has_signal("first_descent_completed") and not first_descent.is_connected("first_descent_completed", _on_first_descent_completed):
        first_descent.connect("first_descent_completed", _on_first_descent_completed)

func _process(_delta: float) -> void:
    if not combat_active:
        return
    _scan_hero_deaths()
    _scan_enemy_changes()
    _scan_capture_attempts()

func _on_new_game_reset() -> void:
    combat_active = false
    enemy_snapshots = {}
    hero_alive = {}
    last_enemy_actor_entity_id = ""
    last_defeated_major_entity_id = ""
    capture_attempt_counter_seen = CreatureManager.capture_attempt_counter
    captured_count_seen = CreatureManager.captured_creatures.size()

func _on_screen_requested(screen_name: String) -> void:
    if screen_name == "combat":
        call_deferred("_begin_current_combat")
        return
    if not combat_active:
        return
    if screen_name == "rewards":
        _finish_current_combat(true, "victory")
    elif screen_name == "sanctuary":
        var retreat := not GameState.alive_heroes().is_empty()
        _finish_current_combat(false, "forced_retreat" if retreat else "defeat")

func _begin_current_combat() -> void:
    if combat_active or GameState.battle_enemies.is_empty():
        return
    combat_active = true
    enemy_snapshots = {}
    hero_alive = {}
    last_enemy_actor_entity_id = ""
    capture_attempt_counter_seen = CreatureManager.capture_attempt_counter
    captured_count_seen = CreatureManager.captured_creatures.size()
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        hero_alive[str(hero.get("id", hero.get("name", "hero")))] = int(hero.get("hp", 0)) > 0
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        var entity_id := RemanenceRuntime.prepare_enemy(enemy, AshlandsRuntime.current_zone_id)
        RemanenceRuntime.note_encounter(enemy, AshlandsRuntime.current_zone_id, _combat_context({
            "summary": "Rencontre avec %s." % str(enemy.get("name", "un adversaire"))
        }))
        enemy_snapshots[entity_id] = _enemy_snapshot(enemy)

func _finish_current_combat(victory: bool, reason: String) -> void:
    _scan_hero_deaths()
    _scan_enemy_changes()
    _scan_capture_attempts()
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        var entity_id := str(enemy.get("remanence_id", ""))
        if entity_id == "":
            continue
        RemanenceRuntime.sync_body_snapshot(enemy)
        if bool(enemy.get("captured", false)):
            RemanenceRuntime.set_entity_status(entity_id, "recruited")
        elif int(enemy.get("hp", 0)) > 0:
            RemanenceRuntime.record_event(entity_id, "survived_combat", _combat_context({
                "summary": "%s survit à l'affrontement." % str(enemy.get("name", "L'adversaire")),
                "combat_result": reason
            }))
            if reason == "forced_retreat":
                RemanenceRuntime.record_event(entity_id, "forced_retreat", _combat_context({
                    "summary": "%s force les Veilleurs à rompre le combat." % str(enemy.get("name", "L'adversaire"))
                }))
        else:
            RemanenceRuntime.set_entity_status(entity_id, "dead")
            if _is_major_enemy(enemy):
                last_defeated_major_entity_id = entity_id
    combat_active = false
    enemy_snapshots = {}
    hero_alive = {}
    last_enemy_actor_entity_id = ""
    if victory:
        _link_recent_capture_records()

func _scan_hero_deaths() -> void:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", hero.get("name", "hero")))
        var was_alive := bool(hero_alive.get(hero_id, int(hero.get("hp", 0)) > 0))
        var is_alive := int(hero.get("hp", 0)) > 0
        if was_alive and not is_alive:
            var killer_id := last_enemy_actor_entity_id
            if killer_id == "":
                killer_id = _first_living_enemy_entity_id()
            if killer_id != "":
                RemanenceRuntime.record_event(killer_id, "killed_watcher", _combat_context({
                    "hero_id": hero_id,
                    "summary": "%s abat %s." % [_entity_name(killer_id), str(hero.get("name", "un Veilleur"))]
                }))
                RemanenceRuntime.link_archive_nodes(killer_id, "hero:%s" % hero_id, "killed", {"run_index": RemanenceRuntime.run_index})
        hero_alive[hero_id] = is_alive

func _scan_enemy_changes() -> void:
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        var entity_id := str(enemy.get("remanence_id", ""))
        if entity_id == "" or not enemy_snapshots.has(entity_id):
            continue
        var before: Dictionary = enemy_snapshots[entity_id]
        var before_lost: Array = before.get("lost_parts", [])
        var now_lost: Array = enemy.get("dismembered_parts", [])
        var severed_this_scan: Dictionary = {}
        for part_value: Variant in now_lost:
            var part_id := str(part_value)
            if before_lost.has(part_value):
                continue
            severed_this_scan[part_id] = true
            _record_mutilation(enemy, entity_id, part_id, "severed")
        var before_injuries: Dictionary = before.get("anatomy_injuries", {})
        var now_injuries: Dictionary = enemy.get("anatomy_injuries", {})
        for part_value: Variant in now_injuries.keys():
            var part_id := str(part_value)
            var state := str(now_injuries.get(part_value, ""))
            var old_state := str(before_injuries.get(part_value, ""))
            if state == "critical" and old_state != "critical" and not severed_this_scan.has(part_id):
                _record_mutilation(enemy, entity_id, part_id, "critical")
        var was_alive := bool(before.get("alive", true))
        var is_alive := int(enemy.get("hp", 0)) > 0
        if was_alive and not is_alive and not bool(enemy.get("captured", false)):
            RemanenceRuntime.set_entity_status(entity_id, "dead")
            RemanenceRuntime.sync_body_snapshot(enemy)
            if _is_major_enemy(enemy):
                last_defeated_major_entity_id = entity_id
        enemy_snapshots[entity_id] = _enemy_snapshot(enemy)

func _record_mutilation(enemy: Dictionary, entity_id: String, part_id: String, state: String) -> void:
    RemanenceRuntime.record_event(entity_id, "major_mutilation", _combat_context({
        "object_id": part_id,
        "injury_state": state,
        "summary": "%s subit une mutilation majeure : %s (%s)." % [str(enemy.get("name", "L'adversaire")), part_id, state]
    }))
    RemanenceRuntime.sync_body_snapshot(enemy)

func _scan_capture_attempts() -> void:
    var attempts := CreatureManager.capture_attempt_counter
    if attempts <= capture_attempt_counter_seen:
        captured_count_seen = CreatureManager.captured_creatures.size()
        return
    var captured_now := CreatureManager.captured_creatures.size()
    var successful_attempts := maxi(0, captured_now - captured_count_seen)
    var failed_attempts := maxi(0, attempts - capture_attempt_counter_seen - successful_attempts)
    for _index in range(failed_attempts):
        var target := _probable_capture_target()
        if not target.is_empty():
            RemanenceRuntime.record_enemy_event(target, "capture_escaped", _combat_context({
                "summary": "%s échappe au sceau de capture." % str(target.get("name", "L'adversaire"))
            }))
    capture_attempt_counter_seen = attempts
    captured_count_seen = captured_now

func _on_proxy_action_started(character_key: String, _action_id: String) -> void:
    if not combat_active or not character_key.begins_with("enemy:"):
        return
    var source_key := character_key.trim_prefix("enemy:")
    for enemy_value: Variant in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        if str(enemy.get("id", enemy.get("name", ""))) == source_key:
            last_enemy_actor_entity_id = str(enemy.get("remanence_id", ""))
            return

func _on_creature_captured(creature: Dictionary) -> void:
    if not combat_active:
        return
    var enemy := _captured_enemy_for(creature)
    if enemy.is_empty():
        return
    var entity_id := str(enemy.get("remanence_id", ""))
    if entity_id == "":
        return
    RemanenceRuntime.set_entity_status(entity_id, "recruited")
    RemanenceRuntime.sync_body_snapshot(enemy)
    var instance_id := str(creature.get("instance_id", ""))
    if instance_id != "":
        RemanenceRuntime.link_archive_nodes(entity_id, "creature:%s" % instance_id, "recruited_as", {
            "species_id": str(creature.get("species_id", "")),
            "name": str(creature.get("name", "Créature"))
        })

func _on_first_descent_completed(award: Dictionary) -> void:
    if last_defeated_major_entity_id == "" or not RemanenceRuntime.entities.has(last_defeated_major_entity_id):
        return
    var relic: Dictionary = award.get("relic", {})
    var relic_id := str(relic.get("id", ""))
    if relic_id == "":
        return
    RemanenceRuntime.record_event(last_defeated_major_entity_id, "relic_taken", {
        "object_id": relic_id,
        "summary": "La relique %s est prise après la chute de %s." % [str(relic.get("name", "Relique")), _entity_name(last_defeated_major_entity_id)],
        "dungeon_id": str(award.get("dungeon_id", ""))
    })
    RemanenceRuntime.link_archive_nodes(last_defeated_major_entity_id, "relic:%s" % relic_id, "relic_taken_from", {
        "name": str(relic.get("name", "Relique"))
    })

func _link_recent_capture_records() -> void:
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if not bool(enemy.get("captured", false)):
            continue
        var entity_id := str(enemy.get("remanence_id", ""))
        if entity_id != "":
            RemanenceRuntime.set_entity_status(entity_id, "recruited")

func _probable_capture_target() -> Dictionary:
    var candidates: Array[Dictionary] = []
    for enemy_value: Variant in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        var readiness: Dictionary = CreatureManager.capture_readiness(enemy)
        if bool(readiness.get("visible", false)):
            candidates.append(enemy)
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_ratio := float(left.get("hp", 0)) / maxf(1.0, float(left.get("max_hp", 1)))
        var right_ratio := float(right.get("hp", 0)) / maxf(1.0, float(right.get("max_hp", 1)))
        return left_ratio < right_ratio
    )
    return candidates[0]

func _captured_enemy_for(creature: Dictionary) -> Dictionary:
    var enemy_id := int(creature.get("enemy_id", -1))
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if bool(enemy.get("captured", false)) and int(enemy.get("id", -2)) == enemy_id:
            return enemy
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if bool(enemy.get("captured", false)):
            return enemy
    return {}

func _enemy_snapshot(enemy: Dictionary) -> Dictionary:
    return {
        "alive": int(enemy.get("hp", 0)) > 0,
        "lost_parts": (enemy.get("dismembered_parts", []) as Array).duplicate(true),
        "anatomy_injuries": (enemy.get("anatomy_injuries", {}) as Dictionary).duplicate(true)
    }

func _first_living_enemy_entity_id() -> String:
    for enemy_value: Variant in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        var entity_id := str(enemy.get("remanence_id", ""))
        if entity_id != "":
            return entity_id
    return ""

func _entity_name(entity_id: String) -> String:
    return str(RemanenceRuntime.entity_state(entity_id).get("name", "L'adversaire"))

func _combat_context(extra: Dictionary = {}) -> Dictionary:
    var result := {
        "zone_id": AshlandsRuntime.current_zone_id,
        "region_id": AshlandsRuntime.current_zone_id,
        "encounter_id": AshlandsCombatBridge.encounter_id if AshlandsCombatBridge.active else "prototype:%d" % GameState.expedition_room
    }
    for key_value: Variant in extra.keys():
        result[str(key_value)] = extra.get(key_value)
    return result

func _is_major_enemy(enemy: Dictionary) -> bool:
    return bool(enemy.get("boss", false)) or bool(enemy.get("is_boss", false)) or bool(enemy.get("is_miniboss", false)) or str(enemy.get("chapter_boss_id", "")) != "" or str(enemy.get("chapter_miniboss_id", "")) != ""
