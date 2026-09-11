extends "res://scripts/ui/combat_sandbox_ui_v50.gd"

# Combat Sandbox v51 — préparation non destructive + focus déterministe.

var _sandbox_focus_return_name_v51 := ""
var _sandbox_restore_focus_v51 := false
var _sandbox_focus_confirm_v51 := false

func _show_combat_sandbox() -> void:
    super._show_combat_sandbox()
    if not _sandbox_started:
        return
    _render_sandbox_preview_v51()
    _apply_focus_contract_v51()
    call_deferred("_restore_sandbox_focus_v51")

func _sandbox_select_action(action_id: String) -> void:
    _sandbox_selected_action = action_id
    _sandbox_feedback_text = ""
    _sandbox_focus_confirm_v51 = _sandbox_action_ready()
    show_screen("combat_sandbox")

func _sandbox_select_target(index: int) -> void:
    _sandbox_selected_target = index
    _sandbox_focus_confirm_v51 = _sandbox_action_ready()
    show_screen("combat_sandbox")

func _sandbox_select_zone(zone: String) -> void:
    _sandbox_selected_zone = zone
    _sandbox_focus_confirm_v51 = _sandbox_action_ready()
    show_screen("combat_sandbox")

func _sandbox_select_ally_or_inspect(index: int) -> void:
    var action := _sandbox_selected_action_data()
    if not action.is_empty() and str(action.get("target", "")) == "ally":
        _sandbox_selected_ally = index
        _sandbox_focus_confirm_v51 = _sandbox_action_ready()
        show_screen("combat_sandbox")
        return
    super._sandbox_select_ally_or_inspect(index)

func _sandbox_execute() -> void:
    _sandbox_confirm_prepared_v51()

func _sandbox_confirm_prepared_v51() -> void:
    if not _sandbox_action_ready():
        return
    _sandbox_focus_confirm_v51 = false
    super._sandbox_execute_v50()

func _sandbox_build_preview_v51() -> Dictionary:
    var action := _sandbox_selected_action_data()
    if action.is_empty():
        return {"ready":false}
    var preview := {
        "ready":_sandbox_action_ready(),
        "action_id":str(action.get("id", "")),
        "action_name":str(action.get("name", action.get("id", "Action"))),
        "ap":int(action.get("ap", 1)),
        "target_type":str(action.get("target", "enemy")),
        "zone":_sandbox_selected_zone,
        "target_name":""
    }
    var target_type := str(preview.get("target_type", "enemy"))
    if target_type.begins_with("enemy"):
        var enemies: Array = _sandbox.get("enemies")
        if _sandbox_selected_target >= 0 and _sandbox_selected_target < enemies.size():
            preview["target_name"] = str((enemies[_sandbox_selected_target] as Dictionary).get("name", "Ennemi"))
    elif target_type == "ally":
        var heroes: Array = _sandbox.get("heroes")
        if _sandbox_selected_ally >= 0 and _sandbox_selected_ally < heroes.size():
            preview["target_name"] = str((heroes[_sandbox_selected_ally] as Dictionary).get("name", "Allié"))
    elif target_type == "self":
        preview["target_name"] = str((_sandbox.call("active_hero") as Dictionary).get("name", "Veilleur"))
    return preview

func _render_sandbox_preview_v51() -> void:
    var preview := _sandbox_build_preview_v51()
    if preview.is_empty() or str(preview.get("action_name", "")) == "":
        return
    var panel := PanelContainer.new()
    panel.name = "SandboxPreparedPreviewV51"
    panel.position = Vector2(900, 286)
    panel.size = Vector2(320, 190)
    panel.z_index = 70
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.96)))
    content.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    panel.add_child(box)
    box.add_child(make_label("PRÉVISUALISATION", 13, CANON_GOLD))
    box.add_child(make_label(str(preview.get("action_name", "Action")), 14, CANON_TEXT))
    var target_name := str(preview.get("target_name", ""))
    var target_line := "Cible : à choisir" if target_name == "" else "Cible : %s" % target_name
    box.add_child(make_label(target_line, 11, CANON_MUTED))
    if str(preview.get("target_type", "")) == "enemy_zone":
        box.add_child(make_label("Zone : %s" % _zone_label_context(str(preview.get("zone", "torso"))), 11, CANON_MUTED))
    box.add_child(make_label("Coût : %d PA · aucun effet avant confirmation" % int(preview.get("ap", 1)), 11, CANON_MUTED))
    var confirm := make_button("CONFIRMER", func(): _sandbox_confirm_prepared_v51(), Vector2(290, 50))
    confirm.name = "SandboxConfirmV51"
    confirm.disabled = not bool(preview.get("ready", false))
    confirm.focus_mode = Control.FOCUS_ALL
    box.add_child(confirm)

func _sandbox_open_inspection(side: String, index: int) -> void:
    _remember_sandbox_focus_v51()
    super._sandbox_open_inspection(side, index)

func _sandbox_close_inspection() -> void:
    _sandbox_restore_focus_v51 = true
    super._sandbox_close_inspection()

func _remember_sandbox_focus_v51() -> void:
    var focused := get_viewport().gui_get_focus_owner()
    if focused != null and is_instance_valid(focused) and is_instance_valid(content) and content.is_ancestor_of(focused):
        _sandbox_focus_return_name_v51 = str(focused.name)

func _apply_focus_contract_v51() -> void:
    if not is_instance_valid(content):
        return
    var action_index := 0
    var inspect_index := 0
    for node_value: Variant in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null:
            continue
        button.focus_mode = Control.FOCUS_ALL
        var text := button.text.strip_edges()
        if text == "FERMER":
            button.name = "SandboxInspectionCloseV51"
        elif text == "EXAMINER":
            button.name = "SandboxInspectV51_%d" % inspect_index
            inspect_index += 1
        elif text.find(" PA") >= 0 and text != "FIN DU TOUR":
            button.name = "SandboxActionV51_%d" % action_index
            action_index += 1

func _restore_sandbox_focus_v51() -> void:
    if not is_instance_valid(content):
        return
    if _sandbox_inspect_side != "" and _sandbox_inspect_index >= 0:
        var close := content.find_child("SandboxInspectionCloseV51", true, false) as Control
        if close != null and close.visible:
            close.grab_focus()
            return
    if _sandbox_restore_focus_v51:
        _sandbox_restore_focus_v51 = false
        if _sandbox_focus_return_name_v51 != "":
            var previous := content.find_child(_sandbox_focus_return_name_v51, true, false) as Control
            if previous != null and previous.visible and previous.focus_mode != Control.FOCUS_NONE:
                previous.grab_focus()
                _sandbox_focus_return_name_v51 = ""
                return
        _sandbox_focus_return_name_v51 = ""
    if _sandbox_focus_confirm_v51:
        var confirm := content.find_child("SandboxConfirmV51", true, false) as Button
        if confirm != null and confirm.visible and not confirm.disabled:
            _sandbox_focus_confirm_v51 = false
            confirm.grab_focus()
            return
    var first_action := content.find_child("SandboxActionV51_0", true, false) as Button
    if first_action != null and first_action.visible and not first_action.disabled:
        first_action.grab_focus()

func _clear_combat_transients_v48() -> void:
    _sandbox_focus_return_name_v51 = ""
    _sandbox_restore_focus_v51 = false
    _sandbox_focus_confirm_v51 = false
    super._clear_combat_transients_v48()
