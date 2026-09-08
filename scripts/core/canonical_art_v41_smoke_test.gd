extends Node

const MAIN_SCENE := "res://scenes/Main.tscn"
var failures: Array[String] = []

func run() -> void:
    var registry := CanonicalArtRegistry.new()
    var manifest := registry.manifest()

    _check(registry.version() == 41, "Art manifest must expose v41")
    _check(not manifest.is_empty(), "Art manifest must load")
    _check(bool(manifest.get("gameplay_guarantee", {}).has("must_not_change")), "Art contract must explicitly protect gameplay rules")

    for color_token in ["ash_black", "worn_bronze", "bone_text", "blood_red", "ember_amber"]:
        _check(str(registry.token("colors", color_token, "")) != "", "Missing canonical color token: %s" % color_token)

    for screen_name in ["title", "sanctuary", "navigation", "company", "hero_profile", "inventory", "skills", "bestiary", "expedition", "combat", "contextual", "results_options", "options"]:
        _check(not registry.screen_contract(screen_name).is_empty(), "Missing screen composition contract: %s" % screen_name)

    var sanctuary := registry.screen_contract("sanctuary")
    _check(str(sanctuary.get("ui_rule", "")) == "location_names_are_the_click_targets", "Sanctuary art contract must preserve direct-name hotspots")

    var f3 := registry.functional_state_contract("F3")
    var f4 := registry.functional_state_contract("F4")
    _check(bool(f3.get("weapon_reassign_if_possible", false)), "F3 must request weapon reassignment when possible")
    _check(not bool(f4.get("segment_visible", true)), "F4 must remove the destroyed/amputated segment visually")
    _check(bool(f4.get("show_absence_or_stump", false)), "F4 must show a real absence/stump")
    _check(bool(f4.get("silhouette_change", false)), "F4 must change the silhouette")

    var humanoid := registry.morphology_contract("HUMANOID")
    var serpentine := registry.morphology_contract("SERPENTINE_ORGANIC")
    var insectoid := registry.morphology_contract("INSECTOID_ORGANIC")
    _check(str(humanoid.get("weapon_reassignment", "")) == "opposite_functional_hand", "Humanoids must transfer a weapon to the opposite functional hand")
    _check(bool(serpentine.get("forbid_humanoid_mannequin", false)), "Serpentine creatures must never use a humanoid anatomy mannequin")
    _check(bool(insectoid.get("forbid_humanoid_mannequin", false)), "Insectoid creatures must never use a humanoid anatomy mannequin")

    var sanctuary_asset := registry.resolve_asset("bg.sanctuary")
    _check(str(sanctuary_asset.get("status", "missing")) in ["placeholder", "final"], "Sanctuary must always resolve to a visible background during the replacement pipeline")
    var future_portrait := registry.resolve_asset("portrait.active_hero", {"entity_id": "future_test_hero"})
    _check(str(future_portrait.get("status", "")) in ["missing", "placeholder", "final"], "Missing future art must degrade safely instead of breaking runtime")

    var serpent_character := {
        "id": "qa_serpent",
        "morphology": "SERPENTINE_ORGANIC"
    }
    var serpent_visual := registry.character_visual_contract(serpent_character, {"functional_state": "F4"})
    _check(str(serpent_visual.get("functional_state", "")) == "F4", "Character visual contract must propagate functional body state")
    _check(str(serpent_visual.get("morphology_contract", {}).get("diagram", "")) == "serpentine", "Character visual contract must preserve real morphology")

    GameState.reset_new_game()
    CampaignState.reset_new_game()
    EquipmentManager.reset_new_game(9411)
    CreatureManager.reset_new_game(9412)
    await _frames(2)

    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must load under v41")
    _check(await _wait_for_main(), "Main must become active under v41")
    await _frames(4)

    var main := get_tree().current_scene
    if main != null and main.name == "Main":
        main.call("show_screen", "sanctuary")
        await _frames(4)
        var marker := main.find_child("CanonicalArtContractV41", true, false)
        _check(marker != null, "Active UI must expose the v41 art contract marker")
        var snapshot: Dictionary = main.call("art_contract_snapshot")
        _check(int(snapshot.get("version", 0)) == 41, "Active Main must report art version 41")
        _check(bool(snapshot.get("gameplay_untouched", false)), "Active Main must declare the art layer gameplay-neutral")
    else:
        _check(false, "Main scene missing after v41 load")

    _finish()

func _wait_for_main(max_frames: int = 180) -> bool:
    for _index in range(max_frames):
        var scene := get_tree().current_scene
        if scene != null and scene.name == "Main":
            return true
        await get_tree().process_frame
    return false

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("CANONICAL_ART_V41_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("CANONICAL_ART_V41_SMOKE: " + failure)
    print("CANONICAL_ART_V41_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
