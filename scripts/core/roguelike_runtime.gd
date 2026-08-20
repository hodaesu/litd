extends Node

signal run_started(seed: int, dungeon: Array)
signal room_entered(room: Dictionary, risk: Dictionary)
signal light_changed(value: int, risk: Dictionary)
signal extraction_available(summary: Dictionary)
signal run_finished(summary: Dictionary)
signal permadeath_recorded(record: Dictionary)
signal knowledge_updated(enemy_id: String, entry: Dictionary)
signal cargo_changed(cargo: Array)

const RULES_PATH := "res://data/roguelike/roguelike_rules.json"

var rules: Dictionary = {}
var active_run: Dictionary = {}
var death_records: Array = []
var bestiary: Dictionary = {}
var lore_archive: Dictionary = {}
var horizontal_unlocks: Dictionary = {}
var run_history: Array = []

func _ready() -> void:
    _load_rules()

func _load_rules() -> void:
    if not FileAccess.file_exists(RULES_PATH):
        push_error("RoguelikeRuntime: missing roguelike rules")
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        rules = parsed

func reset_new_game() -> void:
    active_run = {}
    death_records = []
    bestiary = {}
    lore_archive = {}
    horizontal_unlocks = {}
    run_history = []

func start_run(seed_value: int) -> Dictionary:
    var seed := seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
    var dungeon := generate_dungeon(seed)
    active_run = {
        "seed": seed,
        "active": true,
        "dungeon": dungeon,
        "current_room_id": "",
        "visited": [],
        "cargo": [],
        "captures_by_zone": {},
        "gold_found": 0,
        "essence_found": 0,
        "rooms_cleared": 0,
        "deepest_depth": 0,
        "boss_defeated": false,
        "extracted": false
    }
    run_started.emit(seed, dungeon.duplicate(true))
    return active_run.duplicate(true)

func generate_dungeon(seed_value: int) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var depth_rules: Dictionary = rules.get("depth", {})
    var depth_count := rng.randi_range(int(depth_rules.get("min", 3)), int(depth_rules.get("max", 5)))
    var dungeon: Array = []
    var previous_room_id := ""
    for depth in range(depth_count):
        var room_count := rng.randi_range(int(depth_rules.get("rooms_per_depth_min", 4)), int(depth_rules.get("rooms_per_depth_max", 6)))
        for room_index in range(room_count):
            var room_type := _pick_room_type(rng)
            if depth == 0 and room_index == 0:
                room_type = "start"
            elif depth == depth_count - 1 and room_index == room_count - 1:
                room_type = "boss"
            var room_id := "d%02d_r%02d" % [depth + 1, room_index + 1]
            var hazards: Array = []
            if room_type not in ["start", "camp", "merchant", "boss"] and rng.randf() < 0.28:
                hazards.append(_pick_hazard(rng))
            var room := {
                "id": room_id,
                "depth": depth + 1,
                "index": room_index,
                "type": room_type,
                "module_key": str(rules.get("module_keys", {}).get(room_type, "ASH_ROOM_01")),
                "hazards": hazards,
                "connections": [],
                "visited": false,
                "cleared": false,
                "secret": room_type == "secret"
            }
            if previous_room_id != "":
                room["connections"].append(previous_room_id)
                for previous in dungeon:
                    if str(previous.get("id", "")) == previous_room_id:
                        previous["connections"].append(room_id)
                        break
            dungeon.append(room)
            previous_room_id = room_id
    # Create a few deterministic shortcuts/branches without ever disconnecting the critical path.
    for index in range(1, dungeon.size() - 2):
        if rng.randf() < 0.18:
            var target_index := mini(dungeon.size() - 1, index + 2)
            var target_id := str(dungeon[target_index].get("id", ""))
            if not dungeon[index]["connections"].has(target_id):
                dungeon[index]["connections"].append(target_id)
                dungeon[target_index]["connections"].append(str(dungeon[index].get("id", "")))
    return dungeon

func _pick_room_type(rng: RandomNumberGenerator) -> String:
    var weights: Dictionary = rules.get("room_weights", {})
    var total := 0
    for value in weights.values():
        total += int(value)
    if total <= 0:
        return "combat"
    var roll := rng.randi_range(1, total)
    var cursor := 0
    for key in weights.keys():
        cursor += int(weights[key])
        if roll <= cursor:
            return str(key)
    return "combat"

func _pick_hazard(rng: RandomNumberGenerator) -> String:
    var hazards: Array = rules.get("hazards", [])
    if hazards.is_empty():
        return "darkness"
    return str(hazards[rng.randi_range(0, hazards.size() - 1)])

func enter_room(room_id: String) -> Dictionary:
    if not bool(active_run.get("active", false)):
        return {"success": false, "reason": "no_active_run"}
    var room := _find_room(room_id)
    if room.is_empty():
        return {"success": false, "reason": "unknown_room"}
    var visited: Array = active_run.get("visited", [])
    if not visited.has(room_id):
        visited.append(room_id)
        active_run["visited"] = visited
        active_run["rooms_cleared"] = int(active_run.get("rooms_cleared", 0)) + 1
        active_run["deepest_depth"] = maxi(int(active_run.get("deepest_depth", 0)), int(room.get("depth", 1)))
        _consume_light_for_room()
    active_run["current_room_id"] = room_id
    room["visited"] = true
    var risk := current_risk_profile(int(room.get("depth", 1)))
    if int(risk.get("light", 0)) <= int(rules.get("light", {}).get("low_threshold", 3)):
        ExpeditionManager.apply_pressure(int(rules.get("light", {}).get("pressure_per_dark_room", 4)), "low_light")
    room_entered.emit(room.duplicate(true), risk)
    return {"success": true, "room": room.duplicate(true), "risk": risk}

func _find_room(room_id: String) -> Dictionary:
    for room_value in active_run.get("dungeon", []):
        var room: Dictionary = room_value
        if str(room.get("id", "")) == room_id:
            return room
    return {}

func _consume_light_for_room() -> void:
    var decay := int(rules.get("light", {}).get("room_decay", 1))
    var current := int(ExpeditionManager.inventory.get("light", 0))
    ExpeditionManager.inventory["light"] = maxi(0, current - decay)
    ExpeditionManager.inventory_changed.emit(ExpeditionManager.inventory.duplicate(true))
    light_changed.emit(int(ExpeditionManager.inventory.get("light", 0)), current_risk_profile())

func dim_light(amount: int = 1) -> Dictionary:
    if amount <= 0:
        return current_risk_profile()
    var current := int(ExpeditionManager.inventory.get("light", 0))
    ExpeditionManager.inventory["light"] = maxi(0, current - amount)
    ExpeditionManager.inventory_changed.emit(ExpeditionManager.inventory.duplicate(true))
    var risk := current_risk_profile()
    light_changed.emit(int(ExpeditionManager.inventory.get("light", 0)), risk)
    return risk

func current_risk_profile(depth_override: int = -1) -> Dictionary:
    var light_rules: Dictionary = rules.get("light", {})
    var depth_rules: Dictionary = rules.get("depth", {})
    var max_light := max(1, int(light_rules.get("max", 10)))
    var light := clampi(int(ExpeditionManager.inventory.get("light", 0)), 0, max_light)
    var darkness := 1.0 - (float(light) / float(max_light))
    var depth := depth_override
    if depth < 0:
        depth = maxi(1, int(active_run.get("deepest_depth", 1)))
    var danger := 1.0 + darkness * float(light_rules.get("dark_danger_bonus", 0.9)) + float(depth - 1) * float(depth_rules.get("danger_bonus_per_depth", 0.04))
    var loot := 1.0 + darkness * float(light_rules.get("dark_loot_bonus", 0.75)) + float(depth - 1) * float(depth_rules.get("loot_bonus_per_depth", 0.03))
    var essence := 1.0 + darkness * float(light_rules.get("dark_essence_bonus", 0.6))
    return {"light": light, "darkness": darkness, "danger_multiplier": danger, "loot_multiplier": loot, "essence_multiplier": essence, "depth": depth}

func inventory_slots_used() -> int:
    var used := 0
    for amount in ExpeditionManager.inventory.values():
        if int(amount) > 0:
            used += 1 # supplies are stacked by category
    used += active_run.get("cargo", []).size()
    return used

func inventory_capacity() -> int:
    return int(rules.get("inventory_capacity", 20))

func can_add_cargo() -> bool:
    return inventory_slots_used() < inventory_capacity()

func add_cargo(item: Dictionary) -> bool:
    if not can_add_cargo():
        return false
    var cargo: Array = active_run.get("cargo", [])
    cargo.append(item.duplicate(true))
    active_run["cargo"] = cargo
    cargo_changed.emit(cargo.duplicate(true))
    return true

func discard_cargo(index: int) -> Dictionary:
    var cargo: Array = active_run.get("cargo", [])
    if index < 0 or index >= cargo.size():
        return {}
    var removed: Dictionary = cargo[index]
    cargo.remove_at(index)
    active_run["cargo"] = cargo
    cargo_changed.emit(cargo.duplicate(true))
    return removed

func generate_loot(depth: int, source: String = "room", seed_salt: int = 0) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(active_run.get("seed", 1)) + depth * 7919 + seed_salt * 104729 + source.hash()
    var rarity := _pick_rarity(rng, current_risk_profile(depth).get("loot_multiplier", 1.0))
    var affix_count := int(rules.get("affix_counts", {}).get(rarity, 1))
    var affixes: Array = rules.get("affixes", []).duplicate()
    affixes.shuffle()
    var selected: Array = []
    for i in range(mini(affix_count, affixes.size())):
        selected.append(str(affixes[i]))
    var item := {
        "id": "loot_%s_%s_%d" % [rarity, source, abs(rng.randi())],
        "seed": rng.seed,
        "rarity": rarity,
        "source": source,
        "depth": depth,
        "affixes": selected,
        "cursed": rng.randf() < float(rules.get("cursed_item_chance", 0.10)),
        "identified": rng.randf() >= float(rules.get("unidentified_relic_chance", 0.12))
    }
    return item

func _pick_rarity(rng: RandomNumberGenerator, loot_multiplier: float) -> String:
    var weights: Dictionary = rules.get("loot_rarity_weights", {})
    var ordered := ["common", "uncommon", "rare", "epic", "legendary"]
    var adjusted: Array = []
    var total := 0.0
    for i in range(ordered.size()):
        var rarity: String = ordered[i]
        var weight := float(weights.get(rarity, 0))
        if i >= 2:
            weight *= loot_multiplier
        adjusted.append(weight)
        total += weight
    var roll := rng.randf() * total
    var cursor := 0.0
    for i in range(ordered.size()):
        cursor += float(adjusted[i])
        if roll <= cursor:
            return ordered[i]
    return "common"

func can_capture(enemy: Dictionary, zone_id: String) -> Dictionary:
    var enemy_id := str(enemy.get("id", ""))
    var enemy_name := str(enemy.get("name", ""))
    if bool(enemy.get("boss", false)) or enemy_id.to_lower().contains("angel") or enemy_name.to_lower().contains("ange"):
        return {"allowed": false, "reason": "boss_not_capturable"}
    if bool(enemy.get("manifestation_destructrice", false)):
        return {"allowed": false, "reason": "manifestation_destructrice"}
    var max_hp := max(1, int(enemy.get("max_hp", enemy.get("hp_max", 1))))
    var hp_ratio := float(int(enemy.get("hp", 0))) / float(max_hp)
    if hp_ratio > float(rules.get("capture_hp_ratio", 0.25)):
        return {"allowed": false, "reason": "enemy_not_wounded_enough", "hp_ratio": hp_ratio}
    var captures: Dictionary = active_run.get("captures_by_zone", {})
    if int(captures.get(zone_id, 0)) >= int(rules.get("capture_limit_per_zone", 2)):
        return {"allowed": false, "reason": "zone_capture_limit"}
    return {"allowed": true, "reason": "capturable", "hp_ratio": hp_ratio}

func register_capture(enemy: Dictionary, zone_id: String) -> Dictionary:
    var check := can_capture(enemy, zone_id)
    if not bool(check.get("allowed", false)):
        return check
    var captures: Dictionary = active_run.get("captures_by_zone", {})
    captures[zone_id] = int(captures.get(zone_id, 0)) + 1
    active_run["captures_by_zone"] = captures
    return {"allowed": true, "captured": true, "enemy": enemy.duplicate(true), "zone_id": zone_id}

func ultimate_uses_for_level(level: int) -> int:
    if level >= 48:
        return 3
    if level >= 32:
        return 2
    if level >= 16:
        return 1
    return 0

func record_permadeath(actor_id: String, actor_name: String, actor_kind: String, cause: String, equipment_snapshot: Dictionary = {}) -> Dictionary:
    var record := {
        "actor_id": actor_id,
        "actor_name": actor_name,
        "actor_kind": actor_kind,
        "cause": cause,
        "run_seed": int(active_run.get("seed", 0)),
        "room_id": str(active_run.get("current_room_id", "")),
        "depth": int(active_run.get("deepest_depth", 0)),
        "equipment": equipment_snapshot.duplicate(true),
        "corpse_state": "recoverable"
    }
    death_records.append(record)
    permadeath_recorded.emit(record.duplicate(true))
    return record

func commit_party_deaths(cause: String = "expedition") -> Array:
    var committed: Array = []
    for index in range(GameState.party.size() - 1, -1, -1):
        var hero: Dictionary = GameState.party[index]
        if int(hero.get("hp", 0)) > 0:
            continue
        var hero_id := str(hero.get("id", "hero_%d" % index))
        var snapshot: Dictionary = EquipmentManager.serialize().duplicate(true)
        committed.append(record_permadeath(hero_id, str(hero.get("name", hero_id)), "hero", cause, snapshot))
        GameState.party.remove_at(index)
    if not committed.is_empty():
        GameState.state_changed.emit()
    return committed

func record_enemy_knowledge(enemy_id: String, killed: bool = false) -> Dictionary:
    var entry: Dictionary = bestiary.get(enemy_id, {"encounters": 0, "kills": 0, "tier": "unknown"})
    entry["encounters"] = int(entry.get("encounters", 0)) + 1
    if killed:
        entry["kills"] = int(entry.get("kills", 0)) + 1
    var thresholds: Dictionary = rules.get("bestiary_reveal", {})
    var score := maxi(int(entry["encounters"]), int(entry["kills"]))
    if score >= int(thresholds.get("mastery", 8)):
        entry["tier"] = "mastery"
    elif score >= int(thresholds.get("abilities", 4)):
        entry["tier"] = "abilities"
    elif score >= int(thresholds.get("stats", 2)):
        entry["tier"] = "stats"
    elif score >= int(thresholds.get("identity", 1)):
        entry["tier"] = "identity"
    bestiary[enemy_id] = entry
    knowledge_updated.emit(enemy_id, entry.duplicate(true))
    return entry.duplicate(true)

func archive_lore(entry_id: String, payload: Dictionary) -> bool:
    if lore_archive.has(entry_id):
        return false
    lore_archive[entry_id] = payload.duplicate(true)
    return true

func unlock_meta(unlock_id: String, payload: Dictionary = {}) -> bool:
    if horizontal_unlocks.has(unlock_id):
        return false
    horizontal_unlocks[unlock_id] = payload.duplicate(true)
    return true

func hazard_interactions(hazard_id: String) -> Array:
    match hazard_id:
        "fire": return ["ignite", "extinguish", "push_into"]
        "blood_pool": return ["ignite", "track", "ritual"]
        "poison_gas": return ["vent", "ignite", "resist"]
        "collapse": return ["trigger", "brace", "clear"]
        "pit": return ["push_into", "jump", "bridge"]
        "chains": return ["bind", "break", "anchor"]
        "light_source": return ["ignite", "extinguish", "destroy"]
        "darkness": return ["illuminate", "embrace", "search_secret"]
        _: return []

func extraction_summary() -> Dictionary:
    var risk := current_risk_profile()
    var summary := {
        "seed": int(active_run.get("seed", 0)),
        "rooms_cleared": int(active_run.get("rooms_cleared", 0)),
        "deepest_depth": int(active_run.get("deepest_depth", 0)),
        "cargo": active_run.get("cargo", []).duplicate(true),
        "captures_by_zone": active_run.get("captures_by_zone", {}).duplicate(true),
        "gold_found": int(active_run.get("gold_found", 0)),
        "essence_found": int(active_run.get("essence_found", 0)),
        "risk": risk
    }
    extraction_available.emit(summary.duplicate(true))
    return summary

func finish_run(reason: String) -> Dictionary:
    if active_run.is_empty():
        return {"reason": reason, "active": false}
    var summary := extraction_summary()
    summary["reason"] = reason
    summary["success"] = reason in ["voluntary", "extracted", "boss_defeated"]
    active_run["active"] = false
    active_run["extracted"] = bool(summary["success"])
    run_history.append(summary.duplicate(true))
    run_finished.emit(summary.duplicate(true))
    return summary

func serialize() -> Dictionary:
    return {
        "active_run": active_run,
        "death_records": death_records,
        "bestiary": bestiary,
        "lore_archive": lore_archive,
        "horizontal_unlocks": horizontal_unlocks,
        "run_history": run_history
    }

func deserialize(data: Dictionary) -> void:
    active_run = data.get("active_run", {}).duplicate(true)
    death_records = data.get("death_records", []).duplicate(true)
    bestiary = data.get("bestiary", {}).duplicate(true)
    lore_archive = data.get("lore_archive", {}).duplicate(true)
    horizontal_unlocks = data.get("horizontal_unlocks", {}).duplicate(true)
    run_history = data.get("run_history", []).duplicate(true)
