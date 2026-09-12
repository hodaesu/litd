extends Node

const REQUIRED_DESCRIPTOR_FIELDS := [
    "interaction_id",
    "kind",
    "label",
    "verb",
    "available",
    "blocked_reason",
    "consumed",
    "inspect",
]
const REQUIRED_RESULT_FIELDS := [
    "interaction_id",
    "kind",
    "success",
    "outcome",
    "reason",
    "payload",
]

var failures: Array[String] = []

class ContractProbe:
    extends Node
    var performed := 0

    func interaction_descriptor(_actor: Object = null) -> Dictionary:
        return EnvironmentInteractionContract.descriptor(
            "probe:authored",
            EnvironmentInteractionContract.KIND_MECHANISM,
            "Mécanisme témoin",
            "ACTIVER"
        )

    func perform_interaction(_actor: Object = null) -> Dictionary:
        performed += 1
        return EnvironmentInteractionContract.result(interaction_descriptor(), true, "activated", "", {"performed": performed})

class LegacyHarvestProbe:
    extends Node
    var harvested := 0

    func can_interact() -> bool:
        return true

    func harvest() -> Array:
        harvested += 1
        return [{"item": "legacy_probe", "amount": 1}]

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    _check_authored_contract()
    _check_legacy_adapter()
    _check_representative_world_objects()
    _check_controller_adapter()
    _finish()

func _check_authored_contract() -> void:
    var probe := ContractProbe.new()
    add_child(probe)
    var descriptor := EnvironmentInteractionContract.describe(probe, self)
    _check_descriptor(descriptor, "authored descriptor")
    _check(str(descriptor.get("interaction_id", "")) == "probe:authored", "authored stable id is preserved")
    _check(str(descriptor.get("verb", "")) == "ACTIVER", "authored verb is preserved")
    var result := EnvironmentInteractionContract.perform(probe, self)
    _check_result(result, "authored result")
    _check(bool(result.get("success", false)), "authored interaction succeeds")
    _check(str(result.get("outcome", "")) == "activated", "authored outcome is preserved")
    _check(probe.performed == 1, "specialized perform_interaction remains owner of effect")
    probe.queue_free()

func _check_legacy_adapter() -> void:
    var legacy := LegacyHarvestProbe.new()
    legacy.name = "LegacyHarvest"
    add_child(legacy)
    _check(EnvironmentInteractionContract.supports(legacy), "legacy harvest target remains supported")
    var descriptor := EnvironmentInteractionContract.describe(legacy, self)
    _check_descriptor(descriptor, "legacy descriptor")
    _check(bool((descriptor.get("inspect", {}) as Dictionary).get("legacy_adapter", false)), "legacy target is explicitly marked as adapted")
    var result := EnvironmentInteractionContract.perform(legacy, self)
    _check_result(result, "legacy result")
    _check(bool(result.get("success", false)), "legacy harvest remains executable")
    _check(legacy.harvested == 1, "legacy harvest effect executes exactly once")
    legacy.queue_free()

func _check_representative_world_objects() -> void:
    var gate := ShortcutGate.new()
    var gate_descriptor := gate.interaction_descriptor(self)
    _check_descriptor(gate_descriptor, "shortcut gate")
    _check(str(gate_descriptor.get("kind", "")) == EnvironmentInteractionContract.KIND_DOOR, "shortcut gate is typed as door")
    _check(not bool(gate_descriptor.get("available", true)), "missing shortcut id is blocked")
    _check(str(gate_descriptor.get("blocked_reason", "")) == "missing_shortcut_id", "shortcut blocked reason is explicit")

    var resource := ResourceNode.new()
    resource.node_id = "smoke_resource"
    resource.resource_type = "food"
    var resource_descriptor := resource.interaction_descriptor(self)
    _check_descriptor(resource_descriptor, "resource node")
    _check(str(resource_descriptor.get("interaction_id", "")) == "resource:smoke_resource", "resource has stable id")
    _check(str(resource_descriptor.get("kind", "")) == EnvironmentInteractionContract.KIND_RESOURCE, "resource node is typed")
    resource.depleted = true
    var blocked_resource := EnvironmentInteractionContract.perform(resource, self)
    _check_result(blocked_resource, "blocked resource result")
    _check(not bool(blocked_resource.get("success", true)), "depleted resource stays blocked")
    _check(str(blocked_resource.get("reason", "")) == "depleted", "depleted reason survives normalization")

    var lore := LoreCollectible.new()
    var lore_descriptor := lore.interaction_descriptor(self)
    _check_descriptor(lore_descriptor, "lore curiosity")
    _check(str(lore_descriptor.get("kind", "")) == EnvironmentInteractionContract.KIND_CURIOSITY, "lore is typed as curiosity")
    _check(str(lore_descriptor.get("blocked_reason", "")) == "missing_entry", "empty lore exposes blocked reason")

    var corpse := VeilleursVS001CorpseProxy.new()
    var corpse_descriptor := corpse.interaction_descriptor(self)
    _check_descriptor(corpse_descriptor, "corpse proxy")
    _check(str(corpse_descriptor.get("kind", "")) == EnvironmentInteractionContract.KIND_CORPSE, "corpse keeps dedicated kind")
    _check(str(corpse_descriptor.get("verb", "")) == "AGIR SUR LE CORPS", "corpse keeps explicit player-facing verb")

    var anchor := VeilleursVS001InteractionProxy.new()
    var anchor_descriptor := anchor.interaction_descriptor(self)
    _check_descriptor(anchor_descriptor, "VS001 anchor")
    _check(str(anchor_descriptor.get("blocked_reason", "")) == "missing_anchor_id", "empty anchor is safely blocked")

    var campfire := CampfireInteraction.new()
    campfire.zone_id = "smoke_camp"
    var camp_descriptor := campfire.interaction_descriptor(self)
    _check_descriptor(camp_descriptor, "campfire")
    _check(str(camp_descriptor.get("interaction_id", "")) == "campfire:smoke_camp", "campfire has stable id")
    _check(str(camp_descriptor.get("kind", "")) == EnvironmentInteractionContract.KIND_MECHANISM, "campfire is typed as mechanism")
    _check(str(camp_descriptor.get("verb", "")) == "SE REPOSER", "campfire exposes its own verb")

    gate.free()
    resource.free()
    lore.free()
    corpse.free()
    anchor.free()
    campfire.free()

func _check_controller_adapter() -> void:
    var controller := ExplorationPartyController.new()
    var probe := ContractProbe.new()
    var descriptor := controller.interaction_descriptor_for(probe)
    _check_descriptor(descriptor, "controller descriptor adapter")
    _check(str(descriptor.get("interaction_id", "")) == "probe:authored", "controller reads contract without knowing target type")
    controller.free()
    probe.free()

func _check_descriptor(value: Dictionary, context: String) -> void:
    for field in REQUIRED_DESCRIPTOR_FIELDS:
        _check(value.has(field), "%s contains %s" % [context, field])
    _check(not str(value.get("interaction_id", "")).is_empty(), "%s has non-empty id" % context)
    _check(not str(value.get("label", "")).is_empty(), "%s has text label" % context)
    _check(not str(value.get("verb", "")).is_empty(), "%s has text verb" % context)

func _check_result(value: Dictionary, context: String) -> void:
    for field in REQUIRED_RESULT_FIELDS:
        _check(value.has(field), "%s contains %s" % [context, field])

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("ENVIRONMENT_INTERACTION_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("ENVIRONMENT_INTERACTION_CONTRACT_FAIL: %s" % failure)
    get_tree().quit(1)
