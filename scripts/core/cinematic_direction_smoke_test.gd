extends Node

const RUNTIME := preload("res://scripts/cinematics/cinematic_direction_runtime.gd")


func run() -> void:
    var runtime := RUNTIME.new()
    assert(runtime.load_contracts(), "cinematic direction contracts must load")
    assert(runtime.scene_ids().size() == 6, "all six demo staging scenes must be registered")
    assert(not runtime.physical_profile("darius").is_empty(), "Darius physical profile missing")
    assert(not runtime.physical_profile("hungry_ghoul").is_empty(), "Hungry Ghoul physical profile missing")
    assert(not runtime.proxemic_pair("darius:aurelien").is_empty(), "core proxemic pair missing")
    assert(runtime.nonverbal_channels().has("stillness"), "stillness must be a nonverbal channel")
    assert(runtime.camera_move_is_authored("dolly_in"), "authored camera move missing")
    assert(not runtime.camera_move_is_authored("orbit"), "generic orbit must remain forbidden")
    assert(not runtime.dialogue_scene("demo_darius_ghoul_01").is_empty(), "dialogue must resolve to staged scene")
    for scene_id: String in runtime.scene_ids():
        assert(runtime.validate_scene_handoff(scene_id), "invalid cinematic/gameplay handoff: %s" % scene_id)
    print("CINEMATIC_DIRECTION_RUNTIME_SMOKE_OK")
    get_tree().quit()
