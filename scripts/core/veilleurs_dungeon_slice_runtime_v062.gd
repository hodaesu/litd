extends "res://scripts/core/veilleurs_dungeon_slice_runtime.gd"
class_name VeilleursDungeonSliceRuntimeV062

var watcher_state: Dictionary = {}

func start() -> Dictionary:
    watcher_state.clear()
    return super.start()

func complete_current(outcome: String = "cleared", context: Dictionary = {}) -> Dictionary:
    var result: Dictionary = super.complete_current(outcome, context)
    if bool(result.get("ok", false)) and context.has("watcher_aftermath"):
        watcher_state = (context.get("watcher_aftermath", {}) as Dictionary).duplicate(true)
        result["watcher_state_persisted"] = watcher_state.size()
    return result

func serialize() -> Dictionary:
    var payload: Dictionary = super.serialize()
    payload["version"] = "0.6.2"
    payload["watcher_state"] = watcher_state.duplicate(true)
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    watcher_state = (payload.get("watcher_state", {}) as Dictionary).duplicate(true)
    return true
