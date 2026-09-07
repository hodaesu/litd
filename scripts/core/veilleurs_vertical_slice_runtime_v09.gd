extends "res://scripts/core/veilleurs_vertical_slice_runtime_v08.gd"
class_name VeilleursVerticalSliceRuntimeV09

const TACTICAL_V09_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v09.gd")
const AUTHORED_V09_SCRIPT := preload("res://scripts/core/veilleurs_authored_encounter_runtime_v09.gd")
const NEMESIS_SCRIPT := preload("res://scripts/core/veilleurs_nemesis_return_director_v09.gd")

var nemesis_director: VeilleursNemesisReturnDirectorV09
var expedition_watcher_state: Dictionary = {}
var last_materialized_encounter: Dictionary = {}
var pending_recruit_candidates: Array[Dictionary] = []
var recruitment_decisions: Array[Dictionary] = []

func _init() -> void:
    super()
    nemesis_director = NEMESIS_SCRIPT.new() as VeilleursNemesisReturnDirectorV09

func start_dungeon(dungeon_id: String, seed: int = 0) -> Dictionary:
    expedition_watcher_state.clear()
    last_materialized_encounter.clear()
    pending_recruit_candidates.clear()
    recruitment_decisions.clear()
    return super.start_dungeon(dungeon_id, seed)

func launch_current_encounter(context: Dictionary = {}) -> Dictionary:
    if combat != null:
        return {"ok":false, "reason":"combat_already_active"}
    var encounter: Dictionary = campaign.dungeon.active_encounter
    if encounter.is_empty():
        return {"ok":false, "reason":"node_has_no_encounter", "node_id":campaign.dungeon.current_node}
    combat_node_id = campaign.dungeon.current_node
    var region_id := campaign.current_dungeon_id.to_lower()
    var setup: Dictionary = {}
    if bool(encounter.get("boss", false)):
        combat_kind = "boss"
        combat = TACTICAL_V09_SCRIPT.new() as VeilleursTacticalCombatRuntimeV09
        var boss_context := context.duplicate(true)
        boss_context["region_id"] = region_id
        last_materialized_encounter = encounter.duplicate(true)
        setup = combat.setup_boss_combat(str(encounter.get("boss_id", "")), boss_context)
    else:
        combat_kind = "authored"
        var encounter_seed := ("%s|%s|%d" % [campaign.current_dungeon_id, combat_node_id, campaign.expeditions_started]).hash()
        last_materialized_encounter = nemesis_director.inject_returning_enemy(encounter, region_id, encounter_seed)
        combat = AUTHORED_V09_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeV09
        setup = combat.setup_authored_encounter(last_materialized_encounter, region_id)
    if not bool(setup.get("ok", false)):
        combat = null
        combat_kind = ""
        combat_node_id = ""
        return setup
    _apply_campaign_progress_to_combat()
    _restore_expedition_watcher_state()
    setup["expedition_wounds_restored"] = not expedition_watcher_state.is_empty()
    setup["nemesis_injected"] = bool(last_materialized_encounter.get("nemesis_injected", false))
    setup["nemesis_name"] = str(last_materialized_encounter.get("nemesis_name", ""))
    setup["version"] = "0.9.0"
    return setup

func resolve_active_combat(outcome: String, extra_context: Dictionary = {}) -> Dictionary:
    if combat == null:
        return {"ok":false, "reason":"no_active_combat"}
    expedition_watcher_state = _watcher_aftermath().duplicate(true)
    var result: Dictionary = super.resolve_active_combat(outcome, extra_context)
    _sync_expedition_progress_to_campaign()
    if outcome in ["victory", "cleared"]:
        pending_recruit_candidates = _build_recruit_candidates(result.get("enemy_aftermath", []))
    else:
        pending_recruit_candidates.clear()
    result["recruitment_candidates"] = pending_recruit_candidates.duplicate(true)
    result["expedition_watcher_state"] = expedition_watcher_state.duplicate(true)
    result["nemesis_return"] = {
        "injected":bool(last_materialized_encounter.get("nemesis_injected", false)),
        "name":str(last_materialized_encounter.get("nemesis_name", "")),
        "remanence_id":str(last_materialized_encounter.get("nemesis_remanence_id", ""))
    }
    return result

func recruitment_options() -> Array[Dictionary]:
    return pending_recruit_candidates.duplicate(true)

func resolve_recruitment_decision(candidate_index: int, action: String, context: Dictionary = {}) -> Dictionary:
    if candidate_index < 0 or candidate_index >= pending_recruit_candidates.size():
        return {"ok":false, "reason":"candidate_index"}
    if action not in ["recruit", "spare", "leave"]:
        return {"ok":false, "reason":"invalid_action"}
    var candidate: Dictionary = pending_recruit_candidates[candidate_index]
    if bool(candidate.get("resolved", false)):
        return {"ok":false, "reason":"candidate_already_resolved"}
    var remanence_id := str(candidate.get("remanence_id", ""))
    var result: Dictionary = {"ok":true, "action":action, "candidate":candidate.duplicate(true)}
    if action == "recruit":
        var recruited := campaign.attempt_recruit(candidate, context)
        if not bool(recruited.get("ok", false)):
            return recruited
        result["recruitment"] = recruited
        if remanence_id != "" and RemanenceRuntime != null:
            RemanenceRuntime.set_entity_status(remanence_id, "recruited")
    else:
        if remanence_id != "" and RemanenceRuntime != null:
            var event_type := "was_spared" if action == "spare" else "left_behind"
            RemanenceRuntime.record_event(remanence_id, event_type, {
                "region_id":campaign.current_dungeon_id.to_lower(),
                "zone_id":str(last_resolution.get("node_id", "")),
                "summary":"Post-combat decision: %s" % action
            })
        if campaign.archives != null and remanence_id != "":
            campaign.archives.record_history_event(remanence_id, {
                "event_id":"SPARED" if action == "spare" else "LEFT_BEHIND",
                "dungeon_id":campaign.current_dungeon_id,
                "expedition":campaign.expeditions_started
            })
    candidate["resolved"] = true
    candidate["decision"] = action
    pending_recruit_candidates[candidate_index] = candidate
    recruitment_decisions.append({"remanence_id":remanence_id, "action":action, "node_id":str(last_resolution.get("node_id", ""))})
    result["candidate"] = candidate.duplicate(true)
    return result

func current_snapshot() -> Dictionary:
    var result: Dictionary = super.current_snapshot()
    result["version"] = "0.9.0"
    result["expedition_watcher_state"] = expedition_watcher_state.duplicate(true)
    result["recruitment_candidates"] = pending_recruit_candidates.duplicate(true)
    result["last_materialized_encounter"] = last_materialized_encounter.duplicate(true)
    if combat != null and combat.has_method("boss_phase_snapshot"):
        result["boss_phase"] = combat.call("boss_phase_snapshot")
    return result

func serialize() -> Dictionary:
    var payload: Dictionary = super.serialize()
    payload["version"] = "0.9.0"
    payload["v09_expedition_watcher_state"] = expedition_watcher_state.duplicate(true)
    payload["v09_last_materialized_encounter"] = last_materialized_encounter.duplicate(true)
    payload["v09_pending_recruit_candidates"] = pending_recruit_candidates.duplicate(true)
    payload["v09_recruitment_decisions"] = recruitment_decisions.duplicate(true)
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    expedition_watcher_state = (payload.get("v09_expedition_watcher_state", {}) as Dictionary).duplicate(true)
    last_materialized_encounter = (payload.get("v09_last_materialized_encounter", {}) as Dictionary).duplicate(true)
    pending_recruit_candidates.clear()
    for value: Variant in payload.get("v09_pending_recruit_candidates", []):
        if value is Dictionary:
            pending_recruit_candidates.append((value as Dictionary).duplicate(true))
    recruitment_decisions.clear()
    for value: Variant in payload.get("v09_recruitment_decisions", []):
        if value is Dictionary:
            recruitment_decisions.append((value as Dictionary).duplicate(true))
    var combat_payload: Dictionary = payload.get("combat", {})
    if combat_kind == "boss":
        combat = TACTICAL_V09_SCRIPT.new() as VeilleursTacticalCombatRuntimeV09
        return combat.deserialize(combat_payload)
    if combat_kind == "authored":
        combat = AUTHORED_V09_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeV09
        return combat.deserialize(combat_payload)
    return true

func _apply_campaign_progress_to_combat() -> void:
    if combat == null:
        return
    for watcher_id_value: Variant in campaign.watcher_progress.keys():
        var watcher_id := str(watcher_id_value)
        if not combat.combatants.has(watcher_id):
            continue
        var progress: Dictionary = campaign.watcher_progress[watcher_id]
        var row: Dictionary = combat.combatants[watcher_id]
        row["level"] = int(progress.get("level", row.get("level", 1)))
        row["chosen_tree"] = str(progress.get("chosen_tree", row.get("chosen_tree", "")))
        row["ultimate_charges"] = int(progress.get("ultimate_charges", row.get("ultimate_charges", 0)))
        combat.combatants[watcher_id] = row

func _restore_expedition_watcher_state() -> void:
    if combat == null or expedition_watcher_state.is_empty():
        return
    for watcher_id_value: Variant in expedition_watcher_state.keys():
        var watcher_id := str(watcher_id_value)
        if not combat.combatants.has(watcher_id):
            continue
        var saved: Dictionary = expedition_watcher_state[watcher_id]
        var row: Dictionary = combat.combatants[watcher_id]
        row["hp"] = clampi(int(saved.get("hp", row.get("hp", 1))), 0, int(row.get("max_hp", 1)))
        var body_payload: Dictionary = saved.get("body", {})
        var body: Variant = row.get("body")
        if body != null and body.has_method("deserialize") and not body_payload.is_empty():
            body.call("deserialize", body_payload)
            row["body"] = body
        row["level"] = int(saved.get("level", row.get("level", 1)))
        row["chosen_tree"] = str(saved.get("chosen_tree", row.get("chosen_tree", "")))
        row["ultimate_charges"] = int(saved.get("ultimate_charges", row.get("ultimate_charges", 0)))
        combat.combatants[watcher_id] = row

func _sync_expedition_progress_to_campaign() -> void:
    for watcher_id_value: Variant in expedition_watcher_state.keys():
        var watcher_id := str(watcher_id_value)
        if not campaign.watcher_progress.has(watcher_id):
            continue
        var aftermath: Dictionary = expedition_watcher_state[watcher_id]
        var progress: Dictionary = campaign.watcher_progress[watcher_id]
        progress["level"] = maxi(int(progress.get("level", 1)), int(aftermath.get("level", 1)))
        if str(aftermath.get("chosen_tree", "")) != "":
            progress["chosen_tree"] = str(aftermath.get("chosen_tree", ""))
        progress["ultimate_charges"] = int(aftermath.get("ultimate_charges", progress.get("ultimate_charges", 0)))
        campaign.watcher_progress[watcher_id] = progress

func _build_recruit_candidates(values: Variant) -> Array[Dictionary]:
    var candidates: Array[Dictionary] = []
    if not (values is Array):
        return candidates
    for value: Variant in values:
        if not (value is Dictionary):
            continue
        var enemy: Dictionary = (value as Dictionary).duplicate(true)
        if int(enemy.get("hp", 0)) <= 0:
            continue
        var definition_id := str(enemy.get("entity_id", ""))
        if not definition_id.begins_with("ENT_ENEMY_"):
            continue
        var remanence_id := str(enemy.get("remanence_id", ""))
        if remanence_id != "" and RemanenceRuntime != null:
            var state: Dictionary = RemanenceRuntime.entity_state(remanence_id)
            if str(state.get("status", "active")) != "active":
                continue
            enemy["remanence_stage"] = str(state.get("stage", enemy.get("remanence_stage", "normal")))
            enemy["remanence_score"] = int(state.get("score", 0))
            enemy["adaptations"] = (state.get("adaptations", []) as Array).duplicate(true)
        enemy["definition_id"] = definition_id
        enemy["resolved"] = false
        candidates.append(enemy)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var stage_a := _stage_rank(str(a.get("remanence_stage", "normal")))
        var stage_b := _stage_rank(str(b.get("remanence_stage", "normal")))
        if stage_a != stage_b:
            return stage_a > stage_b
        return int(a.get("remanence_score", 0)) > int(b.get("remanence_score", 0))
    )
    while candidates.size() > 3:
        candidates.pop_back()
    return candidates

func _stage_rank(stage: String) -> int:
    match stage:
        "nemesis": return 4
        "elite": return 3
        "veteran": return 2
        "memorial": return 1
        _: return 0
