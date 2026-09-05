extends RefCounted

const CONDITION_INTACT := "intact"
const CONDITION_BURNED := "burned"
const CONDITION_ABSORBED := "absorbed"
const ScarAging := preload("res://scripts/core/veilleurs_scar_aging_runtime.gd")

static func ensure_state(scar_id: String) -> Dictionary:
    if scar_id == "" or not RemanenceRuntime.world_scars.has(scar_id):
        return {}
    var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    if str(scar.get("type", "")) != "persistent_corpse":
        return {}
    var payload: Dictionary = (scar.get("payload", {}) as Dictionary).duplicate(true)
    var state: Dictionary = (payload.get("corpse_state", {}) as Dictionary).duplicate(true)
    if state.is_empty():
        state = {
            "corpse_id": scar_id,
            "condition": CONDITION_INTACT,
            "burned": false,
            "consumed": false,
            "absorbable": true,
            "reanimable": true,
            "pose_snapshot_id": "%s:pose" % scar_id,
            "ragdoll_resimulation_required": false,
            "body_snapshot": (payload.get("body_snapshot", {}) as Dictionary).duplicate(true),
            "last_transition_run": int(scar.get("created_run", RemanenceRuntime.run_index))
        }
    var changed := _refresh_decay_from_scar(scar, state)
    if not payload.has("corpse_state") or changed:
        payload["corpse_state"] = state.duplicate(true)
        RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    return state.duplicate(true)

static func state(scar_id: String) -> Dictionary:
    return ensure_state(scar_id)

static func reconstruct(scar_id: String) -> Dictionary:
    var corpse := ensure_state(scar_id)
    if corpse.is_empty():
        return {"ok": false, "reason": "corpse_missing"}
    var representation := str(corpse.get("representation", "fresh_body"))
    var physical_body := representation in ["fresh_body", "decomposed_body"]
    return {
        "ok": true,
        "corpse_id": str(corpse.get("corpse_id", scar_id)),
        "corpse_state": corpse.duplicate(true),
        "pose_snapshot_id": str(corpse.get("pose_snapshot_id", "")),
        "representation": representation,
        "decay_stage": str(corpse.get("decay_stage", "fresh")),
        "age_runs": int(corpse.get("age_runs", 0)),
        "reuse_pose_snapshot": physical_body,
        "use_proxy_model": not physical_body,
        "proxy_kind": representation if not physical_body else "",
        "resimulate_ragdoll": false
    }

static func burn(scar_id: String) -> Dictionary:
    var corpse := ensure_state(scar_id)
    if corpse.is_empty():
        return {"ok": false, "reason": "corpse_missing"}
    if bool(corpse.get("consumed", false)):
        return {"ok": false, "reason": "corpse_consumed", "corpse_state": corpse}
    corpse["condition"] = CONDITION_BURNED
    corpse["burned"] = true
    corpse["absorbable"] = false
    corpse["reanimable"] = false
    corpse["last_transition_run"] = RemanenceRuntime.run_index
    _persist(scar_id, corpse)
    return {"ok": true, "corpse_state": corpse.duplicate(true)}

static func can_absorb(scar_id: String) -> bool:
    var corpse := ensure_state(scar_id)
    return not corpse.is_empty() and bool(corpse.get("absorbable", false)) and not bool(corpse.get("burned", false)) and not bool(corpse.get("consumed", false))

static func can_reanimate(scar_id: String) -> bool:
    var corpse := ensure_state(scar_id)
    return not corpse.is_empty() and bool(corpse.get("reanimable", false)) and not bool(corpse.get("burned", false)) and not bool(corpse.get("consumed", false))

static func absorption_intent(corpse_ids: Array, boss_id: String = "mere_des_veines") -> Dictionary:
    var eligible: Array[String] = []
    for value: Variant in corpse_ids:
        var scar_id := str(value)
        if can_absorb(scar_id):
            eligible.append(scar_id)
    eligible.sort()
    if eligible.is_empty():
        return {"ok": false, "reason": "no_admissible_corpse", "telegraphed": false, "eligible_corpse_ids": []}
    var target_id := eligible[0]
    return {
        "ok": true,
        "action_id": "mother_absorb_corpse",
        "boss_id": boss_id,
        "telegraphed": true,
        "target_corpse_id": target_id,
        "eligible_corpse_ids": eligible,
        "summary": "La Mère des Veines relie son réseau au cadavre ciblé avant l'assimilation."
    }

static func resolve_absorption(intent: Dictionary) -> Dictionary:
    if not bool(intent.get("ok", false)) or not bool(intent.get("telegraphed", false)):
        return {"ok": false, "reason": "absorption_not_telegraphed"}
    var scar_id := str(intent.get("target_corpse_id", ""))
    if not can_absorb(scar_id):
        return {"ok": false, "reason": "corpse_not_admissible", "target_corpse_id": scar_id}
    var corpse := ensure_state(scar_id)
    corpse["condition"] = CONDITION_ABSORBED
    corpse["consumed"] = true
    corpse["consumed_by"] = str(intent.get("boss_id", "mere_des_veines"))
    corpse["absorbable"] = false
    corpse["reanimable"] = false
    corpse["last_transition_run"] = RemanenceRuntime.run_index
    _persist(scar_id, corpse)
    return {"ok": true, "target_corpse_id": scar_id, "corpse_state": corpse.duplicate(true)}

static func _refresh_decay_from_scar(scar: Dictionary, corpse: Dictionary) -> bool:
    var presentation := ScarAging.presentation_for_scar(scar)
    if presentation.is_empty():
        return false
    var changed := false
    var decay_stage := str(presentation.get("age_stage", scar.get("age_stage", "fresh")))
    var representation := str(presentation.get("representation", "fresh_body"))
    var age_runs := int(presentation.get("age_runs", scar.get("age_runs", 0)))
    if str(corpse.get("decay_stage", "")) != decay_stage:
        corpse["decay_stage"] = decay_stage
        changed = true
    if str(corpse.get("representation", "")) != representation:
        corpse["representation"] = representation
        changed = true
    if int(corpse.get("age_runs", -1)) != age_runs:
        corpse["age_runs"] = age_runs
        changed = true
    if representation in ["skeletal_remains", "memorial_grave", "memory_trace"] and str(corpse.get("condition", CONDITION_INTACT)) == CONDITION_INTACT:
        if bool(corpse.get("absorbable", true)) or bool(corpse.get("reanimable", true)):
            corpse["absorbable"] = false
            corpse["reanimable"] = false
            changed = true
    return changed

static func _persist(scar_id: String, corpse: Dictionary) -> void:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return
    var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
    var payload: Dictionary = (scar.get("payload", {}) as Dictionary).duplicate(true)
    payload["corpse_state"] = corpse.duplicate(true)
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})