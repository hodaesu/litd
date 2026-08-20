extends Node3D

const PROXY_SCENE := preload("res://scenes/visual/visual_vertical_slice_proxy.tscn")

var proxy_root: Node3D
var loader: ValidatedGLBLoader
var vfx: VisualSliceVFX
var runtime: VisualSliceRuntime
var darius_root: Node3D
var ghoul_root: Node3D

func _ready() -> void:
    proxy_root = PROXY_SCENE.instantiate() as Node3D
    add_child(proxy_root)
    loader = ValidatedGLBLoader.new()
    loader.name = "ValidatedGLBLoader"
    add_child(loader)
    vfx = VisualSliceVFX.new()
    vfx.name = "VisualSliceVFX"
    add_child(vfx)
    runtime = VisualSliceRuntime.new()
    runtime.name = "VisualSliceRuntime"
    add_child(runtime)
    await get_tree().process_frame
    _replace_available_assets()
    runtime.configure(darius_root, ghoul_root, vfx)
    runtime.start_combat()

func _replace_available_assets() -> void:
    var darius_proxy := proxy_root.find_child("DariusProxy", true, false)
    var ghoul_proxy := proxy_root.find_child("HungryGhoulProxy", true, false)
    var arena_proxy := proxy_root.find_child("AshlandsArenaProxy", true, false)
    darius_root = loader.replace_proxy("darius", darius_proxy, proxy_root) as Node3D
    ghoul_root = loader.replace_proxy("enemy_01_goule_affamee", ghoul_proxy, proxy_root) as Node3D
    loader.replace_proxy("ashlands_visual_arena", arena_proxy, proxy_root)

func _unhandled_input(event: InputEvent) -> void:
    if runtime == null or not runtime.combat_active:
        return
    if event.is_action_pressed("ui_accept"):
        runtime.darius_light_attack()
    elif event.is_action_pressed("ui_cancel"):
        runtime.darius_guard()
    elif event.is_action_pressed("ui_left"):
        runtime.darius_heavy_attack()
    elif event.is_action_pressed("ui_right"):
        runtime.ghoul_claw()
