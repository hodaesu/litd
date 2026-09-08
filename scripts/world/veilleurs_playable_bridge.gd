extends Node

const PLAYABLE_SCENE := "res://scenes/veilleurs/vertical_slice.tscn"

var launch_canvas: CanvasLayer
var launch_button: Button

func _ready() -> void:
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not SaveManager.save_finished.is_connected(_on_save_finished):
        SaveManager.save_finished.connect(_on_save_finished)
    call_deferred("_install_launch_ui")

func start_playable() -> bool:
    VeilleursRuntime.reset_new_game()
    return get_tree().change_scene_to_file(PLAYABLE_SCENE) == OK

func resume_playable() -> bool:
    if not VeilleursRuntime.is_active():
        return false
    return get_tree().change_scene_to_file(PLAYABLE_SCENE) == OK

func _install_launch_ui() -> void:
    if launch_canvas != null:
        return
    launch_canvas = CanvasLayer.new()
    launch_canvas.name = "VeilleursLaunchUI"
    launch_canvas.layer = 90
    add_child(launch_canvas)

    launch_button = Button.new()
    launch_button.name = "LaunchVeilleurs"
    launch_button.text = "LES VEILLEURS"
    launch_button.custom_minimum_size = Vector2(220.0, 54.0)
    launch_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    launch_button.position = Vector2(-244.0, 82.0)
    launch_button.pressed.connect(_on_launch_pressed)
    launch_canvas.add_child(launch_button)
    _sync_launch_button()

func _sync_launch_button() -> void:
    if launch_button == null:
        return
    launch_button.visible = GameState.current_screen in ["title", "sanctuary"]

func _on_launch_pressed() -> void:
    start_playable()

func _on_screen_requested(_screen_name: String) -> void:
    call_deferred("_sync_launch_button")

func _on_save_finished(_slot: int, success: bool, _recovered: bool) -> void:
    if success and SaveManager.last_operation == "load" and GameState.current_screen == "title" and VeilleursRuntime.is_active():
        call_deferred("_resume_after_load")

func _resume_after_load() -> void:
    if VeilleursRuntime.is_active():
        resume_playable()

func _on_new_game_reset() -> void:
    VeilleursRuntime.reset_new_game()
    _sync_launch_button()
