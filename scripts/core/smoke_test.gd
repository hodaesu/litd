extends SceneTree

func _initialize() -> void:
    var failures: Array[String] = []
    var required_files := [
        "res://data/classes.json",
        "res://data/races.json",
        "res://data/heroes.json",
        "res://data/enemies.json",
        "res://data/skills.json",
        "res://data/levels/terre_des_cendres_blockout_manifest.json",
        "res://data/levels/ashlands_layout_profiles.json",
        "res://data/levels/ashlands_zone_blueprints.json",
        "res://data/levels/ashlands_survival_rules.json",
        "res://data/levels/ashlands_minibosses.json",
        "res://scripts/core/expedition_manager.gd",
        "res://scripts/world/ashlands_zone_runtime.gd",
        "res://scripts/world/ashlands_miniboss_director.gd",
        "res://scripts/world/ashlands_scene_router.gd",
        "res://scripts/world/ashlands_blockout_builder.gd",
        "res://scripts/world/ashlands_layout_generator.gd",
        "res://scripts/world/ash_volume.gd",
        "res://scripts/world/resource_node.gd",
        "res://scripts/world/corpse_harvest.gd",
        "res://scripts/world/campfire_interaction.gd",
        "res://scripts/world/zone_transition_gate.gd",
        "res://scripts/world/shortcut_gate.gd",
        "res://scripts/world/encounter_trigger.gd",
        "res://scripts/world/exploration_party_controller.gd",
        "res://scripts/world/isometric_camera_rig.gd",
        "res://scenes/world/terre_des_cendres/exploration_party_placeholder.tscn",
        "res://scenes/world/terre_des_cendres/ashlands_hud.tscn"
    ]
    for path in required_files:
        if not FileAccess.file_exists(path):
            failures.append("Missing: " + path)
        elif path.ends_with(".gd") or path.ends_with(".tscn"):
            if ResourceLoader.load(path) == null:
                failures.append("Cannot load: " + path)

    var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/terre_des_cendres_blockout_manifest.json"))
    if typeof(manifest) != TYPE_DICTIONARY:
        failures.append("Invalid Ashlands manifest JSON")
    else:
        var zones: Array = manifest.get("zones", [])
        if zones.size() != 15:
            failures.append("Ashlands must contain exactly 15 zones")
        for zone in zones:
            var id_value := str(zone.get("id", ""))
            var filename := id_value + ".tscn"
            if id_value == "zone_07_cimetiere":
                filename = "zone_07_cimetiere_blockout.tscn"
            var scene_path := "res://scenes/world/terre_des_cendres/" + filename
            if not ResourceLoader.exists(scene_path):
                failures.append("Missing zone scene: " + scene_path)
            elif ResourceLoader.load(scene_path) == null:
                failures.append("Cannot load zone scene: " + scene_path)

        var layout_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/ashlands_layout_profiles.json"))
        if typeof(layout_data) != TYPE_DICTIONARY:
            failures.append("Invalid Ashlands layout profiles JSON")
        else:
            var profiles: Dictionary = layout_data.get("zones", {})
            var rules: Dictionary = layout_data.get("profile_rules", {})
            for zone in zones:
                var zone_id := str(zone.get("id", ""))
                if not profiles.has(zone_id):
                    failures.append("Missing layout profile: " + zone_id)
                    continue
                var profile_name := str(profiles[zone_id].get("profile", ""))
                if not rules.has(profile_name):
                    failures.append("Missing layout rule: " + profile_name)

    if failures.is_empty():
        print("SMOKE_TEST_OK")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
