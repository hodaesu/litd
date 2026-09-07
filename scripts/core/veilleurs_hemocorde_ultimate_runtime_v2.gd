extends RefCounted
class_name VeilleursHemocordeUltimateRuntimeV2

const ULTIMATE_STATE_SCRIPT := preload("res://scripts/core/veilleurs_ultimate_state_runtime.gd")
const CONTRACT_PATH := "res://data/veilleurs/ultimate_choreography_contract.json"
const AISHA_ID := "ENT_WATCHER_AISHA"
const BRANCH := "hemocorde"
const ULTIMATE_NAME := "Le Dernier Battement"

var ultimate_state: VeilleursUltimateStateRuntime

func _init() -> void:
    ultimate_state = ULTIMATE_STATE_SCRIPT.new() as VeilleursUltimateStateRuntime

func configure_aisha(runtime: Variant, level: int, specialization: String = BRANCH, reset_charges: bool = true) -> Dictionary:
    if runtime == null or not runtime.combatants.has(AISHA_ID):
        return {"ok": false, "reason": "aisha_missing"}
    var aisha: Dictionary = runtime.combatants[AISHA_ID]
    ultimate_state.configure(aisha, level, specialization, reset_charges)
    runtime.combatants[AISHA_ID] = aisha
    return {
        "ok": true,
        "level": int(aisha.get("level", 1)),
        "specialization": str(aisha.get("specialization", "")),
        "ultimate_state": (aisha.get("ultimate_state", {}) as Dictionary).duplicate(true)
    }

func note_vascular_knowledge(runtime: Variant, target_id: String, zone: String, certainty: int = 2) -> Dictionary:
    if runtime == null or not runtime.combatants.has(target_id):
        return {"ok": false, "reason": "target_missing"}
    var target: Dictionary = runtime.combatants[target_id]
    _ensure_physiology(target)
    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    if body == null or not VeilleursBodyComponent.ZONES.has(zone) or body.missing_parts.has(zone):
        return {"ok": false, "reason": "invalid_vascular_zone", "zone": zone}
    var known: Dictionary = target.get("vascular_known_zones", {})
    known[zone] = maxi(int(known.get(zone, 0)), clampi(certainty, 1, 3))
    target["vascular_known_zones"] = known
    target = _refresh_physiology(target)
    runtime.combatants[target_id] = target
    return {"ok": true, "zone": zone, "certainty": int(known[zone]), "physiology": _physiology_snapshot(target)}

func apply_bleeding(runtime: Variant, target_id: String, amount: int, wound_delta: int = 1) -> Dictionary:
    if runtime == null or not runtime.combatants.has(target_id):
        return {"ok": false, "reason": "target_missing"}
    var target: Dictionary = runtime.combatants[target_id]
    _ensure_physiology(target)
    target["bleeding"] = clampi(int(target.get("bleeding", 0)) + maxi(0, amount), 0, 20)
    target["open_wound_count"] = clampi(int(target.get("open_wound_count", 0)) + maxi(0, wound_delta), 0, 12)
    target = _refresh_physiology(target)
    runtime.combatants[target_id] = target
    return {"ok": true, "physiology": _physiology_snapshot(target)}

func post_skill_result(runtime: Variant, attacker_id: String, target_id: String, skill: Dictionary, result: Dictionary) -> Dictionary:
    if runtime == null or attacker_id != AISHA_ID or str(skill.get("tree_name", "")) != "Hémocorde":
        return result
    if not bool(result.get("ok", false)) or not runtime.combatants.has(target_id):
        return result
    var target: Dictionary = runtime.combatants[target_id]
    _ensure_physiology(target)
    var skill_id := str(skill.get("skill_id", ""))
    var zone := str(result.get("zone", "torso"))
    var action := str(result.get("action", skill.get("action_type", "attack")))

    if action == "observe":
        if skill_id == "AÏ-HÉM-06":
            var known: Dictionary = target.get("vascular_known_zones", {})
            known[zone] = maxi(int(known.get(zone, 0)), 2)
            target["vascular_known_zones"] = known
            result["vascular_knowledge"] = {"zone": zone, "certainty": int(known[zone])}
        elif skill_id == "AÏ-HÉM-08":
            target["pulse_read_level"] = maxi(int(target.get("pulse_read_level", 0)), 2)
            result["pulse_read"] = true
    elif bool(result.get("hit", false)):
        var power := float(skill.get("canonical_power_0_5", 0.0))
        var bleeding_gain := 1 + int(power >= 3.5) + int(power >= 4.5)
        if skill_id == "AÏ-HÉM-05" and int(target.get("bleeding", 0)) > 0:
            bleeding_gain += 1
        target["bleeding"] = clampi(int(target.get("bleeding", 0)) + bleeding_gain, 0, 20)
        target["open_wound_count"] = clampi(int(target.get("open_wound_count", 0)) + 1, 0, 12)
        if skill_id == "AÏ-HÉM-09":
            var statuses: Dictionary = target.get("statuses", {})
            statuses["RHYTHM_DISRUPTED"] = {"remaining": 1, "strength": 2}
            target["statuses"] = statuses
            result["status_applied"] = "RHYTHM_DISRUPTED"
        if skill_id == "AÏ-HÉM-14":
            target["circulatory_shock"] = clampi(int(target.get("circulatory_shock", 0)) + 1, 0, 4)

    target = _refresh_physiology(target)
    runtime.combatants[target_id] = target
    result["physiology"] = _physiology_snapshot(target)
    return result

func status(runtime: Variant, attacker_id: String, target_id: String, encounter_id: String) -> Dictionary:
    var result := {
        "available": false,
        "reason": "ultimate_unavailable",
        "attacker": attacker_id,
        "target": target_id,
        "branch": BRANCH,
        "ultimate_name": ULTIMATE_NAME,
        "encounter_id": encounter_id
    }
    if runtime == null or not runtime.combatants.has(attacker_id):
        result["reason"] = "attacker_missing"
        return result
    if attacker_id != AISHA_ID:
        result["reason"] = "wrong_watcher"
        return result
    if not runtime.combatants.has(target_id):
        result["reason"] = "target_missing"
        return result

    var aisha: Dictionary = runtime.combatants[attacker_id]
    var target: Dictionary = runtime.combatants[target_id]
    if str(aisha.get("team", "")) != "watcher" or str(target.get("team", "")) != "enemy":
        result["reason"] = "invalid_teams"
        return result
    var aisha_body: VeilleursBodyComponent = aisha.get("body") as VeilleursBodyComponent
    if aisha_body == null or not bool(aisha_body.functional_flags().get("can_react", false)) or not bool(aisha_body.functional_flags().get("alive", false)):
        result["reason"] = "aisha_function_lost"
        return result
    if aisha_body.missing_parts.has("left_arm") and aisha_body.missing_parts.has("right_arm"):
        result["reason"] = "aisha_function_lost"
        return result
    if int(target.get("hp", 0)) <= 0:
        result["reason"] = "valid_target_required"
        return result
    var distance := int(runtime.grid.distance(attacker_id, target_id))
    if distance < 0 or distance > 1:
        result["reason"] = "target_out_of_contact"
        result["distance"] = distance
        return result

    var charge_check := ultimate_state.status(aisha, BRANCH, encounter_id)
    result["charges_remaining"] = int(charge_check.get("charges_remaining", 0))
    result["charges_max"] = int(charge_check.get("charges_max", 0))
    if not bool(charge_check.get("available", false)):
        result["reason"] = str(charge_check.get("reason", "ultimate_unavailable"))
        return result

    target = _refresh_physiology(target)
    runtime.combatants[target_id] = target
    var physiology := _physiology_snapshot(target)
    result["physiology"] = physiology
    var known: Dictionary = target.get("vascular_known_zones", {})
    var best_zone := _best_known_zone(target)
    if known.is_empty() or best_zone == "":
        result["reason"] = "vascular_knowledge_required"
        return result
    var hp_ratio := float(physiology.get("hp_ratio", 1.0))
    if int(physiology.get("shock", 0)) < 2 or int(physiology.get("bleeding", 0)) < 5 or int(physiology.get("hemorrhage_risk", 0)) < 8 or int(physiology.get("open_wounds", 0)) < 1 or hp_ratio > 0.35:
        result["reason"] = "target_not_compromised_enough"
        return result
    result["selected_zone"] = best_zone
    result["available"] = true
    result["reason"] = "ready"
    return result

func resolve(runtime: Variant, attacker_id: String, target_id: String, encounter_id: String) -> Dictionary:
    var check := status(runtime, attacker_id, target_id, encounter_id)
    if not bool(check.get("available", false)):
        return {"ok": false, "reason": str(check.get("reason", "ultimate_unavailable")), "status": check}

    var aisha: Dictionary = (runtime.combatants[attacker_id] as Dictionary).duplicate(true)
    var target: Dictionary = (runtime.combatants[target_id] as Dictionary).duplicate(true)
    var commit := ultimate_state.commit(aisha, BRANCH, encounter_id)
    if not bool(commit.get("ok", false)):
        return {"ok": false, "reason": str(commit.get("reason", "ultimate_commit_failed")), "status": check}

    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    if body == null:
        return {"ok": false, "reason": "target_body_missing"}
    var selected_zone := str(check.get("selected_zone", "torso"))
    var hp_before := int(target.get("hp", 0))
    var max_hp := maxi(1, int(target.get("max_hp", hp_before)))
    var bleeding_before := int(target.get("bleeding", 0))
    var shock_before := int(target.get("circulatory_shock", 0))
    var risk_before := int(target.get("hemorrhage_risk", 0))
    var open_wounds := int(target.get("open_wound_count", 0))
    var hp_ratio_before := float(hp_before) / float(max_hp)
    var derived_damage := maxi(8, int(round(float(max_hp) * 0.12)) + shock_before * 2 + open_wounds)
    var zone_max := maxi(1, int(body.maximum.get(selected_zone, 100)))
    var trauma := maxi(1, int(round(float(zone_max) * 0.10)))
    var body_result := body.apply_trauma(selected_zone, trauma, 0, 3)

    target["bleeding"] = clampi(bleeding_before + 2, 0, 20)
    target["circulatory_shock"] = clampi(shock_before + 1, 0, 4)
    target["hemorrhage_risk"] = clampi(risk_before + 2, 0, 20)
    target["rhythm_disrupted_rounds"] = maxi(3, int(target.get("rhythm_disrupted_rounds", 0)))
    var statuses: Dictionary = target.get("statuses", {})
    statuses["CIRCULATORY_COLLAPSE"] = {"remaining": 3, "strength": 4}
    statuses["RHYTHM_DISRUPTED"] = {"remaining": 3, "strength": 4}
    target["statuses"] = statuses

    var is_boss := bool(target.get("boss", false)) or bool(target.get("is_boss", false))
    var fatal_collapse := shock_before >= 3 and bleeding_before >= 8 and hp_ratio_before <= 0.20 and not is_boss
    if fatal_collapse:
        target["hp"] = 0
        body.dead = true
    else:
        var hp_after := hp_before - derived_damage
        if is_boss:
            hp_after = maxi(1, hp_after)
        else:
            hp_after = maxi(0, hp_after)
        target["hp"] = hp_after
        if hp_after <= 0:
            body.dead = true

    target = _refresh_physiology(target)
    runtime.combatants[attacker_id] = aisha
    runtime.combatants[target_id] = target
    var result := {
        "ok": true,
        "action": "ultimate",
        "attacker": attacker_id,
        "target": target_id,
        "branch": BRANCH,
        "ultimate_name": ULTIMATE_NAME,
        "commit_state": "ULTIMATE_RESOLVE",
        "zone": selected_zone,
        "hp_before": hp_before,
        "hp_after": int(target.get("hp", 0)),
        "damage": hp_before - int(target.get("hp", 0)),
        "body": body_result,
        "bleeding_before": bleeding_before,
        "bleeding_after": int(target.get("bleeding", 0)),
        "shock_before": shock_before,
        "shock_after": int(target.get("circulatory_shock", 0)),
        "hemorrhage_risk_before": risk_before,
        "hemorrhage_risk_after": int(target.get("hemorrhage_risk", 0)),
        "circulatory_collapse": true,
        "fatal_collapse": fatal_collapse,
        "boss_floor_applied": is_boss and int(target.get("hp", 0)) >= 1,
        "charges_remaining": int(commit.get("charges_remaining", 0)),
        "encounter_id": encounter_id,
        "physiology": _physiology_snapshot(target),
        "presentation": _presentation_contract()
    }
    runtime.action_log.append(result.duplicate(true))
    return result

func _ensure_physiology(target: Dictionary) -> void:
    if not target.has("bleeding"):
        target["bleeding"] = 0
    if not target.has("open_wound_count"):
        target["open_wound_count"] = 0
    if not target.has("circulatory_shock"):
        target["circulatory_shock"] = 0
    if not target.has("hemorrhage_risk"):
        target["hemorrhage_risk"] = 0
    if not target.has("vascular_known_zones"):
        target["vascular_known_zones"] = {}
    if not target.has("pulse_read_level"):
        target["pulse_read_level"] = 0

func _refresh_physiology(target: Dictionary) -> Dictionary:
    _ensure_physiology(target)
    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    var severe_zones := 0
    if body != null:
        for zone: String in VeilleursBodyComponent.ZONES:
            var state := str(body.states.get(zone, "L0"))
            if state in ["L3", "L4", "L5"]:
                severe_zones += 1
    var bleeding := clampi(int(target.get("bleeding", 0)), 0, 20)
    var open_wounds := clampi(int(target.get("open_wound_count", 0)), 0, 12)
    var max_hp := maxi(1, int(target.get("max_hp", 1)))
    var hp_ratio := float(int(target.get("hp", 0))) / float(max_hp)
    var shock := int(target.get("circulatory_shock", 0))
    if hp_ratio <= 0.50:
        shock = maxi(shock, 1)
    if hp_ratio <= 0.35:
        shock = maxi(shock, 2)
    if hp_ratio <= 0.20:
        shock = maxi(shock, 3)
    if bleeding >= 8:
        shock = maxi(shock, 3)
    elif bleeding >= 5:
        shock = maxi(shock, 2)
    shock = clampi(shock, 0, 4)
    var risk := clampi(maxi(int(target.get("hemorrhage_risk", 0)), bleeding + open_wounds * 2 + severe_zones * 2), 0, 20)
    target["bleeding"] = bleeding
    target["open_wound_count"] = open_wounds
    target["circulatory_shock"] = shock
    target["hemorrhage_risk"] = risk
    return target

func _physiology_snapshot(target: Dictionary) -> Dictionary:
    var max_hp := maxi(1, int(target.get("max_hp", 1)))
    return {
        "hp_ratio": float(int(target.get("hp", 0))) / float(max_hp),
        "bleeding": int(target.get("bleeding", 0)),
        "open_wounds": int(target.get("open_wound_count", 0)),
        "shock": int(target.get("circulatory_shock", 0)),
        "hemorrhage_risk": int(target.get("hemorrhage_risk", 0)),
        "vascular_known_zones": (target.get("vascular_known_zones", {}) as Dictionary).duplicate(true),
        "pulse_read_level": int(target.get("pulse_read_level", 0))
    }

func _best_known_zone(target: Dictionary) -> String:
    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    if body == null:
        return ""
    var known: Dictionary = target.get("vascular_known_zones", {})
    var best := ""
    var best_score := -1
    for zone_value: Variant in known.keys():
        var zone := str(zone_value)
        if not VeilleursBodyComponent.ZONES.has(zone) or body.missing_parts.has(zone):
            continue
        var certainty := clampi(int(known.get(zone, 0)), 0, 3)
        if certainty <= 0:
            continue
        var zone_max := maxi(1, int(body.maximum.get(zone, 1)))
        var remaining := int(body.current.get(zone, zone_max))
        var damage_ratio := 1.0 - float(remaining) / float(zone_max)
        var score := certainty * 1000 + int(round(damage_ratio * 100.0))
        if score > best_score:
            best_score = score
            best = zone
    return best

func _presentation_contract() -> Dictionary:
    if not FileAccess.file_exists(CONTRACT_PATH):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
    if not (parsed is Dictionary):
        return {}
    var rows: Dictionary = (parsed as Dictionary).get("ultimates", {})
    return (rows.get("aisha_maren:hemocorde", {}) as Dictionary).duplicate(true)
