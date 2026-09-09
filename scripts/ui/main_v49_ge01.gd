extends "res://scripts/ui/main_v48.gd"

# GE01 integration layer ported above current main_v48.
# Keeps corpse-aware formation rules without overriding an enemy-phase method
# that does not exist in the v48 inheritance chain.

const GE01_CORPSE_TACTICAL_SCRIPT := preload("res://scripts/core/veilleurs_corpse_tactical_runtime.gd")
var _ge01_corpse_tactical: RefCounted = GE01_CORPSE_TACTICAL_SCRIPT.new()

func show_combat() -> void:
    CombatPositionRuntime.initialize_battle(GameState.party, GameState.battle_enemies)
    super.show_combat()

func _render_combat_position_menu(hero: Dictionary) -> void:
    super._render_combat_position_menu(hero)
    if not _ge01_combat_active():
        return
    var panel: Control = content.get_node_or_null("CombatPositionMenuV42") as Control
    if panel == null:
        return
    var corpse_ids: Array = _ge01_corpse_ids()
    for node_value: Variant in panel.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button == null or not button.text.begins_with("R"):
            continue
        var first_line: String = str(button.text.split("\n", false)[0])
        var rank_text: String = first_line.trim_prefix("R")
        if not rank_text.is_valid_int():
            continue
        var slot: int = int(rank_text) - 1
        if not bool(_ge01_corpse_tactical.call("can_move_to_slot", slot, corpse_ids, "hero")):
            button.disabled = true
            button.text = "R%d · ☠ BLOQUÉ\nCADAVRE" % (slot + 1)
            button.tooltip_text = "Un cadavre occupe cette ligne. Déplacez ou détruisez le corps avant d'y entrer."

func _change_combat_position_to(target_position: int) -> void:
    if _ge01_combat_active():
        var corpse_ids: Array = _ge01_corpse_ids()
        var target_slot: int = clampi(target_position, 0, 3)
        if not bool(_ge01_corpse_tactical.call("can_move_to_slot", target_slot, corpse_ids, "hero")):
            GameState.add_log("Déplacement impossible : un cadavre bloque R%d." % (target_slot + 1))
            combat_position_menu = true
            show_screen("combat")
            return
    super._change_combat_position_to(target_position)

func _ge01_combat_active() -> bool:
    var runtime: Node = get_node_or_null("/root/GE01Runtime")
    if runtime == null or not runtime.has_method("current_room"):
        return false
    var room_id: String = str(runtime.call("current_room"))
    return room_id in ["ge_04", "ge_09", "ge_11", "ge_12"] and not GameState.battle_enemies.is_empty()

func _ge01_corpse_ids() -> Array:
    var runtime: Node = get_node_or_null("/root/GE01Runtime")
    if runtime == null or not runtime.has_method("tactical_corpse_context"):
        return []
    var context: Dictionary = runtime.call("tactical_corpse_context")
    return context.keys()
