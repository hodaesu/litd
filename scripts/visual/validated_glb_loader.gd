class_name ValidatedGLBLoader
extends Node

const CONTRACT_PATH := "res://data/visual_vertical_slice.json"

signal asset_loaded(asset_id: String, instance: Node)
signal asset_rejected(asset_id: String, reasons: PackedStringArray)

var contract: Dictionary = {}

func _ready() -> void:
    contract = _load_json(CONTRACT_PATH)

func load_validated(asset_id: String) -> Node:
    if contract.is_empty():
        contract = _load_json(CONTRACT_PATH)
    var ingest: Dictionary = contract.get("asset_ingest", {})
    var roots: Dictionary = ingest.get("roots", {})
    var path := str(roots.get(asset_id, ""))
    var reasons := PackedStringArray()
    if path.is_empty():
        reasons.append("asset path not declared")
    elif not ResourceLoader.exists(path):
        reasons.append("asset file missing: " + path)
    if not reasons.is_empty():
        asset_rejected.emit(asset_id, reasons)
        return null
    var resource := load(path)
    if not (resource is PackedScene):
        reasons.append("GLB did not import as PackedScene")
        asset_rejected.emit(asset_id, reasons)
        return null
    var instance := (resource as PackedScene).instantiate()
    reasons = validate_instance(asset_id, instance)
    if not reasons.is_empty():
        instance.queue_free()
        asset_rejected.emit(asset_id, reasons)
        return null
    asset_loaded.emit(asset_id, instance)
    return instance

func validate_instance(asset_id: String, instance: Node) -> PackedStringArray:
    var reasons := PackedStringArray()
    if instance == null:
        reasons.append("instance is null")
        return reasons
    if asset_id in ["darius", "enemy_01_goule_affamee"]:
        var skeleton := _find_first(instance, "Skeleton3D") as Skeleton3D
        if skeleton == null:
            reasons.append("character has no Skeleton3D")
        else:
            var required_bones: Array = contract.get("asset_ingest", {}).get("required_bones", [])
            for bone_name in required_bones:
                if skeleton.find_bone(str(bone_name)) < 0:
                    reasons.append("missing bone: " + str(bone_name))
        var required_sockets: Array = contract.get("asset_ingest", {}).get("required_sockets", [])
        for socket_name in required_sockets:
            if not _has_named_descendant(instance, str(socket_name)):
                reasons.append("missing socket: " + str(socket_name))
        var animation_player := _find_first(instance, "AnimationPlayer") as AnimationPlayer
        if animation_player == null:
            reasons.append("character has no AnimationPlayer")
        else:
            var required_animations: Array = contract.get("characters", {}).get(asset_id, {}).get("animation_minimum", [])
            for animation_name in required_animations:
                if _resolve_clip(animation_player, str(animation_name)).is_empty():
                    reasons.append("missing animation: " + str(animation_name))
    var meshes := _collect_by_class(instance, "MeshInstance3D")
    if meshes.is_empty():
        reasons.append("asset has no MeshInstance3D")
    return reasons

func replace_proxy(asset_id: String, proxy: Node, parent: Node) -> Node:
    var instance := load_validated(asset_id)
    if instance == null:
        return proxy
    parent.add_child(instance)
    if proxy != null:
        if proxy is Node3D and instance is Node3D:
            (instance as Node3D).transform = (proxy as Node3D).transform
        proxy.queue_free()
    return instance

func _resolve_clip(player: AnimationPlayer, state: String) -> StringName:
    var candidates := [state, "default/" + state, "Animation/" + state]
    for candidate in candidates:
        var name := StringName(candidate)
        if player.has_animation(name):
            return name
    return &""

func _find_first(root: Node, class_name_value: String) -> Node:
    if root.is_class(class_name_value):
        return root
    for child in root.get_children():
        var found := _find_first(child, class_name_value)
        if found != null:
            return found
    return null

func _collect_by_class(root: Node, class_name_value: String) -> Array[Node]:
    var found: Array[Node] = []
    if root.is_class(class_name_value):
        found.append(root)
    for child in root.get_children():
        found.append_array(_collect_by_class(child, class_name_value))
    return found

func _has_named_descendant(root: Node, target_name: String) -> bool:
    if root.name == target_name:
        return true
    for child in root.get_children():
        if _has_named_descendant(child, target_name):
            return true
    return false

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
