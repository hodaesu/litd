extends SceneTree

const CONTRACT_PATH := "res://data/visual_vertical_slice.json"
const OUTPUT_DIR := "res://reports/vertical_slice/captures"

func _initialize() -> void:
    call_deferred("_run_capture")

func _run_capture() -> void:
    var contract := JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH)) as Dictionary
    var final_path := str(contract.get("slice", {}).get("final_scene_target", ""))
    var proxy_path := str(contract.get("slice", {}).get("target_scene", ""))
    var scene_path := final_path if ResourceLoader.exists(final_path) else proxy_path
    if not ResourceLoader.exists(scene_path):
        push_error("Vertical slice scene missing")
        quit(2)
        return
    var packed := load(scene_path) as PackedScene
    var instance := packed.instantiate()
    root.add_child(instance)
    await process_frame
    await process_frame
    await process_frame
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    var views := ["combat_wide", "darius_readability", "ghoul_readability", "warm_cold_balance", "attack_telegraph"]
    var files: Array[String] = []
    var camera_nodes := instance.find_children("*", "Camera3D", true, false)
    var camera: Camera3D = camera_nodes[0] as Camera3D if not camera_nodes.is_empty() else null
    var base_transform := camera.global_transform if camera != null else Transform3D.IDENTITY
    for index in range(views.size()):
        if camera != null:
            camera.global_transform = base_transform
            if index == 1:
                camera.translate_object_local(Vector3(-0.55, 0.0, 0.0))
            elif index == 2:
                camera.translate_object_local(Vector3(0.55, 0.0, 0.0))
            elif index == 3:
                camera.translate_object_local(Vector3(0.0, 0.15, 0.15))
            elif index == 4:
                camera.fov = maxf(32.0, camera.fov - 5.0)
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        if image == null or image.is_empty():
            push_error("Unable to capture rendered viewport")
            quit(3)
            return
        var rel := OUTPUT_DIR + "/" + views[index] + ".png"
        image.save_png(ProjectSettings.globalize_path(rel))
        files.append(rel.trim_prefix("res://"))
    var manifest := {"version": 1, "scene": scene_path, "views": views, "files": files}
    var file := FileAccess.open(OUTPUT_DIR + "/manifest.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(manifest, "  ") + "\n")
    print("VISUAL_SLICE_CAPTURE_OK")
    quit()
