extends Node

## Canonical production entry point for LITD: Les Veilleurs.
##
## VS001 remains a frozen compatibility slice for historical saves and regression
## coverage. New production systems must depend on this bridge (v0.9+) instead
## of the VS001 runtime.

const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_vertical_slice_runtime_v09.gd")

var runtime: VeilleursVerticalSliceRuntimeV09 = RUNTIME_SCRIPT.new() as VeilleursVerticalSliceRuntimeV09

func _ready() -> void:
    if not GameState.new_game_reset.is_connected(reset_new_game):
        GameState.new_game_reset.connect(reset_new_game)

func reset_new_game() -> void:
    runtime = RUNTIME_SCRIPT.new() as VeilleursVerticalSliceRuntimeV09

func start_dungeon(dungeon_id: String, seed: int = 0) -> Dictionary:
    return runtime.start_dungeon(dungeon_id, seed)

func enter_next(node_id: String) -> Dictionary:
    return runtime.enter_next(node_id)

func launch_current_encounter(context: Dictionary = {}) -> Dictionary:
    return runtime.launch_current_encounter(context)

func resolve_active_combat(outcome: String, extra_context: Dictionary = {}) -> Dictionary:
    return runtime.resolve_active_combat(outcome, extra_context)

func recruitment_options() -> Array[Dictionary]:
    return runtime.recruitment_options()

func resolve_recruitment_decision(candidate_index: int, action: String, context: Dictionary = {}) -> Dictionary:
    return runtime.resolve_recruitment_decision(candidate_index, action, context)

func current_snapshot() -> Dictionary:
    return runtime.current_snapshot()

func is_active() -> bool:
    if runtime == null or runtime.campaign == null:
        return false
    return str(runtime.campaign.current_dungeon_id) != ""

func serialize() -> Dictionary:
    return {
        "schema_version": 1,
        "runtime_version": "0.9.0",
        "runtime": runtime.serialize()
    }

func deserialize(payload: Dictionary) -> bool:
    runtime = RUNTIME_SCRIPT.new() as VeilleursVerticalSliceRuntimeV09
    if payload.is_empty():
        return true
    var runtime_payload: Dictionary = payload.get("runtime", {})
    if runtime_payload.is_empty():
        return true
    return runtime.deserialize(runtime_payload)
