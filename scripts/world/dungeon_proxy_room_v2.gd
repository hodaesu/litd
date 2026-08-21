extends "res://scripts/world/dungeon_proxy_room.gd"

# v2 conserve exactement la géométrie de gameplay/collisions du blockout validé
# et ajoute une couche de lecture architecturale remplaçable par Blender.
const FIRST_VEIL_ARCHITECTURE_KIT := preload("res://scripts/world/first_veil_architecture_kit.gd")

var architecture_kit: RefCounted = FIRST_VEIL_ARCHITECTURE_KIT.new()
var architecture_summary: Dictionary = {}

func _rebuild() -> void:
    super._rebuild()
    architecture_summary = {}
    if room_spec.is_empty():
        return
    architecture_summary = architecture_kit.decorate(self, room_spec)

func room_summary() -> Dictionary:
    var summary: Dictionary = super.room_summary()
    summary["architecture"] = architecture_summary.duplicate(true)
    summary["blender_contract_ready"] = not architecture_kit.blender_contract().is_empty()
    summary["architecture_kit_version"] = int(architecture_summary.get("kit_version", 0))
    return summary
