extends RefCounted
class_name VeilleursVS001Runtime

const BALANCE_PATH := "res://data/veilleurs/vs001_balance.json"
const CAPTURE_WOUNDS_PATH := "res://data/capture_wound_rules.json"

static func load_balance() -> Dictionary:
    return _load_json(BALANCE_PATH)

static func load_capture_wounds() -> Dictionary:
    return _load_json(CAPTURE_WOUNDS_PATH)

static func recruitment_state(action_ids: Array[String]) -> Dictionary:
    var balance: Dictionary = load_balance()
    var recruitment: Dictionary = balance.get("recruitment_s6", {})
    var actions: Dictionary = recruitment.get("actions", {})
    var state: Dictionary = recruitment.get("initial", {}).duplicate(true)
    var mutable_fields: Array[String] = ["fear", "trust", "pain", "aggression", "stability", "restraint"]
    for action_id: String in action_ids:
        var action: Dictionary = actions.get(action_id, {})
        for field_id: String in mutable_fields:
            if action.has(field_id):
                state[field_id] = clampi(int(state.get(field_id, 0)) + int(action.get(field_id, 0)), 0, 100)
        if action.has("health_ratio_delta"):
            state["health_ratio"] = clampf(
                float(state.get("health_ratio", 0.0)) + float(action.get("health_ratio_delta", 0.0)),
                0.0,
                1.0
            )
    return state

static func capture_preview(action_ids: Array[String], actor_id: String) -> Dictionary:
    var balance: Dictionary = load_balance()
    var wounds: Dictionary = load_capture_wounds()
    var state: Dictionary = recruitment_state(action_ids)
    var recruitment: Dictionary = balance.get("recruitment_s6", {})
    var check: Dictionary = recruitment.get("capture_check", {})
    var actor_bonus: Dictionary = check.get("actor_bonus", {})

    var wound_bonus := 0
    if bool(check.get("wound_bonus_from_existing_contract", false)):
        wound_bonus = mini(
            int(wounds.get("capture_bonus_cap", 20)),
            int(state.get("lost_parts", 0)) * int(wounds.get("capture_bonus_per_lost_part", 0))
            + int(state.get("critical_injuries", 0)) * int(wounds.get("capture_bonus_per_critical_injury", 0))
        )

    var trust_multiplier := _formula_multiplier(str(check.get("trust_bonus_formula", "")), 0.20)
    var fear_multiplier := _formula_multiplier(str(check.get("fear_penalty_formula", "")), 0.25)
    var restraint_multiplier := _formula_multiplier(str(check.get("restraint_bonus_formula", "")), 0.15)
    var stability_multiplier := _formula_multiplier(str(check.get("stability_bonus_formula", "")), 0.10)

    var score := (
        int(check.get("base", 0))
        - int(check.get("creature_resistance", 0))
        + wound_bonus
        + int(actor_bonus.get(actor_id, 0))
        + int(floor(float(state.get("trust", 0)) * trust_multiplier))
        - int(floor(float(maxi(int(state.get("fear", 0)) - 60, 0)) * fear_multiplier))
        + int(floor(float(state.get("restraint", 0)) * restraint_multiplier))
        + int(floor(float(state.get("stability", 0)) * stability_multiplier))
    )

    var roll_range: Array = check.get("deterministic_roll_range", [-8, 8])
    var low := int(roll_range[0])
    var high := int(roll_range[1])
    var threshold := int(check.get("success_threshold", 60))
    var successes := 0
    var total := maxi(1, high - low + 1)
    for roll: int in range(low, high + 1):
        if score + roll >= threshold:
            successes += 1
    var probability := 100.0 * float(successes) / float(total)
    return {
        "state": state,
        "actor": actor_id,
        "score_before_roll": score,
        "roll_range": [low, high],
        "success_threshold": threshold,
        "success_percent": probability
    }

static func apply_light(current: int, action_id: String, combat_rounds: int = 0) -> int:
    var balance: Dictionary = load_balance()
    var light: Dictionary = balance.get("light", {})
    var cost := 0
    if combat_rounds > 0:
        var combat_cost: Dictionary = light.get("combat_cost", {})
        cost = mini(combat_rounds, int(combat_cost.get("per_combat_cap", 6))) * int(combat_cost.get("per_meaningful_round", 1))
    else:
        var costs: Dictionary = light.get("cost_by_action", {})
        cost = int(costs.get(action_id, 0))
    return clampi(current - cost, 0, 100)

static func apply_noise(current: int, action_id: String, calm_pulse: bool) -> int:
    var balance: Dictionary = load_balance()
    var noise: Dictionary = balance.get("noise", {})
    var deltas: Dictionary = noise.get("action_deltas", {})
    var next_value := clampi(current + int(deltas.get(action_id, 0)), 0, 100)
    if calm_pulse:
        next_value = clampi(next_value - int(noise.get("party_noise_decay_per_calm_pulse", 5)), 0, 100)
    return next_value

static func event_chance(light_value: int, noise_value: int) -> int:
    var balance: Dictionary = load_balance()
    var event_rules: Dictionary = balance.get("events", {})
    var light_rules: Dictionary = balance.get("light", {})
    var light_state := "stable"
    for state_value: Variant in light_rules.get("states", []):
        var state: Dictionary = state_value
        if int(state.get("min", 0)) <= light_value and light_value <= int(state.get("max", 100)):
            light_state = str(state.get("id", "stable"))
            break
    var light_mods: Dictionary = event_rules.get("light_event_mod", {})
    var chance := (
        int(event_rules.get("base_check_percent", 10))
        + int(floor(float(maxi(noise_value - 20, 0)) * 0.25))
        + int(event_rules.get("danger_band_vs001", 0)) * 3
        + int(light_mods.get(light_state, 0))
    )
    return clampi(chance, 5, 45)

static func base_seed_gold() -> int:
    var balance: Dictionary = load_balance()
    var loot: Dictionary = balance.get("loot_vs001", {})
    var rooms: Dictionary = loot.get("rooms", {})
    var total := 0
    for room_id_value: Variant in rooms.keys():
        var room_id := str(room_id_value)
        if room_id == "s6":
            continue
        var room: Dictionary = rooms.get(room_id, {})
        total += int(room.get("or", 0))
    return total

static func ghoul_profile(profile_id: String) -> Dictionary:
    var balance: Dictionary = load_balance()
    return balance.get("ghoul_profiles", {}).get(profile_id, {})

static func _formula_multiplier(formula: String, fallback: float) -> float:
    var star_index := formula.find("*")
    if star_index < 0:
        return fallback
    var tail := formula.substr(star_index + 1).strip_edges()
    var close_index := tail.find(")")
    if close_index >= 0:
        tail = tail.substr(0, close_index).strip_edges()
    return tail.to_float() if tail.is_valid_float() else fallback

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
