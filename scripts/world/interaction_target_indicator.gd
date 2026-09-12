extends Node3D
class_name InteractionTargetIndicator

@export var vertical_offset := 1.45
@export var glyph := "◇"
@export var font_size := 34
@export var outline_size := 6

var _target: Node3D = null
var _label: Label3D = null

func _ready() -> void:
    _ensure_label()
    visible = false
    set_process(true)

func set_target(target: Object) -> void:
    _target = target as Node3D
    if _target == null or not is_instance_valid(_target):
        clear_target()
        return
    _ensure_label()
    visible = true
    _sync_to_target()

func clear_target() -> void:
    _target = null
    visible = false

func get_target() -> Node3D:
    return _target

func _process(_delta: float) -> void:
    if _target == null or not is_instance_valid(_target):
        clear_target()
        return
    _sync_to_target()

func _ensure_label() -> void:
    if _label != null and is_instance_valid(_label):
        return
    _label = Label3D.new()
    _label.name = "TargetGlyph"
    _label.text = glyph
    _label.font_size = font_size
    _label.outline_size = outline_size
    _label.modulate = Color(1.0, 0.92, 0.72, 0.92)
    _label.outline_modulate = Color(0.08, 0.07, 0.06, 0.92)
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(_label)

func _sync_to_target() -> void:
    if _target == null:
        return
    global_position = _target.global_position + Vector3.UP * vertical_offset
