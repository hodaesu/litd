extends Area3D
class_name ZoneTransitionGate

signal transition_requested(from_zone: String, to_zone: String, gate_id: String)
signal transition_blocked(reason: String)
signal dangerous_dungeon_confirmation_requested(title: String, warning: String)

@export var gate_id := ""
@export var from_zone := ""
@export var to_zone := ""
@export var secret := false
@export var requires_shortcut := ""
@export var teleporter := false
@export var required_obsidian_points := 0
@export var dungeon := false
@export var optional_content := false
@export var dangerous_entry := false
@export var dungeon_title := ""
@export_multiline var danger_warning := ""

var _danger_confirmation_until := 0

func can_transition() -> bool:
    if requires_shortcut != "" and not AshlandsRuntime.is_shortcut_unlocked(requires_shortcut):
        transition_blocked.emit("shortcut_locked")
        return false
    if secret and not AshlandsRuntime.is_zone_discovered(to_zone):
        # Secret gates can still be entered once physically found; discovery occurs on transition.
        pass
    if teleporter and required_obsidian_points > 0:
        if int(ExpeditionManager.craft_resources.get("obsidian_point", 0)) < required_obsidian_points:
            transition_blocked.emit("missing_obsidian_point")
            return false
    return true

func request_transition() -> bool:
    if dangerous_entry and Time.get_ticks_msec() > _danger_confirmation_until:
        _danger_confirmation_until = Time.get_ticks_msec() + 5000
        dangerous_dungeon_confirmation_requested.emit(dungeon_title, danger_warning)
        transition_blocked.emit("dangerous_dungeon_confirmation")
        return false
    _danger_confirmation_until = 0
    if not can_transition():
        return false
    if teleporter and required_obsidian_points > 0:
        ExpeditionManager.craft_resources["obsidian_point"] = int(ExpeditionManager.craft_resources.get("obsidian_point", 0)) - required_obsidian_points
    transition_requested.emit(from_zone, to_zone, gate_id)
    AshlandsRuntime.request_zone_transition(to_zone)
    return true
