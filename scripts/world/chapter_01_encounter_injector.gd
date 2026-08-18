extends Node

const DATA_PATH := "res://data/levels/chapter_01_story_encounters.json"

var data: Dictionary = {}

func _ready() -> void:
    data = _load_json(DATA_PATH)
    AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    AshlandsSceneRouter.zone_load_finished.connect(_on_zone_loaded)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _on_zone_discovered(zone_id: String) -> void:
    call_deferred("_inject_zone", zone_id)

func _on_zone_loaded(zone_id: String) -> void:
    call_deferred("_inject_zone", zone_id)

func _inject_zone(zone_id: String) -> void:
    if CampaignState.current_chapter_number() > 1:
        return
    var definitions: Array = data.get("zones", {}).get(zone_id, [])
    if definitions.is_empty():
        return
    var generated := _find_generated_blockout()
    if generated == null:
        return
    var parent := generated.get_node_or_null("Chapter01StoryEncounters") as Node3D
    if parent == null:
        parent = Node3D.new()
        parent.name = "Chapter01StoryEncounters"
        generated.add_child(parent)
    for value in definitions:
        var definition: Dictionary = value
        var encounter_id := String(definition.get("id", ""))
        if encounter_id == "" or AshlandsRuntime.is_encounter_cleared(encounter_id):
            continue
        if String(definition.get("type", "normal")) == "boss":
            if _configure_existing_boss(generated, definition):
                continue
        if parent.has_node(encounter_id):
            continue
        var trigger := EncounterTrigger.new()
        trigger.name = encounter_id
        trigger.encounter_id = encounter_id
        trigger.encounter_type = String(definition.get("type", "normal"))
        trigger.position = _vec3(definition.get("position", [0, 0, 0]))
        trigger.alternate_route_available = true
        if trigger.encounter_type == "miniboss":
            trigger.set_meta("miniboss", definition.get("miniboss", {}).duplicate(true))
        trigger.set_meta("story_encounter", true)
        trigger.set_meta("display_name", definition.get("name", encounter_id))
        _add_collision(trigger, Vector3(5.0, 2.5, 5.0) if trigger.encounter_type != "boss" else Vector3(7.0, 3.0, 7.0))
        parent.add_child(trigger)

func _configure_existing_boss(generated: Node, definition: Dictionary) -> bool:
    var boss := generated.get_node_or_null("BossSlot")
    if boss == null or not boss is EncounterTrigger:
        return false
    var trigger := boss as EncounterTrigger
    trigger.encounter_id = String(definition.get("id", "c01_boss_ash_witness"))
    trigger.encounter_type = "boss"
    trigger.position = _vec3(definition.get("position", [0, 0, 0]))
    trigger.set_meta("story_encounter", true)
    trigger.set_meta("display_name", definition.get("name", "Le Témoin des Cendres"))
    return true

func _find_generated_blockout() -> Node3D:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    var generated := scene.find_child("GeneratedBlockout", true, false)
    return generated as Node3D if generated is Node3D else null

func _add_collision(area: Area3D, size: Vector3) -> void:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    collision.position.y = size.y * 0.5
    area.add_child(collision)

func _vec3(value: Variant) -> Vector3:
    if typeof(value) != TYPE_ARRAY or value.size() < 3:
        return Vector3.ZERO
    return Vector3(float(value[0]), float(value[1]), float(value[2]))
