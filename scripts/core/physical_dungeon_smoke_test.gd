extends Node

const PHYSICAL_RUNTIME := preload("res://scripts/core/first_veil_dungeon_runtime.gd")
var failures: Array[String] = []

func _ready() -> void:
    call_deferred("run")

func run() -> void:
    GameState.reset_new_game()
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition(424242, "first_veil_crypts")
    await get_tree().process_frame

    var runtime: Node = ExpeditionManager.roguelike_runtime
    _check(runtime != null, "Roguelike runtime must exist")
    if runtime == null:
        _finish()
        return

    var physical: RefCounted = PHYSICAL_RUNTIME.new()
    var init_result: Dictionary = physical.ensure_run(runtime)
    _check(bool(init_result.get("initialized", false)), "Physical dungeon must initialize from the room catalogue")

    var summary: Dictionary = physical.summary(runtime)
    _check(str(summary.get("orientation", "")) == "vertical_descending", "First Veil must be a vertical descent")
    _check(int(summary.get("palier_count", 0)) == 4, "First Veil must have four paliers")
    _check(int(summary.get("room_count", 0)) >= 30, "Physical dungeon must contain many real rooms")
    _check(int(summary.get("secret_count", 0)) >= 4, "Physical dungeon must contain hidden rooms")
    _check(int(summary.get("discovered_secret_count", -1)) == 0, "No secret room may be discovered at run start")

    var initial_visible: Array = physical.visible_layout(runtime)
    _check(initial_visible.size() == 1, "Fog of war must initially expose only the entrance")
    _check(not _layout_contains_secret(initial_visible), "Secret rooms must be absent from the initial player map")

    var entry_id: String = physical.entry_room_id(runtime)
    _check(entry_id == "fv_entry", "The physical entrance must be the Porte du Premier Voile")
    var entered: Dictionary = ExpeditionManager.enter_dungeon_room(entry_id)
    _check(bool(entered.get("success", false)), "Player must be able to enter the physical entrance")
    var after_entry: Array = physical.visible_layout(runtime)
    _check(after_entry.size() > 1, "Visiting a room must reveal immediately adjacent normal passages")
    _check(not _layout_contains_secret(after_entry), "Secret rooms must remain absent after ordinary exploration")

    # Simule l'arrivée et la sécurisation de la Chambre du mécanisme, qui possède
    # réellement un passage caché. Avant la fouille, le secret n'est ni visible
    # ni empruntable ; après la fouille, il apparaît et devient une vraie salle.
    var active: Dictionary = runtime.active_run
    var visited: Array = active.get("visited", [])
    if not visited.has("p1_puzzle"):
        visited.append("p1_puzzle")
    active["visited"] = visited
    active["current_room_id"] = "p1_puzzle"
    var dungeon: Array = active.get("dungeon", [])
    for room_value in dungeon:
        var room: Dictionary = room_value
        if str(room.get("id", "")) == "p1_puzzle":
            room["visited"] = true
            room["cleared"] = true
            break
    active["dungeon"] = dungeon
    runtime.active_run = active

    _check(not physical.visible_room_ids(runtime).has("p1_secret"), "Hidden caveau must not be present before search")
    _check(not physical.player_connections(runtime, "p1_puzzle").has("p1_secret"), "Hidden passage must not be traversable before discovery")
    var search_result: Dictionary = physical.search_for_secret(runtime, "p1_puzzle")
    _check(bool(search_result.get("found", false)), "Searching the correct room must reveal its hidden passage")
    _check(physical.visible_room_ids(runtime).has("p1_secret"), "Discovered secret room must appear on the map")
    _check(physical.player_connections(runtime, "p1_puzzle").has("p1_secret"), "Discovered hidden passage must become traversable")

    var saved: Dictionary = ExpeditionManager.serialize()
    ExpeditionManager.deserialize(saved)
    runtime = ExpeditionManager.roguelike_runtime
    _check(runtime != null, "Roguelike runtime must survive deserialize")
    if runtime != null:
        var restored_physical: RefCounted = PHYSICAL_RUNTIME.new()
        _check(restored_physical.visible_room_ids(runtime).has("p1_secret"), "Secret discovery must persist through save/load state")
        var restored_summary: Dictionary = restored_physical.summary(runtime)
        _check(int(restored_summary.get("discovered_secret_count", 0)) == 1, "Exactly one secret must remain discovered after restore")

    if ExpeditionManager.expedition_active:
        ExpeditionManager.return_to_hub("physical_dungeon_smoke")
    _finish()

func _layout_contains_secret(layout: Array) -> bool:
    for room_value in layout:
        var room: Dictionary = room_value
        if bool(room.get("secret", false)):
            return true
    return false

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("PHYSICAL_DUNGEON_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PHYSICAL_DUNGEON_SMOKE: " + failure)
    print("PHYSICAL_DUNGEON_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
