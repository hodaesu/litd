extends Node3D
class_name InteractionTargetIndicator

@export var vertical_offset := 1.45
@export var glyph := "◇"
@export var immediate_font_size := 40
@export var contextual_font_size := 34
@export var inspect_font_size := 28
@export var immediate_outline_size := 7
@export var contextual_outline_size := 6
@export var inspect_outline_size := 4

var _target: Node3D = null
var _label: Label3D = null
var _salience := EnvironmentInteractionContract.SALIENCE_CONTEXTUAL

func _ready() -> void:
    _ensure_label()
    _apply_salience_style()
    visible = false
    set_process(true)

func set_target(
    target: Object,
    salience: String = EnvironmentInteractionContract.SALIENCE_CONTEXTUAL
) -> void:
    _target = target as Node3D
    if _target == null or not is_instance_valid(_target):
        clear_target()
        return
    _salience = EnvironmentInteractionContract.normalize_salience(salience)
    _ensure_label()
    _apply_salience_style()
    visible = true
    _sync_to_target()

func clear_target() -> void:
    _target = null
    visible = false

func get_target() -> Node3D:
    return _target

func get_salience() -> String:
    return _salience

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
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(_label)

func _apply_salience_style() -> void:
    if _label == null or not is_instance_valid(_label):
        return
    var profile := presentation_profile(_salience)
    _label.font_size = int(profile.get("font_size", contextual_font_size))
    _label.outline_size = int(profile.get("outline_size", contextual_outline_size))
    _label.modulate = Color(1.0, 0.92, 0.72, float(profile.get("alpha", 0.92)))
    _label.outline_modulate = Color(0.08, 0.07, 0.06, float(profile.get("outline_alpha", 0.92)))

func presentation_profile(salience: String) -> Dictionary:
    match EnvironmentInteractionContract.normalize_salience(salience):
        EnvironmentInteractionContract.SALIENCE_IMMEDIATE:
            return {
                "font_size": immediate_font_size,
                "outline_size": immediate_outline_size,
                "alpha": 0.98,
                "outline_alpha": 0.96,
            }
        EnvironmentInteractionContract.SALIENCE_INSPECT:
            return {
                "font_size": inspect_font_size,
                "outline_size": inspect_outline_size,
                "alpha": 0.66,
                "outline_alpha": 0.72,
            }
        _:
            return {
                "font_size": contextual_font_size,
                "outline_size": contextual_outline_size,
                "alpha": 0.90,
                "outline_alpha": 0.90,
            }

func _sync_to_target() -> void:
    if _target == null:
        return
    global_position = _target.global_position + Vector3.UP * vertical_offset
