class_name LITDSaveSystem
extends RefCounted

## Preproduction skeleton: not compile-validated yet.
## Final implementation must use Godot-safe atomic/transactional file handling.

const SAVE_VERSION := 1
const SLOT_A := "user://litd_veilleurs_autosave_a.json"
const SLOT_B := "user://litd_veilleurs_autosave_b.json"
const ACTIVE_SLOT := "user://litd_veilleurs_autosave_active.txt"

func build_payload(runtime_state: Dictionary) -> Dictionary:
    return {
        "save_version": SAVE_VERSION,
        "campaign": runtime_state.get("campaign", {}),
        "veilleur_states": runtime_state.get("veilleur_states", {}),
        "recruit_registry": runtime_state.get("recruit_registry", {}),
        "enemy_memory_registry": runtime_state.get("enemy_memory_registry", {}),
        "corpse_registry": runtime_state.get("corpse_registry", {}),
        "refuge": runtime_state.get("refuge", {}),
        "knowledge": runtime_state.get("knowledge", {}),
        "world_scars": runtime_state.get("world_scars", {}),
        "narrative_flags": runtime_state.get("narrative_flags", {}),
        "rng_state": runtime_state.get("rng_state", {})
    }

func validate_payload(payload: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for key in ["save_version", "campaign", "veilleur_states", "recruit_registry", "corpse_registry", "refuge", "knowledge", "world_scars", "rng_state"]:
        if not payload.has(key):
            errors.append("Missing save key: %s" % key)
    return errors

func write_transactional(_runtime_state: Dictionary) -> bool:
    # TODO PC/Godot: choose inactive slot, serialize, flush, re-read, validate,
    # then atomically switch ACTIVE_SLOT. Never overwrite the only valid save.
    return false

func migrate_payload(payload: Dictionary) -> Dictionary:
    # TODO: apply ordered migrations until SAVE_VERSION.
    return payload
