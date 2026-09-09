extends RefCounted
class_name VeilleursGE01Definition

const EXPEDITION_ID := "VS01_GALERIES_ETEINTES"
const DISPLAY_NAME := "Les Galeries Éteintes"
const INITIAL_LIGHT := 100

const LIGHT_STATES := {
    "clear": Vector2i(76, 100),
    "weak": Vector2i(51, 75),
    "dark": Vector2i(26, 50),
    "critical": Vector2i(1, 25),
    "darkness": Vector2i(0, 0),
}

const ROOM_COSTS := {
    "ge_01": -1,
    "ge_02": -2,
    "ge_03": -2,
    "ge_03b": -3,
    "ge_04": -4,
    "ge_05": -2,
    "ge_06": -2,
    "ge_07": -2,
    "ge_08": 0,
    "ge_09": -4,
    "ge_10": -1,
    "ge_11": -5,
    "ge_12": -6,
    "ge_13": 0,
    "ge_14": -2,
}

const ACTION_LIGHT_COSTS := {
    "enter_known_room": 1,
    "enter_unknown_room": 2,
    "observe_simple": 1,
    "observe_deep": 3,
    "anatomy_deep": 2,
    "combat_short": 3,
    "combat_standard": 4,
    "combat_long": 6,
    "event_short": 1,
    "event_deep": 3,
}

const ENCOUNTERS := {
    "ge_04": [
        {"weight": 40, "units": ["ghoul_hungry", "ghoul_hungry"]},
        {"weight": 25, "units": ["ghoul_hungry", "emaciated"]},
        {"weight": 20, "units": ["emaciated", "emaciated", "ghoul_hungry"]},
        {"weight": 15, "units": ["ghoul_hungry", "ash_roamer"]},
    ],
    "ge_09": [
        {"weight": 30, "units": ["ghoul_hungry", "ash_roamer"]},
        {"weight": 25, "units": ["ghoul_hungry", "ghoul_hungry"]},
        {"weight": 20, "units": ["ash_bearer", "emaciated"]},
        {"weight": 15, "units": ["ghoul_hungry", "emaciated", "emaciated"]},
        {"weight": 10, "units": ["ghoul_hungry", "ash_bearer", "emaciated"]},
    ],
    "ge_11": [
        {"weight": 30, "units": ["ash_bearer", "ghoul_hungry"]},
        {"weight": 25, "units": ["ash_roamer", "ash_roamer"]},
        {"weight": 20, "units": ["ghoul_voracious"]},
        {"weight": 15, "units": ["ghoul_hungry", "ghoul_hungry", "ash_bearer"]},
        {"weight": 10, "units": ["persistent_candidate"]},
    ],
    "ge_12": [
        {"weight": 35, "units": ["ghoul_voracious", "ash_bearer"]},
        {"weight": 25, "units": ["mutilated_guardian"]},
        {"weight": 20, "units": ["preexisting_veteran"]},
        {"weight": 15, "units": ["elite_group"]},
        {"weight": 5, "units": [], "event": "rare_non_combat"},
    ],
}

const FLEE_BASE_CHANCE := {
    "ghoul_hungry": 35,
    "emaciated": 15,
    "ash_roamer": 55,
    "ash_bearer": 40,
    "ghoul_voracious": 10,
}

static func light_state(value: int) -> String:
    var light := clampi(value, 0, 100)
    if light >= 76:
        return "clear"
    if light >= 51:
        return "weak"
    if light >= 26:
        return "dark"
    if light >= 1:
        return "critical"
    return "darkness"

static func weighted_pick(entries: Array, roll_0_99: int) -> Dictionary:
    if entries.is_empty():
        return {}
    var roll := clampi(roll_0_99, 0, 99)
    var cursor := 0
    for entry_value: Variant in entries:
        var entry: Dictionary = entry_value
        cursor += int(entry.get("weight", 0))
        if roll < cursor:
            return entry.duplicate(true)
    return (entries.back() as Dictionary).duplicate(true)

static func room_base_light_delta(room_id: String) -> int:
    return int(ROOM_COSTS.get(room_id, -2))
