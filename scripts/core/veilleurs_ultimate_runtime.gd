extends RefCounted
class_name VeilleursUltimateRuntime

var pending: Dictionary = {}

func ultimate_for_tree(content_db: Variant, entity_id: String, chosen_tree: String) -> Dictionary:
    var tree_ids: Array[String] = _tree_order(content_db, entity_id)
    var slot := tree_ids.find(chosen_tree) + 1
    if slot <= 0:
        return {}
    for value: Variant in content_db.ultimates_for(entity_id):
        if value is Dictionary and int((value as Dictionary).get("tree_slot", 0)) == slot:
            return (value as Dictionary).duplicate(true)
    return {}

func prepare(runtime: Variant, attacker_id: String, target_id: String, progress_state: Dictionary) -> Dictionary:
    if runtime == null or not runtime.combatants.has(attacker_id):
        return {"ok":false, "reason":"unknown_attacker"}
    var chosen_tree := str(progress_state.get("chosen_tree", (runtime.combatants[attacker_id] as Dictionary).get("chosen_tree", "")))
    var ultimate: Dictionary = ultimate_for_tree(runtime.content_db, attacker_id, chosen_tree)
    if ultimate.is_empty():
        return {"ok":false, "reason":"no_ultimate_for_tree"}
    if not _can_use(progress_state):
        return {"ok":false, "reason":"ultimate_unavailable"}
    if bool(ultimate.get("resolver_required", false)):
        return {"ok":false, "reason":"ultimate_resolver_required", "ultimate_id":str(ultimate.get("ultimate_id", "")), "resolver_id":str(ultimate.get("resolver_id", "")), "charge_spent":false}
    if bool(ultimate.get("telegraph_required", false)):
        pending[attacker_id] = {"ultimate":ultimate, "target_id":target_id, "round":int(runtime.round_index)}
        return {"ok":true, "prepared":true, "ultimate_id":str(ultimate.get("ultimate_id", "")), "name_fr":str(ultimate.get("name_fr", "")), "target":target_id, "telegraph":_telegraph_for(ultimate), "charge_spent":false}
    return execute(runtime, attacker_id, target_id, progress_state, ultimate)

func execute_pending(runtime: Variant, attacker_id: String, progress_state: Dictionary) -> Dictionary:
    if not pending.has(attacker_id):
        return {"ok":false, "reason":"no_pending_ultimate"}
    var state: Dictionary = pending[attacker_id]
    if int(runtime.round_index) <= int(state.get("round", -1)):
        return {"ok":false, "reason":"telegraph_window_not_elapsed"}
    var ultimate: Dictionary = state.get("ultimate", {})
    var target_id := str(state.get("target_id", ""))
    pending.erase(attacker_id)
    return execute(runtime, attacker_id, target_id, progress_state, ultimate)

func execute(runtime: Variant, attacker_id: String, target_id: String, progress_state: Dictionary, ultimate: Dictionary) -> Dictionary:
    if not _can_use(progress_state):
        return {"ok":false, "reason":"ultimate_unavailable"}
    if not runtime.combatants.has(attacker_id):
        return {"ok":false, "reason":"unknown_attacker"}
    var chosen_tree := str(progress_state.get("chosen_tree", (runtime.combatants[attacker_id] as Dictionary).get("chosen_tree", "")))
    var expected: Dictionary = ultimate_for_tree(runtime.content_db, attacker_id, chosen_tree)
    if expected.is_empty() or str(expected.get("ultimate_id", "")) != str(ultimate.get("ultimate_id", "")):
        return {"ok":false, "reason":"ultimate_tree_mismatch"}
    var next_state := progress_state.duplicate(true)
    next_state["ultimate_charges"] = maxi(0, int(next_state.get("ultimate_charges", 0)) - 1)
    var result := _apply(runtime, attacker_id, target_id, ultimate, int(next_state.get("level", 16)))
    result["progress_state"] = next_state
    result["charge_spent"] = true
    return result

func serialize() -> Dictionary:
    return {"pending":pending.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    pending = (payload.get("pending", {}) as Dictionary).duplicate(true)

func _apply(runtime: Variant, attacker_id: String, target_id: String, ultimate: Dictionary, level: int) -> Dictionary:
    var profile := str(ultimate.get("profile", "signature_offense"))
    var result := {"ok":true, "ultimate_id":str(ultimate.get("ultimate_id", "")), "name_fr":str(ultimate.get("name_fr", "")), "attacker":attacker_id, "target":target_id, "profile":profile}
    var attacker: Dictionary = runtime.combatants[attacker_id]
    var target: Dictionary = runtime.combatants.get(target_id, {})
    if profile in ["signature_control", "telegraphed_control", "boss_escalation"]:
        if target.is_empty():
            return {"ok":false, "reason":"ultimate_target_missing"}
        target["statuses"] = _status(target.get("statuses", {}), "PINNED", 1, 5)
        target["statuses"] = _status(target.get("statuses", {}), "EXPOSED", 2, 5)
        target["resolve_current"] = maxi(0, int(target.get("resolve_current", 60)) - (12 + int(level / 8)))
        runtime.combatants[target_id] = target
        result["status_applied"] = ["PINNED", "EXPOSED"]
        return result
    if profile == "signature_mastery":
        attacker["guard_bonus"] = maxi(int(attacker.get("guard_bonus", 0)), 24)
        attacker["statuses"] = _status(attacker.get("statuses", {}), "ADAPTED", 2, 5)
        runtime.combatants[attacker_id] = attacker
        if not target.is_empty():
            target["statuses"] = _status(target.get("statuses", {}), "EXPOSED", 2, 5)
            runtime.combatants[target_id] = target
        result["mastery"] = true
        return result
    if profile == "boss_rule_shift":
        if not target.is_empty():
            target["statuses"] = _status(target.get("statuses", {}), "DISORIENTED", 2, 5)
            runtime.combatants[target_id] = target
        result["rule_shift"] = true
        return result
    var damage := 20 + int(level * 0.35)
    if profile in ["survival_or_execution", "boss_signature"]:
        damage += 10 + int(level * 0.15)
    if target.is_empty():
        var heal := maxi(8, int(round(float(attacker.get("max_hp", 1)) * 0.15)))
        attacker["hp"] = mini(int(attacker.get("max_hp", 1)), int(attacker.get("hp", 0)) + heal)
        runtime.combatants[attacker_id] = attacker
        result["healed"] = heal
        return result
    target["hp"] = maxi(0, int(target.get("hp", 1)) - damage)
    var body: Variant = target.get("body")
    if body != null and body.has_method("apply_trauma"):
        result["body"] = body.call("apply_trauma", "torso", maxi(1, int(damage * 1.15)), 2, 3)
    target["statuses"] = _status(target.get("statuses", {}), "STAGGER", 1, 5)
    runtime.combatants[target_id] = target
    result["damage"] = damage
    result["target_hp"] = int(target["hp"])
    return result

func _tree_order(content_db: Variant, entity_id: String) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in content_db.skills_for(entity_id):
        if not (value is Dictionary):
            continue
        var tree_id := str((value as Dictionary).get("tree_id", ""))
        if tree_id != "" and not result.has(tree_id):
            result.append(tree_id)
    return result

func _can_use(progress_state: Dictionary) -> bool:
    return int(progress_state.get("level", 1)) >= 16 and int(progress_state.get("ultimate_charges", 0)) > 0 and str(progress_state.get("chosen_tree", "")) != ""

func _telegraph_for(ultimate: Dictionary) -> String:
    return "%s se prépare. Le contre-jeu est lisible avant l'exécution." % str(ultimate.get("name_fr", "Ultime"))

func _status(statuses_value: Variant, status: String, duration: int, strength: int) -> Dictionary:
    var statuses: Dictionary = statuses_value.duplicate(true) if statuses_value is Dictionary else {}
    statuses[status] = {"remaining":duration, "strength":strength}
    return statuses