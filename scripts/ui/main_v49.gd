extends "res://scripts/ui/main_v48.gd"

# v49 — polish mobile Combat Sandbox.
# Objectifs : cibles tactiles >= 48 px, commandes avancées sans chevauchement,
# formation plus lisible au pouce, synergie/ultime strictement contextuels.

const SANDBOX_MIN_TOUCH := 48.0
const SANDBOX_COMPACT_WIDTH := 980.0
const SANDBOX_PHONE_BOTTOM_Y := 610.0

func _show_combat_sandbox() -> void:
    super._show_combat_sandbox()
    if not _sandbox_started:
        return
    _sandbox_mobile_polish_pass()

func _sandbox_mobile_polish_pass() -> void:
    _enforce_sandbox_touch_targets(content)
    if _sandbox_is_compact_phone():
        _reflow_advanced_mobile_controls()

func _sandbox_is_compact_phone() -> bool:
    var viewport_size := get_viewport_rect().size
    return viewport_size.x <= SANDBOX_COMPACT_WIDTH or viewport_size.y <= 720.0

func _enforce_sandbox_touch_targets(root: Node) -> void:
    for child in root.get_children():
        if child is Button:
            var button := child as Button
            button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, SANDBOX_MIN_TOUCH)
            button.size.y = maxf(button.size.y, SANDBOX_MIN_TOUCH)
        _enforce_sandbox_touch_targets(child)

func _render_sandbox_result() -> void:
    var compact := _sandbox_is_compact_phone()
    var panel := PanelContainer.new()
    panel.name = "SandboxResultPanelV49"
    panel.position = Vector2(20, 474) if compact else Vector2(52, 522)
    panel.size = Vector2(maxf(600.0, get_viewport_rect().size.x - 40.0), 66) if compact else Vector2(1168, 108)
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.92)))
    content.add_child(panel)
    var text := "Choisissez une action, une cible et une zone."
    if not _sandbox_last_result.is_empty():
        text = _sandbox_result_text(_sandbox_last_result)
    var label := make_label(text, 12, CANON_TEXT)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(label)

func _reflow_advanced_mobile_controls() -> void:
    var viewport_width := maxf(640.0, get_viewport_rect().size.x)
    var margin := 20.0
    var usable := viewport_width - margin * 2.0

    var formation := content.get_node_or_null("SandboxFormationMobileV48") as Control
    if formation != null:
        formation.position = Vector2(margin, SANDBOX_PHONE_BOTTOM_Y)
        formation.size = Vector2(usable, 104)
        var row := _first_hbox(formation)
        if row != null:
            var slot_width := maxf(92.0, (usable - 15.0) / 4.0)
            for child in row.get_children():
                if child is Button:
                    var button := child as Button
                    button.custom_minimum_size = Vector2(slot_width, 56)
                    button.size = Vector2(slot_width, 56)

    var synergy := content.get_node_or_null("SandboxContextualSynergyV48") as Control
    var ultimate := content.get_node_or_null("SandboxUltimateMobileV48") as Control

    if synergy != null:
        synergy.position = Vector2(margin, SANDBOX_PHONE_BOTTOM_Y - 64.0)
        synergy.size = Vector2(usable, 58)
        var synergy_button := synergy.get_node_or_null("SandboxSynergyButtonV48") as Button
        if synergy_button != null:
            synergy_button.custom_minimum_size = Vector2(usable, 52)
            synergy_button.size = Vector2(usable, 52)
        if ultimate != null:
            ultimate.visible = false
    elif ultimate != null:
        ultimate.position = Vector2(margin, SANDBOX_PHONE_BOTTOM_Y - 64.0)
        ultimate.size = Vector2(usable, 58)
        var ultimate_button := ultimate.get_node_or_null("SandboxUltimateButtonV48") as Button
        if ultimate_button != null:
            ultimate_button.custom_minimum_size = Vector2(usable, 52)
            ultimate_button.size = Vector2(usable, 52)

func _first_hbox(root: Node) -> HBoxContainer:
    for child in root.get_children():
        if child is HBoxContainer:
            return child as HBoxContainer
    return null

func _sandbox_move_active_to_slot(slot: int) -> void:
    var active: Dictionary = _sandbox.call("active_hero")
    var current_slot := int(active.get("formation_slot", 0))
    if current_slot == slot:
        return
    super._sandbox_move_active_to_slot(slot)

func _sandbox_result_text(result: Dictionary) -> String:
    var base := super._sandbox_result_text(result)
    if str(result.get("kind", "")) == "formation" and bool(result.get("ok", false)):
        return "%s · R1 = avant droit de l’écran." % base
    return base
