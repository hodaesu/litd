extends Node

signal proxy_action_started(character_key: String, action_id: String)
signal proxy_reaction_started(character_key: String, reaction_id: String)

var visuals: Dictionary = {}
var profiles: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    GameState.screen_requested.connect(func(screen: String):
        if screen != "combat":
            visuals.clear()
            profiles.clear()
    )

func bind_visual(art: Control, character: Dictionary, enemy: bool, formation_index: int) -> Dictionary:
    var key := _key(character, enemy)
    var profile := _profile(character, enemy)
    visuals[key] = art
    profiles[key] = profile
    art.pivot_offset = art.size * 0.5
    art.tooltip_text = _posture_tooltip(profile)
    _apply_posture(art, profile, enemy, formation_index)
    _play_entrance(art, enemy, formation_index, profile)
    if int(character.get("hp", 0)) > 0:
        _play_breath_loop(art, profile)
    return profile

func stage_action(character: Dictionary, enemy: bool, action_id: String) -> void:
    var key := _key(character, enemy)
    var art := _visual(key)
    if art == null:
        return
    proxy_action_started.emit(key, action_id)
    var profile: Dictionary = profiles.get(key, _profile(character, enemy))
    var parameters: Dictionary = profile.get("parameters", {})
    var recovery := clampf(float(parameters.get("recovery_visual_scale", 1.0)), 0.75, 1.45)
    var direction := -1.0 if enemy else 1.0
    var distance := 14.0
    var tilt := 0.025
    match action_id:
        "heavy":
            distance = 24.0
            tilt = 0.065
        "guard":
            distance = -7.0
            tilt = -0.025
        "heal":
            distance = 4.0
            tilt = -0.04
        "capture":
            distance = 18.0
            tilt = 0.045
    var base_position := art.position
    var base_rotation := art.rotation
    var tween := art.create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.tween_property(art, "rotation", base_rotation - direction * tilt, 0.10)
    tween.tween_property(art, "position:x", base_position.x + direction * distance, 0.13)
    tween.tween_property(art, "rotation", base_rotation + direction * tilt * 0.45, 0.07)
    tween.tween_property(art, "position", base_position, 0.16 * recovery)
    tween.parallel().tween_property(art, "rotation", base_rotation, 0.16 * recovery)

func stage_hit(character: Dictionary, enemy: bool, body_part: String = "torso", severity: String = "light") -> void:
    var key := _key(character, enemy)
    var art := _visual(key)
    if art == null:
        return
    var reaction := BodyStateDirector.hit_reaction(character, body_part, severity)
    proxy_reaction_started.emit(key, String(reaction.get("clip", "hit")))
    var base_position := art.position
    var base_rotation := art.rotation
    var direction := 1.0 if enemy else -1.0
    var distance := 9.0 if severity == "light" else 18.0
    var tint := art.modulate
    var tween := art.create_tween()
    tween.tween_property(art, "modulate", Color(1.0, 0.48, 0.42, tint.a), 0.06)
    tween.parallel().tween_property(art, "position:x", base_position.x + direction * distance, 0.08)
    tween.parallel().tween_property(art, "rotation", base_rotation + direction * 0.055, 0.08)
    tween.tween_property(art, "modulate", tint, 0.16)
    tween.parallel().tween_property(art, "position", base_position, 0.16)
    tween.parallel().tween_property(art, "rotation", base_rotation, 0.16)

func stage_death(character: Dictionary, enemy: bool) -> void:
    var art := _visual(_key(character, enemy))
    if art == null:
        return
    var direction := 1.0 if enemy else -1.0
    var tween := art.create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.tween_property(art, "rotation", direction * 0.16, 0.30)
    tween.parallel().tween_property(art, "position:y", art.position.y + 24.0, 0.30)
    tween.parallel().tween_property(art, "modulate:a", 0.25, 0.38)

func state_label(character: Dictionary, enemy: bool) -> String:
    var profile := _profile(character, enemy)
    var psyche := String(profile.get("psychological_state", "neutral"))
    var physical := String(profile.get("physical_state", "healthy"))
    return "%s · %s" % [_state_name(psyche), _state_name(physical)]

func _profile(character: Dictionary, enemy: bool) -> Dictionary:
    var body := BodyStateDirector.evaluate(character)
    if not enemy:
        return body
    var physical := String(body.get("physical_state", "healthy"))
    var enemy_profile := EnemyBodyDirector.compose_for_enemy(character, physical, "idle")
    enemy_profile["psychological_state"] = EnemyFearDirector.body_psychological_state(character)
    enemy_profile["physical_state"] = physical
    enemy_profile["parameters"] = body.get("parameters", {}).duplicate(true)
    enemy_profile["body_profile"] = body
    return enemy_profile

func _apply_posture(art: Control, profile: Dictionary, enemy: bool, formation_index: int) -> void:
    var parameters: Dictionary = profile.get("parameters", {})
    var psyche := String(profile.get("psychological_state", "neutral"))
    var physical := String(profile.get("physical_state", "healthy"))
    var stance := clampf(float(parameters.get("stance_height", 1.0)), 0.72, 1.08)
    var compaction := clampf(float(parameters.get("guard_compaction", 0.0)), 0.0, 1.0)
    var signature_seed := abs(String(profile.get("signature_key", profile.get("character_id", formation_index))).hash())
    var width_variant := 0.94 + float(signature_seed % 11) * 0.01
    var lean_variant := (float(signature_seed % 9) - 4.0) * 0.006
    var lean := lean_variant
    if psyche in ["tense", "terrified", "panic"]:
        lean += (-0.035 if enemy else 0.035) * (1.0 + compaction * 0.5)
    elif psyche == "anger":
        lean += 0.045 if enemy else -0.045
    elif psyche == "despair":
        lean += 0.055
    if physical in ["injured", "critical", "mobility_impaired"]:
        lean += (0.025 if formation_index % 2 == 0 else -0.025)
    art.scale = Vector2(width_variant * (1.0 - compaction * 0.04), stance)
    art.rotation = lean
    if physical == "dead":
        art.modulate.a = 0.25
    elif physical == "critical":
        art.modulate = Color(0.80, 0.72, 0.70, art.modulate.a)
    elif psyche in ["terrified", "panic"]:
        art.modulate = Color(0.82, 0.88, 0.94, art.modulate.a)
    elif psyche == "hope":
        art.modulate = Color(1.0, 0.96, 0.82, art.modulate.a)

func _play_entrance(art: Control, enemy: bool, index: int, profile: Dictionary) -> void:
    var final_position := art.position
    var final_modulate := art.modulate
    var direction := 1.0 if enemy else -1.0
    art.position.x += direction * (18.0 + float(index) * 4.0)
    art.modulate.a = 0.0
    var delay := 0.025 * float(index) + float(profile.get("phase_offset", 0.0)) * 0.04
    var tween := art.create_tween()
    tween.tween_interval(maxf(0.0, delay))
    tween.tween_property(art, "position", final_position, 0.18)
    tween.parallel().tween_property(art, "modulate", final_modulate, 0.18)

func _play_breath_loop(art: Control, profile: Dictionary) -> void:
    var parameters: Dictionary = profile.get("parameters", {})
    var breath := clampf(float(parameters.get("breath_intensity", 0.15)), 0.04, 0.50)
    var noise := clampf(float(parameters.get("gesture_noise", 0.0)), 0.0, 1.0)
    var tempo := clampf(float(profile.get("tempo_scale", 1.0)), 0.65, 1.45)
    var base_scale := art.scale
    var delta := 0.004 + breath * 0.012 + noise * 0.004
    var duration := clampf(1.25 / tempo, 0.70, 1.65)
    var tween := art.create_tween().set_loops()
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_property(art, "scale", Vector2(base_scale.x * (1.0 + delta), base_scale.y * (1.0 - delta * 0.4)), duration)
    tween.tween_property(art, "scale", base_scale, duration)

func _posture_tooltip(profile: Dictionary) -> String:
    return "Posture : %s · État : %s" % [
        String(profile.get("signature_key", profile.get("layers", {}).get("personality", "personnelle"))),
        _state_name(String(profile.get("psychological_state", "neutral")))
    ]

func _visual(key: String) -> Control:
    var value: Variant = visuals.get(key)
    if value is Control and is_instance_valid(value):
        return value
    visuals.erase(key)
    profiles.erase(key)
    return null

func _key(character: Dictionary, enemy: bool) -> String:
    return "%s:%s" % ["enemy" if enemy else "hero", String(character.get("id", character.get("name", "unknown")))]

func _state_name(state: String) -> String:
    return {
        "neutral":"Calme","tense":"Tendu","terrified":"Terrifié","panic":"Panique",
        "fractured":"Affligé","anger":"Colère","despair":"Désespoir","hope":"Espoir",
        "healthy":"Sain","injured":"Blessé","critical":"Critique",
        "mobility_impaired":"Mobilité réduite","dead":"Mort"
    }.get(state, state.capitalize())
