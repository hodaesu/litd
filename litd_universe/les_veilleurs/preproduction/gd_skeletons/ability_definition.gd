@tool
class_name LITDAbilityDefinition
extends Resource

## Preproduction skeleton: not compile-validated yet.
## This is a normalized runtime definition. The importer must preserve the exact source row separately.

@export var runtime_id: StringName
@export var source_id: String
@export var owner_id: StringName
@export var tree_id: StringName
@export_range(1, 50, 1) var unlock_level: int = 1
@export_range(1, 15, 1) var slot_index: int = 1
@export var display_name: String

@export var action_type: StringName
@export_multiline var function_text: String
@export var valid_positions: String
@export var target_rule: String

@export var impact_tags: Array[StringName] = []
@export var preferred_zones: Array[StringName] = []
@export var qualitative_power: String
@export var source_power_0_5: float = 0.0
@export var qualitative_precision: String
@export var source_precision_percent: float = 0.0

@export_multiline var lesion_rules: String
@export_multiline var functional_consequences: String
@export_multiline var dismemberment_rule: String
@export_multiline var armor_interaction: String
@export_multiline var environment_interaction: String
@export var user_risk: String
@export var tags: Array[StringName] = []

@export var cooldown_rule: String
@export var charges_rule: String
@export_multiline var conditions: String
@export_multiline var injured_variant: String
@export_multiline var equipment_variant: String
@export_multiline var godot_note: String

## Runtime enrichments: these are not automatically canonical source fields.
@export var required_body_functions: Array[StringName] = []
@export var forbidden_body_states: Array[StringName] = []
@export var sensory_emission: Dictionary = {}
@export var animation_intent: String = ""
@export var normalized_costs: Dictionary = {}

@export var provenance: Dictionary = {}

func validate_contract() -> PackedStringArray:
    var errors := PackedStringArray()
    if runtime_id.is_empty():
        errors.append("runtime_id is required")
    if source_id.is_empty():
        errors.append("source_id is required")
    if owner_id.is_empty():
        errors.append("owner_id is required")
    if tree_id.is_empty():
        errors.append("tree_id is required")
    if slot_index < 1 or slot_index > 15:
        errors.append("slot_index must be in 1..15")
    if unlock_level < 1 or unlock_level > 50:
        errors.append("unlock_level must be in 1..50")
    if display_name.is_empty():
        errors.append("display_name is required")
    if action_type.is_empty():
        errors.append("action_type is required")
    if provenance.is_empty():
        errors.append("provenance is required")
    return errors
