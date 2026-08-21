extends "res://scripts/world/dungeon_proxy_room.gd"

signal interaction_focus_changed(interaction_id: String, label: String)
signal interaction_requested(interaction_id: String, label: String)

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
    _connect_explorer_interactions()

func _connect_explorer_interactions() -> void:
    if explorer == null:
        return
    if explorer.has_signal("interaction_focus_changed"):
        explorer.connect("interaction_focus_changed", Callable(self, "_on_explorer_interaction_focus_changed"))
    if explorer.has_signal("interaction_requested"):
        explorer.connect("interaction_requested", Callable(self, "_on_explorer_interaction_requested"))

func _on_explorer_interaction_focus_changed(interaction_id: String, label: String) -> void:
    interaction_focus_changed.emit(interaction_id, label)

func _on_explorer_interaction_requested(interaction_id: String, label: String) -> void:
    interaction_requested.emit(interaction_id, label)

func nearest_interaction_for(world_position: Vector3, radius: float) -> Dictionary:
    var root: Node = find_child("InteractionAnchors", true, false)
    if root == null:
        return {}
    var best: Dictionary = {}
    var best_distance := radius
    for child in root.get_children():
        if child is Marker3D:
            var marker := child as Marker3D
            var distance := marker.global_position.distance_to(world_position)
            if distance <= best_distance:
                best_distance = distance
                best = {
                    "id": marker.name,
                    "label": str(marker.get_meta("interaction_label", "Interaction")),
                    "distance": distance
                }
    return best

func room_summary() -> Dictionary:
    var summary: Dictionary = super.room_summary()
    summary["architecture"] = architecture_summary.duplicate(true)
    summary["blender_contract_ready"] = not architecture_kit.blender_contract().is_empty()
    summary["architecture_kit_version"] = int(architecture_summary.get("kit_version", 0))
    summary["contextual_interactions"] = true
    return summary
