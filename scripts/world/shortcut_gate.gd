extends Area3D
class_name ShortcutGate

signal unlocked(shortcut_id: String)

@export var shortcut_id := ""
@export var auto_unlock_on_interact := true

func is_open() -> bool:
    return shortcut_id != "" and AshlandsRuntime.is_shortcut_unlocked(shortcut_id)

func interaction_descriptor(_actor: Object = null) -> Dictionary:
    var open := is_open()
    var available := shortcut_id != "" and (open or auto_unlock_on_interact)
    var reason := ""
    if shortcut_id == "":
        reason = "missing_shortcut_id"
    elif not open and not auto_unlock_on_interact:
        reason = "locked"
    return EnvironmentInteractionContract.descriptor(
        "shortcut:%s" % (shortcut_id if shortcut_id != "" else "missing"),
        EnvironmentInteractionContract.KIND_DOOR,
        "Passage",
        "PASSER" if open else "OUVRIR",
        available,
        reason,
        false,
        {"open": open}
    )

func perform_interaction(actor: Object = null) -> Dictionary:
    var current := interaction_descriptor(actor)
    if not bool(current.get("available", false)):
        return EnvironmentInteractionContract.result(current, false, "blocked", str(current.get("blocked_reason", "locked")))
    var was_open := is_open()
    var success := interact()
    return EnvironmentInteractionContract.result(
        current,
        success,
        "already_open" if was_open and success else ("opened" if success else "blocked"),
        "interaction_failed" if not success else "",
        {"open": is_open()}
    )

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
