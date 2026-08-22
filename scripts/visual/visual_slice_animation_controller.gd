class_name VisualSliceAnimationController
extends Node

signal state_changed(actor_id: String, state: String)

var actor_id := ""
var animation_player: AnimationPlayer
var current_state := "idle"
var valid_states: PackedStringArray = []
var body_adapter: BodyStateVisualAdapter

func configure(p_actor_id: String, root: Node, states: Array) -> void:
    actor_id = p_actor_id
    valid_states = PackedStringArray()
    for value in states:
        valid_states.append(str(value))
    animation_player = _find_animation_player(root)
    body_adapter = BodyStateVisualAdapter.new()
    body_adapter.name = "BodyStateVisualAdapter"
    add_child(body_adapter)
    body_adapter.configure(actor_id, root as Node3D, {"id": actor_id, "hp": 1, "max_hp": 1})
    set_state("idle")

func set_state(next_state: String) -> bool:
    if not valid_states.is_empty() and next_state not in valid_states:
        return false
    current_state = next_state
    if body_adapter != null:
        body_adapter.set_action(next_state)
    if animation_player != null:
        var clip := _resolve_clip(next_state)
        if not clip.is_empty():
            animation_player.play(clip)
    state_changed.emit(actor_id, current_state)
    return true

func update_body_state(character: Dictionary, context: Dictionary = {}) -> Dictionary:
    return body_adapter.update_character(character, context) if body_adapter != null else {}

func set_hit_reaction(body_part: String, severity: String = "light") -> Dictionary:
    return body_adapter.set_hit_reaction(body_part, severity) if body_adapter != null else {}

func body_snapshot() -> Dictionary:
    return body_adapter.snapshot() if body_adapter != null else {}

func has_clip(state: String) -> bool:
    if animation_player == null:
        return false
    return not _resolve_clip(state).is_empty()

func _resolve_clip(state: String) -> StringName:
    if animation_player == null:
        return &""
    var candidates := [state, "default/" + state, "Animation/" + state]
    for candidate in candidates:
        var name := StringName(candidate)
        if animation_player.has_animation(name):
            return name
    return &""

func _find_animation_player(root: Node) -> AnimationPlayer:
    if root == null:
        return null
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null
