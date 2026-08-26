extends Node

signal checklist_changed(results: Dictionary)

const CHECKS := [
    "movement",
    "dialogue",
    "chest",
    "loot",
    "combat_started",
    "combat_finished",
    "consumables",
    "psychology",
    "injury",
    "ash_guidance",
    "save_roundtrip"
]

var results: Dictionary = {}
var active := false

func _ready() -> void:
    reset_session()

func reset_session() -> void:
    results.clear()
    for check_id: String in CHECKS:
        results[check_id] = false
    active = true
    checklist_changed.emit(results.duplicate(true))

func mark(check_id: String, passed: bool = true) -> void:
    if check_id not in CHECKS:
        return
    results[check_id] = passed
    checklist_changed.emit(results.duplicate(true))

func completed_count() -> int:
    var count := 0
    for value: Variant in results.values():
        if bool(value):
            count += 1
    return count

func all_passed() -> bool:
    return completed_count() == CHECKS.size()
