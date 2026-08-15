extends Area3D
class_name EncounterTrigger

signal encounter_started(encounter_id: String, encounter_type: String)
signal encounter_cleared(encounter_id: String)

@export var encounter_id := ""
@export_enum("normal", "ambush", "miniboss", "boss") var encounter_type := "normal"
@export var one_shot := true
@export var alternate_route_available := true
@export var starts_on_contact := true

var cleared := false
var armed := true

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    if encounter_id != "" and AshlandsRuntime.is_encounter_cleared(encounter_id):
        cleared = true
        armed = false

func _on_body_entered(body: Node) -> void:
    if not starts_on_contact or not armed or cleared:
        return
    if not body.is_in_group("player_party"):
        return
    start_encounter()

func can_start() -> bool:
    if cleared or not armed:
        return false
    if encounter_type == "miniboss" and not alternate_route_available:
        return false
    return true

func start_encounter() -> bool:
    if not can_start():
        return false
    armed = false
    encounter_started.emit(encounter_id, encounter_type)
    return true

func mark_cleared() -> void:
    cleared = true
    armed = false
    if one_shot and encounter_id != "":
        AshlandsRuntime.mark_encounter_cleared(encounter_id)
    encounter_cleared.emit(encounter_id)

func reset_for_new_expedition() -> void:
    if one_shot and encounter_id != "" and AshlandsRuntime.is_encounter_cleared(encounter_id):
        cleared = true
        armed = false
        return
    cleared = false
    armed = true
