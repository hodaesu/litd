@tool
class_name LITDAbilityDefinition
extends Resource

## Preproduction skeleton: not compile-validated yet.

@export var ability_id: StringName
@export var owner_scope: StringName
@export var tree_id: StringName
@export_range(1, 15, 1) var slot_index: int = 1
@export var rank: StringName
@export var tier: StringName
@export var display_name_key: StringName
@export var description_key: StringName

@export var action_type: StringName
@export var targeting_mode: StringName
@export var range_profile: StringName

@export var endurance_cost: StringName
@export var maintenance_cost: StringName
@export var material_cost: StringName
@export var preparation_profile: StringName
@export var recovery_profile: StringName

@export var required_body_functions: Array[StringName] = []
@export var forbidden_body_states: Array[StringName] = []
@export var impact_types: Array[StringName] = []

@export var physical_power: StringName
@export var precision: StringName
@export var user_risk: StringName
@export var allowed_zones: Array[StringName] = []
@export var preferred_zones: Array[StringName] = []
@export var lesion_rule_ids: Array[StringName] = []
@export var functional_effect_ids: Array[StringName] = []

@export var dismemberment_eligibility: StringName
@export var armor_interaction: StringName
@export var environment_interaction: StringName

@export var noise_profile: StringName
@export var vibration_profile: StringName
@export var biological_profile: StringName

@export var friendly_fire: bool = false
@export var prerequisite_ids: Array[StringName] = []
@export var synergy_tags: Array[StringName] = []
@export var ai_tags: Array[StringName] = []
@export_multiline var animation_intent: String
@export var fx_tags: Array[StringName] = []
@export var knowledge_reveal: StringName

func validate_contract() -> PackedStringArray:
    var errors := PackedStringArray()
    if ability_id.is_empty():
        errors.append("ability_id is required")
    if tree_id.is_empty():
        errors.append("tree_id is required")
    if slot_index < 1 or slot_index > 15:
        errors.append("slot_index must be in 1..15")
    if action_type.is_empty():
        errors.append("action_type is required")
    if targeting_mode.is_empty():
        errors.append("targeting_mode is required")
    if preparation_profile.is_empty():
        errors.append("preparation_profile must be explicit")
    if recovery_profile.is_empty():
        errors.append("recovery_profile must be explicit")
    if animation_intent.is_empty():
        errors.append("animation_intent is required")
    return errors
