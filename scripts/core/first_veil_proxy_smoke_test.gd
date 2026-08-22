extends Node

const FIRST_VEIL := preload("res://scripts/core/first_veil_dungeon_runtime.gd")
const PROXY_PLAN := preload("res://scripts/core/first_veil_proxy_plan_runtime.gd")
const ARCHITECTURE_KIT := preload("res://scripts/world/first_veil_architecture_kit.gd")
const PROXY_ROOM := preload("res://scenes/dungeon/DungeonProxyRoom.tscn")

var failures: Array[String] = []
var first_veil: RefCounted = FIRST_VEIL.new()
var proxy_plan: RefCounted = PROXY_PLAN.new()
var architecture_kit: RefCounted = ARCHITECTURE_KIT.new()

func _ready() -> void:
    call_deferred("run")

func run() -> void:
    GameState.reset_new_game()
    if ExpeditionManager.expedition_active:
        ExpeditionManager.return_to_hub("proxy_smoke_reset")
    ExpeditionManager.reset_to_full_resupply()
    var runtime: Node = ExpeditionManager.roguelike_runtime
    _check(runtime != null, "Roguelike runtime must exist")
    if runtime == null:
        _finish()
        return
    runtime.start_run(424242)
    var init_result: Dictionary = first_veil.ensure_run(runtime)
    _check(bool(init_result.get("initialized", false)), "Physical first Veil must initialize")
    _check(proxy_plan.room_count() == 37, "Exact proxy plan must cover all 37 spaces")
    _check(not architecture_kit.blender_contract().is_empty(), "Architecture kit must expose a Blender handoff contract")
    _check((architecture_kit.blender_contract().get("required_collections", []) as Array).has("GAMEPLAY_ANCHORS"), "Blender handoff must preserve GAMEPLAY_ANCHORS")

    var active: Dictionary = runtime.active_run
    var dungeon: Array = active.get("dungeon", [])
    var entry_id: String = first_veil.entry_room_id(runtime)
    var entry: Dictionary = first_veil.room_by_id(runtime, entry_id)
    var resolved_entry: Dictionary = proxy_plan.resolved_room(entry, dungeon)
    _check(not resolved_entry.is_empty(), "Entry room must resolve a spatial plan")
    _check(resolved_entry.get("dimensions_m", Vector3.ZERO) == Vector3(14.0, 6.0, 10.0), "Entry dimensions must be 14x10x6 meters")
    _check((resolved_entry.get("interaction_points", []) as Array).size() == 3, "Entry must expose three physical interaction anchors")

    var visible_entry_exits: Array[String] = first_veil.player_connections(runtime, entry_id)
    var room_node: Node3D = PROXY_ROOM.instantiate() as Node3D
    add_child(room_node)
    room_node.call("configure", resolved_entry, visible_entry_exits, false)
    await get_tree().process_frame
    var summary: Dictionary = room_node.call("room_summary")
    _check(bool(summary.get("has_explorer", false)), "Proxy room must instantiate a walkable explorer")
    _check(int(summary.get("visible_exit_count", 0)) == 2, "Entry must expose its two physical exits")
    _check(not bool(summary.get("exits_enabled", true)), "Unresolved room exits must remain locked")
    _check(bool(summary.get("blender_contract_ready", false)), "Dressed proxy must report Blender contract readiness")
    _check(int(summary.get("architecture_kit_version", 0)) >= 1, "Dressed proxy must report architecture kit version")
    _check(bool(summary.get("contextual_interactions", false)), "Dressed proxy must expose contextual interaction support")
    _check(room_node.find_child("GameplayAnchors", true, false) != null, "Gameplay anchors must exist in 3D")
    _check(room_node.find_child("InteractionAnchors", true, false) != null, "Interaction anchors must exist in 3D")
    _check(room_node.find_child("ArchitectureKit", true, false) != null, "Architectural dressing must be instantiated")
    _check(room_node.find_child("Pillar_0", true, false) != null, "Architectural kit must add readable crypt pillars")
    _check(room_node.find_child("Lamp_0", true, false) != null, "Architectural kit must add room lighting fixtures")
    _check(room_node.find_child("Floor", true, false) != null, "Proxy room must have a physical floor")

    var puzzle: Dictionary = first_veil.room_by_id(runtime, "p1_puzzle")
    var puzzle_targets_before: Array[String] = first_veil.player_connections(runtime, "p1_puzzle")
    _check(not puzzle_targets_before.has("p1_secret"), "Undiscovered secret must not be an instantiated exit")
    var search_result: Dictionary = first_veil.search_for_secret(runtime, "p1_puzzle")
    _check(bool(search_result.get("found", false)), "Searching the mechanism room must reveal its secret")
    var puzzle_targets_after: Array[String] = first_veil.player_connections(runtime, "p1_puzzle")
    _check(puzzle_targets_after.has("p1_secret"), "Discovered secret must become a real physical exit")

    var resolved_puzzle: Dictionary = proxy_plan.resolved_room(puzzle, (runtime.active_run as Dictionary).get("dungeon", []))
    room_node.call("configure", resolved_puzzle, puzzle_targets_after, true)
    await get_tree().process_frame
    _check(room_node.find_child("Exit_p1_secret", true, false) != null, "Discovered secret passage must instantiate an Area3D exit")

    var boss: Dictionary = first_veil.room_by_id(runtime, "fv_boss")
    var resolved_boss: Dictionary = proxy_plan.resolved_room(boss, (runtime.active_run as Dictionary).get("dungeon", []))
    _check(resolved_boss.get("dimensions_m", Vector3.ZERO) == Vector3(28.0, 10.0, 22.0), "Boss chamber must be a 28x22x10 meter cathedral proxy")
    _check(str(resolved_boss.get("blender_module_id", "")) == "FV_BOSS_CHAMBER", "Boss room must expose a stable Blender module id")
    var no_boss_exits: Array[String] = []
    room_node.call("configure", resolved_boss, no_boss_exits, true)
    await get_tree().process_frame
    _check(room_node.find_child("BossDais", true, false) != null, "Boss chamber architecture must include a physical dais")
    _check(room_node.find_child("BossAltar", true, false) != null, "Boss chamber architecture must include a physical altar")

    room_node.queue_free()
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("FIRST_VEIL_PROXY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("FIRST_VEIL_PROXY_SMOKE: " + failure)
    print("FIRST_VEIL_PROXY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
