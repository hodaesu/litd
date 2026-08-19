extends Area3D
class_name FieldEncounterTrigger

var event_id: String = ""
var encounter_name: String = "Rencontre"
var encounter_type: String = "survivor_choice"

func configure(definition: Dictionary) -> void:
    event_id = str(definition.get("id", ""))
    encounter_name = str(definition.get("name", event_id))
    encounter_type = str(definition.get("type", "survivor_choice"))
    set_meta("display_name", encounter_name)
    set_meta("field_encounter", true)
    _build_visual(definition)
    if not FieldEncounterRuntime.encounter_resolved.is_connected(_on_encounter_resolved):
        FieldEncounterRuntime.encounter_resolved.connect(_on_encounter_resolved)
    _refresh_visibility()

func can_interact() -> bool:
    return event_id != "" and not FieldEncounterRuntime.is_resolved(event_id)

func interact() -> void:
    if can_interact():
        FieldEncounterRuntime.open_encounter(event_id)

func _on_encounter_resolved(resolved_id: String, _outcome: String) -> void:
    if resolved_id == event_id:
        _refresh_visibility()

func _refresh_visibility() -> void:
    var active: bool = can_interact()
    monitoring = active
    monitorable = active
    visible = active

func _build_visual(definition: Dictionary) -> void:
    if has_node("BlockoutVisual"):
        return
    var visual := Node3D.new()
    visual.name = "BlockoutVisual"
    add_child(visual)

    var base_material := StandardMaterial3D.new()
    base_material.albedo_color = Color(0.19, 0.16, 0.14, 1.0)
    base_material.roughness = 0.95
    var accent_material := StandardMaterial3D.new()
    accent_material.albedo_color = Color(0.50, 0.37, 0.18, 1.0)
    accent_material.roughness = 0.88

    if encounter_type == "survivor_choice":
        for index in range(3):
            var figure := MeshInstance3D.new()
            var capsule := CapsuleMesh.new()
            capsule.radius = 0.34
            capsule.height = 1.45
            capsule.material = base_material
            figure.mesh = capsule
            figure.position = Vector3(float(index - 1) * 0.82, 0.78, 0.18 * float(index % 2))
            figure.rotation.z = -0.20 + float(index) * 0.18
            visual.add_child(figure)
        var beam := MeshInstance3D.new()
        var beam_mesh := BoxMesh.new()
        beam_mesh.size = Vector3(3.4, 0.22, 0.34)
        beam_mesh.material = accent_material
        beam.mesh = beam_mesh
        beam.position = Vector3(0.0, 1.45, 0.1)
        beam.rotation.z = -0.32
        visual.add_child(beam)
    else:
        var marker := MeshInstance3D.new()
        var marker_mesh := CylinderMesh.new()
        marker_mesh.top_radius = 0.55
        marker_mesh.bottom_radius = 0.75
        marker_mesh.height = 1.35
        marker_mesh.material = accent_material
        marker.mesh = marker_mesh
        marker.position = Vector3(0.0, 0.68, 0.0)
        visual.add_child(marker)
        var sign := MeshInstance3D.new()
        var sign_mesh := BoxMesh.new()
        sign_mesh.size = Vector3(1.8, 0.08, 1.0)
        sign_mesh.material = base_material
        sign.mesh = sign_mesh
        sign.position = Vector3(0.0, 1.42, 0.0)
        sign.rotation.x = -0.12
        visual.add_child(sign)

    var label := Label3D.new()
    label.text = "%s\nINTERAGIR" % str(definition.get("name", "Rencontre"))
    label.position = Vector3(0.0, 2.45, 0.0)
    label.font_size = 42
    label.outline_size = 9
    label.modulate = Color("#d5b26c")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    visual.add_child(label)
