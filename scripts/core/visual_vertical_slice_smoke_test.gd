extends Node

var failures: Array[String] = []

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    var packed := load("res://scenes/visual/visual_vertical_slice_proxy.tscn") as PackedScene
    _check(packed != null, "visual vertical slice proxy scene must load")
    if packed == null:
        _finish()
        return

    var instance := packed.instantiate() as Node3D
    add_child(instance)
    await get_tree().process_frame

    _check(instance.get_node_or_null("DariusProxy") != null, "Darius proxy must exist")
    _check(instance.get_node_or_null("HungryGhoulProxy") != null, "Hungry Ghoul proxy must exist")
    _check(instance.get_node_or_null("AshlandsArenaProxy") != null, "Ashlands arena proxy must exist")
    _check(instance.get_node_or_null("CombatCamera") != null, "combat camera must exist")
    _check(instance.get_node_or_null("CoolMoonKey") != null, "cool key light must exist")
    _check(instance.get_node_or_null("WarmLanternAccent") != null, "warm accent light must exist")

    var darius := instance.get_node_or_null("DariusProxy") as Node3D
    var ghoul := instance.get_node_or_null("HungryGhoulProxy") as Node3D
    if darius != null:
        _check(darius.get_node_or_null("Shield") != null, "Darius silhouette must include shield")
        _check(darius.get_node_or_null("Lantern") != null, "Darius silhouette must include lantern")
        _check(darius.get_node_or_null("LamellarChest") != null, "Darius silhouette must include lamellar chest mass")
    if ghoul != null:
        _check(ghoul.get_node_or_null("ArmLeft") != null and ghoul.get_node_or_null("ArmRight") != null, "Ghoul silhouette must include elongated arms")
        _check(ghoul.get_node_or_null("ClawLeft") != null and ghoul.get_node_or_null("ClawRight") != null, "Ghoul silhouette must include claws")

    _check(ResourceLoader.exists("res://shaders/litd_cel.gdshader"), "LITD cel shader must exist")
    _check(ResourceLoader.exists("res://shaders/litd_outline.gdshader"), "LITD outline shader must exist")

    var contract_text := FileAccess.get_file_as_string("res://data/visual_vertical_slice.json")
    var parsed: Variant = JSON.parse_string(contract_text)
    _check(parsed is Dictionary, "visual vertical slice contract must be valid JSON")
    if parsed is Dictionary:
        var contract: Dictionary = parsed
        _check(bool(contract.get("reference_rules", {}).get("art_bible_is_authoritative", false)), "Art Bible must remain authoritative")
        _check(str(contract.get("slice", {}).get("hero_id", "")) == "darius", "slice hero must be Darius")
        _check(str(contract.get("slice", {}).get("enemy_id", "")) == "enemy_01_goule_affamee", "slice enemy must be Hungry Ghoul")

    instance.queue_free()
    await get_tree().process_frame
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VISUAL_VERTICAL_SLICE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VISUAL_VERTICAL_SLICE_SMOKE: " + failure)
    print("VISUAL_VERTICAL_SLICE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
