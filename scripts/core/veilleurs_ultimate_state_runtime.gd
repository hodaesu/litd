extends RefCounted
class_name VeilleursUltimateStateRuntime

const STATE_KEY := "ultimate_state"
const BRANCHES_BY_ENTITY := {
    "ENT_WATCHER_NAYRA": ["bastion", "brisure", "serment"],
    "ENT_WATCHER_TAREK": ["traque", "entaille", "disparition"],
    "ENT_WATCHER_AISHA": ["anatomie", "suture", "hemocorde"],
    "ENT_WATCHER_IDRIS": ["sentence", "concorde", "dissidence"]
}

func charges_for_level(level: int) -> int:
    if level >= 48:
        return 3
    if level >= 32:
        return 2
    if level >= 16:
        return 1
    return 0

func configure(watcher: Dictionary, level: int, specialization: String, reset_charges: bool = true) -> Dictionary:
    watcher["level"] = clampi(level, 1, 50)
    watcher["specialization"] = specialization
    if reset_charges:
        watcher[STATE_KEY] = _fresh_state(watcher)
    else:
        ensure(watcher)
    return watcher

func ensure(watcher: Dictionary) -> Dictionary:
    var entity_id := str(watcher.get("entity_id", ""))
    var branches_value: Variant = BRANCHES_BY_ENTITY.get(entity_id, [])
    var branches: Array = branches_value if branches_value is Array else []
    var count := charges_for_level(int(watcher.get("level", 1)))
    var state_value: Variant = watcher.get(STATE_KEY, {})
    var state: Dictionary = state_value if state_value is Dictionary else {}
    var charges_value: Variant = state.get("charges", {})
    var max_value: Variant = state.get("max_charges", {})
    var used_value: Variant = state.get("encounters_used", {})
    var charges: Dictionary = charges_value if charges_value is Dictionary else {}
    var max_charges: Dictionary = max_value if max_value is Dictionary else {}
    var encounters_used: Dictionary = used_value if used_value is Dictionary else {}

    for branch_value: Variant in branches:
        var branch := str(branch_value)
        var previous_max := int(max_charges.get(branch, count))
        max_charges[branch] = count
        if not charges.has(branch):
            charges[branch] = count
        elif previous_max != count:
            charges[branch] = mini(int(charges.get(branch, 0)), count)
        else:
            charges[branch] = clampi(int(charges.get(branch, 0)), 0, count)

    state["charges"] = charges
    state["max_charges"] = max_charges
    state["encounters_used"] = encounters_used
    watcher[STATE_KEY] = state
    return state

func reset_for_expedition(watcher: Dictionary) -> Dictionary:
    var state := _fresh_state(watcher)
    watcher[STATE_KEY] = state
    return state

func status(watcher: Dictionary, branch: String, encounter_id: String) -> Dictionary:
    var entity_id := str(watcher.get("entity_id", ""))
    var branches_value: Variant = BRANCHES_BY_ENTITY.get(entity_id, [])
    var branches: Array = branches_value if branches_value is Array else []
    var result := {
        "available": false,
        "reason": "ultimate_unavailable",
        "entity_id": entity_id,
        "branch": branch,
        "charges_remaining": 0,
        "charges_max": 0,
        "encounter_id": encounter_id
    }
    if not branches.has(branch):
        result["reason"] = "unknown_ultimate_branch"
        return result
    if int(watcher.get("hp", 0)) <= 0:
        result["reason"] = "watcher_unavailable"
        return result
    if int(watcher.get("level", 1)) < 16:
        result["reason"] = "ultimate_level_locked"
        return result
    if str(watcher.get("specialization", "")) != branch:
        result["reason"] = "wrong_specialization"
        return result
    if encounter_id == "":
        result["reason"] = "encounter_required"
        return result

    var state := ensure(watcher)
    var charges: Dictionary = state.get("charges", {})
    var max_charges: Dictionary = state.get("max_charges", {})
    var used: Dictionary = state.get("encounters_used", {})
    result["charges_remaining"] = int(charges.get(branch, 0))
    result["charges_max"] = int(max_charges.get(branch, 0))
    if int(result.get("charges_remaining", 0)) <= 0:
        result["reason"] = "no_ultimate_charges"
        return result
    if bool(used.get(_use_key(branch, encounter_id), false)):
        result["reason"] = "ultimate_already_used_this_encounter"
        return result
    result["available"] = true
    result["reason"] = "ready"
    return result

func commit(watcher: Dictionary, branch: String, encounter_id: String) -> Dictionary:
    var check := status(watcher, branch, encounter_id)
    if not bool(check.get("available", false)):
        return {"ok": false, "reason": str(check.get("reason", "ultimate_unavailable")), "status": check}
    var state := ensure(watcher)
    var charges: Dictionary = state.get("charges", {})
    var used: Dictionary = state.get("encounters_used", {})
    charges[branch] = maxi(0, int(charges.get(branch, 0)) - 1)
    used[_use_key(branch, encounter_id)] = true
    state["charges"] = charges
    state["encounters_used"] = used
    watcher[STATE_KEY] = state
    return {
        "ok": true,
        "branch": branch,
        "encounter_id": encounter_id,
        "charges_remaining": int(charges.get(branch, 0)),
        "charges_max": int((state.get("max_charges", {}) as Dictionary).get(branch, 0))
    }

func _fresh_state(watcher: Dictionary) -> Dictionary:
    var entity_id := str(watcher.get("entity_id", ""))
    var count := charges_for_level(int(watcher.get("level", 1)))
    var charges: Dictionary = {}
    var max_charges: Dictionary = {}
    var branches_value: Variant = BRANCHES_BY_ENTITY.get(entity_id, [])
    var branches: Array = branches_value if branches_value is Array else []
    for branch_value: Variant in branches:
        var branch := str(branch_value)
        charges[branch] = count
        max_charges[branch] = count
    return {"charges": charges, "max_charges": max_charges, "encounters_used": {}}

func _use_key(branch: String, encounter_id: String) -> String:
    return "%s@%s" % [branch, encounter_id]
