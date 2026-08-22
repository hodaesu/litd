extends Node

signal adaptation_changed(snapshot: Dictionary)

const DATA_PATH := "res://data/audio_director.json"

var config: Dictionary = {}
var current_intensity: float = 0.0
var current_reason: String = "boot"
var current_decision: Dictionary = {}
var initial_enemy_count: int = 0
var dialogue_active: bool = false
var silence_active: bool = false
var narrative_hold_until_msec: int = 0
var resolution_hold_until_msec: int = 0
var cue_hold_until_msec: int = 0
var _hold_generation: int = 0
var _connected: bool = false
var _mix_tween: Tween
var _last_music_target_db: float = 999.0
var _last_ambience_target_db: float = 999.0

func _ready() -> void:
    var root: Dictionary = _load_dictionary(DATA_PATH)
    var value: Variant = root.get("adaptive_music", {})
    config = value.duplicate(true) if value is Dictionary else {}
    call_deferred("_connect_sources")
    call_deferred("refresh", "boot")

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _connect_sources() -> void:
    if _connected:
        return
    if not GameState.state_changed.is_connected(_on_game_state_changed):
        GameState.state_changed.connect(_on_game_state_changed)
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not AudioDirector.audio_state_changed.is_connected(_on_audio_state_changed):
        AudioDirector.audio_state_changed.connect(_on_audio_state_changed)
    if not AudioDirector.mix_changed.is_connected(_on_audio_mix_changed):
        AudioDirector.mix_changed.connect(_on_audio_mix_changed)
    if not NarrativeAudioDirector.dialogue_state_changed.is_connected(_on_dialogue_state_changed):
        NarrativeAudioDirector.dialogue_state_changed.connect(_on_dialogue_state_changed)
    if not NarrativeAudioDirector.narrative_beat_started.is_connected(_on_narrative_beat_started):
        NarrativeAudioDirector.narrative_beat_started.connect(_on_narrative_beat_started)
    if not AshlandsCombatBridge.ashlands_combat_started.is_connected(_on_combat_started):
        AshlandsCombatBridge.ashlands_combat_started.connect(_on_combat_started)
    if not AshlandsCombatBridge.ashlands_combat_finished.is_connected(_on_combat_finished):
        AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)
    _connected = true
    dialogue_active = NarrativeAudioDirector.dialogue_depth > 0
    silence_active = NarrativeAudioDirector.silence_active

func refresh(reason: String = "state") -> Dictionary:
    if config.is_empty():
        return {}
    var context: Dictionary = _build_context()
    var decision: Dictionary = _decide(context)
    current_decision = decision.duplicate(true)
    current_intensity = clampf(float(decision.get("intensity", 0.0)), 0.0, 1.0)
    current_reason = reason

    var cue_id: String = str(decision.get("cue", ""))
    if bool(decision.get("switch_music", false)) and cue_id != "" and cue_id != AudioDirector.active_music_cue and _music_switch_allowed():
        AudioDirector.request_music(cue_id, {
            "reason": "adaptive_context",
            "adaptive_reason": str(decision.get("reason", reason)),
            "intensity": current_intensity,
            "context": context.duplicate(true)
        })
        cue_hold_until_msec = Time.get_ticks_msec() + int(round(_seconds("cue_min_hold_seconds", 3.2) * 1000.0))

    _apply_adaptive_mix()
    adaptation_changed.emit(snapshot())
    return current_decision.duplicate(true)

func snapshot() -> Dictionary:
    return {
        "intensity": current_intensity,
        "reason": current_reason,
        "decision": current_decision.duplicate(true),
        "dialogue_active": dialogue_active,
        "silence_active": silence_active,
        "narrative_hold": Time.get_ticks_msec() < narrative_hold_until_msec,
        "resolution_hold": Time.get_ticks_msec() < resolution_hold_until_msec,
        "audio_mode": AudioDirector.mode,
        "music_cue": AudioDirector.active_music_cue,
        "encounter_type": AudioDirector.current_encounter_type,
        "initial_enemy_count": initial_enemy_count
    }

func _build_context() -> Dictionary:
    var risk: Dictionary = ExpeditionManager.current_risk_profile()
    var light_value: int = int(ExpeditionManager.inventory.get("light", 8))
    var party_hp: int = 0
    var party_max_hp: int = 0
    var critical_heroes: int = 0
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value if hero_value is Dictionary else {}
        if hero.is_empty():
            continue
        var hp: int = maxi(0, int(hero.get("hp", 0)))
        var max_hp: int = maxi(1, int(hero.get("max_hp", 1)))
        party_hp += hp
        party_max_hp += max_hp
        if hp > 0 and float(hp) / float(max_hp) <= 0.30:
            critical_heroes += 1

    var enemy_hp: int = 0
    var enemy_max_hp: int = 0
    var living_enemies: int = 0
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value if enemy_value is Dictionary else {}
        if enemy.is_empty():
            continue
        var hp: int = maxi(0, int(enemy.get("hp", 0)))
        var max_hp: int = maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
        enemy_hp += hp
        enemy_max_hp += max_hp
        if hp > 0:
            living_enemies += 1

    var space_id: String = str(NarrativeAudioDirector.current_space_id)
    return {
        "mode": str(AudioDirector.mode),
        "encounter_type": str(AudioDirector.current_encounter_type),
        "boss_phase": int(AudioDirector.boss_phase),
        "zone_id": str(AudioDirector.current_zone_id if AudioDirector.current_zone_id != "" else AshlandsRuntime.current_zone_id),
        "space_id": space_id,
        "dialogue_active": dialogue_active,
        "silence_active": silence_active,
        "party_hp_ratio": float(party_hp) / float(maxi(1, party_max_hp)),
        "critical_heroes": critical_heroes,
        "max_party_fear": int(AudioDirector.max_party_fear),
        "enemy_hp_ratio": float(enemy_hp) / float(maxi(1, enemy_max_hp)),
        "living_enemies": living_enemies,
        "initial_enemies": maxi(initial_enemy_count, GameState.battle_enemies.size()),
        "danger_multiplier": float(risk.get("danger_multiplier", 1.0)),
        "light": light_value,
        "active_cue": str(AudioDirector.active_music_cue)
    }

func _decide(context: Dictionary) -> Dictionary:
    if bool(context.get("silence_active", false)):
        return {"switch_music": false, "cue": "", "intensity": 0.0, "reason": "scripted_silence"}
    if bool(context.get("dialogue_active", false)):
        return {
            "switch_music": false,
            "cue": str(context.get("active_cue", "")),
            "intensity": maxf(0.08, current_intensity * 0.72),
            "reason": "dialogue_focus"
        }
    if str(context.get("space_id", "")) != "" and str(context.get("mode", "exploration")) == "exploration":
        return {
            "switch_music": false,
            "cue": str(context.get("active_cue", "")),
            "intensity": 0.18,
            "reason": "authored_space"
        }

    var mode: String = str(context.get("mode", "exploration"))
    if mode in ["combat", "boss"]:
        return _combat_decision(context)
    return _exploration_decision(context)

func _combat_decision(context: Dictionary) -> Dictionary:
    var encounter_type: String = str(context.get("encounter_type", "normal"))
    if encounter_type == "":
        encounter_type = "normal"
    var cue_map_variant: Variant = config.get("combat_cues", {})
    var cue_map: Dictionary = cue_map_variant if cue_map_variant is Dictionary else {}
    var cue_id: String = str(cue_map.get(encounter_type, cue_map.get("normal", "combat_normal")))

    var base_variant: Variant = config.get("combat_base_intensity", {})
    var bases: Dictionary = base_variant if base_variant is Dictionary else {}
    var intensity: float = float(bases.get(encounter_type, bases.get("normal", 0.55)))
    var party_ratio: float = clampf(float(context.get("party_hp_ratio", 1.0)), 0.0, 1.0)
    var enemy_ratio: float = clampf(float(context.get("enemy_hp_ratio", 1.0)), 0.0, 1.0)
    var fear: int = clampi(int(context.get("max_party_fear", 0)), 0, 100)
    var critical_heroes: int = maxi(0, int(context.get("critical_heroes", 0)))
    var living: int = maxi(0, int(context.get("living_enemies", 0)))
    var initial: int = maxi(1, int(context.get("initial_enemies", living)))
    var boss_phase: int = maxi(0, int(context.get("boss_phase", 0)))

    if party_ratio <= 0.50:
        intensity += 0.08
    if party_ratio <= 0.28:
        intensity += 0.10
    intensity += minf(0.12, float(critical_heroes) * 0.04)
    if fear >= 50:
        intensity += 0.06
    if fear >= 75:
        intensity += 0.08
    if encounter_type == "boss" or str(context.get("mode", "")) == "boss":
        intensity += 0.04 * float(maxi(0, boss_phase - 1))
        if enemy_ratio <= 0.25:
            intensity += 0.05
    elif living == 1 and initial >= 3 and party_ratio > 0.45:
        intensity -= 0.10
    elif enemy_ratio <= 0.20 and party_ratio > 0.55:
        intensity -= 0.05

    return {
        "switch_music": true,
        "cue": cue_id,
        "intensity": clampf(intensity, 0.0, 1.0),
        "reason": "combat_%s" % encounter_type
    }

func _exploration_decision(context: Dictionary) -> Dictionary:
    var danger: float = maxf(1.0, float(context.get("danger_multiplier", 1.0)))
    var light_value: int = clampi(int(context.get("light", 8)), 0, 10)
    var fear: int = clampi(int(context.get("max_party_fear", 0)), 0, 100)
    var danger_component: float = clampf((danger - 1.0) / 0.75, 0.0, 1.0)
    var darkness_component: float = 1.0 - float(light_value) / 10.0
    var fear_component: float = float(fear) / 100.0
    var threat_score: float = clampf(danger_component * 0.50 + darkness_component * 0.30 + fear_component * 0.20, 0.0, 1.0)

    var enter_threshold: float = clampf(float(config.get("exploration_threat_enter", 0.55)), 0.0, 1.0)
    var release_threshold: float = clampf(float(config.get("exploration_threat_release", 0.34)), 0.0, enter_threshold)
    var active_cue: String = str(context.get("active_cue", ""))
    var threatened: bool = threat_score >= enter_threshold or (active_cue == "exploration_threat" and threat_score >= release_threshold)
    var cue_id: String = "exploration_threat" if threatened else _base_exploration_cue(str(context.get("zone_id", "")))
    var intensity: float = clampf(0.16 + threat_score * 0.54, 0.12, 0.72)
    return {
        "switch_music": true,
        "cue": cue_id,
        "intensity": intensity,
        "threat_score": threat_score,
        "reason": "exploration_threat" if threatened else "exploration_context"
    }

func _base_exploration_cue(zone_id: String) -> String:
    var lowered: String = zone_id.to_lower()
    var tokens_variant: Variant = config.get("ruin_tokens", ["archive", "ruin", "crypt", "vault", "vestige"])
    var tokens: Array = tokens_variant if tokens_variant is Array else []
    for token_value: Variant in tokens:
        var token: String = str(token_value).to_lower()
        if token != "" and lowered.contains(token):
            return "exploration_ruins"
    return "exploration_ashlands"

func _music_switch_allowed() -> bool:
    var now: int = Time.get_ticks_msec()
    if dialogue_active or silence_active:
        return false
    if now < narrative_hold_until_msec or now < resolution_hold_until_msec:
        return false
    return now >= cue_hold_until_msec

func _apply_adaptive_mix() -> void:
    if dialogue_active or silence_active or NarrativeAudioDirector.current_space_id != "":
        return
    var music_base: float = float(AudioDirector.bus_levels_db.get("Music", -8.0))
    var ambience_base: float = float(AudioDirector.bus_levels_db.get("Ambience", -2.0))
    var music_span: float = float(config.get("music_intensity_span_db", 2.4))
    var ambience_span: float = float(config.get("ambience_intensity_span_db", 2.0))
    var music_offset: float = (current_intensity - 0.45) * music_span
    var ambience_offset: float = (0.35 - current_intensity) * ambience_span
    var music_target: float = clampf(music_base + music_offset, -80.0, 6.0)
    var ambience_target: float = clampf(ambience_base + ambience_offset, -80.0, 6.0)
    if absf(music_target - _last_music_target_db) < 0.05 and absf(ambience_target - _last_ambience_target_db) < 0.05:
        return
    _last_music_target_db = music_target
    _last_ambience_target_db = ambience_target
    if _mix_tween != null and _mix_tween.is_valid():
        _mix_tween.kill()
    _mix_tween = create_tween()
    _mix_tween.set_parallel(true)
    var seconds: float = _seconds("mix_reaction_seconds", 0.45)
    _tween_bus("Music", music_target, seconds)
    _tween_bus("Ambience", ambience_target, seconds)

func _tween_bus(bus_name: String, target_db: float, seconds: float) -> void:
    var index: int = AudioServer.get_bus_index(bus_name)
    if index < 0:
        return
    var current_db: float = AudioServer.get_bus_volume_db(index)
    _mix_tween.tween_method(Callable(self, "_set_bus_volume").bind(bus_name), current_db, target_db, seconds)

func _set_bus_volume(value: float, bus_name: String) -> void:
    var index: int = AudioServer.get_bus_index(bus_name)
    if index >= 0:
        AudioServer.set_bus_volume_db(index, clampf(value, -80.0, 6.0))

func _on_game_state_changed() -> void:
    refresh("game_state")

func _on_screen_requested(_screen_name: String) -> void:
    call_deferred("refresh", "screen")

func _on_audio_state_changed(_snapshot: Dictionary) -> void:
    call_deferred("refresh", "audio_state")

func _on_audio_mix_changed(_levels: Dictionary) -> void:
    call_deferred("_apply_adaptive_mix")

func _on_dialogue_state_changed(active: bool, _tag: String) -> void:
    dialogue_active = active
    silence_active = NarrativeAudioDirector.silence_active
    if not active:
        call_deferred("refresh", "dialogue_end")

func _on_narrative_beat_started(kind: String, _payload: Dictionary) -> void:
    var beats_variant: Variant = NarrativeAudioDirector.data.get("beats", {})
    var beats: Dictionary = beats_variant if beats_variant is Dictionary else {}
    var beat_value: Variant = beats.get(kind, {})
    var beat: Dictionary = beat_value if beat_value is Dictionary else {}
    var hold: float = float(beat.get("silence_seconds", 0.0)) + float(beat.get("hold_seconds", 0.0)) + 0.35
    hold = maxf(hold, _seconds("narrative_min_hold_seconds", 1.0))
    narrative_hold_until_msec = Time.get_ticks_msec() + int(round(hold * 1000.0))
    _hold_generation += 1
    _release_hold_after(hold, _hold_generation, "narrative_release")

func _on_combat_started(_encounter_id: String, _encounter_type: String) -> void:
    initial_enemy_count = maxi(1, GameState.alive_enemies().size())
    resolution_hold_until_msec = 0
    cue_hold_until_msec = 0
    call_deferred("refresh", "combat_start")

func _on_combat_finished(_encounter_id: String, _victory: bool, _loot: Dictionary) -> void:
    initial_enemy_count = 0
    var hold: float = _seconds("resolution_hold_seconds", 4.8)
    resolution_hold_until_msec = Time.get_ticks_msec() + int(round(hold * 1000.0))
    _hold_generation += 1
    _release_hold_after(hold, _hold_generation, "resolution_release")

func _release_hold_after(seconds: float, generation: int, reason: String) -> void:
    await get_tree().create_timer(maxf(0.05, seconds)).timeout
    if generation != _hold_generation:
        return
    if reason == "narrative_release":
        narrative_hold_until_msec = 0
    elif reason == "resolution_release":
        resolution_hold_until_msec = 0
    cue_hold_until_msec = 0
    refresh(reason)

func _on_new_game_reset() -> void:
    initial_enemy_count = 0
    current_intensity = 0.0
    current_reason = "new_game"
    current_decision.clear()
    narrative_hold_until_msec = 0
    resolution_hold_until_msec = 0
    cue_hold_until_msec = 0
    _hold_generation += 1
    _last_music_target_db = 999.0
    _last_ambience_target_db = 999.0
    call_deferred("refresh", "new_game")

func _seconds(key: String, fallback: float) -> float:
    return maxf(0.0, float(config.get(key, fallback)))
