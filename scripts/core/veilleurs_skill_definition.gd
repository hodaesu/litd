extends Resource
class_name VeilleursSkillDefinition

@export var skill_id := ""
@export var entity_id := ""
@export var tree_id := ""
@export var skill_index := 0
@export var unlock_level := 1
@export var name_fr := ""
@export var mechanical_profile := ""
@export var activation_type := "active"
@export var action_type := "attack"
@export var target_type := "enemy_single"
@export var precision_mod := 0
@export var dismemberment_rules: Dictionary = {}
@export var effect_spec: Dictionary = {}

static func from_dictionary(payload: Dictionary) -> VeilleursSkillDefinition:
    var result := VeilleursSkillDefinition.new()
    result.skill_id = str(payload.get("skill_id", ""))
    result.entity_id = str(payload.get("entity_id", ""))
    result.tree_id = str(payload.get("tree_id", ""))
    result.skill_index = int(payload.get("skill_index", 0))
    result.unlock_level = int(payload.get("unlock_level", 1))
    result.name_fr = str(payload.get("name_fr", ""))
    result.mechanical_profile = str(payload.get("mechanical_profile", ""))
    result.activation_type = str(payload.get("activation_type", "active"))
    result.action_type = str(payload.get("action_type", "attack"))
    result.target_type = str(payload.get("target_type", "enemy_single"))
    result.precision_mod = int(payload.get("precision_mod", 0))
    result.dismemberment_rules = (payload.get("dismemberment_rules", {}) as Dictionary).duplicate(true)
    result.effect_spec = (payload.get("effect_spec", {}) as Dictionary).duplicate(true)
    return result
