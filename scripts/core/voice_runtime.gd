extends Node

signal voice_started(line_id: String, local_path: String)
signal voice_finished(line_id: String)
signal voice_missing(line_id: String)

const MANIFEST_PATH := "res://data/voice_assets.json"

var _assets_by_line: Dictionary = {}
var _player: AudioStreamPlayer
var _active_line_id: String = ""
var _dialogue_token: String = ""

func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.name = "VoicePlayer"
    _player.bus = "Dialogue"
    add_child(_player)
    _player.finished.connect(_on_player_finished)
    reload_manifest()
    if not DialogueDirector.line_selected.is_connected(_on_line_selected):
        DialogueDirector.line_selected.connect(_on_line_selected)

func reload_manifest() -> void:
    _assets_by_line.clear()
    if not FileAccess.file_exists(MANIFEST_PATH):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    if not parsed is Dictionary:
        return
    var payload: Dictionary = parsed
    for value in payload.get("assets", []):
        var asset: Dictionary = value if value is Dictionary else {}
        var line_id: String = str(asset.get("line_id", ""))
        if line_id != "":
            _assets_by_line[line_id] = asset.duplicate(true)

func asset_for_line(line_id: String) -> Dictionary:
    var value: Variant = _assets_by_line.get(line_id, {})
    return value.duplicate(true) if value is Dictionary else {}

func voice_available(line_id: String) -> bool:
    var asset: Dictionary = asset_for_line(line_id)
    if asset.is_empty():
        return false
    if not bool(asset.get("human_reviewed", false)):
        return false
    var local_path: String = str(asset.get("local_path", ""))
    return local_path != "" and ResourceLoader.exists(local_path)

func play_payload(payload: Dictionary) -> bool:
    var line_id: String = str(payload.get("id", ""))
    if line_id == "" or not voice_available(line_id):
        if line_id != "":
            voice_missing.emit(line_id)
        return false

    var asset: Dictionary = asset_for_line(line_id)
    var local_path: String = str(asset.get("local_path", ""))
    var stream: AudioStream = load(local_path) as AudioStream
    if stream == null:
        voice_missing.emit(line_id)
        return false

    if _player.playing:
        _finish_active_voice(false)

    _active_line_id = line_id
    _dialogue_token = "voice:" + line_id
    _player.stream = stream
    NarrativeAudioDirector.begin_dialogue(_dialogue_token)
    _player.play()
    voice_started.emit(line_id, local_path)
    return true

func stop_voice() -> void:
    if _player.playing:
        _player.stop()
    _finish_active_voice(false)

func _on_line_selected(payload: Dictionary) -> void:
    play_payload(payload)

func _on_player_finished() -> void:
    _finish_active_voice(true)

func _finish_active_voice(emit_finished_signal: bool) -> void:
    var finished_line: String = _active_line_id
    if _dialogue_token != "":
        NarrativeAudioDirector.end_dialogue(_dialogue_token)
    _active_line_id = ""
    _dialogue_token = ""
    if emit_finished_signal and finished_line != "":
        voice_finished.emit(finished_line)

func snapshot() -> Dictionary:
    return {
        "active_line_id": _active_line_id,
        "playing": _player != null and _player.playing,
        "asset_count": _assets_by_line.size()
    }
