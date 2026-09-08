extends "res://scripts/core/mobile_touch_smoke_test.gd"

# Le nouvel écran d'expédition nomme explicitement la destination du bouton.
# Le smoke tactile conserve les mêmes gestes et dimensions, mais cible ce libellé.

const TACTICAL_UI_SCENE := preload("res://scenes/veilleurs/v06_tactical_combat.tscn")

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
    # Garde est désormais la compétence équipée du slot 3 et son bouton affiche
    # aussi ses rangs autorisés. Le test tactile cible donc le libellé visible actuel.
    _check(await _touch_button("3 · Garde", false), "Touch must activate equipped Guard in combat on %s" % active_device_name)
    _check(_log_contains("se met en garde"), "Combat touch must execute equipped Guard on %s" % active_device_name)

    await _audit_v09_mobile_contract()

func _audit_v09_mobile_contract() -> void:
    var original_text_scale := GameSettings.text_scale
    var original_ui_scale := GameSettings.ui_scale
    GameSettings.set_text_scale(1.4)
    GameSettings.set_ui_scale(1.4)
    await _frames(3)

    var tactical := TACTICAL_UI_SCENE.instantiate() as VeilleursTacticalUI
    _check(tactical != null, "v0.9 tactical UI must instantiate on %s" % active_device_name)
    if tactical == null:
        GameSettings.set_text_scale(original_text_scale)
        GameSettings.set_ui_scale(original_ui_scale)
        return
    get_tree().root.add_child(tactical)
    tactical.size = Vector2(720, 540)
    await _frames(2)

    tactical.bind_snapshot({
        "runtime": {
            "round": 1,
            "grid": {
                "0:0": "ENT_WATCHER_TEST",
                "1:0": "ENT_ENEMY_ALPHA",
                "2:0": "ENT_ENEMY_BETA"
            },
            "combatants": {
                "ENT_WATCHER_TEST": {"name": "Nayra", "team": "watcher", "hp": 40, "max_hp": 40, "level": 1},
                "ENT_ENEMY_ALPHA": {"name": "Goule alpha", "team": "enemy", "hp": 18, "max_hp": 20, "level": 1},
                "ENT_ENEMY_BETA": {"name": "Goule bêta", "team": "enemy", "hp": 16, "max_hp": 20, "level": 1}
            }
        }
    })
    _check(tactical.touch_contract_ok(), "v0.9 tactical touch targets must remain >=44 px on %s" % active_device_name)

    var beta_button: Button = null
    for button: Button in tactical.cell_buttons:
        if str(button.get_meta("occupant", "")) == "ENT_ENEMY_BETA":
            beta_button = button
            break
    _check(beta_button != null, "v0.9 tactical grid must expose the second enemy on %s" % active_device_name)
    if beta_button != null:
        beta_button.pressed.emit()
        await _frames(2)
        _check(tactical.selected_target == "ENT_ENEMY_BETA", "first touch must select the intended enemy on %s" % active_device_name)
        _check(not CombatantInspectionUI.detail_open, "first touch on a new target must not steal selection on %s" % active_device_name)
        beta_button.pressed.emit()
        await _frames(3)
        _check(CombatantInspectionUI.detail_open, "second touch on selected combatant must open inspection on %s" % active_device_name)

    if CombatantInspectionUI.detail_open:
        _check(is_instance_valid(CombatantInspectionUI.detail_frame), "inspection detail frame must exist on %s" % active_device_name)
        if is_instance_valid(CombatantInspectionUI.detail_frame):
            var viewport_size := get_viewport().get_visible_rect().size
            var detail_rect := CombatantInspectionUI.detail_frame.get_global_rect()
            _check(detail_rect.position.x >= -1.0 and detail_rect.position.y >= -1.0, "inspection must stay inside top/left bounds at ui_scale 1.4 on %s" % active_device_name)
            _check(detail_rect.end.x <= viewport_size.x + 1.0 and detail_rect.end.y <= viewport_size.y + 1.0, "inspection must stay inside viewport at ui_scale 1.4 on %s" % active_device_name)
        if CombatantInspectionUI.detail_content.get_child_count() > 0:
            var title_label := CombatantInspectionUI.detail_content.get_child(0) as Label
            _check(title_label != null and title_label.get_theme_font_size("font_size") >= 34, "text_scale 1.4 must visibly enlarge inspection title on %s" % active_device_name)
        CombatantInspectionUI.close_detail()

    tactical.queue_free()
    GameSettings.set_text_scale(original_text_scale)
    GameSettings.set_ui_scale(original_ui_scale)
    await _frames(2)
