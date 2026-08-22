class_name BodyStateVisualAdapter
extends Node

signal visual_profile_applied(character_id: String, profile: Dictionary)
signal action_requested(character_id: String, action_id: String, plan: Dictionary)

@export var transition_speed: float = 7.5
@export var procedural_preview_enabled: bool = true

var character_id: String = ""
var actor_root: Node3D
var pose_target: Node3D
var animation_tree: AnimationTree
var current_character: Dictionary = {}
var current_context: Dictionary = {}
var current_profile: Dictionary = {}
var current_action: String = "idle"
var current_plan: Dictionary = {}
var base_transform: Transform3D
var pose_time: float = 0.0
var target_pitch: float = 0.0
var target_roll: float = 0.0
var target_yaw: float = 0.0
var target_height_scale: float = 1.0
var target_breath: float = 0.15
var target_noise: float = 0.0
var last_animation_parameters: Dictionary = {}

func configure(p_character_id: String, p_actor_root: Node3D, character: Dictionary = {}) -> void:
    character_id = p_character_id
    actor_root = p_actor_root
    current_character = character.duplicate(true)
    animation_tree = _find_animation_tree(actor_root)
    pose_target = _find_pose_target(actor_root)
    if pose_target != null:
        base_transform = pose_target.transform
    set_process(true)
    refresh()

func update_character(character: Dictionary, context: Dictionary = {}) -> Dictionary:
    current_character = character.duplicate(true)
    current_context = context.duplicate(true)
    return refresh()

func set_context(context: Dictionary) -> Dictionary:
    current_context = context.duplicate(true)
    return refresh()

func set_action(action_id: String, context: Dictionary = {}) -> Dictionary:
    current_action = action_id
    current_context.merge(context, true)
    current_plan = BodyStateDirector.combat_action_plan(current_character, action_id, current_context)
    current_profile = current_plan.get("profile", BodyStateDirector.evaluate(current_character, current_context))
    _cache_targets()
    _apply_animation_tree_parameters()
    action_requested.emit(character_id, action_id, current_plan.duplicate(true))
    return current_plan.duplicate(true)

func set_hit_reaction(body_part: String, severity: String = "light") -> Dictionary:
    var reaction: Dictionary = BodyStateDirector.hit_reaction(current_character, body_part, severity)
    current_context["reaction"] = str(reaction.get("clip", "hit"))
    current_action = str(reaction.get("clip", "hit"))
    current_profile = reaction.get("profile", {})
    _cache_targets()
    _apply_animation_tree_parameters()
    return reaction

func refresh() -> Dictionary:
    if current_character.is_empty():
        current_character = {"id": character_id, "hp": 1, "max_hp": 1}
    current_context["action"] = current_action
    current_profile = BodyStateDirector.evaluate(current_character, current_context)
    _cache_targets()
    _apply_animation_tree_parameters()
    visual_profile_applied.emit(character_id, current_profile.duplicate(true))
    return current_profile.duplicate(true)

func snapshot() -> Dictionary:
    return {
        "character_id": character_id,
        "action": current_action,
        "profile": current_profile.duplicate(true),
        "animation_tree_found": animation_tree != null,
        "procedural_preview": procedural_preview_enabled,
        "animation_parameters": last_animation_parameters.duplicate(true),
        "pose_target_found": pose_target != null
    }

func _process(delta: float) -> void:
    if pose_target == null or not procedural_preview_enabled:
        return
    pose_time += delta
    var parameters: Dictionary = current_profile.get("parameters", {})
    var gaze_scan: float = float(parameters.get("gaze_scan", 0.0))
    var stride: float = float(parameters.get("stride_scale", 1.0))
    var action_pulse: float = _action_pulse()
    var fear_hesitation: float = sin(pose_time * (5.0 + gaze_scan * 4.0)) * target_noise * 0.025
    var breath_offset: float = sin(pose_time * (1.6 + target_breath * 1.8)) * target_breath * 0.018
    var locomotion_bob: float = sin(pose_time * 8.0) * 0.018 * stride if str(current_profile.get("locomotion_state", "idle")) != "idle" else 0.0
    var desired_rotation := Vector3(target_pitch + action_pulse * 0.08, target_yaw + fear_hesitation, target_roll)
    pose_target.rotation = pose_target.rotation.lerp(base_transform.basis.get_euler() + desired_rotation, clampf(delta * transition_speed, 0.0, 1.0))
    var desired_scale := base_transform.basis.get_scale()
    desired_scale.y *= target_height_scale
    desired_scale.x *= 1.0 + action_pulse * 0.025
    pose_target.scale = pose_target.scale.lerp(desired_scale, clampf(delta * transition_speed, 0.0, 1.0))
    var desired_position := base_transform.origin + Vector3(fear_hesitation * 0.20, breath_offset + locomotion_bob, 0.0)
    pose_target.position = pose_target.position.lerp(desired_position, clampf(delta * transition_speed, 0.0, 1.0))

func _cache_targets() -> void:
    var state: String = str(current_profile.get("psychological_state", "neutral"))
    var physical: String = str(current_profile.get("physical_state", "healthy"))
    var parameters: Dictionary = current_profile.get("parameters", {})
    target_height_scale = float(parameters.get("stance_height", 1.0))
    target_breath = float(parameters.get("breath_intensity", 0.15))
    target_noise = float(parameters.get("gesture_noise", 0.0))
    target_pitch = 0.0
    target_roll = 0.0
    target_yaw = 0.0
    match state:
        "tense": target_pitch = -0.04
        "terrified": target_pitch = -0.10
        "panic": target_pitch = -0.15
        "fractured": target_roll = 0.08
        "anger": target_pitch = 0.10
        "despair": target_pitch = -0.18
        "hope": target_pitch = 0.05
    match physical:
        "injured": target_roll += 0.06
        "critical": target_pitch -= 0.14; target_roll += 0.10
        "mobility_impaired": target_roll += 0.14
        "dead": target_roll = 1.35

func _apply_animation_tree_parameters() -> void:
    last_animation_parameters = {
        "psychology": str(current_profile.get("psychological_state", "neutral")),
        "physical": str(current_profile.get("physical_state", "healthy")),
        "locomotion": str(current_profile.get("locomotion_state", "idle")),
        "relation": str(current_profile.get("relation_state", "none")),
        "action": current_action,
        "fear_blend": float(current_profile.get("fear", 0)) / 100.0,
        "madness_blend": float(current_profile.get("madness", 0)) / 100.0,
        "injury_blend": 1.0 - float(current_profile.get("hp_ratio", 1.0)),
        "stride_scale": float(current_profile.get("parameters", {}).get("stride_scale", 1.0))
    }
    if animation_tree == null:
        return
    animation_tree.active = true
    _set_tree_parameter("parameters/body_state/fear_blend", last_animation_parameters["fear_blend"])
    _set_tree_parameter("parameters/body_state/madness_blend", last_animation_parameters["madness_blend"])
    _set_tree_parameter("parameters/body_state/injury_blend", last_animation_parameters["injury_blend"])
    _set_tree_parameter("parameters/body_state/stride_scale", last_animation_parameters["stride_scale"])
    _travel_if_available(str(last_animation_parameters["action"]))

func _set_tree_parameter(path: String, value: Variant) -> void:
    for property_value: Variant in animation_tree.get_property_list():
        if property_value is Dictionary and str(property_value.get("name", "")) == path:
            animation_tree.set(path, value)
            return

func _travel_if_available(state: String) -> void:
    var playback: Variant = animation_tree.get("parameters/playback")
    if playback is AnimationNodeStateMachinePlayback:
        (playback as AnimationNodeStateMachinePlayback).travel(state)

func _action_pulse() -> float:
    if current_action in ["attack_light", "attack_heavy", "claw_1", "claw_2", "lunge", "friendly_fire"]:
        return maxf(0.0, sin(pose_time * PI * 3.0))
    if current_action in ["guard", "protect_ally"]:
        return 0.35
    return 0.0

func _find_animation_tree(root: Node) -> AnimationTree:
    if root == null:
        return null
    if root is AnimationTree:
        return root as AnimationTree
    for child: Node in root.get_children():
        var found: AnimationTree = _find_animation_tree(child)
        if found != null:
            return found
    return null

func _find_pose_target(root: Node3D) -> Node3D:
    if root == null:
        return null
    for preferred: String in ["ModelSlot", "Armature", "Skeleton3D", "Mesh", "Visual"]:
        var found: Node = root.find_child(preferred, true, false)
        if found is Node3D:
            return found as Node3D
    return root
