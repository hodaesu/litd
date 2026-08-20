extends Node

func _ready() -> void:
    var contract := JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_vertical_slice.json")) as Dictionary
    assert(contract.get("version") == 2)

    var darius := Node3D.new()
    darius.name = "DariusProxy"
    add_child(darius)
    var ghoul := Node3D.new()
    ghoul.name = "HungryGhoulProxy"
    add_child(ghoul)

    var runtime := VisualSliceRuntime.new()
    add_child(runtime)
    runtime.configure(darius, ghoul, null)
    runtime.start_combat()
    assert(runtime.combat_active)
    assert(runtime.darius_hp == runtime.darius_max_hp)
    assert(runtime.ghoul_hp == runtime.ghoul_max_hp)

    runtime.darius_light_attack()
    assert(runtime.ghoul_hp == runtime.ghoul_max_hp - 18)
    runtime.darius_guard()
    runtime.ghoul_claw()
    assert(runtime.darius_hp == runtime.darius_max_hp - 6)
    runtime.darius_heavy_attack()
    assert(runtime.ghoul_controller.current_state in ["stagger", "death"])

    var loader := ValidatedGLBLoader.new()
    add_child(loader)
    var proxy := Node3D.new()
    add_child(proxy)
    var kept := loader.replace_proxy("darius", proxy, self)
    assert(kept == proxy)

    var anim := VisualSliceAnimationController.new()
    add_child(anim)
    anim.configure("darius", darius, contract["characters"]["darius"]["animation_minimum"])
    assert(anim.set_state("guard"))
    assert(anim.current_state == "guard")
    assert(not anim.set_state("dance"))

    print("VISUAL_SLICE_RUNTIME_SMOKE_OK")
    get_tree().quit()
