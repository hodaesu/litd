extends Node

func _ready() -> void:
    if not AshlandsRuntime.zone_discovered.is_connected(_on_zone_discovered):
        AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    if not AshlandsSceneRouter.zone_load_finished.is_connected(_on_zone_loaded):
        AshlandsSceneRouter.zone_load_finished.connect(_on_zone_loaded)

func _on_zone_discovered(zone_id: String) -> void:
    call_deferred("_inject_zone", zone_id)

func _on_zone_loaded(zone_id: String) -> void:
    call_deferred("_inject_zone", zone_id)

func _inject_zone(zone_id: String) -> void:
    var definitions: Array[Dictionary] = FieldEncounterRuntime.encounters_for(CampaignState.current_chapter_number(), zone_id)
    if definitions.is_empty():
        return
    var generated := _find_generated_blockout()
    if generated == null:
        return
    var parent := generated.get_node_or_null("ReactiveFieldEncounters") as Node3D
    if parent == null:
        parent = Node3D.new()
        parent.name = "ReactiveFieldEncounters"
        generated.add_child(parent)
    for definition in definitions:
        var event_id: String = str(definition.get("id", ""))
        if event_id == "" or parent.has_node(event_id):
            continue
        var trigger := FieldEncounterTrigger.new()
        trigger.name = event_id
        trigger.position = _vec3(definition.get("position", [0, 0, 0]))
        _add_collision(trigger)
        parent.add_child(trigger)
        trigger.configure(definition)

func _find_generated_blockout() -> Node3D:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    var generated := scene.find_child("GeneratedBlockout", true, false)
    return generated as Node3D if generated is Node3D else null

func _add_collision(area: Area3D) -> void:
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.6
    collision.shape = shape
    collision.position = Vector3(0.0, 1.0, 0.0)
    area.add_child(collision)

func _vec3(value: Variant) -> Vector3:
    if not value is Array or value.size() < 3:
        return Vector3.ZERO
    return Vector3(float(value[0]), float(value[1]), float(value[2]))
