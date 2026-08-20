class_name VisualSliceRuntime
extends Node

signal combat_started()
signal combat_finished(winner_id: String)
signal hp_changed(actor_id: String, hp: int, max_hp: int)
signal action_resolved(actor_id: String, action_id: String)

const CONTRACT_PATH := "res://data/visual_vertical_slice.json"

var contract: Dictionary = {}
var darius_hp := 120
var ghoul_hp := 82
var darius_max_hp := 120
var ghoul_max_hp := 82
var darius_guarding := false
var combat_active := false
var darius_controller: VisualSliceAnimationController
var ghoul_controller: VisualSliceAnimationController
var vfx: VisualSliceVFX
var darius_root: Node3D
var ghoul_root: Node3D

func _ready() -> void:
    contract = _load_json(CONTRACT_PATH)
    _load_combat_values()

func configure(p_darius_root: Node3D, p_ghoul_root: Node3D, p_vfx: VisualSliceVFX) -> void:
    darius_root = p_darius_root
    ghoul_root = p_ghoul_root
    vfx = p_vfx
    darius_controller = VisualSliceAnimationController.new()
    ghoul_controller = VisualSliceAnimationController.new()
    add_child(darius_controller)
    add_child(ghoul_controller)
    var characters: Dictionary = contract.get("characters", {})
    darius_controller.configure("darius", darius_root, characters.get("darius", {}).get("animation_minimum", []))
    ghoul_controller.configure("enemy_01_goule_affamee", ghoul_root, characters.get("enemy_01_goule_affamee", {}).get("animation_minimum", []))

func start_combat() -> void:
    darius_hp = darius_max_hp
    ghoul_hp = ghoul_max_hp
    darius_guarding = false
    combat_active = true
    _state(darius_controller, "idle")
    _state(ghoul_controller, "idle")
    _audio_event("combat_music", darius_root)
    _audio_event("ashlands_wind", darius_root)
    combat_started.emit()
    _emit_hp()

func darius_light_attack() -> void:
    if not _can_act():
        return
    darius_guarding = false
    _state(darius_controller, "attack_light")
    _audio_event("combat_telegraph", darius_root)
    _spawn("subtle_attack_trail", _actor_pos(darius_root) + Vector3(0.55, 1.1, 0.0), Vector3.RIGHT)
    _damage_ghoul(_darius_combat_value("attack_light", 18), "attack_light")

func darius_heavy_attack() -> void:
    if not _can_act():
        return
    darius_guarding = false
    _state(darius_controller, "attack_heavy")
    _audio_event("combat_telegraph", darius_root)
    _spawn("subtle_attack_trail", _actor_pos(darius_root) + Vector3(0.6, 1.0, 0.0), Vector3.RIGHT)
    _damage_ghoul(_darius_combat_value("attack_heavy", 28), "attack_heavy")

func darius_guard() -> void:
    if not _can_act():
        return
    darius_guarding = true
    _state(darius_controller, "guard")
    _audio_event("combat_telegraph", darius_root)
    action_resolved.emit("darius", "guard")

func ghoul_claw() -> void:
    if not _can_act():
        return
    _state(ghoul_controller, "claw_1")
    _audio_event("ghoul_vocal", ghoul_root)
    _damage_darius(_ghoul_combat_value("claw_damage", 14), "claw_1")

func ghoul_lunge() -> void:
    if not _can_act():
        return
    _state(ghoul_controller, "lunge")
    _audio_event("combat_telegraph", ghoul_root)
    _audio_event("ghoul_vocal", ghoul_root)
    _damage_darius(_ghoul_combat_value("lunge_damage", 22), "lunge")

func step_actor(actor_id: String, world_position: Vector3) -> void:
    _spawn("ash_step_puff", world_position, Vector3.UP)
    _audio_event("footstep_ash", darius_root if actor_id == "darius" else ghoul_root)

func _damage_ghoul(amount: int, action_id: String) -> void:
    ghoul_hp = maxi(0, ghoul_hp - amount)
    _state(ghoul_controller, "stagger" if amount >= 25 else "hit")
    var hit_pos := _actor_pos(ghoul_root) + Vector3(0, 1.0, 0)
    _spawn("sword_impact", hit_pos, Vector3.UP + Vector3.RIGHT)
    _spawn("metal_sparks", hit_pos, Vector3.UP)
    _spawn("restrained_blood", hit_pos, Vector3.UP + Vector3.RIGHT)
    _audio_event("weapon_impact", ghoul_root)
    hp_changed.emit("enemy_01_goule_affamee", ghoul_hp, ghoul_max_hp)
    action_resolved.emit("darius", action_id)
    if ghoul_hp <= 0:
        _state(ghoul_controller, "death")
        _finish("darius")

func _damage_darius(amount: int, action_id: String) -> void:
    var final_amount := amount
    if darius_guarding:
        var reduction := float(contract.get("characters", {}).get("darius", {}).get("combat", {}).get("guard_reduction", 0.55))
        final_amount = maxi(1, roundi(float(amount) * (1.0 - reduction)))
        _state(darius_controller, "guard")
        _spawn("metal_sparks", _actor_pos(darius_root) + Vector3(-0.45, 1.1, 0), Vector3.UP)
    else:
        _state(darius_controller, "stagger" if final_amount >= 20 else "hit")
        _spawn("restrained_blood", _actor_pos(darius_root) + Vector3(0, 1.0, 0), Vector3.UP)
    darius_guarding = false
    darius_hp = maxi(0, darius_hp - final_amount)
    _audio_event("weapon_impact", darius_root)
    hp_changed.emit("darius", darius_hp, darius_max_hp)
    action_resolved.emit("enemy_01_goule_affamee", action_id)
    if darius_hp <= 0:
        _state(darius_controller, "death")
        _finish("enemy_01_goule_affamee")

func _finish(winner_id: String) -> void:
    combat_active = false
    combat_finished.emit(winner_id)

func _can_act() -> bool:
    return combat_active and darius_hp > 0 and ghoul_hp > 0

func _load_combat_values() -> void:
    var characters: Dictionary = contract.get("characters", {})
    var dc: Dictionary = characters.get("darius", {}).get("combat", {})
    var gc: Dictionary = characters.get("enemy_01_goule_affamee", {}).get("combat", {})
    darius_max_hp = int(dc.get("max_hp", 120))
    ghoul_max_hp = int(gc.get("max_hp", 82))
    darius_hp = darius_max_hp
    ghoul_hp = ghoul_max_hp

func _darius_combat_value(key: String, fallback: int) -> int:
    return int(contract.get("characters", {}).get("darius", {}).get("combat", {}).get(key, fallback))

func _ghoul_combat_value(key: String, fallback: int) -> int:
    return int(contract.get("characters", {}).get("enemy_01_goule_affamee", {}).get("combat", {}).get(key, fallback))

func _spawn(effect_id: String, position: Vector3, direction: Vector3) -> void:
    if vfx != null:
        vfx.spawn(effect_id, position, direction)

func _state(controller: VisualSliceAnimationController, next_state: String) -> void:
    if controller != null:
        controller.set_state(next_state)

func _actor_pos(actor: Node3D) -> Vector3:
    return actor.global_position if actor != null else Vector3.ZERO

func _audio_event(event_id: String, source: Node3D) -> void:
    var audio_director := get_node_or_null("/root/AudioDirector")
    var sfx_runtime := get_node_or_null("/root/SfxRuntime")
    if event_id == "combat_music" and audio_director != null:
        if audio_director.has_method("enter_combat"):
            audio_director.call("enter_combat")
        elif audio_director.has_method("set_mode"):
            audio_director.call("set_mode", "combat")
        return
    if event_id == "ashlands_wind" and audio_director != null:
        if audio_director.has_method("enter_exploration"):
            audio_director.call("enter_exploration")
        return
    if sfx_runtime != null:
        if sfx_runtime.has_method("play_cue"):
            sfx_runtime.call("play_cue", event_id, _actor_pos(source))
        elif sfx_runtime.has_method("request_sfx"):
            sfx_runtime.call("request_sfx", event_id, _actor_pos(source))

func _emit_hp() -> void:
    hp_changed.emit("darius", darius_hp, darius_max_hp)
    hp_changed.emit("enemy_01_goule_affamee", ghoul_hp, ghoul_max_hp)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
