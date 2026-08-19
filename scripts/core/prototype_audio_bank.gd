extends Node

const DATA_PATH := "res://data/prototype_audio_bank.json"

var data: Dictionary = {}
var _stream_cache: Dictionary = {}
var _variant_cursors: Dictionary = {}

func _ready() -> void:
    data = _load_dictionary(DATA_PATH)

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func assets() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values_variant: Variant = data.get("assets", [])
    var values: Array = values_variant if values_variant is Array else []
    for value: Variant in values:
        var item: Dictionary = value if value is Dictionary else {}
        if not item.is_empty():
            result.append(item.duplicate(true))
    return result

func external_verified_sources() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values_variant: Variant = data.get("external_verified_sources", [])
    var values: Array = values_variant if values_variant is Array else []
    for value: Variant in values:
        var item: Dictionary = value if value is Dictionary else {}
        if not item.is_empty():
            result.append(item.duplicate(true))
    return result

func asset_for_cue(cue_id: String, kind: String = "") -> Dictionary:
    for item: Dictionary in assets():
        if kind != "" and str(item.get("kind", "")) != kind:
            continue
        var cues_variant: Variant = item.get("cues", [])
        var cues: Array = cues_variant if cues_variant is Array else []
        if cues.has(cue_id):
            return item
    return {}

func has_cue(cue_id: String, kind: String = "") -> bool:
    return not asset_for_cue(cue_id, kind).is_empty()

func prototype_id_for_cue(cue_id: String, kind: String = "") -> String:
    return str(asset_for_cue(cue_id, kind).get("id", ""))

func stream_for_cue(cue_id: String, kind: String = "") -> AudioStream:
    var asset: Dictionary = asset_for_cue(cue_id, kind)
    if asset.is_empty():
        return null
    var asset_id: String = str(asset.get("id", ""))
    var variants: int = maxi(1, int(asset.get("variants", 1)))
    var cursor: int = int(_variant_cursors.get(asset_id, 0))
    var variant_index: int = cursor % variants
    _variant_cursors[asset_id] = cursor + 1
    var cache_key: String = "%s#%d" % [asset_id, variant_index]
    if _stream_cache.has(cache_key):
        return _stream_cache[cache_key] as AudioStream
    var stream: AudioStreamWAV = _build_stream(asset, variant_index)
    if stream != null:
        _stream_cache[cache_key] = stream
    return stream

func reset_variants() -> void:
    _variant_cursors.clear()

func clear_cache() -> void:
    _stream_cache.clear()

func coverage() -> Dictionary:
    var cue_ids: Dictionary = {}
    var sfx_count: int = 0
    var music_count: int = 0
    var loop_count: int = 0
    for item: Dictionary in assets():
        if str(item.get("kind", "")) == "music":
            music_count += 1
        else:
            sfx_count += 1
        if bool(item.get("loop", false)):
            loop_count += 1
        var cues_variant: Variant = item.get("cues", [])
        var cues: Array = cues_variant if cues_variant is Array else []
        for cue_value: Variant in cues:
            cue_ids[str(cue_value)] = true
    return {
        "assets": assets().size(),
        "sfx": sfx_count,
        "music": music_count,
        "loops": loop_count,
        "cues": cue_ids.size(),
        "cached_streams": _stream_cache.size(),
        "external_verified_sources": external_verified_sources().size()
    }

func _build_stream(asset: Dictionary, variant_index: int) -> AudioStreamWAV:
    var sample_rate: int = maxi(8000, int(data.get("sample_rate", 16000)))
    var duration: float = maxf(0.05, float(asset.get("duration", 0.2)))
    var frame_count: int = maxi(1, int(round(float(sample_rate) * duration)))
    var generator_id: String = str(asset.get("generator", ""))
    var pcm: PackedByteArray = PackedByteArray()
    pcm.resize(frame_count)
    var rng := RandomNumberGenerator.new()
    rng.seed = abs(hash(str(asset.get("id", "")))) + variant_index * 7919 + 17
    var filtered_noise: float = 0.0
    for frame: int in range(frame_count):
        var t: float = float(frame) / float(sample_rate)
        var sample: float = 0.0
        var raw_noise: float = rng.randf_range(-1.0, 1.0)
        filtered_noise = filtered_noise * 0.84 + raw_noise * 0.16
        match generator_id:
            "footstep_ash":
                var env_ash: float = exp(-16.0 * t)
                sample = (0.48 * filtered_noise + 0.24 * sin(TAU * 68.0 * t)) * env_ash
            "footstep_stone":
                var env_stone: float = exp(-24.0 * t)
                sample = (0.50 * raw_noise + 0.38 * sin(TAU * 96.0 * t)) * env_stone
                sample += 0.16 * sin(TAU * 1420.0 * t) * exp(-70.0 * t)
            "ui_confirm":
                var env_ui: float = exp(-45.0 * t)
                sample = (0.42 * sin(TAU * 650.0 * t) + 0.18 * sin(TAU * 1100.0 * t)) * env_ui
            "combat_telegraph":
                var env_telegraph: float = exp(-18.0 * t)
                sample = (0.55 * sin(TAU * 380.0 * t) + 0.25 * sin(TAU * 760.0 * t)) * env_telegraph
            "heartbeat":
                sample = _heartbeat_sample(t)
            "fear_breath":
                var breath_shape: float = sin(PI * clampf(t / duration, 0.0, 1.0))
                sample = filtered_noise * 0.34 * breath_shape + sin(TAU * 115.0 * t) * 0.06 * breath_shape
            "tinnitus":
                sample = sin(TAU * (4300.0 + 80.0 * sin(TAU * 3.0 * t)) * t) * 0.16 * exp(-2.2 * t)
            "panic_sting":
                sample = sin(TAU * (980.0 - 760.0 * clampf(t / duration, 0.0, 1.0)) * t) * 0.34 * exp(-5.0 * t)
                sample += raw_noise * 0.12 * exp(-10.0 * t)
            "boss_presence":
                sample = sin(TAU * 48.0 * t) * 0.62 * exp(-4.5 * t)
                sample += filtered_noise * 0.20 * exp(-3.0 * t)
            "boss_phase":
                var normalized: float = clampf(t / duration, 0.0, 1.0)
                var sweep_freq: float = lerpf(240.0, 54.0, normalized)
                sample = sin(TAU * sweep_freq * t) * 0.28 * exp(-2.0 * t)
                sample += sin(TAU * 55.0 * t) * 0.58 * exp(-6.0 * t)
                sample += filtered_noise * 0.25 * sin(PI * normalized)
            "wind_ashlands":
                sample = filtered_noise * 0.20 + sin(TAU * 37.0 * t) * 0.025 + sin(TAU * 71.0 * t) * 0.015
            "sanctuary_crowd":
                sample = filtered_noise * 0.055
                sample += 0.022 * sin(TAU * 118.0 * t + 0.7 * sin(TAU * 0.23 * t))
                sample += 0.012 * sin(TAU * 177.0 * t + 1.4 * sin(TAU * 0.17 * t))
            "tavern_roomtone":
                sample = filtered_noise * 0.070
                var hearth: float = pow(maxf(0.0, sin(TAU * 2.7 * t)), 12.0)
                sample += hearth * raw_noise * 0.055
                sample += 0.018 * sin(TAU * 92.0 * t)
            "chapel_roomtone":
                sample = filtered_noise * 0.025
                sample += 0.020 * sin(TAU * 66.0 * t) + 0.010 * sin(TAU * 99.0 * t)
            "memorial_roomtone":
                sample = filtered_noise * 0.035
                sample += 0.014 * sin(TAU * 43.0 * t + 0.35 * sin(TAU * 0.12 * t))
            "sanctuary_bell":
                var bell_env: float = exp(-2.9 * t)
                sample = bell_env * (0.31 * sin(TAU * 523.25 * t) + 0.18 * sin(TAU * 784.88 * t) + 0.09 * sin(TAU * 1046.5 * t))
            "memory_echo":
                var echo_env: float = sin(PI * clampf(t / duration, 0.0, 1.0)) * exp(-1.8 * t)
                sample = echo_env * (0.18 * sin(TAU * 311.0 * t) + 0.11 * sin(TAU * 466.5 * t + 0.5))
            "music_ashlands":
                sample = _music_sample(t, duration, [55.0, 82.5, 110.0], 0.0)
            "music_threat":
                sample = _music_sample(t, duration, [48.0, 72.0, 96.0, 144.0], 0.08)
            "music_combat":
                sample = _music_sample(t, duration, [65.0, 97.5, 130.0, 195.0], 0.16)
            "music_boss":
                sample = _music_sample(t, duration, [43.0, 64.5, 86.0, 129.0], 0.22)
            "music_victory":
                sample = _resolution_sample(t, duration, true)
            "music_defeat":
                sample = _resolution_sample(t, duration, false)
            "music_sanctuary":
                sample = _music_sample(t, duration, [65.4, 98.1, 130.8], 0.0)
            "music_tavern":
                sample = _music_sample(t, duration, [73.4, 110.0, 146.8], 0.035)
            "music_chapel":
                sample = _music_sample(t, duration, [55.0, 82.5, 123.75], 0.0)
            "music_memorial":
                sample = _music_sample(t, duration, [49.0, 73.5, 98.0], 0.0) * 0.82
            "music_revelation":
                sample = _music_sample(t, duration, [58.3, 87.45, 116.6, 174.9], 0.025)
            _:
                sample = 0.0
        var signed_sample: int = int(round(clampf(sample, -1.0, 1.0) * 127.0))
        pcm[frame] = signed_sample & 0xff

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_8_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = pcm
    if bool(asset.get("loop", false)):
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = frame_count
    return stream

func _heartbeat_sample(t: float) -> float:
    var result: float = 0.0
    for pulse_value: Variant in [[0.05, 0.74, 58.0], [0.18, 0.46, 48.0]]:
        var pulse: Array = pulse_value as Array
        var center: float = float(pulse[0])
        var dt: float = t - center
        if dt >= 0.0:
            result += float(pulse[1]) * sin(TAU * float(pulse[2]) * dt) * exp(-38.0 * dt)
    return result

func _music_sample(t: float, duration: float, frequencies: Array, pulse_amount: float) -> float:
    var value: float = 0.0
    for index: int in range(frequencies.size()):
        var frequency: float = float(frequencies[index])
        var slow_mod: float = 1.0 + 0.0035 * sin(TAU * (0.09 + float(index) * 0.025) * t)
        value += (0.16 / float(index + 1)) * sin(TAU * frequency * slow_mod * t)
    if pulse_amount > 0.0:
        var pulse: float = pow(0.5 + 0.5 * sin(TAU * 2.0 * t), 4.0)
        value += pulse_amount * pulse * sin(TAU * 48.0 * t)
    var edge: float = minf(1.0, minf(t / 0.12, (duration - t) / 0.12))
    return value * clampf(edge, 0.0, 1.0)

func _resolution_sample(t: float, duration: float, victory: bool) -> float:
    var normalized: float = clampf(t / duration, 0.0, 1.0)
    var base_frequency: float = 98.0 if victory else 73.0
    var second_frequency: float = 147.0 if victory else 109.5
    var envelope: float = sin(PI * normalized) * exp(-0.8 * t)
    return (0.26 * sin(TAU * base_frequency * t) + 0.13 * sin(TAU * second_frequency * t)) * envelope
