extends Node

signal settings_changed

const PATH := "user://litd_settings.json"

var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.9
var voice_volume := 0.9
var ambience_volume := 0.85
var ui_volume := 0.9
var fullscreen := false
var subtitles := true
var screen_shake := true
var ui_scale := 1.0
var text_scale := 1.0
var high_contrast := false
var reduce_flashes := false
var color_assist := "none"
var dynamic_range := "medium"
var mono_output := false
var animation_speed := 1.0

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

func set_voice_volume(value: float) -> void:
    voice_volume = clampf(value, 0.0, 1.0)
    apply(); save_settings()

func set_ambience_volume(value: float) -> void:
    ambience_volume = clampf(value, 0.0, 1.0)
    apply(); save_settings()

func set_ui_volume(value: float) -> void:
    ui_volume = clampf(value, 0.0, 1.0)
    apply(); save_settings()

func set_dynamic_range(value: String) -> void:
    dynamic_range = value if value in ["night", "medium", "wide"] else "medium"
    apply(); save_settings()

func set_mono_output(value: bool) -> void:
    mono_output = value
    apply(); save_settings()

func set_animation_speed(value: float) -> void:
    animation_speed = clampf(value, 0.5, 1.5)
    apply(); save_settings()

func set_fullscreen(value: bool) -> void:
    fullscreen = value
    apply(); save_settings()

func set_subtitles(value: bool) -> void:
    subtitles = value
    apply(); save_settings()

func set_screen_shake(value: bool) -> void:
    screen_shake = value
    apply(); save_settings()

func set_ui_scale(value: float) -> void:
    ui_scale = clampf(value, 0.8, 1.4)
    apply(); save_settings()

func set_text_scale(value: float) -> void:
    text_scale = clampf(value, 0.9, 1.5)
    apply(); save_settings()

func set_high_contrast(value: bool) -> void:
    high_contrast = value
    apply(); save_settings()

func set_reduce_flashes(value: bool) -> void:
    reduce_flashes = value
    apply(); save_settings()

func set_color_assist(value: String) -> void:
    color_assist = value if value in ["none", "deuteranopia", "protanopia", "tritanopia"] else "none"
    apply(); save_settings()

func apply() -> void:
    _set_bus("Master", master_volume)
    _set_bus("Music", music_volume)
    _set_bus("SFX", sfx_volume)
    _set_bus("Voice", voice_volume)
    _set_bus("Ambience", ambience_volume)
    _set_bus("UI", ui_volume)
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
    Engine.time_scale = animation_speed
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
    voice_volume = float(parsed.get("voice_volume", voice_volume))
    ambience_volume = float(parsed.get("ambience_volume", ambience_volume))
    ui_volume = float(parsed.get("ui_volume", ui_volume))
    fullscreen = bool(parsed.get("fullscreen", fullscreen))
    subtitles = bool(parsed.get("subtitles", subtitles))
    screen_shake = bool(parsed.get("screen_shake", screen_shake))
    ui_scale = float(parsed.get("ui_scale", ui_scale))
    text_scale = float(parsed.get("text_scale", text_scale))
    high_contrast = bool(parsed.get("high_contrast", high_contrast))
    reduce_flashes = bool(parsed.get("reduce_flashes", reduce_flashes))
    color_assist = String(parsed.get("color_assist", color_assist))
    dynamic_range = String(parsed.get("dynamic_range", dynamic_range))
    mono_output = bool(parsed.get("mono_output", mono_output))
    animation_speed = float(parsed.get("animation_speed", animation_speed))
    return true

func serialize() -> Dictionary:
    return {
        "master_volume": master_volume,
        "music_volume": music_volume,
        "sfx_volume": sfx_volume,
        "voice_volume": voice_volume,
        "ambience_volume": ambience_volume,
        "ui_volume": ui_volume,
        "fullscreen": fullscreen,
        "subtitles": subtitles,
        "screen_shake": screen_shake,
        "ui_scale": ui_scale,
        "text_scale": text_scale,
        "high_contrast": high_contrast,
        "reduce_flashes": reduce_flashes,
        "color_assist": color_assist,
        "dynamic_range": dynamic_range,
        "mono_output": mono_output,
        "animation_speed": animation_speed
    }
