extends RefCounted
class_name VeilleursRuntimeFacade

## Canonical entry point for Les Veilleurs runtime while the historical VS001
## implementation is still being strangled out. New production code must depend
## on this facade rather than on VS001 autoloads directly.

static func is_active() -> bool:
    return VeilleursVS001WorldRuntime.is_active()


static func start_playable() -> bool:
    return VeilleursVS001PlayableBridge.start_playable()


static func resume_playable() -> bool:
    return VeilleursVS001PlayableBridge.resume_playable()


static func serialize() -> Dictionary:
    return VeilleursVS001PlayableBridge.serialize()


static func deserialize(payload: Dictionary) -> void:
    VeilleursVS001PlayableBridge.deserialize(payload)


static func watcher_ids() -> Array[String]:
    return VeilleursVS001PlayableBridge.watcher_ids()


static func watcher_names() -> Array[String]:
    return VeilleursVS001PlayableBridge.watcher_names()
