class_name LITDMemoryEvent
extends Resource

## Preproduction skeleton: not compile-validated yet.

enum Importance { TRIVIAL, MINOR, SIGNIFICANT, MAJOR, FOUNDATIONAL }

@export var memory_id: StringName
@export var event_type: StringName
@export var participant_ids: Array[StringName] = []
@export var location_id: StringName
@export var expedition_id: StringName
@export var importance: Importance = Importance.MINOR
@export var emotional_tags: Array[StringName] = []
@export var factual_tags: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var certainty: float = 1.0
@export_range(0.0, 1.0, 0.01) var accuracy: float = 1.0
@export var created_at_turn: int = 0
@export var last_recalled_at_turn: int = -1

func is_foundational() -> bool:
    return importance == Importance.FOUNDATIONAL
