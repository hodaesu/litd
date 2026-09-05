class_name LITDSensoryEvent
extends RefCounted

## Preproduction skeleton: not compile-validated yet.

enum Channel { VISUAL, NOISE, ODOR, VIBRATION, BIOLOGICAL }

enum Intensity { TRACE, LOW, MEDIUM, HIGH, EXTREME }

var event_id: StringName
var source_id: StringName
var zone_id: StringName
var local_position: Vector2
var channel: Channel
var intensity: Intensity
var tags: Array[StringName] = []
var duration_turns: int = 0
var environment_modifier: float = 1.0
var created_turn: int = 0

func expires_at_turn() -> int:
    return created_turn + maxi(duration_turns, 0)

func is_expired(current_turn: int) -> bool:
    return duration_turns >= 0 and current_turn > expires_at_turn()
