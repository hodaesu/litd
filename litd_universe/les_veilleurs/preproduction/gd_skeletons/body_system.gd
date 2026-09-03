class_name LITDBodySystem
extends RefCounted

## Preproduction skeleton: not compile-validated yet.
## The real implementation must remain data-driven.

signal character_injured(character_id: StringName, injury_data: Dictionary)
signal body_part_lost(character_id: StringName, body_part_id: StringName, cause: Dictionary)
signal character_incapacitated(character_id: StringName, cause: Dictionary)
signal character_died(character_id: StringName, cause: Dictionary)

func resolve_physical_action(action: Dictionary, attacker: Dictionary, target: Dictionary) -> Dictionary:
    var result := {
        "valid": false,
        "contact": {},
        "armor": {},
        "lesions": [],
        "functional_changes": [],
        "dismemberments": [],
        "incapacitated": false,
        "dead": false,
        "events": []
    }

    if not _validate_action(action, attacker, target):
        return result

    result.valid = true
    result.contact = _resolve_contact(action, attacker, target)
    result.armor = _resolve_armor(action, target, result.contact)
    result.lesions = _resolve_tissues_and_lesions(action, target, result.contact, result.armor)
    result.functional_changes = _resolve_functional_consequences(target, result.lesions)
    result.dismemberments = _resolve_dismemberments(action, target, result.lesions, result.armor)
    result.incapacitated = _check_incapacity(target, result)
    result.dead = _check_death(target, result)
    return result

func _validate_action(_action: Dictionary, _attacker: Dictionary, _target: Dictionary) -> bool:
    return true

func _resolve_contact(_action: Dictionary, _attacker: Dictionary, _target: Dictionary) -> Dictionary:
    return {}

func _resolve_armor(_action: Dictionary, _target: Dictionary, _contact: Dictionary) -> Dictionary:
    return {}

func _resolve_tissues_and_lesions(_action: Dictionary, _target: Dictionary, _contact: Dictionary, _armor: Dictionary) -> Array:
    return []

func _resolve_functional_consequences(_target: Dictionary, _lesions: Array) -> Array:
    return []

func _resolve_dismemberments(_action: Dictionary, _target: Dictionary, _lesions: Array, _armor: Dictionary) -> Array:
    # Must check anatomy severable + compatible impact + compromised zone + armor + ability permission.
    return []

func _check_incapacity(_target: Dictionary, _result: Dictionary) -> bool:
    return false

func _check_death(_target: Dictionary, _result: Dictionary) -> bool:
    return false
