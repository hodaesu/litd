extends RefCounted

# Assemble uniquement des salles dont la géométrie a été conçue et validée à la main.
# Le procédural choisit les salles, leurs variantes autorisées et leurs connexions ;
# il ne fabrique jamais les murs, les portes, les arènes ou la mise en scène narrative.

const POLICY_PATH := "res://data/roguelike/hybrid_dungeon_generation.json"
const RoomPersistenceAssembler := preload("res://scripts/core/veilleurs_room_persistence_assembler.gd")

var policy: Dictionary = {}
var catalog_cache: Dictionary = {}
var room_persistence_assembler: RefCounted

func _init() -> void:
    policy = _load_dictionary(POLICY_PATH)
    room_persistence_assembler = RoomPersistenceAssembler.new()

func generate(seed_value: int, dungeon_id: String, context: Dictionary = {}) -> Dictionary:
    var dungeon_rules: Dictionary = policy.get("dungeons", {}).get(dungeon_id, {})
    if dungeon_rules.is_empty():
        return {"success": false, "reason": "unknown_dungeon", "layout": []}

    var ngplus_context: Dictionary = NgPlusCycleDirector.dungeon_context(seed_value, dungeon_id)
    var ngplus_active := bool(ngplus_context.get("active", false))
    var visit_kind := str(context.get("visit_kind", "revisit"))
    # Le premier passage du cycle initial reste une mise en scène fixe écrite à la main.
    # En NG+, la première revisite de campagne peut utiliser le graphe contrôlé : c'est
    # précisément une des différences fortes de rejouabilité, sans générer de géométrie.
    if visit_kind == "campaign_first_visit" and not ngplus_active:
        return {"success": false, "reason": "authored_fixed_layout_required", "layout": []}

    var catalog_path := str(dungeon_rules.get("catalog", ""))
    var catalog := _catalog(catalog_path)
    var templates: Array = catalog.get("rooms", [])
    var recipe: Dictionary = dungeon_rules.get("recipe", {})
    if templates.is_empty() or recipe.is_empty():
        return {"success": false, "reason": "missing_handcrafted_catalog", "layout": []}

    var effective_seed := int(ngplus_context.get("seed", seed_value)) if ngplus_active else seed_value
    var rng := RandomNumberGenerator.new()
    rng.seed = effective_seed * 104729 + int(dungeon_id.hash())
    var selected_by_key: Dictionary = {}
    var used_templates: Array[String] = []
    var layout: Array = []
    var room_states: Array = policy.get("room_states", ["intact"])
    var secret_bonus := float(ngplus_context.get("secret_chance_bonus", 0.0)) if ngplus_active else 0.0
    var ngplus_hazards: Array = ngplus_context.get("extra_hazard_pool", []) if ngplus_active else []
    var ngplus_variant := str(ngplus_context.get("variant_tag", ""))
    var ngplus_profile := str(ngplus_context.get("profile_id", ""))
    var ngplus_world_variant := str(ngplus_context.get("world_variant", ""))

    for node_value: Variant in recipe.get("nodes", []):
        var node: Dictionary = node_value
        var chance := float(node.get("optional_chance", 1.0))
        if ngplus_active and chance < 1.0:
            chance = minf(1.0, chance + secret_bonus)
        if chance < 1.0 and rng.randf() > chance:
            continue
        var template := _pick_template(templates, node.get("types", []), used_templates, rng)
        if template.is_empty():
            return {"success": false, "reason": "no_compatible_handcrafted_room", "node": str(node.get("key", "")), "layout": []}
        var key := str(node.get("key", "room"))
        var room := template.duplicate(true)
        room["id"] = "hy_%02d_%s" % [layout.size() + 1, key]
        room["template_id"] = str(template.get("id", ""))
        room["graph_key"] = key
        room["depth"] = int(node.get("depth", template.get("depth", 1)))
        room["palier"] = room["depth"]
        room["connections"] = []
        room["hand_authored_geometry"] = true
        room["geometry_policy"] = "immutable_authored"
        room["immutable_staging"] = bool(node.get("immutable", false))
        room["secret"] = bool(node.get("secret", template.get("secret", false)))
        room["discovered"] = not bool(room["secret"])
        room["map_visible"] = key == "entry"
        room["visited"] = false
        room["cleared"] = false
        room["room_state"] = "intact" if bool(room["immutable_staging"]) else str(room_states[rng.randi_range(0, room_states.size() - 1)])
        room["variant"] = _pick_string(template.get("variant_pool", ["standard"]), rng, "standard")
        room["hazards"] = []
        var hazard_pool: Array = template.get("hazard_pool", [])
        if not hazard_pool.is_empty() and not bool(room["immutable_staging"]):
            room["hazards"].append(_pick_string(hazard_pool, rng, "darkness"))

        if ngplus_active:
            room["ngplus_cycle"] = EndgameState.active_cycle
            room["ngplus_profile"] = ngplus_profile
            room["ngplus_world_variant"] = ngplus_world_variant
            room["ngplus_variant"] = ngplus_variant
            if ngplus_variant != "":
                room["variant"] = "%s:%s" % [str(room["variant"]), ngplus_variant]
            # Les dangers NG+ enrichissent une salle existante ; ils ne remplacent
            # jamais une géométrie ou une mise en scène authored.
            if not bool(room["immutable_staging"]) and not ngplus_hazards.is_empty() and rng.randf() <= 0.35:
                var extra_hazard := _pick_string(ngplus_hazards, rng, "")
                if extra_hazard != "" and not room["hazards"].has(extra_hazard):
                    room["hazards"].append(extra_hazard)

        # La Rémanence est projetée après la sélection de la salle : elle peut conserver
        # cadavres, cicatrices et états de route sans jamais fabriquer ni remplacer la géométrie authored.
        var persistence_context: Dictionary = context.duplicate(true)
        persistence_context["dungeon_id"] = dungeon_id
        persistence_context["zone_id"] = str(context.get("zone_id", dungeon_id))
        persistence_context["region_id"] = str(context.get("region_id", dungeon_id))
        persistence_context["device_profile"] = str(context.get("device_profile", "mobile"))
        var persistence_result: Dictionary = room_persistence_assembler.call("assemble_room", room, {}, persistence_context)
        if bool(persistence_result.get("ok", false)):
            room = persistence_result.get("room", room)

        selected_by_key[key] = room
        used_templates.append(str(template.get("id", "")))
        layout.append(room)

    for edge_value: Variant in recipe.get("edges", []):
        var edge: Array = edge_value
        if edge.size() != 2:
            continue
        var from_key := str(edge[0])
        var to_key := str(edge[1])
        if not selected_by_key.has(from_key) or not selected_by_key.has(to_key):
            continue
        var source: Dictionary = selected_by_key[from_key]
        var target: Dictionary = selected_by_key[to_key]
        _connect(source, target)

    var validation := validate_layout(layout)
    return {
        "success": bool(validation.get("valid", false)),
        "reason": str(validation.get("reason", "ok")),
        "layout": layout,
        "validation": validation,
        "generation_mode": "handcrafted_rooms_controlled_graph",
        "seed": effective_seed,
        "source_seed": seed_value,
        "ngplus": ngplus_context.duplicate(true) if ngplus_active else {"active": false},
        "room_persistence_projection": true
    }

func validate_layout(layout: Array) -> Dictionary:
    if layout.is_empty():
        return {"valid": false, "reason": "empty_layout"}
    var ids: Dictionary = {}
    var entry_id := ""
    var boss_id := ""
    var templates: Array[String] = []
    for room_value: Variant in layout:
        var room: Dictionary = room_value
        var room_id := str(room.get("id", ""))
        if room_id == "" or ids.has(room_id):
            return {"valid": false, "reason": "invalid_or_duplicate_room_id"}
        if not bool(room.get("hand_authored_geometry", false)):
            return {"valid": false, "reason": "non_authored_geometry"}
        ids[room_id] = room
        if str(room.get("graph_key", "")) == "entry":
            entry_id = room_id
        if str(room.get("graph_key", "")) == "boss":
            boss_id = room_id
        if not bool(room.get("secret", false)):
            var template_id := str(room.get("template_id", ""))
            if templates.has(template_id):
                return {"valid": false, "reason": "duplicate_required_template"}
            templates.append(template_id)
    if entry_id == "" or boss_id == "":
        return {"valid": false, "reason": "missing_entry_or_boss"}
    for room_value: Variant in layout:
        var room: Dictionary = room_value
        for target_value: Variant in room.get("connections", []):
            if not ids.has(str(target_value)):
                return {"valid": false, "reason": "unknown_connection"}
    if not _has_path(ids, entry_id, boss_id):
        return {"valid": false, "reason": "objective_unreachable"}
    if not _has_path(ids, boss_id, entry_id):
        return {"valid": false, "reason": "physical_retreat_unreachable"}
    return {
        "valid": true,
        "reason": "ok",
        "entry_id": entry_id,
        "boss_id": boss_id,
        "ash_route_supported": true,
        "physical_retreat_supported": true
    }

func _pick_template(templates: Array, allowed_types: Array, used: Array[String], rng: RandomNumberGenerator) -> Dictionary:
    var candidates: Array = []
    for template_value: Variant in templates:
        var template: Dictionary = template_value
        if not allowed_types.has(str(template.get("type", ""))):
            continue
        if used.has(str(template.get("id", ""))):
            continue
        candidates.append(template)
    if candidates.is_empty():
        return {}
    return candidates[rng.randi_range(0, candidates.size() - 1)]

func _pick_string(values: Array, rng: RandomNumberGenerator, fallback: String) -> String:
    if values.is_empty():
        return fallback
    return str(values[rng.randi_range(0, values.size() - 1)])

func _connect(source: Dictionary, target: Dictionary) -> void:
    var source_id := str(source.get("id", ""))
    var target_id := str(target.get("id", ""))
    var source_connections: Array = source.get("connections", [])
    var target_connections: Array = target.get("connections", [])
    if not source_connections.has(target_id):
        source_connections.append(target_id)
    if not target_connections.has(source_id):
        target_connections.append(source_id)
    source["connections"] = source_connections
    target["connections"] = target_connections

func _has_path(ids: Dictionary, start_id: String, target_id: String) -> bool:
    var pending: Array[String] = [start_id]
    var visited: Array[String] = []
    while not pending.is_empty():
        var current: String = pending.pop_front()
        if current == target_id:
            return true
        if visited.has(current):
            continue
        visited.append(current)
        var room: Dictionary = ids.get(current, {})
        for next_value: Variant in room.get("connections", []):
            var next_id := str(next_value)
            if not visited.has(next_id):
                pending.append(next_id)
    return false

func _catalog(path: String) -> Dictionary:
    if catalog_cache.has(path):
        return catalog_cache[path]
    var loaded := _load_dictionary(path)
    catalog_cache[path] = loaded
    return loaded

func _load_dictionary(path: String) -> Dictionary:
    if path == "" or not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
