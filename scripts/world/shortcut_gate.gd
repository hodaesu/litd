extends Area3D
class_name ShortcutGate

signal unlocked(shortcut_id: String)

@export var shortcut_id := ""
@export var auto_unlock_on_interact := true

func is_open() -> bool:
    return shortcut_id != "" and AshlandsRuntime.is_shortcut_unlocked(shortcut_id)

func interact() -> bool:
    if shortcut_id == "":
        return false
    if is_open():
        return true
    if not auto_unlock_on_interact:
        return false
    AshlandsRuntime.unlock_shortcut(shortcut_id)
    unlocked.emit(shortcut_id)
    return true
