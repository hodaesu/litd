class_name LITDBossPhaseController
extends RefCounted

## Preproduction skeleton: NOT compile-validated.
## Consumes rows from boss_5_phases.json without embedding boss logic in code.

signal phase_changed(boss_name: String, previous_phase: int, new_phase: int)

var boss_name: String = ""
var phase_rows: Array = []
var current_phase: int = 1
var completed_transition_tags: Array[StringName] = []

func configure(source_boss_name: String, all_phase_rows: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    boss_name = source_boss_name
    phase_rows.clear()
    for row in all_phase_rows:
        if String(row.get("Boss", "")) == boss_name:
            phase_rows.append(row)
    phase_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("Phase", 0)) < int(b.get("Phase", 0))
    )
    if phase_rows.is_empty():
        errors.append("No boss phases found for %s" % boss_name)
        return errors
    var expected := 4 if boss_name == "Le Copiste" else 3
    if phase_rows.size() != expected:
        errors.append("Boss %s has %d phases; expected %d" % [boss_name, phase_rows.size(), expected])
    current_phase = int(phase_rows[0].get("Phase", 1))
    return errors

func current_definition() -> Dictionary:
    for row in phase_rows:
        if int(row.get("Phase", 0)) == current_phase:
            return row
    return {}

func request_transition(context: Dictionary) -> Dictionary:
    var current := current_definition()
    if current.is_empty():
        return {"changed": false, "error": "Missing current phase definition"}

    # The transition column contains authored conditions such as vitality plus
    # tactical achievements. It must be interpreted by CombatResolver / a
    # condition evaluator on PC, not by fragile string parsing here.
    var authored_transition := String(current.get("Transition", ""))
    var evaluator: Callable = context.get("transition_evaluator", Callable())
    if not evaluator.is_valid():
        return {
            "changed": false,
            "error": "No transition evaluator supplied",
            "authored_transition": authored_transition
        }

    var allowed: bool = bool(evaluator.call(current, context))
    if not allowed:
        return {"changed": false, "error": "", "authored_transition": authored_transition}

    var next_phase := current_phase + 1
    if not _has_phase(next_phase):
        return {"changed": false, "error": "Boss is already in final phase"}

    var previous := current_phase
    current_phase = next_phase
    phase_changed.emit(boss_name, previous, current_phase)
    return {"changed": true, "error": "", "phase": current_phase}

func _has_phase(value: int) -> bool:
    for row in phase_rows:
        if int(row.get("Phase", 0)) == value:
            return true
    return false
