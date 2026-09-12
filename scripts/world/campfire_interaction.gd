extends Area3D
class_name CampfireInteraction

signal rest_completed(zone_id: String, effects: Dictionary)
signal rest_failed(zone_id: String, reason: String)

@export var zone_id := ""
@export var one_use_per_expedition := false
var used_this_expedition := false

func can_rest() -> bool:
    if one_use_per_expedition and used_this_expedition:
        return false
    return true

func interaction_descriptor(_actor: Object = null) -> Dictionary:
    var stable_id := zone_id if zone_id != "" else str(name)
    return EnvironmentInteractionContract.descriptor(
        "campfire:%s" % stable_id,
        EnvironmentInteractionContract.KIND_MECHANISM,
        "Feu de camp",
        "SE REPOSER",
        can_rest(),
        "already_used" if not can_rest() else "",
        used_this_expedition,
        {"one_use_per_expedition": one_use_per_expedition}
    )

func perform_interaction(actor: Object = null) -> Dictionary:
    var current := interaction_descriptor(actor)
    if not bool(current.get("available", false)):
        return EnvironmentInteractionContract.result(current, false, "blocked", str(current.get("blocked_reason", "unavailable")))
    var raw := rest()
    var success := bool(raw.get("success", false))
    return EnvironmentInteractionContract.result(
        current,
        success,
        "rested" if success else "blocked",
        str(raw.get("reason", "interaction_failed" if not success else "")),
        {"rest": raw}
    )

func rest() -> Dictionary:
    if not can_rest():
        rest_failed.emit(zone_id, "already_used")
        return {"success": false, "reason": "already_used"}
    var result := ExpeditionManager.use_campfire()
    if not bool(result.get("success", false)):
        rest_failed.emit(zone_id, str(result.get("reason", "unknown")))
        return result
    used_this_expedition = true
    AshlandsRuntime.use_campfire(zone_id)
    _apply_party_recovery(result.get("effects", {}))
    rest_completed.emit(zone_id, result.get("effects", {}))
    return result

func _apply_party_recovery(effects: Dictionary) -> void:
    var heal_ratio := float(effects.get("party_heal_ratio", 0.0))
    var stress_reduction := int(effects.get("stress_reduction", 0))
    for hero in GameState.party:
        var max_hp := int(hero.get("max_hp", hero.get("hp", 0)))
        if max_hp > 0 and int(hero.get("hp", 0)) > 0:
            hero["hp"] = min(max_hp, int(hero.get("hp", 0)) + int(round(max_hp * heal_ratio)))
    ExpeditionManager.reduce_pressure(stress_reduction)
    GameState.state_changed.emit()
