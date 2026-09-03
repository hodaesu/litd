extends Node

signal corpse_scar_created(scar_id: String, origin_id: String)
signal scar_visited(scar_id: String, result: Dictionary)
signal nemesis_assigned(entity_id: String, room_id: String)
signal remembered_enemy_reappeared(entity_id: String, enemy: Dictionary)

const RULES_PATH := "res://data/remanence_world_rules.json"
const FIRST_ACCORD_ANCHORS_PATH := "res://data/dungeons/first_accord_remanence_anchors.json"

var rules: Dictionary = {}
var anchor_catalog: Dictionary = {}
var seen_entities_this_run: Dictionary = {}
var last_seen_run_index := -1

func _ready() -> void:
    _load_data()
    call_deferred("_connect_sources")

func _connect_sources() -> void:
    if GameState != null and not GameState.new_game_reset.is_connected(reset_new_game):
        GameState.new_game_reset.connect(reset_new_game)
    if RemanenceRuntime != null and not RemanenceRuntime.entity_stage_changed.is_connected(_on_entity_stage_changed):
        RemanenceRuntime.entity_stage_changed.connect(_on_entity_stage_changed)
    if ExpeditionManager != null and not ExpeditionManager.expedition_ended.is_connected(_on_expedition_ended):
        ExpeditionManager.expedition_ended.connect(_on_expedition_ended)

func _load_data() -> void:
    var parsed_rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
    rules = parsed_rules if parsed_rules is Dictionary else {}
    anchor_catalog = {}
    var parsed_anchors: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIRST_ACCORD_ANCHORS_PATH))
    if parsed_anchors is Dictionary:
        for anchor_value: Variant in (parsed_anchors as Dictionary).get("anchors", []):
            if anchor_value is Dictionary:
                var anchor: Dictionary = anchor_value
                anchor_catalog[str(anchor.get("anchor_id", ""))] = anchor.duplicate(true)

func reset_new_game() -> void:
    seen_entities_this_run = {}
    last_seen_run_index = RemanenceRuntime.run_index if RemanenceRuntime != null else 0

func _on_expedition_ended(_reason: String) -> void:
    seen_entities_this_run = {}
    last_seen_run_index = RemanenceRuntime.run_index

func _sync_run_cache() -> void:
    if last_seen_run_index == RemanenceRuntime.run_index:
        return
    last_seen_run_index = RemanenceRuntime.run_index
    seen_entities_this_run = {}

func create_corpse_scar(character: Dictionary, enemy: bool, context: Dictionary = {}) -> String:
    _sync_run_cache()
    var origin_id := ""
    var origin_entity_id := ""
    var origin_hero_id := ""
    if enemy:
        origin_entity_id = str(character.get("remanence_id", ""))
        if origin_entity_id == "":
            return ""
        var record := RemanenceRuntime.entity_state(origin_entity_id)
        var stage := str(record.get("stage", "normal"))
        var minimum_stage := str(rules.get("corpse_policy", {}).get("enemy_minimum_stage", "memorial"))
        var major := _is_major_enemy(character)
        if not major and _stage_rank(stage) < _stage_rank(minimum_stage):
            return ""
        origin_id = origin_entity_id
    else:
        origin_hero_id = str(character.get("id", character.get("name", "watcher")))
        if origin_hero_id == "":
            return ""
        origin_id = "hero:%s" % origin_hero_id

    if bool(rules.get("corpse_policy", {}).get("one_corpse_per_origin_per_run", true)) and _corpse_exists_for_origin(origin_id, RemanenceRuntime.run_index):
        return ""

    var preferred_anchor := str(context.get("anchor_id", ""))
    var category := "enemy_corpse" if enemy else "watcher_corpse"
    var anchor_id := resolve_anchor("persistent_corpse", category, preferred_anchor, origin_id)
    if anchor_id == "":
        return ""

    var body_snapshot := _character_body_snapshot(character)
    var summary := "%s est resté ici." % str(character.get("name", "Un corps"))
    if not enemy:
        summary = "Le corps de %s demeure là où le Veilleur est tombé." % str(character.get("name", "un Veilleur"))
    var scar_context := {
        "region_id": str(context.get("region_id", AshlandsRuntime.current_zone_id)),
        "zone_id": str(context.get("zone_id", AshlandsRuntime.current_zone_id)),
        "origin_entity_id": origin_entity_id,
        "origin_hero_id": origin_hero_id,
        "summary": summary,
        "owner_kind": "enemy" if enemy else "watcher",
        "owner_id": origin_id,
        "owner_name": str(character.get("name", "Inconnu")),
        "body_snapshot": body_snapshot,
        "combat_id": str(context.get("combat_id", "")),
        "visit_count": 0,
        "last_seen_run": -1
    }
    var severity := "regional" if (not enemy or _is_major_enemy(character)) else "local"
    var scar_id := RemanenceRuntime.create_world_scar(anchor_id, "persistent_corpse", severity, scar_context)
    if scar_id == "":
        return ""
    if origin_entity_id != "":
        RemanenceRuntime.link_archive_nodes(origin_entity_id, scar_id, "corpse_left", {"run_index": RemanenceRuntime.run_index})
    elif origin_hero_id != "":
        RemanenceRuntime.link_archive_nodes("hero:%s" % origin_hero_id, scar_id, "corpse_left", {"run_index": RemanenceRuntime.run_index})
    corpse_scar_created.emit(scar_id, origin_id)
    return scar_id

func create_nemesis_mark(entity_id: String, context: Dictionary = {}) -> String:
    if entity_id == "" or not RemanenceRuntime.entities.has(entity_id):
        return ""
    if _active_scar_exists("nemesis_mark", entity_id):
        return ""
    var anchor_id := resolve_anchor("nemesis_mark", "nemesis_mark", str(context.get("anchor_id", "")), entity_id)
    if anchor_id == "":
        return ""
    var record := RemanenceRuntime.entity_state(entity_id)
    var scar_id := RemanenceRuntime.create_world_scar(anchor_id, "nemesis_mark", "historical", {
        "origin_entity_id": entity_id,
        "region_id": str(context.get("region_id", record.get("region_id", ""))),
        "summary": "%s a laissé ici une marque que les Veilleurs reconnaissent." % str(record.get("name", "Un Némésis")),
        "protected": true,
        "owner_id": entity_id,
        "owner_name": str(record.get("name", "Némésis")),
        "visit_count": 0,
        "last_seen_run": -1
    })
    if scar_id != "":
        RemanenceRuntime.link_archive_nodes(entity_id, scar_id, "nemesis_mark", {"run_index": RemanenceRuntime.run_index})
    return scar_id

func resolve_anchor(scar_type: String, category: String, preferred_anchor: String = "", salt: String = "") -> String:
    if preferred_anchor != "" and _anchor_allows(preferred_anchor, scar_type):
        return preferred_anchor
    var preferences: Array = rules.get("scar_anchor_preferences", {}).get(category, [])
    var candidates: Array[String] = []
    for value: Variant in preferences:
        var anchor_id := str(value)
        if _anchor_allows(anchor_id, scar_type):
            candidates.append(anchor_id)
    if candidates.is_empty():
        for key_value: Variant in anchor_catalog.keys():
            var anchor_id := str(key_value)
            if _anchor_allows(anchor_id, scar_type):
                candidates.append(anchor_id)
    if candidates.is_empty():
        return ""
    var seed_text := "%s|%s|%d|%s" % [scar_type, category, RemanenceRuntime.run_index, salt]
    return candidates[absi(seed_text.hash()) % candidates.size()]

func prepare_battle(enemies: Array, context: Dictionary = {}) -> Array[String]:
    _sync_run_cache()
    var assigned: Array[String] = []
    var candidates := _reappearance_candidates(context)
    for enemy_value: Variant in enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        if bool(enemy.get("boss", false)) or bool(enemy.get("is_boss", false)):
            continue
        var species_key := _species_key(enemy)
        for record_value: Variant in candidates:
            var record: Dictionary = record_value
            var entity_id := str(record.get("id", ""))
            if entity_id == "" or seen_entities_this_run.has(entity_id) or assigned.has(entity_id):
                continue
            if str(record.get("species_id", "")) != species_key:
                continue
            if not _passes_reappearance_roll(record, context):
                continue
            enemy["remanence_id"] = entity_id
            apply_entity_memory_to_enemy(enemy, entity_id)
            assigned.append(entity_id)
            seen_entities_this_run[entity_id] = true
            remembered_enemy_reappeared.emit(entity_id, enemy)
            break
    return assigned

func apply_entity_memory_to_enemy(enemy: Dictionary, entity_id: String) -> void:
    var record := RemanenceRuntime.entity_state(entity_id)
    if record.is_empty():
        return
    var stage := str(record.get("stage", "normal"))
    enemy["remanence_id"] = entity_id
    enemy["remanence_stage"] = stage
    enemy["remanence_score"] = int(record.get("score", 0))
    enemy["remanence_adaptations"] = (record.get("adaptations", []) as Array).duplicate(true)
    if stage in ["elite", "nemesis"]:
        enemy["elite"] = true

    var snapshot: Dictionary = record.get("body_snapshot", {})
    for key in ["persistent_injuries", "body_state", "dismembered_parts", "anatomy_injuries", "anatomy_part_states", "anatomy_part_trauma"]:
        var value: Variant = snapshot.get(key)
        if value is Array:
            enemy[key] = (value as Array).duplicate(true)
        elif value is Dictionary:
            enemy[key] = (value as Dictionary).duplicate(true)
    _apply_stage_scaling(enemy, stage)
    _apply_body_consequences(enemy)
    for adaptation_value: Variant in record.get("adaptations", []):
        _apply_adaptation(enemy, entity_id, str(adaptation_value))

func decorate_plan(plan: Dictionary) -> Dictionary:
    var copy := plan.duplicate(true)
    var remanence: Dictionary = copy.get("remanence", {})
    var applied: Array = remanence.get("applied", [])
    var proxy_budget := _proxy_budget()
    var max_visible := int(proxy_budget.get("max_visible_scars_per_room", 4))
    var max_interactive := int(proxy_budget.get("max_interactive_scars_per_room", 2))
    var applied_count := 0
    var interactive_count := 0

    for node_value: Variant in copy.get("nodes", []):
        if not (node_value is Dictionary):
            continue
        var node: Dictionary = node_value
        var anchors: Array = node.get("scar_anchors", [])
        var node_scars: Array[Dictionary] = []
        var node_interactive := 0
        for scar_value: Variant in applied:
            if not (scar_value is Dictionary):
                continue
            var scar: Dictionary = scar_value
            var anchor_id := str(scar.get("anchor_id", ""))
            var scar_type := str(scar.get("type", ""))
            if not anchors.has(anchor_id) or not _anchor_allows(anchor_id, scar_type):
                continue
            if scar_type == "persistent_corpse" and _corpse_count_for_anchor(node_scars, anchor_id) >= _corpse_cap(anchor_id):
                continue
            var effect: Dictionary = rules.get("scar_effects", {}).get(scar_type, {})
            var is_interactive := bool(effect.get("interaction", false))
            if is_interactive and node_interactive >= max_interactive:
                continue
            node_scars.append(scar.duplicate(true))
            if is_interactive:
                node_interactive += 1
                interactive_count += 1
            _merge_node_effect(node, effect, scar)
            if node_scars.size() >= max_visible:
                break
        node["remanence_scars"] = node_scars
        node["remanence_interactive_count"] = node_interactive
        applied_count += node_scars.size()

    var nemesis_assignment := _assign_nemesis_to_plan(copy)
    copy["remanence_summary"] = {
        "visible_scars": applied_count,
        "interactive_scars": interactive_count,
        "deferred_scars": (remanence.get("deferred", []) as Array).size(),
        "nemesis_entity_id": str(nemesis_assignment.get("entity_id", "")),
        "nemesis_room_id": str(nemesis_assignment.get("room_id", ""))
    }
    return copy

func visit_scar(scar_id: String) -> Dictionary:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return {"ok": false, "reason": "scar_missing"}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    var visits := int(payload.get("visit_count", 0)) + 1
    payload["visit_count"] = visits
    payload["last_seen_run"] = RemanenceRuntime.run_index
    var great_rule: Dictionary = rules.get("great_remanence", {})
    var became_great := false
    if not bool(payload.get("great_remanence", false)) and int(scar.get("age_runs", 0)) >= int(great_rule.get("minimum_age_runs", 2)) and visits >= int(great_rule.get("minimum_visits", 2)):
        payload["great_remanence"] = true
        became_great = true
    var patch := {"payload": payload}
    if became_great and bool(great_rule.get("protect_scar", true)):
        patch["protected"] = true
        patch["severity"] = "historical"
    RemanenceRuntime.update_world_scar(scar_id, patch)

    var result := {
        "ok": true,
        "scar_id": scar_id,
        "type": str(scar.get("type", "trace")),
        "age_runs": int(scar.get("age_runs", 0)),
        "visit_count": visits,
        "great_remanence": bool(payload.get("great_remanence", false)),
        "became_great_remanence": became_great,
        "text": _scar_visit_text(scar, payload, became_great)
    }
    scar_visited.emit(scar_id, result.duplicate(true))
    return result

func disturb_scar(scar_id: String, disturbance: String) -> bool:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return false
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    var disturbances: Array = payload.get("disturbances", [])
    if not disturbances.has(disturbance):
        disturbances.append(disturbance)
    payload["disturbances"] = disturbances
    payload["last_disturbed_run"] = RemanenceRuntime.run_index
    return RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})

func adaptation_label(adaptation_id: String) -> String:
    return str(rules.get("adaptations", {}).get(adaptation_id, {}).get("label", adaptation_id.replace("_", " ").capitalize()))

func _on_entity_stage_changed(entity_id: String, _previous_stage: String, new_stage: String) -> void:
    if _stage_rank(new_stage) >= _stage_rank("veteran"):
        _assign_adaptations(entity_id)
    if new_stage == "nemesis":
        create_nemesis_mark(entity_id)

func _assign_adaptations(entity_id: String) -> void:
    var record := RemanenceRuntime.entity_state(entity_id)
    if record.is_empty():
        return
    var stage := str(record.get("stage", "normal"))
    var limit := int(RemanenceRuntime.rules.get("adaptation_limits", {}).get(stage, 0))
    if limit <= 0:
        return
    var current: Array = record.get("adaptations", [])
    if current.size() >= limit:
        return
    var candidates: Dictionary = {}
    var event_map: Dictionary = rules.get("event_to_adaptations", {})
    for event: Dictionary in RemanenceRuntime.recent_events(entity_id, 40):
        for adaptation_value: Variant in event_map.get(str(event.get("type", "")), []):
            candidates[str(adaptation_value)] = true
    for priority_value: Variant in rules.get("adaptation_priority", []):
        if current.size() >= limit:
            break
        var adaptation_id := str(priority_value)
        if not candidates.has(adaptation_id) or current.has(adaptation_id):
            continue
        if RemanenceRuntime.add_adaptation(entity_id, adaptation_id):
            current.append(adaptation_id)

func _apply_adaptation(enemy: Dictionary, entity_id: String, adaptation_id: String) -> void:
    var definition: Dictionary = rules.get("adaptations", {}).get(adaptation_id, {})
    match str(definition.get("effect", "")):
        "protect_last_mutilated_part":
            var part_id := _latest_mutilated_part(entity_id)
            if part_id != "":
                enemy["protected_anatomy_part"] = part_id
                enemy["remanence_anatomy_hit_penalty"] = int(definition.get("anatomy_hit_penalty", 15))
        "capture_resistance":
            enemy["remanence_capture_resistance"] = int(definition.get("capture_resistance", 15))
        "target_mode":
            enemy["remanence_target_mode"] = str(definition.get("target_mode", "weakest"))
        "damage_multiplier":
            enemy["remanence_damage_multiplier"] = float(definition.get("damage_multiplier", 1.0))
        "fear_resistance":
            enemy["remanence_fear_resistance"] = int(definition.get("fear_resistance", 0))

func _apply_stage_scaling(enemy: Dictionary, stage: String) -> void:
    if bool(enemy.get("remanence_stage_scaled", false)):
        return
    var values: Dictionary = rules.get("stage_combat_multipliers", {}).get(stage, {})
    var hp_multiplier := float(values.get("hp", 1.0))
    var damage_multiplier := float(values.get("damage", 1.0))
    var max_hp := maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
    max_hp = maxi(1, int(round(float(max_hp) * hp_multiplier)))
    enemy["max_hp"] = max_hp
    enemy["hp"] = max_hp
    var damage: Array = enemy.get("damage", [])
    if damage.size() >= 2:
        enemy["damage"] = [
            maxi(1, int(round(float(damage[0]) * damage_multiplier))),
            maxi(1, int(round(float(damage[1]) * damage_multiplier)))
        ]
    enemy["remanence_stage_scaled"] = true

func _apply_body_consequences(enemy: Dictionary) -> void:
    var lost: Array = enemy.get("dismembered_parts", [])
    if lost.is_empty():
        return
    var attack_multiplier := 1.0
    var fear_multiplier := 1.0
    var mobility_lost := false
    for part_value: Variant in lost:
        var part := AnatomyRuntime.part_definition(enemy, str(part_value))
        var tags: Array = part.get("tags", [])
        if tags.has("attack") or tags.has("weapon"):
            attack_multiplier *= 0.78
        if tags.has("fear") or tags.has("sensor"):
            fear_multiplier *= 0.80
        if tags.has("mobility"):
            mobility_lost = true
    var damage: Array = enemy.get("damage", [])
    if damage.size() >= 2 and attack_multiplier < 1.0:
        enemy["damage"] = [
            maxi(1, int(round(float(damage[0]) * attack_multiplier))),
            maxi(1, int(round(float(damage[1]) * attack_multiplier)))
        ]
    if fear_multiplier < 1.0:
        enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * fear_multiplier)))
    if mobility_lost:
        enemy["remanence_mobility_impaired"] = true

func _reappearance_candidates(context: Dictionary) -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    var region_id := str(context.get("region_id", ""))
    for key_value: Variant in RemanenceRuntime.entities.keys():
        var record: Dictionary = RemanenceRuntime.entities[str(key_value)]
        var stage := str(record.get("stage", "normal"))
        if stage == "normal" or str(record.get("status", "active")) != "active":
            continue
        var copy := record.duplicate(true)
        copy["same_region"] = region_id != "" and str(record.get("region_id", "")) == region_id
        rows.append(copy)
    rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_priority := _stage_rank(str(left.get("stage", "normal"))) * 1000 + int(left.get("score", 0)) + (100 if bool(left.get("same_region", false)) else 0)
        var right_priority := _stage_rank(str(right.get("stage", "normal"))) * 1000 + int(right.get("score", 0)) + (100 if bool(right.get("same_region", false)) else 0)
        return left_priority > right_priority
    )
    return rows

func _passes_reappearance_roll(record: Dictionary, context: Dictionary) -> bool:
    var stage := str(record.get("stage", "normal"))
    var chance := float(rules.get("reappearance_chance", {}).get(stage, 0.0))
    if chance >= 1.0:
        return true
    if chance <= 0.0:
        return false
    var seed_text := "%s|%d|%s|%s" % [str(record.get("id", "")), RemanenceRuntime.run_index, str(context.get("combat_id", "")), str(context.get("zone_id", ""))]
    var roll := float(absi(seed_text.hash()) % 10000) / 10000.0
    return roll < chance

func _assign_nemesis_to_plan(plan: Dictionary) -> Dictionary:
    var candidates: Array[Dictionary] = []
    for key_value: Variant in RemanenceRuntime.entities.keys():
        var record: Dictionary = RemanenceRuntime.entities[str(key_value)]
        if str(record.get("stage", "")) == "nemesis" and str(record.get("status", "active")) == "active":
            candidates.append(record.duplicate(true))
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("score", 0)) > int(right.get("score", 0)))
    var nemesis: Dictionary = candidates[0]
    var eligible: Array[Dictionary] = []
    for node_value: Variant in plan.get("nodes", []):
        if node_value is Dictionary:
            var node: Dictionary = node_value
            if bool(node.get("nemesis_eligible", false)) and str(node.get("role", "")) not in ["entry", "boss", "secret"]:
                eligible.append(node)
    if eligible.is_empty():
        return {}
    eligible.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("depth", 0)) > int(right.get("depth", 0)))
    var seed_text := "%s|%s|%d" % [str(plan.get("seed", 0)), str(nemesis.get("id", "")), RemanenceRuntime.run_index]
    var selected: Dictionary = eligible[absi(seed_text.hash()) % eligible.size()]
    selected["nemesis_entity_id"] = str(nemesis.get("id", ""))
    selected["nemesis_override"] = true
    selected["nemesis_name"] = str(nemesis.get("name", "Némésis"))
    var tags: Array = selected.get("environment_tags", [])
    if not tags.has("nemesis_presence"):
        tags.append("nemesis_presence")
    selected["environment_tags"] = tags
    nemesis_assigned.emit(str(nemesis.get("id", "")), str(selected.get("id", "")))
    return {"entity_id": str(nemesis.get("id", "")), "room_id": str(selected.get("id", ""))}

func _merge_node_effect(node: Dictionary, effect: Dictionary, scar: Dictionary) -> void:
    var tags: Array = node.get("environment_tags", [])
    for tag_value: Variant in effect.get("environment_tags", []):
        if not tags.has(tag_value):
            tags.append(tag_value)
    node["environment_tags"] = tags
    if bool(effect.get("boost_nemesis_eligibility", false)):
        node["nemesis_eligible"] = true
        node["nemesis_trace"] = true
    var route_state := str(effect.get("route_state", ""))
    if route_state != "":
        node["remanence_route_state"] = route_state
    var resource_state := str(effect.get("resource_state", ""))
    if resource_state != "":
        node["remanence_resource_state"] = resource_state
    if str(scar.get("type", "")) == "persistent_corpse":
        node["contains_persistent_corpse"] = true

func _scar_visit_text(scar: Dictionary, payload: Dictionary, became_great: bool) -> String:
    var owner_name := str(payload.get("owner_name", ""))
    var scar_type := str(scar.get("type", "trace"))
    if became_great:
        return "Ce lieu ne conserve plus seulement une trace : il est devenu une Grande Rémanence."
    if scar_type == "persistent_corpse":
        if str(payload.get("owner_kind", "")) == "watcher":
            return "Les Veilleurs reconnaissent %s. Le corps est toujours là, mais le lieu a changé autour de lui." % owner_name
        return "Le corps de %s porte encore les conséquences du combat précédent." % owner_name
    if scar_type == "nemesis_mark":
        return "La marque de %s est récente. L'adversaire sait que les Veilleurs peuvent revenir." % owner_name
    if scar_type == "old_blood":
        return "Le sang a noirci, mais la scène raconte encore la violence qui a eu lieu ici."
    return str(scar.get("summary", "Le monde se souvient de ce qui s'est produit ici."))

func _character_body_snapshot(character: Dictionary) -> Dictionary:
    return {
        "hp": int(character.get("hp", 0)),
        "max_hp": int(character.get("max_hp", character.get("hp", 0))),
        "persistent_injuries": (character.get("persistent_injuries", []) as Array).duplicate(true),
        "body_state": (character.get("body_state", {}) as Dictionary).duplicate(true),
        "dismembered_parts": (character.get("dismembered_parts", []) as Array).duplicate(true),
        "anatomy_injuries": (character.get("anatomy_injuries", {}) as Dictionary).duplicate(true),
        "anatomy_part_states": (character.get("anatomy_part_states", {}) as Dictionary).duplicate(true),
        "anatomy_part_trauma": (character.get("anatomy_part_trauma", {}) as Dictionary).duplicate(true)
    }

func _latest_mutilated_part(entity_id: String) -> String:
    for event: Dictionary in RemanenceRuntime.recent_events(entity_id, 30):
        if str(event.get("type", "")) == "major_mutilation":
            return str(event.get("object_id", ""))
    return ""

func _corpse_exists_for_origin(origin_id: String, run_index: int) -> bool:
    for scar_value: Variant in RemanenceRuntime.world_scars.values():
        if not (scar_value is Dictionary):
            continue
        var scar: Dictionary = scar_value
        if str(scar.get("type", "")) != "persistent_corpse" or int(scar.get("created_run", -1)) != run_index:
            continue
        var payload: Dictionary = scar.get("payload", {})
        if str(payload.get("owner_id", "")) == origin_id:
            return true
    return false

func _active_scar_exists(scar_type: String, origin_id: String) -> bool:
    for scar_value: Variant in RemanenceRuntime.world_scars.values():
        if scar_value is Dictionary:
            var scar: Dictionary = scar_value
            if str(scar.get("type", "")) == scar_type and str(scar.get("origin_entity_id", scar.get("payload", {}).get("owner_id", ""))) == origin_id:
                return true
    return false

func _anchor_allows(anchor_id: String, scar_type: String) -> bool:
    if not anchor_catalog.has(anchor_id):
        return false
    var anchor: Dictionary = anchor_catalog[anchor_id]
    return (anchor.get("allowed", []) as Array).has(scar_type)

func _corpse_cap(anchor_id: String) -> int:
    var anchor: Dictionary = anchor_catalog.get(anchor_id, {})
    var mobile := OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
    if mobile:
        return maxi(1, int(anchor.get("corpse_cap_mobile", 2)))
    return maxi(1, int(anchor.get("corpse_cap_pc", 4)))

func _corpse_count_for_anchor(scars: Array[Dictionary], anchor_id: String) -> int:
    var count := 0
    for scar: Dictionary in scars:
        if str(scar.get("anchor_id", "")) == anchor_id and str(scar.get("type", "")) == "persistent_corpse":
            count += 1
    return count

func _proxy_budget() -> Dictionary:
    var mobile := OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")
    return rules.get("mobile_proxy_budget" if mobile else "pc_proxy_budget", {})

func _is_major_enemy(enemy: Dictionary) -> bool:
    return bool(enemy.get("boss", false)) or bool(enemy.get("is_boss", false)) or bool(enemy.get("is_miniboss", false)) or bool(enemy.get("elite", false)) or str(enemy.get("chapter_boss_id", "")) != "" or str(enemy.get("chapter_miniboss_id", "")) != ""

func _stage_rank(stage: String) -> int:
    return int({"normal": 0, "memorial": 1, "veteran": 2, "elite": 3, "nemesis": 4}.get(stage, 0))

func _species_key(enemy: Dictionary) -> String:
    return str(enemy.get("species_id", enemy.get("id", "unknown")))
