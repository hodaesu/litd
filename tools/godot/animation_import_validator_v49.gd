extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    var manifest_path := "data/godot/animation_import_manifest_v49.json"
    var index := args.find("--manifest")
    if index >= 0 and index + 1 < args.size():
        manifest_path = args[index + 1]

    var file := FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        push_error("V49: impossible d'ouvrir le manifeste: %s" % manifest_path)
        quit(2)
        return

    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("V49: manifeste JSON invalide")
        quit(2)
        return

    var validated := 0
    for bundle in parsed.get("bundles", []):
        validated += _validate_bundle(bundle)

    if not failures.is_empty():
        for failure in failures:
            push_error(failure)
        quit(2)
        return

    print("ANIMATION_IMPORT_V49_OK bundles=%d clips=%d" % [parsed.get("bundle_count", 0), validated])
    quit(0)


func _validate_bundle(bundle: Dictionary) -> int:
    var bundle_id := str(bundle.get("bundle_id", ""))
    var resource_path := str(bundle.get("resource_path", ""))
    if not ResourceLoader.exists(resource_path):
        failures.append("V49 missing GLB %s -> %s" % [bundle_id, resource_path])
        return 0

    var packed = load(resource_path)
    if packed == null or not (packed is PackedScene):
        failures.append("V49 invalid PackedScene %s -> %s" % [bundle_id, resource_path])
        return 0

    var root: Node = packed.instantiate()
    var found := {}
    _collect_animations(root, found)
    root.free()

    var expected: Array = bundle.get("expected_animations", [])
    for animation_name in expected:
        if not found.has(str(animation_name)):
            failures.append("V49 missing animation %s in %s" % [str(animation_name), bundle_id])
    return expected.size()


func _collect_animations(node: Node, found: Dictionary) -> void:
    if node is AnimationPlayer:
        var player := node as AnimationPlayer
        for library_name in player.get_animation_library_list():
            var library := player.get_animation_library(library_name)
            if library == null:
                continue
            for animation_name in library.get_animation_list():
                found[str(animation_name)] = true
    for child in node.get_children():
        _collect_animations(child, found)
