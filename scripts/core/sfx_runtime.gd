extends Node

signal cue_played(cue_id: String, spatial: String, bus_name: String)
signal loop_state_changed(cues: Array[String])

const MAX_ACTIVE_EMITTERS: int = 24

var _active_emitters: Array[Node] = []
var _loop_players: Dictionary = {}
var _playback_counter: int = 0
var _last_playback: Dictionary = {}

func play_cue(cue_id: String, context: Dictionary = {}) -> Dictionary:
    if cue_id == "":
        return {"played": false, "reason": "empty_cue"}
    var stream: AudioStream = PrototypeAudioBank.stream_for_cue(cue_id, "sfx")
    if stream == null:
        return {"played": false, "reason": "no_local_stream", "cue_id": cue_id}
    _trim_emitters()
    var metadata: Dictionary = SfxLibrary.cue_metadata(cue_id)
    var spatial: String = str(metadata.get("spatial", "2d"))
    var bus_name: String = _bus_for_cue(cue_id)
    var position_value: Variant = context.get("position_3d", null)
    var can_spatialize: bool = spatial == "3d" and position_value is Vector3
    var emitter: Node
    if can_spatialize:
        var player_3d := AudioStreamPlayer3D.new()
        player_3d.name = "Sfx3D_%s" % cue_id
        player_3d.bus = bus_name
        player_3d.stream = stream
        player_3d.global_position = position_value as Vector3
        player_3d.unit_size = maxf(1.0, float(context.get("unit_size", 4.0)))
        player_3d.max_distance = maxf(4.0, float(context.get("max_distance", 28.0)))
        player_3d.max_polyphony = 1
        _apply_variation(player_3d, cue_id, context)
        add_child(player_3d)
        player_3d.finished.connect(_on_emitter_finished.bind(player_3d))
        player_3d.play()
        emitter = player_3d
    else:
        var player := AudioStreamPlayer.new()
        player.name = "Sfx2D_%s" % cue_id
        player.bus = bus_name
        player.stream = stream
        player.max_polyphony = 1
        _apply_variation(player, cue_id, context)
        add_child(player)
        player.finished.connect(_on_emitter_finished.bind(player))
        player.play()
        emitter = player
        spatial = "2d"
    _active_emitters.append(emitter)
    _playback_counter += 1
    _last_playback = {
        "cue_id": cue_id,
        "spatial": spatial,
        "bus": bus_name,
        "positioned": can_spatialize,
        "counter": _playback_counter,
        "prototype_id": PrototypeAudioBank.prototype_id_for_cue(cue_id, "sfx")
    }
    cue_played.emit(cue_id, spatial, bus_name)
    return {
        "played": true,
        "cue_id": cue_id,
        "spatial": spatial,
        "bus": bus_name,
        "positioned": can_spatialize,
        "prototype_id": str(_last_playback.get("prototype_id", ""))
    }

func set_loop_cues(cue_ids: Array[String]) -> void:
    var wanted: Dictionary = {}
    for cue_id: String in cue_ids:
        if cue_id != "" and PrototypeAudioBank.has_cue(cue_id, "sfx"):
            wanted[cue_id] = true
    for existing_value: Variant in _loop_players.keys():
        var existing: String = str(existing_value)
        if wanted.has(existing):
            continue
        var old_player: AudioStreamPlayer = _loop_players.get(existing, null) as AudioStreamPlayer
        if is_instance_valid(old_player):
            old_player.stop()
            old_player.queue_free()
        _loop_players.erase(existing)
    for wanted_value: Variant in wanted.keys():
        var cue_id: String = str(wanted_value)
        if _loop_players.has(cue_id):
            continue
        var stream: AudioStream = PrototypeAudioBank.stream_for_cue(cue_id, "sfx")
        if stream == null:
            continue
        var player := AudioStreamPlayer.new()
        player.name = "SfxLoop_%s" % cue_id
        player.bus = _bus_for_cue(cue_id)
        player.stream = stream
        player.volume_db = -4.0
        add_child(player)
        player.play()
        _loop_players[cue_id] = player
    loop_state_changed.emit(loop_cues())

func stop_all_loops() -> void:
    set_loop_cues([])

func loop_cues() -> Array[String]:
    var result: Array[String] = []
    for key_value: Variant in _loop_players.keys():
        result.append(str(key_value))
    result.sort()
    return result

func active_count() -> int:
    _trim_emitters()
    return _active_emitters.size()

func last_playback() -> Dictionary:
    return _last_playback.duplicate(true)

func reset_runtime() -> void:
    for emitter: Node in _active_emitters:
        if is_instance_valid(emitter):
            if emitter.has_method("stop"):
                emitter.call("stop")
            emitter.queue_free()
    _active_emitters.clear()
    stop_all_loops()
    _last_playback.clear()
    _playback_counter = 0

func _bus_for_cue(cue_id: String) -> String:
    var asset: Dictionary = PrototypeAudioBank.asset_for_cue(cue_id, "sfx")
    var explicit_bus: String = str(asset.get("bus", ""))
    if explicit_bus != "":
        return explicit_bus
    var domain: String = SfxLibrary.cue_domain(cue_id)
    match domain:
        "combat", "boss":
            return "Combat"
        "creature":
            return "Creatures"
        "psychology", "narrative":
            return "Psychology"
        "ambience", "environment", "sanctuary":
            return "Ambience"
        "ui":
            return "UI"
        "interaction", "foley", "exploration":
            return "Foley"
        _:
            return "Foley"

func _apply_variation(player: Node, cue_id: String, context: Dictionary) -> void:
    var fixed_pitch: Variant = context.get("pitch_scale", null)
    var fixed_volume: Variant = context.get("volume_db", null)
    var seed_value: int = abs(hash(cue_id)) + _playback_counter * 3571 + 29
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var pitch: float = float(fixed_pitch) if fixed_pitch is float or fixed_pitch is int else rng.randf_range(0.96, 1.04)
    var volume: float = float(fixed_volume) if fixed_volume is float or fixed_volume is int else rng.randf_range(-1.25, 0.0)
    player.set("pitch_scale", pitch)
    player.set("volume_db", volume)

func _on_emitter_finished(emitter: Node) -> void:
    _active_emitters.erase(emitter)
    if is_instance_valid(emitter):
        emitter.queue_free()

func _trim_emitters() -> void:
    var alive: Array[Node] = []
    for emitter: Node in _active_emitters:
        if is_instance_valid(emitter):
            alive.append(emitter)
    _active_emitters = alive
    while _active_emitters.size() >= MAX_ACTIVE_EMITTERS:
        var oldest: Node = _active_emitters.pop_front()
        if is_instance_valid(oldest):
            if oldest.has_method("stop"):
                oldest.call("stop")
            oldest.queue_free()
