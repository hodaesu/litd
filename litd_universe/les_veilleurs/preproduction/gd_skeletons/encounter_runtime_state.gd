class_name LITDEncounterRuntimeState
extends Resource

## Preproduction skeleton: NOT compile-validated.

@export var campaign_seed: int = 0
@export var encounter_seed: int = 0
@export var act_id: StringName
@export_range(1, 5, 1) var depth: int = 1
@export var zone_id: StringName
@export var encounter_id: StringName
@export var turn_index: int = 0

@export var recent_encounter_ids: Array[StringName] = []
@export var active_enemy_ids: Array[StringName] = []
@export var memoriel_candidate_ids: Array[StringName] = []
@export var active_hazard_ids: Array[StringName] = []
@export var zone_scar_ids: Array[StringName] = []
@export var narrative_flag_ids: Array[StringName] = []

@export var rng_state: Dictionary = {}
@export var source_provenance: Dictionary = {}

func remember_encounter(id: StringName, max_history: int = 6) -> void:
    recent_encounter_ids.append(id)
    while recent_encounter_ids.size() > max_history:
        recent_encounter_ids.pop_front()

func has_recently_seen(id: StringName) -> bool:
    return id in recent_encounter_ids
