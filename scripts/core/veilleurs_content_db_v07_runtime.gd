extends "res://scripts/core/veilleurs_content_db_v07.gd"
class_name VeilleursContentDBV07Runtime

func skill(skill_id: String) -> Dictionary:
    var base_skill: Dictionary = super.skill(skill_id)
    if not base_skill.is_empty():
        return base_skill
    return production_skill(skill_id)

func skills_for(entity_id: String) -> Array:
    var base_skills: Array = super.skills_for(entity_id)
    if not base_skills.is_empty():
        return base_skills
    return production_skills_for(entity_id)

func entity(entity_id: String) -> Dictionary:
    var base_entity: Dictionary = super.entity(entity_id)
    if not base_entity.is_empty():
        return base_entity
    return boss(entity_id)
