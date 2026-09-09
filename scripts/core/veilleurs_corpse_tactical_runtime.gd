extends RefCounted
class_name VeilleursCorpseTacticalRuntime

const MIN_SLOT := 0
const MAX_SLOT := 3
const DESTROYED_STATES := ["destroyed", "consumed", "burned"]

func place(scar_id: String, slot: int, blocks_slot: bool = true) -> Dictionary:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return {"ok": false, "reason": "scar_missing"}
    if slot < MIN_SLOT or slot > MAX_SLOT:
        return {"ok": false, "reason": "invalid_slot", "slot": slot}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    if str(scar.get("type", "")) != "persistent_corpse":
        return {"ok": false, "reason": "not_a_corpse"}
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    if str(payload.get("corpse_state", "intact")) in DESTROYED_STATES:
        return {"ok": false, "reason": "corpse_unusable"}
    payload["combat_slot"] = slot
    payload["blocks_combat_slot"] = blocks_slot
    payload["corpse_state"] = "moved" if int(payload.get("move_count", 0)) > 0 else str(payload.get("corpse_state", "intact"))
    payload["last_tactical_move_run"] = RemanenceRuntime.run_index
    payload["move_count"] = int(payload.get("move_count", 0)) + 1
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    return {"ok": true, "scar_id": scar_id, "slot": slot, "blocks_slot": blocks_slot}

func destroy(scar_id: String, cause: String = "combat") -> Dictionary:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return {"ok": false, "reason": "scar_missing"}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    if str(scar.get("type", "")) != "persistent_corpse":
        return {"ok": false, "reason": "not_a_corpse"}
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    if str(payload.get("corpse_state", "intact")) in DESTROYED_STATES:
        return {"ok": false, "reason": "already_destroyed"}
    payload["corpse_state"] = "destroyed"
    payload["blocks_combat_slot"] = false
    payload["prepared_as_cover"] = false
    payload["destroyed_by"] = cause
    payload["destroyed_run"] = RemanenceRuntime.run_index
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload, "severity": "regional"})
    var origin_entity_id := str(scar.get("origin_entity_id", ""))
    if origin_entity_id != "":
        RemanenceRuntime.record_event(origin_entity_id, "corpse_destroyed", {
            "scar_id": scar_id,
            "cause": cause,
            "summary": "Le corps persistant est détruit pendant un affrontement."
        })
    return {"ok": true, "scar_id": scar_id, "state": "destroyed", "cause": cause}

func snapshot(scar_ids: Array = []) -> Dictionary:
    var ids: Array = scar_ids.duplicate()
    if ids.is_empty():
        for scar_id_value: Variant in RemanenceRuntime.world_scars.keys():
            var scar_id := str(scar_id_value)
            var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
            if str(scar.get("type", "")) == "persistent_corpse":
                ids.append(scar_id)
    var corpses: Array[Dictionary] = []
    var blocked_slots: Array[int] = []
    var cover_by_slot: Dictionary = {}
    for scar_id_value: Variant in ids:
        var scar_id := str(scar_id_value)
        if not RemanenceRuntime.world_scars.has(scar_id):
            continue
        var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
        var payload: Dictionary = scar.get("payload", {})
        var state := str(payload.get("corpse_state", "intact"))
        if state in DESTROYED_STATES:
            continue
        var slot := clampi(int(payload.get("combat_slot", -1)), -1, MAX_SLOT)
        var blocks := bool(payload.get("blocks_combat_slot", false)) and slot >= MIN_SLOT
        var prepared := bool(payload.get("prepared_as_cover", false))
        var cover := int(payload.get("cover_quality", 0)) if prepared else 15
        if blocks and not blocked_slots.has(slot):
            blocked_slots.append(slot)
        if slot >= MIN_SLOT:
            cover_by_slot[slot] = maxi(int(cover_by_slot.get(slot, 0)), cover)
        corpses.append({
            "scar_id": scar_id,
            "slot": slot,
            "blocks_slot": blocks,
            "prepared_as_cover": prepared,
            "cover_quality": cover,
            "state": state
        })
    blocked_slots.sort()
    return {
        "corpses": corpses,
        "blocked_slots": blocked_slots,
        "cover_by_slot": cover_by_slot,
        "corpse_count": corpses.size(),
        "has_corpses": not corpses.is_empty()
    }

func can_move_to_slot(slot: int, scar_ids: Array = []) -> bool:
    if slot < MIN_SLOT or slot > MAX_SLOT:
        return false
    return not (snapshot(scar_ids).get("blocked_slots", []) as Array).has(slot)

func skill_context(scar_ids: Array = []) -> Dictionary:
    var state := snapshot(scar_ids)
    var prepared := 0
    for corpse_value: Variant in state.get("corpses", []):
        if bool((corpse_value as Dictionary).get("prepared_as_cover", false)):
            prepared += 1
    return {
        "corpse_count": int(state.get("corpse_count", 0)),
        "prepared_corpse_count": prepared,
        "blocked_slots": (state.get("blocked_slots", []) as Array).duplicate(),
        "corpse_skill_available": int(state.get("corpse_count", 0)) > 0,
        "tags": ["CADAVRE", "COUVERTURE"] if int(state.get("corpse_count", 0)) > 0 else []
    }

func consume_for_skill(scar_id: String, skill_id: String, effect: String = "consume") -> Dictionary:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return {"ok": false, "reason": "scar_missing"}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    if str(payload.get("corpse_state", "intact")) in DESTROYED_STATES:
        return {"ok": false, "reason": "corpse_unusable"}
    payload["last_skill_id"] = skill_id
    payload["last_skill_effect"] = effect
    payload["last_skill_run"] = RemanenceRuntime.run_index
    if effect == "consume":
        payload["corpse_state"] = "consumed"
        payload["blocks_combat_slot"] = false
        payload["prepared_as_cover"] = false
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    return {"ok": true, "scar_id": scar_id, "skill_id": skill_id, "effect": effect, "state": payload.get("corpse_state", "intact")}
