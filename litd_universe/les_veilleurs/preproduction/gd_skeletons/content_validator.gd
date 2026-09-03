@tool
class_name LITDContentValidator
extends RefCounted

## Preproduction skeleton: not compile-validated yet.
## Counts aligned with the recovered master combat reference.

const SKILLS_PER_TREE := 15

const EXPECTED_VEILLEUR_TREE_COUNT := 12
const EXPECTED_VEILLEUR_SKILL_COUNT := 180
const EXPECTED_VEILLEUR_ULTIMATE_COUNT := 12

const EXPECTED_ENEMY_BOSS_ENTITY_COUNT := 29
const EXPECTED_ENEMY_BOSS_TREE_COUNT := 87
const EXPECTED_ENEMY_BOSS_SKILL_COUNT := 1305
const EXPECTED_ENEMY_BOSS_ULTIMATE_COUNT := 87

const EXPECTED_TOTAL_TREE_COUNT := 99
const EXPECTED_TOTAL_NORMAL_SKILL_COUNT := 1485
const EXPECTED_TOTAL_ULTIMATE_COUNT := 99

const EXPECTED_ENCOUNTER_TEMPLATE_COUNT := 64
const EXPECTED_BOSS_PHASE_COUNT := 16
const EXPECTED_HAZARD_COUNT := 12
const EXPECTED_ACCEPTANCE_TEST_COUNT := 48

func validate_veilleur_registry(tree_rows: Array, skill_rows: Array, ultimate_rows: Array) -> PackedStringArray:
    return _validate_domain(
        tree_rows,
        skill_rows,
        ultimate_rows,
        EXPECTED_VEILLEUR_TREE_COUNT,
        EXPECTED_VEILLEUR_SKILL_COUNT,
        EXPECTED_VEILLEUR_ULTIMATE_COUNT,
        "veilleur"
    )

func validate_enemy_boss_registry(entity_rows: Array, tree_rows: Array, skill_rows: Array, ultimate_rows: Array) -> PackedStringArray:
    var errors := _validate_domain(
        tree_rows,
        skill_rows,
        ultimate_rows,
        EXPECTED_ENEMY_BOSS_TREE_COUNT,
        EXPECTED_ENEMY_BOSS_SKILL_COUNT,
        EXPECTED_ENEMY_BOSS_ULTIMATE_COUNT,
        "enemy_boss"
    )
    if entity_rows.size() != EXPECTED_ENEMY_BOSS_ENTITY_COUNT:
        errors.append("Expected %d enemy/boss entities, got %d" % [EXPECTED_ENEMY_BOSS_ENTITY_COUNT, entity_rows.size()])
    return errors

func validate_support_content(encounters: Array, boss_phases: Array, hazards: Array, acceptance_tests: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    if encounters.size() != EXPECTED_ENCOUNTER_TEMPLATE_COUNT:
        errors.append("Expected %d encounter templates, got %d" % [EXPECTED_ENCOUNTER_TEMPLATE_COUNT, encounters.size()])
    if boss_phases.size() != EXPECTED_BOSS_PHASE_COUNT:
        errors.append("Expected %d boss phases, got %d" % [EXPECTED_BOSS_PHASE_COUNT, boss_phases.size()])
    if hazards.size() != EXPECTED_HAZARD_COUNT:
        errors.append("Expected %d combat hazards, got %d" % [EXPECTED_HAZARD_COUNT, hazards.size()])
    if acceptance_tests.size() != EXPECTED_ACCEPTANCE_TEST_COUNT:
        errors.append("Expected %d acceptance tests, got %d" % [EXPECTED_ACCEPTANCE_TEST_COUNT, acceptance_tests.size()])
    return errors

func _validate_domain(trees: Array, skills: Array, ultimates: Array, expected_trees: int, expected_skills: int, expected_ultimates: int, label: String) -> PackedStringArray:
    var errors := PackedStringArray()
    if trees.size() != expected_trees:
        errors.append("%s: expected %d trees, got %d" % [label, expected_trees, trees.size()])
    if skills.size() != expected_skills:
        errors.append("%s: expected %d normal skills, got %d" % [label, expected_skills, skills.size()])
    if ultimates.size() != expected_ultimates:
        errors.append("%s: expected %d ultimates, got %d" % [label, expected_ultimates, ultimates.size()])
    errors.append_array(_validate_unique_ids(trees, "%s tree" % label))
    errors.append_array(_validate_unique_ids(skills, "%s skill" % label))
    errors.append_array(_validate_unique_ids(ultimates, "%s ultimate" % label))
    errors.append_array(_validate_skill_slots(trees, skills))
    errors.append_array(_validate_tree_ultimates(trees, ultimates))
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
        if slot < 1 or slot > SKILLS_PER_TREE:
            errors.append("Invalid skill slot %d in %s" % [slot, tree_id])
        elif slots_by_tree[tree_id].has(slot):
            errors.append("Duplicate slot %d in %s" % [slot, tree_id])
        else:
            slots_by_tree[tree_id][slot] = true
    for tree in trees:
        var tree_id: String = str(tree.get("id", ""))
        if not slots_by_tree.has(tree_id) or slots_by_tree[tree_id].size() != SKILLS_PER_TREE:
            errors.append("Tree %s does not contain exactly %d normal skill slots" % [tree_id, SKILLS_PER_TREE])
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

func validate_superseded_contract_not_loaded(metadata: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if int(metadata.get("normal_skill_count", -1)) == 315:
        errors.append("Superseded 315-stage corpus detected. Load the recovered master combat reference instead.")
    if int(metadata.get("orientation_count", -1)) == 75 and int(metadata.get("archetype_count", -1)) == 25:
        errors.append("Legacy 25/75 concept matrix detected as current roster. Keep it as concept reserve only unless explicitly reintroduced.")
    return errors
