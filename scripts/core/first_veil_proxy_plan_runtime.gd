extends RefCounted

# Résout le plan spatial proxy du premier donjon. Cette couche est volontairement
# indépendante des meshes : les mêmes dimensions, ports et ancres servent au
# prototype Godot puis au remplacement par les modules Blender définitifs.

const PLAN_PATH := "res://data/roguelike/first_veil_proxy_plan.json"

var plan: Dictionary = {}

func _init() -> void:
    _load_plan()

func _load_plan() -> void:
    plan = {}
    if not FileAccess.file_exists(PLAN_PATH):
        push_error("FirstVeilProxyPlanRuntime: plan proxy introuvable")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("FirstVeilProxyPlanRuntime: plan proxy invalide")
        return
    plan = parsed

func plan_for_room(room_id: String) -> Dictionary:
    for value in plan.get("rooms", []):
        var room_plan: Dictionary = value
        if str(room_plan.get("id", "")) == room_id:
            return room_plan.duplicate(true)
    return {}

func resolved_room(room: Dictionary, dungeon_layout: Array) -> Dictionary:
    if room.is_empty():
        return {}
    var room_id: String = str(room.get("id", ""))
    var room_plan: Dictionary = plan_for_room(room_id)
    if room_plan.is_empty():
        return {}
    var result: Dictionary = room.duplicate(true)
    result["proxy"] = room_plan.duplicate(true)
    result["dimensions_m"] = _dimensions(room_plan)
    result["anchors"] = _resolved_anchors(room_plan)
    result["ports"] = _resolved_ports(room, room_plan, dungeon_layout)
    result["blender_module_id"] = str(room_plan.get("module", ""))
    result["production_phase"] = int(room_plan.get("phase", 5))
    return result

func _dimensions(room_plan: Dictionary) -> Vector3:
    var values: Array = room_plan.get("dimensions", [12.0, 10.0, 5.0])
    if values.size() < 3:
        return Vector3(12.0, 5.0, 10.0)
    return Vector3(float(values[0]), float(values[2]), float(values[1]))

func _resolved_anchors(room_plan: Dictionary) -> Dictionary:
    var dimensions: Vector3 = _dimensions(room_plan)
    var profile: Dictionary = plan.get("anchor_profile", {})
    var result: Dictionary = {}
    for key_value in profile.keys():
        var key: String = str(key_value)
        var raw: Array = profile.get(key, [])
        if raw.size() < 3:
            continue
        # X et Z sont des proportions de la largeur/longueur. Y est exprimé en
        # mètres sauf camera_focus, dont la valeur verticale est proportionnelle.
        var y_value: float = float(raw[1])
        if key == "camera_focus":
            y_value *= dimensions.y
        result[key] = Vector3(
            float(raw[0]) * dimensions.x,
            y_value,
            float(raw[2]) * dimensions.z
        )
    return result

func _resolved_ports(room: Dictionary, room_plan: Dictionary, dungeon_layout: Array) -> Array:
    var result: Array = []
    var connections: Array = room.get("connections", [])
    var sides: Array = room_plan.get("port_sides", ["north", "east", "south", "west"])
    var dimensions: Vector3 = _dimensions(room_plan)
    for index in range(connections.size()):
        var target_id: String = str(connections[index])
        var side: String = str(sides[index % maxi(1, sides.size())])
        var target: Dictionary = _room_from_layout(dungeon_layout, target_id)
        var connector: String = _connector_type(room, target)
        result.append({
            "target_room_id": target_id,
            "side": side,
            "position": _port_position(dimensions, side),
            "connector_type": connector,
            "secret": bool(target.get("secret", false)),
            "target_palier": int(target.get("palier", room.get("palier", 0)))
        })
    return result

func _room_from_layout(layout: Array, room_id: String) -> Dictionary:
    for value in layout:
        var room: Dictionary = value
        if str(room.get("id", "")) == room_id:
            return room
    return {}

func _connector_type(source: Dictionary, target: Dictionary) -> String:
    if bool(source.get("secret", false)) or bool(target.get("secret", false)):
        return "secret_passage"
    if str(source.get("room_role", "")) == "preboss" or str(target.get("room_role", "")) == "boss":
        return "boss_gate"
    var source_palier: int = int(source.get("palier", source.get("depth", 0)))
    var target_palier: int = int(target.get("palier", target.get("depth", source_palier)))
    if source_palier != target_palier:
        return "stairwell"
    return "standard_corridor"

func _port_position(dimensions: Vector3, side: String) -> Vector3:
    var inset: float = 0.05
    match side:
        "north":
            return Vector3(0.0, 0.15, -dimensions.z * 0.5 + inset)
        "south":
            return Vector3(0.0, 0.15, dimensions.z * 0.5 - inset)
        "east":
            return Vector3(dimensions.x * 0.5 - inset, 0.15, 0.0)
        "west":
            return Vector3(-dimensions.x * 0.5 + inset, 0.15, 0.0)
        _:
            return Vector3.ZERO

func interaction_points(room: Dictionary, dungeon_layout: Array) -> Array:
    var resolved: Dictionary = resolved_room(room, dungeon_layout)
    if resolved.is_empty():
        return []
    var anchors: Dictionary = resolved.get("anchors", {})
    var interactions: Array = room.get("interactions", [])
    var anchor_keys: Array[String] = ["interaction_primary", "interaction_secondary", "interaction_tertiary"]
    var result: Array = []
    for index in range(mini(interactions.size(), anchor_keys.size())):
        var key: String = anchor_keys[index]
        result.append({
            "id": "%s_%d" % [str(room.get("id", "room")), index],
            "label": str(interactions[index]),
            "position": anchors.get(key, Vector3.ZERO),
            "anchor": key
        })
    return result

func connector_definition(connector_type: String) -> Dictionary:
    return (plan.get("connectors", {}) as Dictionary).get(connector_type, {}).duplicate(true)

func production_order() -> Array:
    return plan.get("production_order", []).duplicate(true)

func room_count() -> int:
    return (plan.get("rooms", []) as Array).size()

func all_room_ids() -> Array[String]:
    var result: Array[String] = []
    for value in plan.get("rooms", []):
        var room_plan: Dictionary = value
        result.append(str(room_plan.get("id", "")))
    return result
