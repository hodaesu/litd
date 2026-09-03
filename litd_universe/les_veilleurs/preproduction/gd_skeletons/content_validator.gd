@tool
class_name LITDContentValidator
extends RefCounted

## Preproduction skeleton: not compile-validated yet.

const EXPECTED_TREE_COUNT := 21
const EXPECTED_SKILLS_PER_TREE := 15
const EXPECTED_SKILL_COUNT := 315
const EXPECTED_ULTIMATE_COUNT := 21
const EXPECTED_ARCHETYPE_COUNT := 25
const EXPECTED_ORIENTATION_COUNT := 75

func validate_registry(tree_rows: Array, skill_rows: Array, ultimate_rows: Array, archetype_rows: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    errors.append_array(_validate_counts(tree_rows, skill_rows, ultimate_rows, archetype_rows))
    errors.append_array(_validate_unique_ids(tree_rows, "tree"))
    errors.append_array(_validate_unique_ids(skill_rows, "skill"))
    errors.append_array(_validate_unique_ids(ultimate_rows, "ultimate"))
    errors.append_array(_validate_skill_slots(tree_rows, skill_rows))
    errors.append_array(_validate_tree_ultimates(tree_rows, ultimate_rows))
    errors.append_array(_validate_archetype_orientations(archetype_rows))
    return errors

func _validate_counts(trees: Array, skills: Array, ultimates: Array, archetypes: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    if trees.size() != EXPECTED_TREE_COUNT:
        errors.append("Expected %d trees, got %d" % [EXPECTED_TREE_COUNT, trees.size()])
    if skills.size() != EXPECTED_SKILL_COUNT:
        errors.append("Expected %d skills, got %d" % [EXPECTED_SKILL_COUNT, skills.size()])
    if ultimates.size() != EXPECTED_ULTIMATE_COUNT:
        errors.append("Expected %d ultimates, got %d" % [EXPECTED_ULTIMATE_COUNT, ultimates.size()])
    if archetypes.size() != EXPECTED_ARCHETYPE_COUNT:
        errors.append("Expected %d archetypes, got %d" % [EXPECTED_ARCHETYPE_COUNT, archetypes.size()])
    return errors

func _validate_unique_ids(rows: Array, label: String) -> PackedStringArray:
    var errors := PackedStringArray()
    var seen := {}
    for row in rows:
        var row_id: String = str(row.get("id", ""))
        if row_id.is_empty():
            errors.append("%s row without id" % label)
        elif seen.has(row_id):
            errors.append("Duplicate %s id: %s" % [label, row_id])
        else:
            seen[row_id] = true
    return errors

func _validate_skill_slots(trees: Array, skills: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    var slots_by_tree := {}
    for skill in skills:
        var tree_id: String = str(skill.get("tree_id", ""))
        var slot: int = int(skill.get("slot_index", 0))
        if not slots_by_tree.has(tree_id):
            slots_by_tree[tree_id] = {}
        if slot < 1 or slot > EXPECTED_SKILLS_PER_TREE:
            errors.append("Invalid skill slot %d in %s" % [slot, tree_id])
        elif slots_by_tree[tree_id].has(slot):
            errors.append("Duplicate slot %d in %s" % [slot, tree_id])
        else:
            slots_by_tree[tree_id][slot] = true
    for tree in trees:
        var tree_id: String = str(tree.get("id", ""))
        if not slots_by_tree.has(tree_id) or slots_by_tree[tree_id].size() != EXPECTED_SKILLS_PER_TREE:
            errors.append("Tree %s does not contain exactly %d skill slots" % [tree_id, EXPECTED_SKILLS_PER_TREE])
    return errors

func _validate_tree_ultimates(trees: Array, ultimates: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    var ultimate_ids := {}
    for ultimate in ultimates:
        ultimate_ids[str(ultimate.get("id", ""))] = true
    for tree in trees:
        var ultimate_id: String = str(tree.get("ultimate_id", ""))
        if ultimate_id.is_empty() or not ultimate_ids.has(ultimate_id):
            errors.append("Tree %s has no resolvable ultimate" % str(tree.get("id", "")))
    return errors

func _validate_archetype_orientations(archetypes: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    var total := 0
    for archetype in archetypes:
        var orientations: Array = archetype.get("orientations", [])
        total += orientations.size()
        if orientations.size() != 3:
            errors.append("Archetype %s must have exactly 3 orientations" % str(archetype.get("id", "")))
    if total != EXPECTED_ORIENTATION_COUNT:
        errors.append("Expected %d orientations, got %d" % [EXPECTED_ORIENTATION_COUNT, total])
    return errors
