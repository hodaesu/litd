extends Node

signal audio_state_changed(snapshot: Dictionary)
signal cue_requested(kind: String, cue_id: String, payload: Dictionary)
signal mix_changed(bus_levels: Dictionary)
signal music_transition_started(from_cue: String, to_cue: String, seconds: float)

const DATA_PATH := "res://data/audio_director.json"
const SILENT_DB: float = -80.0

var data: Dictionary = {}
var mode: String = "exploration"
var current_zone_id: String = ""
var current_encounter_id: String = ""
var current_encounter_type: String = ""
var boss_phase: int = 0
var fear_profile_id: String = "calm"
var max_party_fear: int = 0
var active_music_cue: String = ""
var active_music_candidate: Dictionary = {}
var active_music_source: String = "none"
var active_sfx_cues: Array[String] = []
var bus_levels_db: Dictionary = {}
var event_history: Array[Dictionary] = []
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index: int = -1
var _music_tween: Tween
var _music_transition_id: int = 0
var _connected: bool = false
var _last_boss_phase_seen: int = 0

func _ready() -> void:
    data = _load_dictionary(DATA_PATH)
    _ensure_buses()
    _ensure_music_players()
    _apply_current_mix()
    call_deferred("_connect_sources")
    call_deferred("refresh_from_game_state")

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _connect_sources() -> void:
    if _connected:
        return
    if not AshlandsRuntime.zone_discovered.is_connected(_on_zone_discovered):
        AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    if not AshlandsRuntime.transition_requested.is_connected(_on_zone_transition_requested):
        AshlandsRuntime.transition_requested.connect(_on_zone_transition_requested)
    if not AshlandsCombatBridge.ashlands_combat_started.is_connected(_on_combat_started):
        AshlandsCombatBridge.ashlands_combat_started.connect(_on_combat_started)
    if not AshlandsCombatBridge.ashlands_combat_finished.is_connected(_on_combat_finished):
        AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)
    if not PsychologyRuntime.hero_psychology_changed.is_connected(_on_hero_psychology_changed):
        PsychologyRuntime.hero_psychology_changed.connect(_on_hero_psychology_changed)
    if not GameState.state_changed.is_connected(_on_game_state_changed):
        GameState.state_changed.connect(_on_game_state_changed)
    _connected = true

func _ensure_buses() -> void:
    var order_variant: Variant = data.get("bus_order", [])
    var order: Array = order_variant if order_variant is Array else []
    for name_value: Variant in order:
        var bus_name: String = str(name_value)
        if bus_name == "" or bus_name == "Master":
            continue
        var bus_index: int = AudioServer.get_bus_index(bus_name)
        if bus_index < 0:
            AudioServer.add_bus()
            bus_index = AudioServer.get_bus_count() - 1
            AudioServer.set_bus_name(bus_index, bus_name)
            AudioServer.set_bus_send(bus_index, "Master")
    var defaults_variant: Variant = data.get("bus_defaults_db", {})
    var defaults: Dictionary = defaults_variant if defaults_variant is Dictionary else {}
    for key_value: Variant in defaults.keys():
        var bus_name: String = str(key_value)
        var bus_index: int = AudioServer.get_bus_index(bus_name)
        if bus_index >= 0:
            AudioServer.set_bus_volume_db(bus_index, clampf(float(defaults.get(key_value, 0.0)), SILENT_DB, 6.0))

func _ensure_music_players() -> void:
    if _music_players.size() == 2 and is_instance_valid(_music_players[0]) and is_instance_valid(_music_players[1]):
        return
    _music_players.clear()
    for index: int in range(2):
        var player := AudioStreamPlayer.new()
        player.name = "AdaptiveMusic%s" % ("A" if index == 0 else "B")
        player.bus = "Music"
        player.volume_db = SILENT_DB
        add_child(player)
        _music_players.append(player)

func required_buses() -> Array[String]:
    var result: Array[String] = []
    var values_variant: Variant = data.get("bus_order", [])
    var values: Array = values_variant if values_variant is Array else []
    for value: Variant in values:
        var bus_name: String = str(value)
        if bus_name != "":
            result.append(bus_name)
    return result

func music_player_count() -> int:
    _ensure_music_players()
    return _music_players.size()

func music_crossfade_seconds() -> float:
    return maxf(0.0, float(data.get("music_crossfade_seconds", 1.15)))

func is_music_transitioning() -> bool:
    return _music_tween != null and _music_tween.is_valid() and _music_tween.is_running()

func set_exploration_zone(zone_id: String) -> void:
    if zone_id == "":
        return
    current_zone_id = zone_id
    mode = "exploration"
    current_encounter_id = ""
    current_encounter_type = ""
    boss_phase = 0
    _last_boss_phase_seen = 0
    active_sfx_cues = _string_array_from_value(data.get("exploration_sfx", []))
    _sync_looping_context()
    _request_music(_music_cue_for_zone(zone_id), {"reason": "zone", "zone_id": zone_id})
    _refresh_fear_state(false)
    _apply_current_mix()
    _record_event("exploration", {"zone_id": zone_id, "music_cue": active_music_cue})
    _emit_state()

func enter_combat_context(encounter_id: String, encounter_type: String) -> void:
    current_encounter_id = encounter_id
    current_encounter_type = encounter_type
    mode = "boss" if encounter_type == "boss" else "combat"
    boss_phase = 1 if encounter_type == "boss" else 0
    _last_boss_phase_seen = boss_phase
    active_sfx_cues.clear()
    SfxRuntime.stop_all_loops()
    var music_map_variant: Variant = data.get("encounter_music", {})
    var music_map: Dictionary = music_map_variant if music_map_variant is Dictionary else {}
    var cue_id: String = str(music_map.get(encounter_type, music_map.get("normal", "combat_normal")))
    _request_music(cue_id, {"reason": "combat_start", "encounter_id": encounter_id, "encounter_type": encounter_type})
    if encounter_type == "boss":
        for cue_value: String in _string_array_from_value(data.get("boss_entry_sfx", [])):
            _request_sfx(cue_value, {"reason": "boss_entry", "encounter_id": encounter_id})
            if not active_sfx_cues.has(cue_value):
                active_sfx_cues.append(cue_value)
    _refresh_fear_state(false)
    _apply_current_mix()
    _record_event("combat_start", {"encounter_id": encounter_id, "encounter_type": encounter_type, "music_cue": cue_id})
    _emit_state()

func finish_combat_context(victory: bool) -> void:
    var finished_id: String = current_encounter_id
    var finished_type: String = current_encounter_type
    mode = "exploration"
    current_encounter_id = ""
    current_encounter_type = ""
    boss_phase = 0
    _last_boss_phase_seen = 0
    active_sfx_cues = _string_array_from_value(data.get("exploration_sfx", []))
    _sync_looping_context()
    var resolution_variant: Variant = data.get("combat_resolution_music", {})
    var resolution: Dictionary = resolution_variant if resolution_variant is Dictionary else {}
    var outcome_key: String = "victory" if victory else "defeat"
    var cue_id: String = str(resolution.get(outcome_key, "victory_costly" if victory else "defeat_retreat"))
    _request_music(cue_id, {"reason": "combat_finish", "victory": victory, "encounter_id": finished_id, "encounter_type": finished_type})
    _refresh_fear_state(false)
    _apply_current_mix()
    _record_event("combat_finish", {"encounter_id": finished_id, "encounter_type": finished_type, "victory": victory, "music_cue": cue_id})
    _emit_state()

func notify_boss_phase(phase_value: int) -> void:
    if mode != "boss" or phase_value <= 0 or phase_value == boss_phase:
        return
    var previous_phase: int = boss_phase
    boss_phase = phase_value
    _last_boss_phase_seen = phase_value
    if phase_value > previous_phase:
        for cue_value: String in _string_array_from_value(data.get("boss_phase_sfx", [])):
            _request_sfx(cue_value, {"reason": "boss_phase", "encounter_id": current_encounter_id, "phase": phase_value})
            if not active_sfx_cues.has(cue_value):
                active_sfx_cues.append(cue_value)
    _record_event("boss_phase", {"encounter_id": current_encounter_id, "from": previous_phase, "to": phase_value})
    _emit_state()

func refresh_from_game_state() -> void:
    _refresh_fear_state(true)
    _refresh_boss_phase_from_battle()
    if mode == "exploration" and current_zone_id == "" and str(AshlandsRuntime.current_zone_id) != "":
        current_zone_id = str(AshlandsRuntime.current_zone_id)
        active_sfx_cues = _string_array_from_value(data.get("exploration_sfx", []))
        _sync_looping_context()
    _apply_current_mix()
    _emit_state()

func request_sfx(cue_id: String, context: Dictionary = {}) -> Dictionary:
    return _request_sfx(cue_id, context)

func request_music(cue_id: String, context: Dictionary = {}) -> Dictionary:
    return _request_music(cue_id, context)

func snapshot() -> Dictionary:
    return {
        "mode": mode,
        "zone_id": current_zone_id,
        "encounter_id": current_encounter_id,
        "encounter_type": current_encounter_type,
        "boss_phase": boss_phase,
        "fear_profile": fear_profile_id,
        "max_party_fear": max_party_fear,
        "music_cue": active_music_cue,
        "music_candidate_id": str(active_music_candidate.get("id", "")),
        "music_source": active_music_source,
        "music_transitioning": is_music_transitioning(),
        "active_sfx_cues": active_sfx_cues.duplicate(),
        "loop_sfx_cues": SfxRuntime.loop_cues(),
        "sfx_emitters": SfxRuntime.active_count(),
        "bus_levels_db": bus_levels_db.duplicate(true),
        "history_size": event_history.size()
    }

func history() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Dictionary in event_history:
        result.append(value.duplicate(true))
    return result

func reset_runtime() -> void:
    mode = "exploration"
    current_zone_id = ""
    current_encounter_id = ""
    current_encounter_type = ""
    boss_phase = 0
    _last_boss_phase_seen = 0
    fear_profile_id = "calm"
    max_party_fear = 0
    active_music_cue = ""
    active_music_candidate.clear()
    active_music_source = "none"
    active_sfx_cues.clear()
    event_history.clear()
    _music_transition_id += 1
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()
    _music_tween = null
    _ensure_music_players()
    for player: AudioStreamPlayer in _music_players:
        player.stop()
        player.stream = null
        player.volume_db = SILENT_DB
    _active_music_index = -1
    SfxRuntime.reset_runtime()
    PrototypeAudioBank.reset_variants()
    _apply_current_mix()
    _emit_state()

func _on_zone_discovered(zone_id: String) -> void:
    if mode != "boss" and mode != "combat":
        set_exploration_zone(zone_id)

func _on_zone_transition_requested(zone_id: String) -> void:
    if mode != "boss" and mode != "combat":
        set_exploration_zone(zone_id)

func _on_combat_started(encounter_id: String, encounter_type: String) -> void:
    enter_combat_context(encounter_id, encounter_type)

func _on_combat_finished(_encounter_id: String, victory: bool, _loot: Dictionary) -> void:
    finish_combat_context(victory)

func _on_hero_psychology_changed(_hero_id: String, _event_id: String) -> void:
    _refresh_fear_state(true)
    _apply_current_mix()
    _emit_state()

func _on_game_state_changed() -> void:
    _refresh_fear_state(true)
    _refresh_boss_phase_from_battle()
    _apply_current_mix()

func _refresh_boss_phase_from_battle() -> void:
    if mode != "boss":
        return
    var detected_phase: int = 1
    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value if enemy_value is Dictionary else {}
        if enemy.is_empty():
            continue
        var same_encounter: bool = str(enemy.get("chapter_boss_id", "")) == current_encounter_id
        if same_encounter or bool(enemy.get("is_boss", false)):
            detected_phase = maxi(1, int(enemy.get("chapter_phase", 1)))
            break
    if detected_phase != _last_boss_phase_seen:
        notify_boss_phase(detected_phase)

func _refresh_fear_state(request_cues_on_change: bool) -> void:
    var highest: int = 0
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value if hero_value is Dictionary else {}
        if hero.is_empty() or int(hero.get("hp", 1)) <= 0:
            continue
        highest = maxi(highest, clampi(int(hero.get("fear", 0)), 0, 100))
    max_party_fear = highest
    var profile: Dictionary = _fear_profile_for(highest)
    var next_id: String = str(profile.get("id", "calm"))
    var changed: bool = next_id != fear_profile_id
    fear_profile_id = next_id
    _rebuild_contextual_sfx(profile)
    if changed and request_cues_on_change:
        var sfx_values: Array[String] = _string_array_from_value(profile.get("sfx", []))
        for cue_id: String in sfx_values:
            _request_sfx(cue_id, {"reason": "fear_profile", "fear": highest, "profile": fear_profile_id})
        _record_event("fear_profile", {"profile": fear_profile_id, "fear": highest})

func _rebuild_contextual_sfx(profile: Dictionary) -> void:
    var contextual: Array[String] = []
    if mode == "exploration":
        contextual = _string_array_from_value(data.get("exploration_sfx", []))
    elif mode == "boss":
        contextual = _string_array_from_value(data.get("boss_entry_sfx", []))
    var psychology_cues: Array[String] = _string_array_from_value(profile.get("sfx", []))
    for cue_id: String in psychology_cues:
        if not contextual.has(cue_id):
            contextual.append(cue_id)
    if mode == "boss" and boss_phase > 1:
        for cue_id: String in _string_array_from_value(data.get("boss_phase_sfx", [])):
            if not contextual.has(cue_id):
                contextual.append(cue_id)
    active_sfx_cues = contextual
    _sync_looping_context()

func _sync_looping_context() -> void:
    var loops: Array[String] = []
    if mode == "exploration":
        for cue_id: String in _string_array_from_value(data.get("exploration_sfx", [])):
            var asset: Dictionary = PrototypeAudioBank.asset_for_cue(cue_id, "sfx")
            if bool(asset.get("loop", false)):
                loops.append(cue_id)
    SfxRuntime.set_loop_cues(loops)

func _fear_profile_for(fear_value: int) -> Dictionary:
    var values_variant: Variant = data.get("fear_profiles", [])
    var values: Array = values_variant if values_variant is Array else []
    for profile_value: Variant in values:
        var profile: Dictionary = profile_value if profile_value is Dictionary else {}
        if fear_value >= int(profile.get("min", 0)) and fear_value <= int(profile.get("max", 100)):
            return profile
    return {"id": "calm", "min": 0, "max": 24, "psychology_db": SILENT_DB, "music_offset_db": 0.0, "sfx": []}

func _music_cue_for_zone(zone_id: String) -> String:
    var lowered: String = zone_id.to_lower()
    var rules_variant: Variant = data.get("zone_music_rules", [])
    var rules: Array = rules_variant if rules_variant is Array else []
    for rule_value: Variant in rules:
        var rule: Dictionary = rule_value if rule_value is Dictionary else {}
        var contains_values: Array[String] = _string_array_from_value(rule.get("contains", []))
        for token: String in contains_values:
            if token != "" and lowered.contains(token.to_lower()):
                return str(rule.get("cue", data.get("default_exploration_music", "exploration_ashlands")))
    return str(data.get("default_exploration_music", "exploration_ashlands"))

func _request_music(cue_id: String, context: Dictionary) -> Dictionary:
    if cue_id == "":
        return {}
    var previous_cue: String = active_music_cue
    active_music_cue = cue_id
    var tiers: Array[String] = []
    var policy_variant: Variant = data.get("selection_policy", {})
    var policy: Dictionary = policy_variant if policy_variant is Dictionary else {}
    var tiers_variant: Variant = policy.get("music_legal_tiers", ["green"])
    var tiers_raw: Array = tiers_variant if tiers_variant is Array else ["green"]
    for value: Variant in tiers_raw:
        tiers.append(str(value))
    var candidates: Array[Dictionary] = MusicLibrary.tracks_for_cue(cue_id, tiers)
    active_music_candidate = candidates[0].duplicate(true) if not candidates.is_empty() else {}
    active_music_source = "none"
    var stream: AudioStream = _stream_from_music_candidate(active_music_candidate)
    if stream != null:
        active_music_source = "catalog_local"
    elif bool(data.get("prototype_audio_enabled", true)) and PrototypeAudioBank.has_cue(cue_id, "music"):
        stream = PrototypeAudioBank.stream_for_cue(cue_id, "music")
        active_music_source = "prototype_generated" if stream != null else "none"
        if stream != null:
            active_music_candidate = {
                "id": PrototypeAudioBank.prototype_id_for_cue(cue_id, "music"),
                "title": "Prototype audio local",
                "legal_tier": "green"
            }
    var played: bool = false
    if stream != null:
        played = _crossfade_to_stream(stream, previous_cue, cue_id)
    var payload: Dictionary = context.duplicate(true)
    payload["candidate_id"] = str(active_music_candidate.get("id", ""))
    payload["candidate_count"] = candidates.size()
    payload["audio_source"] = active_music_source
    payload["has_runtime_audio"] = played
    payload["crossfade_seconds"] = music_crossfade_seconds()
    cue_requested.emit("music", cue_id, payload)
    return payload

func _stream_from_music_candidate(candidate: Dictionary) -> AudioStream:
    if candidate.is_empty():
        return null
    var local_path: String = str(candidate.get("local_path", ""))
    if local_path == "" or not local_path.begins_with("res://") or not ResourceLoader.exists(local_path):
        return null
    var resource: Resource = load(local_path)
    return resource as AudioStream if resource is AudioStream else null

func _crossfade_to_stream(stream: AudioStream, from_cue: String, to_cue: String) -> bool:
    if stream == null:
        return false
    _ensure_music_players()
    if _active_music_index >= 0:
        var active_player: AudioStreamPlayer = _music_players[_active_music_index]
        if active_player.stream == stream and active_player.playing:
            active_player.volume_db = 0.0
            return true
    var next_index: int = 0 if _active_music_index != 0 else 1
    var next_player: AudioStreamPlayer = _music_players[next_index]
    next_player.stop()
    next_player.stream = stream
    var duration: float = music_crossfade_seconds()
    if _active_music_index < 0 or duration <= 0.0:
        next_player.volume_db = 0.0
        next_player.play()
        if _active_music_index >= 0:
            var previous_player: AudioStreamPlayer = _music_players[_active_music_index]
            previous_player.stop()
            previous_player.stream = null
            previous_player.volume_db = SILENT_DB
        _active_music_index = next_index
        return true
    var old_player: AudioStreamPlayer = _music_players[_active_music_index]
    _music_transition_id += 1
    var transition_id: int = _music_transition_id
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()
    next_player.volume_db = SILENT_DB
    next_player.play()
    _music_tween = create_tween()
    _music_tween.set_parallel(true)
    _music_tween.tween_property(old_player, "volume_db", SILENT_DB, duration)
    _music_tween.tween_property(next_player, "volume_db", 0.0, duration)
    _music_tween.finished.connect(_on_music_crossfade_finished.bind(old_player, transition_id))
    _active_music_index = next_index
    music_transition_started.emit(from_cue, to_cue, duration)
    return true

func _on_music_crossfade_finished(old_player: AudioStreamPlayer, transition_id: int) -> void:
    if transition_id != _music_transition_id:
        return
    if is_instance_valid(old_player):
        old_player.stop()
        old_player.stream = null
        old_player.volume_db = SILENT_DB

func _request_sfx(cue_id: String, context: Dictionary) -> Dictionary:
    if cue_id == "" or not SfxLibrary.has_cue(cue_id):
        return {}
    var policy_variant: Variant = data.get("selection_policy", {})
    var policy: Dictionary = policy_variant if policy_variant is Dictionary else {}
    var include_amber: bool = bool(policy.get("sfx_include_amber", false))
    var packs: Array[Dictionary] = SfxLibrary.packs_for_cue(cue_id, include_amber)
    var pack_ids: Array[String] = []
    for pack: Dictionary in packs:
        var pack_id: String = str(pack.get("id", ""))
        if pack_id != "":
            pack_ids.append(pack_id)
    var playback: Dictionary = SfxRuntime.play_cue(cue_id, context)
    var payload: Dictionary = context.duplicate(true)
    payload["pack_ids"] = pack_ids
    payload["pack_count"] = packs.size()
    payload["spatial"] = str(SfxLibrary.cue_metadata(cue_id).get("spatial", "2d"))
    payload["has_runtime_audio"] = bool(playback.get("played", false))
    payload["audio_source"] = "prototype_generated" if bool(playback.get("played", false)) else "catalog_only"
    payload["prototype_id"] = str(playback.get("prototype_id", ""))
    payload["positioned"] = bool(playback.get("positioned", false))
    cue_requested.emit("sfx", cue_id, payload)
    return payload

func _apply_current_mix() -> void:
    _ensure_buses()
    var presets_variant: Variant = data.get("mix_presets", {})
    var presets: Dictionary = presets_variant if presets_variant is Dictionary else {}
    var preset_key: String = "boss" if mode == "boss" else ("combat" if mode == "combat" else "exploration")
    var preset_variant: Variant = presets.get(preset_key, data.get("bus_defaults_db", {}))
    var preset: Dictionary = preset_variant if preset_variant is Dictionary else {}
    var next_levels: Dictionary = preset.duplicate(true)
    var profile: Dictionary = _fear_profile_for(max_party_fear)
    if next_levels.has("Psychology"):
        next_levels["Psychology"] = float(profile.get("psychology_db", next_levels.get("Psychology", SILENT_DB)))
    if next_levels.has("Music"):
        next_levels["Music"] = clampf(float(next_levels.get("Music", 0.0)) + float(profile.get("music_offset_db", 0.0)), SILENT_DB, 6.0)
    _apply_bus_levels(next_levels)

func _apply_bus_levels(levels: Dictionary) -> void:
    bus_levels_db.clear()
    for key_value: Variant in levels.keys():
        var bus_name: String = str(key_value)
        var db: float = clampf(float(levels.get(key_value, 0.0)), SILENT_DB, 6.0)
        var bus_index: int = AudioServer.get_bus_index(bus_name)
        if bus_index < 0:
            continue
        AudioServer.set_bus_volume_db(bus_index, db)
        bus_levels_db[bus_name] = db
    mix_changed.emit(bus_levels_db.duplicate(true))

func _record_event(kind: String, payload: Dictionary) -> void:
    var item: Dictionary = payload.duplicate(true)
    item["kind"] = kind
    event_history.append(item)
    var history_limit: int = maxi(8, int(data.get("history_limit", 48)))
    while event_history.size() > history_limit:
        event_history.pop_front()

func _emit_state() -> void:
    audio_state_changed.emit(snapshot())

func _string_array_from_value(value: Variant) -> Array[String]:
    var result: Array[String] = []
    var values: Array = value if value is Array else []
    for item: Variant in values:
        var text: String = str(item)
        if text != "":
            result.append(text)
    return result
