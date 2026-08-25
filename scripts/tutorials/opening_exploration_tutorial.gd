extends CanvasLayer
class_name OpeningExplorationTutorial

const DATA_PATH := "res://data/tutorials/opening_exploration.json"
const STARTED_FLAG := "opening_tutorial_started"
const COMPLETE_FLAG := "opening_tutorial_complete"

var data: Dictionary = {}
var stages: Array = []
var stage_index := 0
var panel: PanelContainer
var instruction: Label
var _running := false
var _move_origin := Vector3.ZERO
var _party: Node3D


func begin(party: Node3D) -> void:
    if bool(CampaignState.chapter_flags.get(COMPLETE_FLAG, false)):
        queue_free()
        return
    _party = party
    data = _read_json(DATA_PATH)
    stages = data.get("stages", [])
    if stages.is_empty():
        queue_free()
        return
    layer = 185
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()
    _move_origin = _party.global_position
    CampaignState.set_chapter_flag(STARTED_FLAG, true)
    _running = true
    _show_stage()


func _process(_delta: float) -> void:
    if not _running or _party == null or stage_index >= stages.size():
        return
    var stage: Dictionary = stages[stage_index]
    if str(stage.get("completion", "")) == "party_moved" and _party.global_position.distance_to(_move_origin) >= 1.25:
        _advance()


func _unhandled_input(event: InputEvent) -> void:
    if not _running or stage_index >= stages.size():
        return
    var completion := str((stages[stage_index] as Dictionary).get("completion", ""))
    if completion == "interaction_requested" and event.is_action_pressed("interact"):
        _advance()
    elif completion == "ash_guidance_requested" and event.is_action_pressed("ash_guidance"):
        _advance()


func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "ContextualTutorialPrompt"
    panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    panel.position = Vector2(-250.0, -108.0)
    panel.size = Vector2(500.0, 72.0)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(panel)
    instruction = Label.new()
    instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    instruction.add_theme_font_size_override("font_size", 18)
    panel.add_child(instruction)


func _show_stage() -> void:
    var stage: Dictionary = stages[stage_index]
    instruction.text = str(stage.get("prompt", ""))
    panel.modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(panel, "modulate:a", 1.0, 0.22)


func _advance() -> void:
    stage_index += 1
    if stage_index >= stages.size():
        _finish()
        return
    _show_stage()


func _finish() -> void:
    _running = false
    CampaignState.set_chapter_flag(COMPLETE_FLAG, true)
    var tween := create_tween()
    tween.tween_property(panel, "modulate:a", 0.0, 0.35)
    tween.tween_callback(queue_free)


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
