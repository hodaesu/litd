extends RefCounted
class_name VeilleursBodyComponent

const ZONES: Array[String] = ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
const SEVERABLE: Array[String] = ["left_arm", "right_arm", "left_leg", "right_leg"]

var maximum: Dictionary = {}
var current: Dictionary = {}
var states: Dictionary = {}
var missing_parts: Array[String] = []
var dead := false

func _init(integrity: Dictionary = {}) -> void:
    for zone: String in ZONES:
        var value := maxi(1, int(integrity.get(zone, _default_integrity(zone))))
        maximum[zone] = value
        current[zone] = value
        states[zone] = "L0"

func apply_trauma(zone: String, amount: int, dismemberment_power: int = 0, zone_resistance: int = 3) -> Dictionary:
    if not ZONES.has(zone) or amount <= 0:
        return {"ok": false, "zone": zone}
    if missing_parts.has(zone):
        return {"ok": false, "zone": zone, "reason": "missing_part"}
    current[zone] = maxi(0, int(current.get(zone, 0)) - amount)
    var state := _state_for(zone)
    var severed := false
    if int(current[zone]) <= 0:
        if SEVERABLE.has(zone) and dismemberment_power >= zone_resistance:
            state = "L5"
            missing_parts.append(zone)
            severed = true
        elif zone in ["head", "torso"]:
            state = "L5"
            dead = true
        else:
            state = "L4"
    states[zone] = state
    return {
        "ok": true,
        "zone": zone,
        "trauma": amount,
        "remaining": int(current[zone]),
        "state": state,
        "severed": severed,
        "dead": dead
    }

func heal(zone: String, amount: int) -> int:
    if not ZONES.has(zone) or missing_parts.has(zone):
        return int(current.get(zone, 0))
    current[zone] = mini(int(maximum[zone]), int(current[zone]) + maxi(0, amount))
    states[zone] = _state_for(zone)
    return int(current[zone])

func functional_flags() -> Dictionary:
    return {
        "can_walk": not (missing_parts.has("left_leg") and missing_parts.has("right_leg")),
        "can_sprint": _zone_below("left_leg", "L3") and _zone_below("right_leg", "L3"),
        "can_use_two_handed": _zone_below("left_arm", "L4") and _zone_below("right_arm", "L4"),
        "can_guard": not (missing_parts.has("left_arm") and missing_parts.has("right_arm")),
        "can_react": _zone_below("head", "L4") and not dead,
        "alive": not dead
    }

func serialize() -> Dictionary:
    return {
        "maximum": maximum.duplicate(true),
        "current": current.duplicate(true),
        "states": states.duplicate(true),
        "missing_parts": missing_parts.duplicate(),
        "dead": dead
    }

func deserialize(payload: Dictionary) -> void:
    maximum = (payload.get("maximum", maximum) as Dictionary).duplicate(true)
    current = (payload.get("current", current) as Dictionary).duplicate(true)
    states = (payload.get("states", states) as Dictionary).duplicate(true)
    missing_parts.clear()
    for value: Variant in payload.get("missing_parts", []):
        missing_parts.append(str(value))
    dead = bool(payload.get("dead", false))

func _state_for(zone: String) -> String:
    var max_value := maxi(1, int(maximum.get(zone, 1)))
    var value := int(current.get(zone, 0))
    if value <= 0:
        return "L4"
    var ratio := float(value) / float(max_value)
    if ratio > 0.75:
        return "L0"
    if ratio > 0.50:
        return "L1"
    if ratio > 0.25:
        return "L2"
    return "L3"

func _zone_below(zone: String, threshold: String) -> bool:
    return _level(str(states.get(zone, "L0"))) < _level(threshold)

func _level(state: String) -> int:
    if state.length() < 2:
        return 0
    return int(state.substr(1))

func _default_integrity(zone: String) -> int:
    return {"head": 70, "torso": 140, "left_arm": 90, "right_arm": 90, "left_leg": 100, "right_leg": 100}.get(zone, 100)
