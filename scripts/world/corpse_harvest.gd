extends Area3D
class_name CorpseHarvest

signal harvested(corpse_id: String, drops: Array)

@export var corpse_id := ""
@export_enum("crow", "dog", "humanoid", "undead") var corpse_type := "humanoid"
@export var persist_harvested := true

var already_harvested := false

func can_interact() -> bool:
    return not already_harvested

func harvest() -> Array:
    if already_harvested:
        return []
    var drops := ExpeditionManager.harvest_corpse(corpse_type)
    already_harvested = true
    if persist_harvested and corpse_id != "":
        AshlandsRuntime.mark_resource_collected("corpse:" + corpse_id)
    harvested.emit(corpse_id, drops)
    return drops

func sync_from_runtime() -> void:
    if persist_harvested and corpse_id != "":
        already_harvested = AshlandsRuntime.is_resource_collected("corpse:" + corpse_id)
