extends RefCounted

# Première passe spatiale des Cryptes du Premier Voile.
# La carte macro n'est qu'une représentation : chaque nœud est une vraie zone
# visitable, chaque liaison un passage, et les salles secrètes sont absentes du
# plan tant qu'elles n'ont pas été découvertes depuis une salle adjacente.

const CATALOG_PATH := "res://data/roguelike/first_veil_rooms.json"
const PHYSICAL_DUNGEON_VERSION := 1

var catalog: Dictionary = {}

func _init() -> void:
    _load_catalog()

func _load_catalog() -> void:
    catalog = {}
    if not FileAccess.file_exists(CATALOG_PATH):
        push_error("FirstVeilDungeonRuntime: catalogue de salles introuvable")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        catalog = parsed
    else:
        push_error("FirstVeilDungeonRuntime: catalogue de salles invalide")

func ensure_run(runtime: Node) -> Dictionary:
    if runtime == null:
        return {"initialized": false, "reason": "runtime_unavailable"}
    var active: Dictionary = runtime.active_run
    if not bool(active.get("active", false)):
        return {"initialized": false, "reason": "no_active_run"}
    if int(active.get("physical_dungeon_version", 0)) >= PHYSICAL_DUNGEON_VERSION and str(active.get("dungeon_id", "")) == str(catalog.get("dungeon_id", "first_veil_crypts")):
        return {"initialized": false, "reason": "already_initialized", "active_run": active.duplicate(true)}

    var seed_value: int = int(active.get("seed", 1))
    var layout: Array = _build_layout(seed_value)
    if layout.is_empty():
        return {"initialized": false, "reason": "empty_catalog"}

    active["dungeon"] = layout
    active["dungeon_id"] = str(catalog.get("dungeon_id", "first_veil_crypts"))
    active["orientation"] = str(catalog.get("orientation", "vertical_descending"))
    active["orientation_label"] = str(catalog.get("orientation_label", "DESCENTE VERTICALE"))
    active["palier_count"] = int(catalog.get("palier_count", 4))
    active["physical_dungeon_version"] = PHYSICAL_DUNGEON_VERSION
    active["current_room_id"] = ""
    active["visited"] = []
    active["rooms_cleared"] = 0
    active["deepest_depth"] = 0
    active["secret_searches"] = {}
    active["discovered_secrets"] = []
    active["room_transition_history"] = []
    runtime.active_run = active
    return {"initialized": true, "active_run": active.duplicate(true), "room_count": layout.size()}

func _build_layout(seed_value: int) -> Array:
    if catalog.is_empty():
        return []
    var source_rooms: Array = catalog.get("rooms", []).duplicate(true)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value * 7919 + 17011
    var result: Array = []

    for index in range(source_rooms.size()):
        var room: Dictionary = source_rooms[index]
        var variants: Array = room.get("variant_pool", [])
        var variant_id := "standard"
        if not variants.is_empty():
            variant_id = str(variants[rng.randi_range(0, variants.size() - 1)])
        var hazards: Array = []
        var hazard_pool: Array = room.get("hazard_pool", [])
        if not hazard_pool.is_empty():
            hazards.append(str(hazard_pool[rng.randi_range(0, hazard_pool.size() - 1)]))

        room["index"] = index
        room["variant"] = variant_id
        room["hazards"] = hazards
        room["visited"] = false
        room["cleared"] = false
        room["interaction_resolved"] = false
        room["secret"] = bool(room.get("secret", false))
        room["discovered"] = not bool(room.get("secret", false))
        room["map_visible"] = str(room.get("room_role", "")) == "entry"
        result.append(room)

    _normalize_connections(result)
    return result

func _normalize_connections(layout: Array) -> void:
    for room_value in layout:
        var room: Dictionary = room_value
        var room_id := str(room.get("id", ""))
        var connections: Array = room.get("connections", [])
        for target_value in connections.duplicate():
            var target_id := str(target_value)
            var target: Dictionary = _room_from_layout(layout, target_id)
            if target.is_empty():
                push_error("FirstVeilDungeonRuntime: liaison inconnue %s -> %s" % [room_id, target_id])
                connections.erase(target_value)
                continue
            var reverse: Array = target.get("connections", [])
            if not reverse.has(room_id):
                reverse.append(room_id)
                target["connections"] = reverse
        room["connections"] = connections

func _room_from_layout(layout: Array, room_id: String) -> Dictionary:
    for room_value in layout:
        var room: Dictionary = room_value
        if str(room.get("id", "")) == room_id:
            return room
    return {}

func room_by_id(runtime: Node, room_id: String) -> Dictionary:
    if runtime == null:
        return {}
    var active: Dictionary = runtime.active_run
    return _room_from_layout(active.get("dungeon", []), room_id)

func entry_room_id(runtime: Node) -> String:
    if runtime == null:
        return ""
    var active: Dictionary = runtime.active_run
    for room_value in active.get("dungeon", []):
        var room: Dictionary = room_value
        if str(room.get("room_role", "")) == "entry":
            return str(room.get("id", ""))
    return ""

func visible_layout(runtime: Node) -> Array:
    if runtime == null:
        return []
    var active: Dictionary = runtime.active_run
    var visible_ids: Array[String] = visible_room_ids(runtime)
    var result: Array = []
    for room_value in active.get("dungeon", []):
        var room: Dictionary = room_value
        if visible_ids.has(str(room.get("id", ""))):
            result.append(room.duplicate(true))
    return result

func visible_room_ids(runtime: Node) -> Array[String]:
    var result: Array[String] = []
    if runtime == null:
        return result
    var active: Dictionary = runtime.active_run
    var visited: Array = active.get("visited", [])
    var dungeon: Array = active.get("dungeon", [])
    var entry_id := entry_room_id(runtime)

    if visited.is_empty():
        if entry_id != "":
            result.append(entry_id)
        return result

    for visited_value in visited:
        var visited_id := str(visited_value)
        _append_unique(result, visited_id)
        var source: Dictionary = _room_from_layout(dungeon, visited_id)
        for target_value in source.get("connections", []):
            var target_id := str(target_value)
            var target: Dictionary = _room_from_layout(dungeon, target_id)
            if target.is_empty() or not _room_can_be_revealed(target):
                continue
            _append_unique(result, target_id)

    var current_id := str(active.get("current_room_id", ""))
    if current_id != "":
        _append_unique(result, current_id)
    return result

func _append_unique(values: Array[String], value: String) -> void:
    if value != "" and not values.has(value):
        values.append(value)

func _room_can_be_revealed(room: Dictionary) -> bool:
    if not bool(room.get("secret", false)):
        return true
    return bool(room.get("discovered", false))

func is_room_visible(runtime: Node, room_id: String) -> bool:
    return visible_room_ids(runtime).has(room_id)

func player_connections(runtime: Node, room_id: String) -> Array[String]:
    var result: Array[String] = []
    var source: Dictionary = room_by_id(runtime, room_id)
    if source.is_empty():
        return result
    for target_value in source.get("connections", []):
        var target_id := str(target_value)
        var target: Dictionary = room_by_id(runtime, target_id)
        if target.is_empty() or not _room_can_be_revealed(target):
            continue
        result.append(target_id)
    return result

func is_reachable(runtime: Node, room_id: String) -> bool:
    if runtime == null:
        return false
    var active: Dictionary = runtime.active_run
    var visited: Array = active.get("visited", [])
    if visited.is_empty():
        return room_id == entry_room_id(runtime)
    var current_id := str(active.get("current_room_id", ""))
    if current_id == "" or room_id == current_id:
        return false
    return player_connections(runtime, current_id).has(room_id)

func transition_label(runtime: Node, from_room_id: String, to_room_id: String) -> String:
    var source: Dictionary = room_by_id(runtime, from_room_id)
    var target: Dictionary = room_by_id(runtime, to_room_id)
    if source.is_empty() or target.is_empty():
        return "PASSAGE"
    var source_palier := int(source.get("palier", source.get("depth", 1)))
    var target_palier := int(target.get("palier", target.get("depth", 1)))
    var verb := "PASSAGE"
    if target_palier > source_palier:
        verb = "DESCENDRE"
    elif target_palier < source_palier:
        verb = "REMONTER"
    var active: Dictionary = runtime.active_run
    var visited: Array = active.get("visited", [])
    var target_name := str(target.get("name", "Salle inconnue")) if visited.has(to_room_id) else "SALLE INCONNUE"
    if bool(target.get("secret", false)):
        target_name = str(target.get("name", "Salle secrète")) if visited.has(to_room_id) else "PASSAGE SECRET DÉCOUVERT"
    return "%s → %s" % [verb, target_name.to_upper()]

func record_transition(runtime: Node, from_room_id: String, to_room_id: String) -> void:
    if runtime == null or from_room_id == "" or to_room_id == "":
        return
    var active: Dictionary = runtime.active_run
    var history: Array = active.get("room_transition_history", [])
    history.append({
        "from": from_room_id,
        "to": to_room_id,
        "from_palier": int(room_by_id(runtime, from_room_id).get("palier", 0)),
        "to_palier": int(room_by_id(runtime, to_room_id).get("palier", 0))
    })
    active["room_transition_history"] = history
    runtime.active_run = active

func was_searched(runtime: Node, room_id: String) -> bool:
    if runtime == null:
        return false
    var active: Dictionary = runtime.active_run
    var searches: Dictionary = active.get("secret_searches", {})
    return bool(searches.get(room_id, false))

func search_for_secret(runtime: Node, room_id: String) -> Dictionary:
    if runtime == null:
        return {"success": false, "found": false, "reason": "runtime_unavailable"}
    var active: Dictionary = runtime.active_run
    var searches: Dictionary = active.get("secret_searches", {})
    if bool(searches.get(room_id, false)):
        return {"success": false, "found": false, "reason": "already_searched"}
    searches[room_id] = true
    active["secret_searches"] = searches

    var source: Dictionary = _room_from_layout(active.get("dungeon", []), room_id)
    var secret_id := str(source.get("secret_target", ""))
    if secret_id == "":
        runtime.active_run = active
        return {"success": true, "found": false, "reason": "nothing_found"}

    var target: Dictionary = _room_from_layout(active.get("dungeon", []), secret_id)
    if target.is_empty():
        runtime.active_run = active
        return {"success": true, "found": false, "reason": "missing_secret_target"}

    target["discovered"] = true
    var discovered: Array = active.get("discovered_secrets", [])
    if not discovered.has(secret_id):
        discovered.append(secret_id)
    active["discovered_secrets"] = discovered
    runtime.active_run = active
    return {
        "success": true,
        "found": true,
        "secret_id": secret_id,
        "secret_name": str(target.get("name", "Salle secrète"))
    }

func mark_interaction_resolved(runtime: Node, room_id: String) -> void:
    if runtime == null:
        return
    var active: Dictionary = runtime.active_run
    var room: Dictionary = _room_from_layout(active.get("dungeon", []), room_id)
    if room.is_empty():
        return
    room["interaction_resolved"] = true
    runtime.active_run = active

func room_variant_text(room: Dictionary) -> String:
    return str(room.get("variant", "standard")).replace("_", " ")

func space_kind_text(room: Dictionary) -> String:
    return str(room.get("space_kind", "salle")).replace("_", " ")

func summary(runtime: Node) -> Dictionary:
    if runtime == null:
        return {}
    var active: Dictionary = runtime.active_run
    var total := 0
    var secrets := 0
    var discovered := 0
    for room_value in active.get("dungeon", []):
        var room: Dictionary = room_value
        total += 1
        if bool(room.get("secret", false)):
            secrets += 1
            if bool(room.get("discovered", false)):
                discovered += 1
    return {
        "dungeon_id": str(active.get("dungeon_id", "")),
        "orientation": str(active.get("orientation", "")),
        "palier_count": int(active.get("palier_count", 0)),
        "room_count": total,
        "secret_count": secrets,
        "discovered_secret_count": discovered,
        "visited_count": (active.get("visited", []) as Array).size()
    }
