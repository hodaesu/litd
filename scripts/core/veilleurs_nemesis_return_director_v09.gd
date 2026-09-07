extends RefCounted
class_name VeilleursNemesisReturnDirectorV09

const MAX_INJECTED := 1
const ELIGIBLE_STAGES: Array[String] = ["elite", "nemesis"]
const ELIGIBLE_STATUSES: Array[String] = ["active"]
const MAX_ENCOUNTER_SIZE := 10

func inject_returning_enemy(encounter: Dictionary, region_id: String, seed: int = 0) -> Dictionary:
    var result: Dictionary = encounter.duplicate(true)
    result["nemesis_injected"] = false
    result["nemesis_candidates"] = 0
    if encounter.is_empty() or bool(encounter.get("boss", false)) or RemanenceRuntime == null:
        return result
    var composition: Array = (result.get("composition", []) as Array).duplicate(true)
    if composition.size() >= MAX_ENCOUNTER_SIZE:
        return result
    for member_value: Variant in composition:
        if member_value is Dictionary and str((member_value as Dictionary).get("remanence_id", "")) != "":
            return result
    var candidates := candidates_for_region(region_id)
    result["nemesis_candidates"] = candidates.size()
    if candidates.is_empty():
        return result
    var selected: Dictionary = candidates[_deterministic_index(candidates.size(), seed)]
    var definition_id := str(selected.get("species_id", ""))
    var remanence_id := str(selected.get("id", ""))
    if definition_id == "" or remanence_id == "":
        return result
    composition.append({
        "definition_id": definition_id,
        "remanence_id": remanence_id,
        "returning_enemy": true,
        "remanence_stage": str(selected.get("stage", "elite"))
    })
    result["composition"] = composition
    result["nemesis_injected"] = true
    result["nemesis_remanence_id"] = remanence_id
    result["nemesis_stage"] = str(selected.get("stage", "elite"))
    result["nemesis_name"] = str(selected.get("name", definition_id))
    return result

func candidates_for_region(region_id: String) -> Array[Dictionary]:
    var same_region: Array[Dictionary] = []
    var elsewhere: Array[Dictionary] = []
    if RemanenceRuntime == null:
        return same_region
    for id_value: Variant in RemanenceRuntime.entities.keys():
        var remanence_id := str(id_value)
        var state: Dictionary = RemanenceRuntime.entity_state(remanence_id)
        if not _eligible(state):
            continue
        if str(state.get("region_id", "")) == region_id:
            same_region.append(state)
        else:
            elsewhere.append(state)
    _sort_candidates(same_region)
    _sort_candidates(elsewhere)
    return same_region if not same_region.is_empty() else elsewhere

func _eligible(state: Dictionary) -> bool:
    if state.is_empty():
        return false
    if str(state.get("stage", "normal")) not in ELIGIBLE_STAGES:
        return false
    if str(state.get("status", "active")) not in ELIGIBLE_STATUSES:
        return false
    if int(state.get("encounters", 0)) < 2 or int(state.get("score", 0)) < 10:
        return false
    var remanence_id := str(state.get("id", ""))
    var events: Array[Dictionary] = RemanenceRuntime.recent_events(remanence_id, 1)
    if not events.is_empty() and str(events[0].get("type", "")) == "killed":
        return false
    var body_snapshot: Dictionary = state.get("body_snapshot", {})
    if not body_snapshot.is_empty() and int(body_snapshot.get("max_hp", 1)) > 0 and int(body_snapshot.get("hp", 1)) <= 0:
        return false
    return str(state.get("species_id", "")) != ""

func _sort_candidates(values: Array[Dictionary]) -> void:
    values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var stage_a := _stage_rank(str(a.get("stage", "normal")))
        var stage_b := _stage_rank(str(b.get("stage", "normal")))
        if stage_a != stage_b:
            return stage_a > stage_b
        var score_a := int(a.get("score", 0))
        var score_b := int(b.get("score", 0))
        if score_a != score_b:
            return score_a > score_b
        var encounters_a := int(a.get("encounters", 0))
        var encounters_b := int(b.get("encounters", 0))
        if encounters_a != encounters_b:
            return encounters_a > encounters_b
        return str(a.get("id", "")) < str(b.get("id", ""))
    )

func _stage_rank(stage: String) -> int:
    return 2 if stage == "nemesis" else (1 if stage == "elite" else 0)

func _deterministic_index(size: int, seed: int) -> int:
    if size <= 1:
        return 0
    return posmod(seed, mini(size, MAX_INJECTED)) if MAX_INJECTED > 1 else 0
