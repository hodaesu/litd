extends "res://scripts/core/mobile_touch_smoke_test.gd"

# Le nouvel écran d'expédition nomme explicitement la destination du bouton.
# Le smoke tactile conserve les mêmes gestes et dimensions, mais cible ce libellé.

func _run_device_profile() -> void:
    EndgameState.reset_profile_progress()
    GameState.reset_new_game()
    CampaignState.reset_new_game()
    EquipmentManager.reset_new_game(8101)
    CreatureManager.reset_new_game(8102)
    AshlandsRuntime.reset_world_progression()
    if ExpeditionManager.expedition_active:
        ExpeditionManager.return_to_hub("mobile_touch_smoke_reset")
    ExpeditionManager.reset_to_full_resupply()
    AshlandsCombatBridge.active = false
    AshlandsCombatBridge.encounter_id = ""
    AshlandsCombatBridge.encounter_type = ""

    get_tree().root.size = active_window_size
    await _frames(3)

    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    _check(error == OK, "Main scene must load on %s" % active_device_name)
    _check(await _wait_for_main(), "Main scene must become active on %s" % active_device_name)
    await _frames(4)

    _check(GameState.current_screen == "title", "Title must be visible on %s" % active_device_name)
    await _audit_visible_buttons("title")
    _check(await _touch_button("NOUVELLE PARTIE", true), "Touch must activate Nouvelle Partie on %s" % active_device_name)
    _check(GameState.current_screen == "sanctuary", "Touch Nouvelle Partie must open Sanctuary on %s" % active_device_name)

    await _audit_visible_buttons("sanctuary")
    _check(_count_buttons("INFIRMERIE\nSoins et blessures", true) == 1, "Sanctuary must expose exactly one Infirmary button on %s" % active_device_name)
    _check(_count_buttons("CHAPELLE\nPeur, folie et espoir", true) == 1, "Sanctuary must expose exactly one Chapel button on %s" % active_device_name)
    _check(_count_buttons("TAVERNE\nRecruter et rumeurs", true) == 1, "Sanctuary must expose exactly one Tavern button on %s" % active_device_name)
    _check(_count_buttons("MÉMORIAL\nHéros tombés", true) == 1, "Sanctuary must expose exactly one Memorial button on %s" % active_device_name)
    _check(await _touch_button("LA PORTE", false), "Touch must activate La Porte on %s" % active_device_name)
    _check(GameState.current_screen == "expedition", "Touch La Porte must open expedition screen on %s" % active_device_name)

    await _audit_visible_buttons("expedition")
    _check(await _touch_button("RETOUR AU SANCTUAIRE", true), "Touch must return from expedition setup on %s" % active_device_name)
    _check(GameState.current_screen == "sanctuary", "Touch return must restore Sanctuary on %s" % active_device_name)

    for screen_name_value in ["company", "market", "creatures", "infirmary", "chapel", "tavern", "memorial"]:
        var screen_name := str(screen_name_value)
        GameState.request_screen(screen_name)
        await _frames(4)
        _check(GameState.current_screen == screen_name, "%s screen must render on %s" % [screen_name, active_device_name])
        await _audit_visible_buttons(screen_name)

    GameState.request_screen("sanctuary")
    await _frames(3)
    var main := get_tree().current_scene
    _check(main != null and main.name == "Main", "Main must still own UI before mobile combat on %s" % active_device_name)
    if main == null or main.name != "Main":
        return

    main.call("start_random_battle")
    await _frames(5)
    _check(GameState.current_screen == "combat", "Prototype combat must render for touch audit on %s" % active_device_name)
    await _audit_visible_buttons("combat")
    _check(await _touch_button("GARDE", true), "Touch must activate GARDE in combat on %s" % active_device_name)
    _check(_log_contains("se met en garde"), "Combat touch must execute GARDE on %s" % active_device_name)
