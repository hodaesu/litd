class_name LITDEnemyMemoryState
extends Resource

## Preproduction skeleton: NOT compile-validated.

@export var enemy_unique_id: StringName
@export var source_enemy_id: StringName
@export var stage: StringName = &"NORMAL"
@export var foundational_memory_ids: Array[StringName] = []
@export var significant_memory_ids: Array[StringName] = []
@export var recent_memory_ids: Array[StringName] = []
@export var learned_action_family_counts: Dictionary = {}
@export var known_veilleur_ids: Array[StringName] = []
@export var injury_memory_ids: Array[StringName] = []
@export var survival_count: int = 0
@export var retreat_count: int = 0
@export var encounters_with_veilleurs: int = 0

func record_action_family(action_family: StringName) -> void:
    learned_action_family_counts[action_family] = int(learned_action_family_counts.get(action_family, 0)) + 1

func knows_action_family(action_family: StringName) -> bool:
    return learned_action_family_counts.has(action_family)

func can_use_learned_counter(action_family: StringName) -> bool:
    # A counter may only exist if this individual actually observed/learned it.
    return knows_action_family(action_family)

func promote_if_eligible(event_tags: Array[StringName]) -> StringName:
    # Placeholder only. Final promotion rules must use lived events and the
    # bounded memory system; never promote by random rarity.
    if stage == &"NORMAL" and (&"SURVIVED_MEANINGFUL_ENCOUNTER" in event_tags):
        stage = &"MEMORIEL"
    elif stage == &"MEMORIEL" and (&"TACTICAL_ADAPTATION_EARNED" in event_tags):
        stage = &"VETERAN"
    elif stage == &"VETERAN" and (&"GROUP_INFLUENCE_EARNED" in event_tags):
        stage = &"ELITE"
    elif stage == &"ELITE" and (&"SHARED_HISTORY_NEMESIS" in event_tags):
        stage = &"NEMESIS"
    return stage
