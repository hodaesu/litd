extends Node

signal layer_mix_changed(snapshot: Dictionary)
signal layered_cue_started(cue_id: String, bank: int)

const DATA_PATH := "res://data/adaptive_music_layers.json"
const SILENT_DB: float = -80.0

var data: Dictionary = {}
var current_cue: String = ""
var current_intensity: float = 0.0
var active_layers: Array[String] = []
var cue_generation: int = 0

var _layer_order: Array[String] = []
var _banks: Array = []
var _bank_cues: Array[String] = ["", ""]
var _active_bank: int = -1
var _stream_cache: Dictionary = {}
var _mix_tween: Tween
var _transition_generation: int = 0
var _connected: bool = false

func _ready() -> void:
    data = _load_dictionary(DATA_PATH)
    _layer_order = _string_array(data.get("layer_order", []))
    _ensure_banks()
    call_deferred("_connect_sources")
    call_deferred("_sync_from_directors")

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _connect_sources() -> void:
    if _connected:
        return
    if not AudioDirector.cue_requested.is_connected(_on_audio_cue_requested):
        AudioDirector.cue_requested.connect(_on_audio_cue_requested)
    if not AdaptiveMusicDirector.adaptation_changed.is_connected(_on_adaptation_changed):
        AdaptiveMusicDirector.adaptation_changed.connect(_on_adaptation_changed)
    if not NarrativeAudioDirector.narrative_audio_changed.is_connected(_on_narrative_audio_changed):
        NarrativeAudioDirector.narrative_audio_changed.connect(_on_narrative_audio_changed)
    if not NarrativeAudioDirector.dialogue_state_changed.is_connected(_on_dialogue_state_changed):
        NarrativeAudioDirector.dialogue_state_changed.connect(_on_dialogue_state_changed)
    _connected = true

func _sync_from_directors() -> void:
    current_intensity = clampf(float(AdaptiveMusicDirector.current_intensity), 0.0, 1.0)
    var cue_id: String = str(AudioDirector.active_music_cue)
    if supports_cue(cue_id):
        sync_cue(cue_id, current_intensity)

func profiles() -> Dictionary:
    var value: Variant = data.get("profiles", {})
    return value.duplicate(true) if value is Dictionary else {}

func profile_for_cue(cue_id: String) -> Dictionary:
    var map: Dictionary = profiles()
    var value: Variant = map.get(cue_id, {})
    return value.duplicate(true) if value is Dictionary else {}

func supports_cue(cue_id: String) -> bool:
    return not profile_for_cue(cue_id).is_empty()

func layer_player_count() -> int:
    _ensure_banks()
    var count: int = 0
    for bank_value: Variant in _banks:
        var bank: Array = bank_value if bank_value is Array else []
        count += bank.size()
    return count

func running_layer_count() -> int:
    if _active_bank < 0 or _active_bank >= _banks.size():
        return 0
    var bank: Array = _banks[_active_bank]
    var count: int = 0
    for player_value: Variant in bank:
        var player: AudioStreamPlayer = player_value as AudioStreamPlayer
        if player != null and player.playing:
            count += 1
    return count

func preview_layer_ids(cue_id: String, intensity: float, previous_layers: Array[String] = []) -> Array[String]:
    var profile: Dictionary = profile_for_cue(cue_id)
    if profile.is_empty():
        return []
    var layers_variant: Variant = profile.get("layers", {})
    var layers: Dictionary = layers_variant if layers_variant is Dictionary else {}
    var result: Array[String] = []
    var normalized: float = clampf(intensity, 0.0, 1.0)
    for layer_id: String in _layer_order:
        var definition_value: Variant = layers.get(layer_id, {})
        var definition: Dictionary = definition_value if definition_value is Dictionary else {}
        if definition.is_empty():
            continue
        var was_active: bool = previous_layers.has(layer_id)
        var threshold: float = float(definition.get("exit", 0.0)) if was_active else float(definition.get("enter", 1.0))
        if normalized >= threshold:
            result.append(layer_id)
    return result

func sync_cue(cue_id: String, intensity: float = -1.0) -> void:
    var requested_intensity: float = current_intensity if intensity < 0.0 else clampf(intensity, 0.0, 1.0)
    current_intensity = requested_intensity
    if not supports_cue(cue_id):
        _fade_out_and_stop_all()
        current_cue = ""
        active_layers.clear()
        layer_mix_changed.emit(snapshot())
        return
    if cue_id == current_cue and _active_bank >= 0:
        _apply_intensity(requested_intensity)
        return
    _start_layered_cue(cue_id, requested_intensity)

func set_intensity(value: float) -> void:
    current_intensity = clampf(value, 0.0, 1.0)
    if current_cue != "" and _active_bank >= 0:
        _apply_intensity(current_intensity)

func snapshot() -> Dictionary:
    return {
        "cue": current_cue,
        "intensity": current_intensity,
        "active_layers": active_layers.duplicate(),
        "active_bank": _active_bank,
        "bank_cues": _bank_cues.duplicate(),
        "player_count": layer_player_count(),
        "running_layers": running_layer_count(),
        "phase_spread_seconds": phase_spread_seconds(),
        "narrative_override": _narrative_override_active(),
        "cue_generation": cue_generation
    }

func phase_spread_seconds() -> float:
    if _active_bank < 0 or _active_bank >= _banks.size():
        return 0.0
    var bank: Array = _banks[_active_bank]
    var minimum: float = INF
    var maximum: float = -INF
    var found: bool = false
    for player_value: Variant in bank:
        var player: AudioStreamPlayer = player_value as AudioStreamPlayer
        if player == null or not player.playing:
            continue
        var position: float = player.get_playback_position()
        minimum = minf(minimum, position)
        maximum = maxf(maximum, position)
        found = true
    return maxf(0.0, maximum - minimum) if found else 0.0

func reset_runtime() -> void:
    _cancel_tween()
    for bank_value: Variant in _banks:
        var bank: Array = bank_value if bank_value is Array else []
        for player_value: Variant in bank:
            var player: AudioStreamPlayer = player_value as AudioStreamPlayer
            if player == null:
                continue
            player.stop()
            player.stream = null
            player.volume_db = SILENT_DB
    current_cue = ""
    current_intensity = 0.0
    active_layers.clear()
    _active_bank = -1
    _bank_cues = ["", ""]
    cue_generation = 0
    _transition_generation += 1

func _ensure_banks() -> void:
    if _banks.size() == 2:
        return
    _banks.clear()
    for bank_index: int in range(2):
        var bank: Array = []
        for layer_id: String in _layer_order:
            var player := AudioStreamPlayer.new()
            player.name = "AdaptiveStem_%d_%s" % [bank_index, layer_id]
            player.bus = "Music"
            player.volume_db = SILENT_DB
            add_child(player)
            bank.append(player)
        _banks.append(bank)

func _start_layered_cue(cue_id: String, intensity: float) -> void:
    _ensure_banks()
    var profile: Dictionary = profile_for_cue(cue_id)
    if profile.is_empty():
        return
    var next_bank: int = 0 if _active_bank != 0 else 1
    var next_players: Array = _banks[next_bank]
    for index: int in range(_layer_order.size()):
        var player: AudioStreamPlayer = next_players[index] as AudioStreamPlayer
        player.stop()
        player.stream = _stream_for_layer(cue_id, _layer_order[index], profile)
        player.volume_db = SILENT_DB
        if player.stream != null:
            player.play(0.0)

    var old_bank: int = _active_bank
    _active_bank = next_bank
    _bank_cues[next_bank] = cue_id
    current_cue = cue_id
    current_intensity = clampf(intensity, 0.0, 1.0)
    active_layers = preview_layer_ids(cue_id, current_intensity, [])
    cue_generation += 1

    _cancel_tween()
    _mix_tween = create_tween()
    _mix_tween.set_parallel(true)
    var seconds: float = maxf(0.0, float(data.get("crossfade_seconds", 0.62)))
    if old_bank >= 0:
        var old_players: Array = _banks[old_bank]
        for old_value: Variant in old_players:
            var old_player: AudioStreamPlayer = old_value as AudioStreamPlayer
            if old_player != null:
                _mix_tween.tween_property(old_player, "volume_db", SILENT_DB, seconds)
    for index: int in range(_layer_order.size()):
        var layer_id: String = _layer_order[index]
        var new_player: AudioStreamPlayer = next_players[index] as AudioStreamPlayer
        if new_player == null:
            continue
        var target: float = SILENT_DB if _narrative_override_active() or not active_layers.has(layer_id) else _target_db(profile, layer_id, current_intensity)
        _mix_tween.tween_property(new_player, "volume_db", target, seconds)

    _transition_generation += 1
    var generation: int = _transition_generation
    if old_bank >= 0:
        _mix_tween.finished.connect(_finish_bank_crossfade.bind(old_bank, generation))
    layered_cue_started.emit(cue_id, next_bank)
    layer_mix_changed.emit(snapshot())

func _finish_bank_crossfade(old_bank: int, generation: int) -> void:
    if generation != _transition_generation or old_bank < 0 or old_bank >= _banks.size() or old_bank == _active_bank:
        return
    var bank: Array = _banks[old_bank]
    for player_value: Variant in bank:
        var player: AudioStreamPlayer = player_value as AudioStreamPlayer
        if player == null:
            continue
        player.stop()
        player.stream = null
        player.volume_db = SILENT_DB
    _bank_cues[old_bank] = ""

func _apply_intensity(value: float) -> void:
    if current_cue == "" or _active_bank < 0:
        return
    var profile: Dictionary = profile_for_cue(current_cue)
    if profile.is_empty():
        return
    current_intensity = clampf(value, 0.0, 1.0)
    active_layers = preview_layer_ids(current_cue, current_intensity, active_layers)
    _cancel_tween()
    _mix_tween = create_tween()
    _mix_tween.set_parallel(true)
    var seconds: float = maxf(0.0, float(data.get("layer_reaction_seconds", 0.42)))
    var players: Array = _banks[_active_bank]
    var override_active: bool = _narrative_override_active()
    for index: int in range(_layer_order.size()):
        var layer_id: String = _layer_order[index]
        var player: AudioStreamPlayer = players[index] as AudioStreamPlayer
        if player == null:
            continue
        var target: float = SILENT_DB if override_active or not active_layers.has(layer_id) else _target_db(profile, layer_id, current_intensity)
        _mix_tween.tween_property(player, "volume_db", target, seconds)
    layer_mix_changed.emit(snapshot())

func _target_db(profile: Dictionary, layer_id: String, intensity: float) -> float:
    var layers_variant: Variant = profile.get("layers", {})
    var layers: Dictionary = layers_variant if layers_variant is Dictionary else {}
    var definition_value: Variant = layers.get(layer_id, {})
    var definition: Dictionary = definition_value if definition_value is Dictionary else {}
    if definition.is_empty():
        return SILENT_DB
    var base_db: float = float(definition.get("db", -20.0))
    var enter: float = clampf(float(definition.get("enter", 0.0)), 0.0, 0.99)
    var energy: float = clampf((intensity - enter) / maxf(0.01, 1.0 - enter), 0.0, 1.0)
    return clampf(base_db + energy * 2.5, SILENT_DB, 0.0)

func _narrative_override_active() -> bool:
    if NarrativeAudioDirector.dialogue_depth > 0 or NarrativeAudioDirector.silence_active:
        return true
    return NarrativeAudioDirector.current_space_id != "" and AudioDirector.mode == "exploration"

func _fade_out_and_stop_all() -> void:
    _cancel_tween()
    if _active_bank < 0:
        return
    var bank_to_stop: int = _active_bank
    var players: Array = _banks[bank_to_stop]
    _mix_tween = create_tween()
    _mix_tween.set_parallel(true)
    var seconds: float = maxf(0.0, float(data.get("layer_reaction_seconds", 0.42)))
    for player_value: Variant in players:
        var player: AudioStreamPlayer = player_value as AudioStreamPlayer
        if player != null:
            _mix_tween.tween_property(player, "volume_db", SILENT_DB, seconds)
    _transition_generation += 1
    var generation: int = _transition_generation
    _mix_tween.finished.connect(_finish_unsupported_fade.bind(bank_to_stop, generation))
    _active_bank = -1

func _finish_unsupported_fade(bank_index: int, generation: int) -> void:
    if generation != _transition_generation or bank_index < 0 or bank_index >= _banks.size():
        return
    var bank: Array = _banks[bank_index]
    for player_value: Variant in bank:
        var player: AudioStreamPlayer = player_value as AudioStreamPlayer
        if player != null:
            player.stop()
            player.stream = null
            player.volume_db = SILENT_DB
    _bank_cues[bank_index] = ""

func _cancel_tween() -> void:
    if _mix_tween != null and _mix_tween.is_valid():
        _mix_tween.kill()
    _mix_tween = null

func _stream_for_layer(cue_id: String, layer_id: String, profile: Dictionary) -> AudioStream:
    var cache_key: String = "%s:%s" % [cue_id, layer_id]
    if _stream_cache.has(cache_key):
        return _stream_cache[cache_key] as AudioStream
    var stream: AudioStreamWAV = _build_layer_stream(layer_id, profile)
    if stream != null:
        _stream_cache[cache_key] = stream
    return stream

func _build_layer_stream(layer_id: String, profile: Dictionary) -> AudioStreamWAV:
    var sample_rate: int = maxi(8000, int(data.get("sample_rate", 12000)))
    var duration: float = maxf(0.5, float(profile.get("duration_seconds", 3.0)))
    var frame_count: int = maxi(1, int(round(float(sample_rate) * duration)))
    var frequencies_variant: Variant = profile.get("frequencies", [55.0, 82.5, 110.0])
    var frequencies: Array = frequencies_variant if frequencies_variant is Array else [55.0, 82.5, 110.0]
    var tempo_hz: float = maxf(0.2, float(profile.get("tempo_hz", 1.0)))
    var pcm := PackedByteArray()
    pcm.resize(frame_count)
    for frame: int in range(frame_count):
        var t: float = float(frame) / float(sample_rate)
        var sample: float = _layer_sample(layer_id, t, tempo_hz, frequencies)
        var signed_sample: int = int(round(clampf(sample, -1.0, 1.0) * 127.0))
        pcm[frame] = signed_sample & 0xff
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_8_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = pcm
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = frame_count
    return stream

func _layer_sample(layer_id: String, t: float, tempo_hz: float, frequencies: Array) -> float:
    var fundamental: float = maxf(32.0, float(frequencies[0]) if not frequencies.is_empty() else 55.0)
    var beat_period: float = 1.0 / tempo_hz
    var local_beat: float = fposmod(t, beat_period)
    match layer_id:
        "pulse":
            var pulse: float = pow(0.5 + 0.5 * sin(TAU * tempo_hz * t - PI * 0.5), 5.0)
            return 0.24 * pulse * sin(TAU * fundamental * 0.5 * t)
        "percussion":
            var kick: float = sin(TAU * fundamental * 0.72 * local_beat) * exp(-18.0 * local_beat)
            var second_local: float = fposmod(t + beat_period * 0.5, beat_period)
            var second: float = sin(TAU * fundamental * 1.45 * second_local) * exp(-28.0 * second_local)
            return 0.32 * kick + 0.13 * second
        "strings":
            var strings: float = 0.0
            for index: int in range(frequencies.size()):
                var frequency: float = float(frequencies[index]) * 2.0
                strings += (0.065 / float(index + 1)) * sin(TAU * frequency * t + 0.16 * sin(TAU * 0.11 * t + float(index)))
            return strings
        "choir":
            var breath: float = 0.72 + 0.28 * sin(TAU * 0.19 * t)
            var choir: float = 0.0
            for index: int in range(mini(3, frequencies.size())):
                var frequency: float = float(frequencies[index])
                choir += 0.052 * sin(TAU * frequency * 1.5 * t + float(index) * 0.7)
                choir += 0.030 * sin(TAU * frequency * 3.0 * t + float(index) * 0.4)
            return choir * breath
        "crisis":
            var tremolo: float = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TAU * tempo_hz * 2.0 * t), 3.0)
            var dissonance: float = 0.12 * sin(TAU * fundamental * 1.4142 * t)
            dissonance += 0.09 * sin(TAU * fundamental * 2.07 * t + 0.8)
            dissonance += 0.08 * sin(TAU * fundamental * 0.5 * local_beat) * exp(-12.0 * local_beat)
            return dissonance * tremolo
        _:
            return 0.0

func _on_audio_cue_requested(kind: String, cue_id: String, _payload: Dictionary) -> void:
    if kind != "music":
        return
    sync_cue(cue_id, current_intensity)

func _on_adaptation_changed(adaptation: Dictionary) -> void:
    current_intensity = clampf(float(adaptation.get("intensity", current_intensity)), 0.0, 1.0)
    var cue_id: String = str(adaptation.get("music_cue", AudioDirector.active_music_cue))
    if supports_cue(cue_id):
        if cue_id != current_cue:
            sync_cue(cue_id, current_intensity)
        else:
            _apply_intensity(current_intensity)
    elif current_cue != "":
        sync_cue(cue_id, current_intensity)

func _on_narrative_audio_changed(_snapshot: Dictionary) -> void:
    if current_cue != "" and _active_bank >= 0:
        _apply_intensity(current_intensity)

func _on_dialogue_state_changed(_active: bool, _tag: String) -> void:
    if current_cue != "" and _active_bank >= 0:
        _apply_intensity(current_intensity)

func _string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    var values: Array = value if value is Array else []
    for item: Variant in values:
        var text: String = str(item)
        if text != "":
            result.append(text)
    return result
