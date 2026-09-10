extends "res://scripts/ui/main_v49.gd"

# Stable GE01 helper layer above the current player-facing main_v49 layer.
# Corpse actions remain in v50. Formation interception is deliberately kept out
# of this layer until its parent contract is covered by a dedicated smoke test.

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
