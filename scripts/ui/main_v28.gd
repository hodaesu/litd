extends "res://scripts/ui/main_v27.gd"

# v28 : blockout spatial jouable. Les salles logiques de v27 peuvent maintenant
# être ouvertes comme proxies 3D walkables. Les ports physiques utilisent les
# mêmes connexions que la carte macro et restent verrouillés tant que la salle
# n'est pas sécurisée. Les secrets non découverts ne sont jamais instanciés.

const FIRST_VEIL_PROXY_PLAN_RUNTIME := preload("res://scripts/core/first_veil_proxy_plan_runtime.gd")
const DUNGEON_PROXY_ROOM_SCENE := preload("res://scenes/dungeon/DungeonProxyRoom.tscn")

var first_veil_proxy_plan: RefCounted = FIRST_VEIL_PROXY_PLAN_RUNTIME.new()
var proxy_room_instance: Node3D = null

func show_screen(name: String) -> void:
    if name == "dungeon_proxy":
        GameState.current_screen = name
        clear_content()
        show_dungeon_proxy()
        call_deferred("_postprocess_mobile_screen")
        return
    super.show_screen(name)

func show_dungeon_room() -> void:
    super.show_dungeon_room()
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null or not ExpeditionManager.expedition_active:
        return
    if int((runtime.active_run as Dictionary).get("physical_dungeon_version", 0)) <= 0:
        return
    var room_id: String = str((runtime.active_run as Dictionary).get("current_room_id", ""))
    if room_id == "":
        return
    var proxy_button := make_button("VISITER LA SALLE EN PROXY 3D", func(): GameState.request_screen("dungeon_proxy"), Vector2(330, 46))
    proxy_button.position = Vector2(590, 620)
    content.add_child(proxy_button)

func show_dungeon_proxy() -> void:
    _ensure_physical_first_veil()
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        GameState.request_screen("expedition")
        return
    var active: Dictionary = runtime.active_run
    var room_id: String = str(active.get("current_room_id", ""))
    var room: Dictionary = first_veil_dungeon.room_by_id(runtime, room_id)
    if room.is_empty():
        GameState.request_screen("expedition")
        return
    var dungeon: Array = active.get("dungeon", [])
    var resolved: Dictionary = first_veil_proxy_plan.resolved_room(room, dungeon)
    if resolved.is_empty():
        GameState.add_log("Le plan spatial de cette salle n'est pas encore disponible.")
        GameState.request_screen("dungeon_room")
        return

    var visible_targets: Array[String] = first_veil_dungeon.player_connections(runtime, room_id)
    var cleared: bool = bool(room.get("cleared", false))

    var viewport_container := SubViewportContainer.new()
    viewport_container.position = Vector2(0, 0)
    viewport_container.size = Vector2(1280, 720)
    viewport_container.stretch = true
    content.add_child(viewport_container)

    var sub_viewport := SubViewport.new()
    sub_viewport.size = Vector2i(1280, 720)
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    sub_viewport.handle_input_locally = true
    viewport_container.add_child(sub_viewport)

    proxy_room_instance = DUNGEON_PROXY_ROOM_SCENE.instantiate() as Node3D
    if proxy_room_instance == null:
        GameState.add_log("Impossible d'instancier le blockout de la salle.")
        GameState.request_screen("dungeon_room")
        return
    sub_viewport.add_child(proxy_room_instance)
    proxy_room_instance.connect("exit_reached", Callable(self, "_on_proxy_exit_reached"))
    proxy_room_instance.call("configure", resolved, visible_targets, cleared)

    var top_shade := ColorRect.new()
    top_shade.color = Color(0.0, 0.0, 0.0, 0.72)
    top_shade.position = Vector2(12, 12)
    top_shade.size = Vector2(1256, 78)
    content.add_child(top_shade)

    var title := make_label("%s · BLOCKOUT 3D" % str(room.get("name", "Salle")), 22, GOLD)
    title.position = Vector2(28, 20)
    title.size = Vector2(650, 32)
    content.add_child(title)

    var dimensions: Vector3 = resolved.get("dimensions_m", Vector3.ZERO)
    var state_text: String = "SÉCURISÉE — sorties physiques actives" if cleared else "NON RÉSOLUE — sorties verrouillées"
    var meta := make_label(
        "%s · %.0f × %.0f m · hauteur %.1f m · %s" % [
            str(resolved.get("blender_module_id", "PROXY")),
            dimensions.x,
            dimensions.z,
            dimensions.y,
            state_text
        ],
        12,
        TEXT
    )
    meta.position = Vector2(28, 52)
    meta.size = Vector2(760, 28)
    content.add_child(meta)

    var controls := make_label("Déplacement : ZQSD / WASD / flèches", 12, MUTED)
    controls.position = Vector2(790, 24)
    controls.size = Vector2(300, 26)
    content.add_child(controls)

    var room_button := make_button("INTERACTIONS / COMBAT", func(): GameState.request_screen("dungeon_room"), Vector2(190, 44))
    room_button.position = Vector2(1065, 18)
    content.add_child(room_button)
    var map_button := make_button("CARTE MACRO", func(): GameState.request_screen("expedition"), Vector2(150, 42))
    map_button.position = Vector2(1095, 650)
    content.add_child(map_button)

    if not cleared:
        var lock_note := make_label("Sécurise l'événement principal pour ouvrir physiquement les passages.", 12, GOLD)
        lock_note.position = Vector2(28, 665)
        lock_note.size = Vector2(620, 28)
        content.add_child(lock_note)
    else:
        var exit_note := make_label("Marche jusqu'à une ouverture pour emprunter ce passage réel.", 12, TEXT)
        exit_note.position = Vector2(28, 665)
        exit_note.size = Vector2(620, 28)
        content.add_child(exit_note)

func _on_proxy_exit_reached(target_room_id: String) -> void:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        return
    var current_room: Dictionary = first_veil_dungeon.room_by_id(runtime, str((runtime.active_run as Dictionary).get("current_room_id", "")))
    if current_room.is_empty() or not bool(current_room.get("cleared", false)):
        GameState.add_log("Le passage reste fermé tant que la salle n'est pas sécurisée.")
        return
    if not first_veil_dungeon.is_reachable(runtime, target_room_id):
        GameState.add_log("Ce passage n'est pas encore révélé.")
        return
    _enter_roguelike_room(target_room_id)
    if GameState.current_screen == "dungeon_room":
        show_screen("dungeon_proxy")
