extends "res://scripts/ui/main_v49.gd"

# v50 — P0 UX/UI: focus déterministe pour le combat joueur.
# L'inspection v45 est conservée, mais elle devient une vraie modale côté
# clavier/manette : le bouton Fermer reçoit le focus et la fermeture rend le focus
# au combattant qui avait ouvert la fiche. Les sélecteurs de cible reçoivent aussi
# un point d'entrée de focus stable après chaque reconstruction de l'écran.

var combat_focus_return_name_v50: String = ""
var restore_combat_focus_v50 := false

func show_combat() -> void:
    super.show_combat()
    if GameState.current_screen != "combat" or not is_instance_valid(content):
        return
    if inspected_combat_side != "" and inspected_combat_key != "":
        call_deferred("_focus_inspection_close_v50")
        return
    if restore_combat_focus_v50:
        call_deferred("_restore_combat_focus_v50")
    else:
        call_deferred("_focus_active_combat_decision_v50")

func _inspect_enemy(index: int, uid: String) -> void:
    _remember_combat_focus_v50()
    super._inspect_enemy(index, uid)

func _inspect_combatant(side: String, key: String) -> void:
    _remember_combat_focus_v50()
    super._inspect_combatant(side, key)

func _close_combat_inspection() -> void:
    restore_combat_focus_v50 = true
    super._close_combat_inspection()

func _remember_combat_focus_v50() -> void:
    var focused := get_viewport().gui_get_focus_owner()
    if focused != null and is_instance_valid(focused) and content != null and content.is_ancestor_of(focused):
        combat_focus_return_name_v50 = str(focused.name)

func _focus_inspection_close_v50() -> void:
    if not is_instance_valid(content):
        return
    var panel := content.get_node_or_null("CombatInspectionV45")
    if panel == null:
        return
    for node_value: Variant in panel.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.visible or button.disabled:
            continue
        button.name = "CombatInspectionCloseV50"
        button.focus_mode = Control.FOCUS_ALL
        button.grab_focus()
        return

func _restore_combat_focus_v50() -> void:
    restore_combat_focus_v50 = false
    if not is_instance_valid(content):
        return
    if combat_focus_return_name_v50 != "":
        var candidate := content.find_child(combat_focus_return_name_v50, true, false) as Control
        if candidate != null and candidate.visible and candidate.focus_mode != Control.FOCUS_NONE:
            candidate.grab_focus()
            combat_focus_return_name_v50 = ""
            return
    combat_focus_return_name_v50 = ""
    _focus_active_combat_decision_v50()

func _focus_active_combat_decision_v50() -> void:
    if not is_instance_valid(content):
        return
    # Priority follows the current decision: explicit single target, multi-target,
    # then any visible enabled combat action. This prevents focus from disappearing
    # after show_screen("combat") rebuilds the tree.
    for panel_name in ["ExplicitTargetPickerV44", "MultiTargetPickerV49"]:
        var panel := content.get_node_or_null(panel_name)
        if panel == null:
            continue
        var first := _first_focusable_button_v50(panel)
        if first != null:
            first.grab_focus()
            return

    var active_hero_token := ""
    var active := _active_combat_hero()
    if not active.is_empty():
        active_hero_token = str(active.get("name", ""))
    var fallback: Button = null
    for node_value: Variant in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.visible or button.disabled or button.focus_mode == Control.FOCUS_NONE:
            continue
        if fallback == null:
            fallback = button
        if active_hero_token != "" and _button_descendant_text(button).contains(active_hero_token):
            button.grab_focus()
            return
    if fallback != null:
        fallback.grab_focus()

func _first_focusable_button_v50(root: Node) -> Button:
    for node_value: Variant in root.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button != null and button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
            return button
    return null

func _clear_combat_transients_v48() -> void:
    combat_focus_return_name_v50 = ""
    restore_combat_focus_v50 = false
    super._clear_combat_transients_v48()
