extends Area3D
class_name ResourceNode

signal harvested(node_id: String, drops: Array)

@export var node_id := ""
@export var resource_type := "food"
@export var amount_min := 1
@export var amount_max := 1
@export var one_shot := true
@export var persist_depleted := true

var depleted := false

func can_interact() -> bool:
    return not depleted

func interaction_descriptor(_actor: Object = null) -> Dictionary:
    var stable_id := node_id if node_id != "" else str(name)
    return EnvironmentInteractionContract.descriptor(
        "resource:%s" % stable_id,
        EnvironmentInteractionContract.KIND_RESOURCE,
        "Ressource · %s" % resource_type.capitalize(),
        "RÉCOLTER",
        can_interact(),
        "depleted" if depleted else "",
        depleted,
        {"resource_type": resource_type}
    )

func perform_interaction(actor: Object = null) -> Dictionary:
    var current := interaction_descriptor(actor)
    if not bool(current.get("available", false)):
        return EnvironmentInteractionContract.result(current, false, "blocked", str(current.get("blocked_reason", "depleted")))
    var drops := harvest()
    return EnvironmentInteractionContract.result(
        current,
        not drops.is_empty(),
        "harvested" if not drops.is_empty() else "blocked",
        "no_drop" if drops.is_empty() else "",
        {"drops": drops}
    )

func harvest(rng: RandomNumberGenerator = null) -> Array:
    if depleted:
        return []
    var local_rng := rng
    if local_rng == null:
        local_rng = RandomNumberGenerator.new()
        local_rng.randomize()
    var amount := local_rng.randi_range(amount_min, amount_max)
    ExpeditionManager.add_resource(resource_type, amount)
    if one_shot:
        depleted = true
        if persist_depleted and node_id != "":
            AshlandsRuntime.mark_resource_collected(node_id)
    var drops := [{"item": resource_type, "amount": amount}]
    harvested.emit(node_id, drops)
    return drops

func sync_from_runtime() -> void:
    if persist_depleted and node_id != "":
        depleted = AshlandsRuntime.is_resource_collected(node_id)
