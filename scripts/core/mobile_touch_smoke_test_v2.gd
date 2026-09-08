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
                "ENT_ENEMY_BETA": {
                    "name": "Goule bêta",
                    "team": "enemy",
                    "hp": 16,
                    "max_hp": 20,
                    "level": 1,
                    "statuses": {"PINNED": {"remaining": 1, "strength": 2}},
                    "mobility_penalty": 6,
                    "body": {
                        "states": {
                            "head": "L0",
                            "torso": "L0",
                            "left_arm": "L0",
                            "right_arm": "L5",
                            "left_leg": "L4",
                            "right_leg": "L0"
                        },
                        "missing_parts": ["right_arm"]
                    }
                }
            }
        }
    })
    _check(tactical.touch_contract_ok(), "v0.9 tactical touch targets must remain >=44 px on %s" % active_device_name)

    var alpha_button: Button = null
    var beta_button: Button = null
    for button: Button in tactical.cell_buttons:
        var occupant := str(button.get_meta("occupant", ""))
        if occupant == "ENT_ENEMY_ALPHA":
            alpha_button = button
        elif occupant == "ENT_ENEMY_BETA":
            beta_button = button
    _check(alpha_button != null, "v0.9 tactical grid must expose the first enemy on %s" % active_device_name)
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
        _check(_tree_text_contains(CombatantInspectionUI.detail_content, "ANATOMIE CRITIQUE : Bras droit — membre perdu"), "inspection must expose a lost body part in readable French on %s" % active_device_name)
        _check(_tree_text_contains(CombatantInspectionUI.detail_content, "Entravé — 1 tour"), "inspection must expose v0.9 runtime statuses on %s" % active_device_name)
        _check(_tree_text_contains(CombatantInspectionUI.detail_content, "Conséquence fonctionnelle : mobilité réduite"), "inspection must expose functional injury consequences on %s" % active_device_name)
        CombatantInspectionUI.close_detail()

    if alpha_button != null and beta_button != null:
        var test_skills: Array[String] = ["Entaille"]
        var emitted_cells: Array[Vector2i] = []
        tactical.tactical_cell_pressed.connect(func(cell: Vector2i) -> void: emitted_cells.append(cell))
        tactical.set_skill_labels(test_skills)
        tactical.set_armed_skill(0)
        tactical.set_targeting_mode(true, ["ENT_ENEMY_ALPHA"], ["ENT_ENEMY_BETA"], false)
        await _frames(2)

        _check(tactical.armed_skill_slot == 0, "first offensive skill tap must remain armed on %s" % active_device_name)
        _check(tactical.skill_buttons[0].text.begins_with("CIBLER"), "armed offensive skill must clearly request a target on %s" % active_device_name)
        _check(alpha_button.text.begins_with("○"), "valid target must be marked with a circle on %s" % active_device_name)
        _check(beta_button.text.begins_with("×"), "blocked target must be marked out of range on %s" % active_device_name)

        beta_button.pressed.emit()
        await _frames(2)
        _check(emitted_cells.is_empty(), "blocked target touch must not emit a tactical selection on %s" % active_device_name)
        _check(not tactical.target_choice_confirmed, "blocked target must not confirm targeting on %s" % active_device_name)
        _check(tactical.armed_skill_slot == 0, "blocked target must not disarm the selected skill on %s" % active_device_name)

        alpha_button.pressed.emit()
        await _frames(2)
        _check(emitted_cells.size() == 1, "valid target touch must emit exactly one tactical selection on %s" % active_device_name)
        _check(tactical.selected_target == "ENT_ENEMY_ALPHA", "valid target touch must lock the intended enemy on %s" % active_device_name)
        _check(tactical.target_choice_confirmed, "valid target must enter confirmation state on %s" % active_device_name)
        _check(alpha_button.text.begins_with("◎"), "locked target must switch from circle to locked marker on %s" % active_device_name)
        _check(tactical.skill_buttons[0].text.begins_with("CONFIRMER"), "locked target must make the skill button request confirmation on %s" % active_device_name)

        var head_button := tactical.zone_buttons[0]
        head_button.pressed.emit()
        await _frames(2)
        _check(tactical.selected_zone == "head", "body-zone touch must change the anatomical target on %s" % active_device_name)
        _check(tactical.armed_skill_slot == 0 and tactical.target_choice_confirmed, "body-zone touch must preserve armed skill and locked target on %s" % active_device_name)

        tactical.set_armed_skill(-1)
        await _frames(1)
        _check(tactical.armed_skill_slot == -1, "disarm must clear the armed skill on %s" % active_device_name)
        _check(not tactical.target_selection_mode and not tactical.target_choice_confirmed, "disarm must fully reset target mode on %s" % active_device_name)

    tactical.queue_free()
    GameSettings.set_text_scale(original_text_scale)
    GameSettings.set_ui_scale(original_ui_scale)
    await _frames(2)
    _audit_combat_feedback_contract()

func _audit_combat_feedback_contract() -> void:
    var runtime := VeilleursTacticalCombatRuntimeV09.new()
    var setup := runtime.setup_first_combat(["ENT_ENEMY_GOULE_AFFAMEE"])
    _check(bool(setup.get("ok", false)), "combat feedback contract must have a valid v0.9 runtime on %s" % active_device_name)
    if not bool(setup.get("ok", false)):
        return

    var watcher_ids: Array[String] = runtime.alive_ids("watcher")
    var enemy_ids: Array[String] = runtime.alive_ids("enemy")
    _check(not watcher_ids.is_empty() and not enemy_ids.is_empty(), "combat feedback contract requires one watcher and one enemy on %s" % active_device_name)
    if watcher_ids.is_empty() or enemy_ids.is_empty():
        return

    var watcher_id := watcher_ids[0]
    var enemy_id := enemy_ids[0]
    var qa_stub := VeilleursVerticalSliceQAV09.new()
    qa_stub.selected_zone = "left_arm"
    var feedback := VeilleursCombatTurnFeedbackV09.new()
    feedback.qa = qa_stub

    var hit_event := {
        "ok": true,
        "hit": true,
        "attacker": watcher_id,
        "target": enemy_id,
        "skill_id": "",
        "zone": "left_arm",
        "damage": 7,
        "target_hp": 11,
        "body": {"ok": true, "trauma": 9, "state": "L3", "severed": false, "dead": false},
        "status_applied": "STAGGER"
    }
    var hit_text := feedback._format_player_event(runtime, hit_event)
    _check(hit_text.contains("TOUCHÉ"), "feedback must explicitly report a successful hit on %s" % active_device_name)
    _check(hit_text.contains("Bras gauche"), "feedback must localize body zones on %s" % active_device_name)
    _check(hit_text.contains("traumatisme 9") and hit_text.contains("critique"), "feedback must expose trauma and anatomical severity on %s" % active_device_name)
    _check(hit_text.contains("déséquilibré"), "feedback must localize applied combat status on %s" % active_device_name)

    var miss_event := {
        "ok": true,
        "hit": false,
        "attacker": watcher_id,
        "target": enemy_id,
        "skill_id": "",
        "zone": "torso",
        "hit_chance": 72
    }
    var miss_text := feedback._format_player_event(runtime, miss_event)
    _check(miss_text.contains("RATÉ") and miss_text.contains("chance 72%"), "feedback must expose misses and hit chance on %s" % active_device_name)

    var severed_event := hit_event.duplicate(true)
    severed_event["body"] = {"ok": true, "trauma": 24, "state": "L5", "severed": true, "dead": false}
    var severed_text := feedback._format_player_event(runtime, severed_event)
    _check(severed_text.contains("MEMBRE TRANCHÉ"), "feedback must expose dismemberment on %s" % active_device_name)

    var enemy_hit := {
        "ok": true,
        "action": "attack",
        "attacker": enemy_id,
        "target": watcher_id,
        "hit": true,
        "zone": "right_leg",
        "damage": 5,
        "status_applied": "PINNED"
    }
    var enemy_miss := {
        "ok": true,
        "action": "attack",
        "attacker": enemy_id,
        "target": watcher_id,
        "hit": false,
        "zone": "torso"
    }
    var enemy_text := feedback._enemy_response_summary(runtime, [enemy_hit, enemy_miss], 0)
    _check(enemy_text.contains("RIPOSTE ENNEMIE"), "enemy response feedback must have an explicit heading on %s" % active_device_name)
    _check(enemy_text.contains("Jambe droite") and enemy_text.contains("-5 PV"), "enemy response must identify body zone and damage per character on %s" % active_device_name)
    _check(enemy_text.contains("entravé") and enemy_text.contains("RATÉ"), "enemy response must expose status and misses per action on %s" % active_device_name)

func _tree_text_contains(root: Node, needle: String) -> bool:
    if root is Label and (root as Label).text.contains(needle):
        return true
    if root is Button and (root as Button).text.contains(needle):
        return true
    for child: Node in root.get_children():
        if _tree_text_contains(child, needle):
            return true
    return false
