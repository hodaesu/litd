extends Node

signal settings_changed

const PATH := "user://litd_settings.json"

var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.9
var fullscreen := false
var subtitles := true
var screen_shake := true
var ui_scale := 1.0

func _ready() -> void:
    load_settings()
    apply()

func set_master_volume(value: float) -> void:
    master_volume = clampf(value, 0.0, 1.0)
    apply(); save_settings()

func set_music_volume(value: float) -> void:
    music_volume = clampf(value, 0.0, 1.0)
    apply(); save_settings()

func set_sfx_volume(value: float) -> void:
    sfx_volume = clampf(value, 0.0, 1.0)
    apply(); save_settings()

func set_fullscreen(value: bool) -> void:
    fullscreen = value
    apply(); save_settings()

func set_subtitles(value: bool) -> void:
    subtitles = value
    save_settings()

func set_screen_shake(value: bool) -> void:
    screen_shake = value
    save_settings()

func set_ui_scale(value: float) -> void:
    ui_scale = clampf(value, 0.8, 1.4)
    save_settings()

func apply() -> void:
    _set_bus("Master", master_volume)
    _set_bus("Music", music_volume)
    _set_bus("SFX", sfx_volume)
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
    settings_changed.emit()

func _set_bus(bus_name: String, linear: float) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    if index < 0:
        return
    AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, linear)))
    AudioServer.set_bus_mute(index, linear <= 0.001)

func save_settings() -> bool:
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(serialize()))
    settings_changed.emit()
    return true

func load_settings() -> bool:
    if not FileAccess.file_exists(PATH):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not parsed is Dictionary:
        return false
    master_volume = float(parsed.get("master_volume", master_volume))
    music_volume = float(parsed.get("music_volume", music_volume))
    sfx_volume = float(parsed.get("sfx_volume", sfx_volume))
    fullscreen = bool(parsed.get("fullscreen", fullscreen))
    subtitles = bool(parsed.get("subtitles", subtitles))
    screen_shake = bool(parsed.get("screen_shake", screen_shake))
    ui_scale = float(parsed.get("ui_scale", ui_scale))
    return true

func serialize() -> Dictionary:
    return {
        "master_volume": master_volume,
        "music_volume": music_volume,
        "sfx_volume": sfx_volume,
        "fullscreen": fullscreen,
        "subtitles": subtitles,
        "screen_shake": screen_shake,
        "ui_scale": ui_scale
    }
