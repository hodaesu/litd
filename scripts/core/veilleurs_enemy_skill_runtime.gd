extends RefCounted
class_name VeilleursEnemySkillRuntime

const CATALOG_PATH := "res://data/veilleurs/skills/enemy_skill_runtime_catalog_v1.json"
const INTENT_RESOLVER_SCRIPT := preload("res://scripts/core/veilleurs_intent_resolver.gd")

var catalog: Dictionary = {}
var node_schema: Dictionary = {}
var trees_by_entity: Dictionary = {}
var skills_by_runtime_id: Dictionary = {}
var entity_names: Dictionary = {}
var boss_entities: Dictionary = {}
var assigned_trees: Dictionary = {}
var intent_resolver: VeilleursIntentResolver

func _init() -> void:
    intent_resolver = INTENT_RESOLVER_SCRIPT.new() as VeilleursIntentResolver
    reload_content()

func reload_content() -> Dictionary:
    catalog = _load_dictionary(CATALOG_PATH)
    node_schema.clear()
    trees_by_entity.clear()
    skills_by_runtime_id.clear()
    entity_names.clear()
    boss_entities.clear()
    var source: Dictionary = catalog.get("canonical_source", {})
    for file_value: Variant in source.get("tree_files", []):
        if not (file_value is Dictionary):
            continue
        var file_entry: Dictionary = file_value
        var path := str(file_entry.get("path", ""))
        var data := _load_dictionary(path)
        if data.is_empty():
            continue
        if node_schema.is_empty():
            node_schema = (data.get("node_schema", {}) as Dictionary).duplicate(true)
        var is_boss_file := path.ends_with("boss_skill_trees_225_v1.json")
        for tree_value: Variant in data.get("trees", []):
            if tree_value is Dictionary:
                _register_tree(tree_value as Dictionary, is_boss_file)
    return validation_report()

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    var expected: Dictionary = catalog.get("counts", {})
    if trees_by_entity.size() != int(expected.get("entities", 29)):
        errors.append("entities:%d" % trees_by_entity.size())
    if skills_by_runtime_id.size() != int(expected.get("skills", 1305)):
        errors.append("skills:%d" % skills_by_runtime_id.size())
    var tree_count := 0
    var boss_skill_count := 0
    for entity_id: Variant in trees_by_entity.keys():
        var trees: Array = trees_by_entity[entity_id]
        tree_count += trees.size()
        if trees.size() != 3:
            errors.append("tree_count:%s:%d" % [str(entity_id), trees.size()])
        for tree_value: Variant in trees:
            if not (tree_value is Dictionary):
                continue
            var tree: Dictionary = tree_value
            var skills: Array = tree.get("skills", [])
            if skills.size() != 15:
                errors.append("skill_count:%s:%s:%d" % [str(entity_id), str(tree.get("tree", "")), skills.size()])
            if boss_entities.has(str(entity_id)):
                boss_skill_count += skills.size()
    if tree_count != int(expected.get("trees", 87)):
        errors.append("trees:%d" % tree_count)
    if boss_entities.size() != int(expected.get("bosses", 5)):
        errors.append("bosses:%d" % boss_entities.size())
    if boss_skill_count != int(expected.get("boss_skills", 225)):
        errors.append("boss_skills:%d" % boss_skill_count)
    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "entities": trees_by_entity.size(),
        "trees": tree_count,
        "skills": skills_by_runtime_id.size(),
        "bosses": boss_entities.size(),
        "boss_skills": boss_skill_count,
        "runtime_id_collisions": maxi(0, 1305 - skills_by_runtime_id.size())
    }

func recognizes_entity(entity_id: String) -> bool:
    return trees_by_entity.has(entity_id)

func is_boss_entity(entity_id: String) -> bool:
    return boss_entities.has(entity_id)

func trees_for_entity(entity_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in trees_by_entity.get(entity_id, []):
        if value is Dictionary:
            result.append((value as Dictionary).duplicate(true))
    return result

func skills_for_entity(entity_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for tree: Dictionary in trees_for_entity(entity_id):
        for value: Variant in tree.get("skills", []):
            if value is Dictionary:
                result.append((value as Dictionary).duplicate(true))
    return result

func skill(runtime_id: String) -> Dictionary:
    var value: Variant = skills_by_runtime_id.get(runtime_id, {})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func select_active_tree(entity_id: String, seed_value: int, preserved_tree: String = "") -> String:
    var trees := trees_for_entity(entity_id)
    if trees.is_empty():
        return ""
    if not preserved_tree.is_empty() and _tree_exists(entity_id, preserved_tree):
        return preserved_tree
    var names: Array[String] = []
    for tree: Dictionary in trees:
        names.append(str(tree.get("tree", "")))
    names.sort()
    var rng := RandomNumberGenerator.new()
    rng.seed = int(seed_value) * 104729 + int(entity_id.hash())
    return names[rng.randi_range(0, names.size() - 1)]

func prepare_enemy(enemy: Dictionary, seed_value: int) -> Dictionary:
    var entity_id := _entity_id(enemy)
    if not recognizes_entity(entity_id):
        return enemy
    enemy["veilleurs_entity_id"] = entity_id
    enemy["veilleurs_skill_runtime"] = true
    if is_boss_entity(entity_id):
        return enemy
    var current_tree := str(enemy.get("veilleurs_active_tree", ""))
    var key := _instance_key(enemy, entity_id)
    if current_tree.is_empty() and assigned_trees.has(key):
        current_tree = str(assigned_trees[key])
    current_tree = select_active_tree(entity_id, seed_value, current_tree)
    if not current_tree.is_empty():
        enemy["veilleurs_active_tree"] = current_tree
        assigned_trees[key] = current_tree
    return enemy

func candidate_actions(entity_id: String, allowed_trees: Array, context: Dictionary = {}) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var allowed: Dictionary = {}
    for tree_value: Variant in allowed_trees:
        allowed[str(tree_value)] = true
    for tree: Dictionary in trees_for_entity(entity_id):
        var tree_name := str(tree.get("tree", ""))
        if not allowed.is_empty() and not allowed.has(tree_name):
            continue
        for skill_value: Variant in tree.get("skills", []):
            if not (skill_value is Dictionary):
                continue
            var source_skill: Dictionary = skill_value
            if not _channel_allowed(source_skill, context):
                continue
            if not _position_allowed(source_skill, context):
                continue
            var intent := intent_resolver.resolve_skill_intent(entity_id, source_skill)
            if not bool(intent.get("ok", false)):
                continue
            var action := source_skill.duplicate(true)
            action["intent"] = str(intent.get("intent_family", ""))
            action["secondary_intent"] = str(intent.get("secondary_intent", ""))
            action["action_channel"] = str(intent.get("action_channel", ""))
            action["queued"] = bool(intent.get("queued", false))
            result.append(action)
    return result

func choose_action(enemy: Dictionary, heroes: Array, context: Dictionary = {}) -> Dictionary:
    var entity_id := _entity_id(enemy)
    if not recognizes_entity(entity_id):
        return {}
    var allowed_trees: Array = context.get("allowed_trees", [])
    if allowed_trees.is_empty():
        var active_tree := str(enemy.get("veilleurs_active_tree", ""))
        if active_tree.is_empty() and not is_boss_entity(entity_id):
            var seed_value := int(context.get("seed", enemy.get("seed", enemy.get("identity_seed", 0))))
            active_tree = select_active_tree(entity_id, seed_value)
        if not active_tree.is_empty():
            allowed_trees = [active_tree]
    if is_boss_entity(entity_id) and allowed_trees.is_empty():
        return {"blocked": true, "reason": "boss_phase_tree_required", "veilleurs_skill": true, "entity_id": entity_id}
    var candidates := candidate_actions(entity_id, allowed_trees, context)
    if candidates.is_empty():
        return {"blocked": true, "reason": "no_canonical_skill_available_in_context", "veilleurs_skill": true, "entity_id": entity_id}
    var seed_value := int(context.get("seed", enemy.get("seed", enemy.get("identity_seed", 0))))
    var turn_index := int(context.get("turn_index", context.get("round", 0)))
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value * 104729 + turn_index * 1009 + int(entity_id.hash())
    var chosen: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
    var target := _target_for(chosen, heroes, rng)
    return {
        "id": str(chosen.get("runtime_skill_id", "")),
        "name": str(chosen.get("skill_name", "")),
        "runtime_skill_id": str(chosen.get("runtime_skill_id", "")),
        "source_skill_id": str(chosen.get("source_skill_id", "")),
        "veilleurs_skill": true,
        "entity_id": entity_id,
        "tree": str(chosen.get("tree", "")),
        "node": int(chosen.get("node", 0)),
        "level": int(chosen.get("level", 0)),
        "skill_type": str(chosen.get("skill_type", "")),
        "node_role": str(chosen.get("node_role", "")),
        "intent": str(chosen.get("intent", "")),
        "secondary_intent": str(chosen.get("secondary_intent", "")),
        "action_channel": str(chosen.get("action_channel", "")),
        "veilleurs_power_0_5": float(chosen.get("power_0_5", 0.0)),
        "precision_pct": int(chosen.get("precision_pct", 0)),
        "positions": str(chosen.get("positions", "")),
        "tags": (chosen.get("tags", []) as Array).duplicate(),
        "target_side": str(target.get("side", "world")),
        "target_index": int(target.get("index", -1)),
        "power": 0.0,
        "resolver_required": true,
        "mechanical_resolution": "canonical_resolver_required",
        "generic_damage_fallback_forbidden": true,
        "party_counterpick_used": false
    }

func serialize() -> Dictionary:
    return {"assigned_trees": assigned_trees.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    assigned_trees = payload.get("assigned_trees", {}).duplicate(true)

func _register_tree(tree_source: Dictionary, is_boss: bool) -> void:
    var entity_id := str(tree_source.get("entity_id", ""))
    var tree_name := str(tree_source.get("tree", ""))
    if entity_id.is_empty() or tree_name.is_empty():
        return
    entity_names[entity_id] = str(tree_source.get("entity_name", entity_id))
    if is_boss:
        boss_entities[entity_id] = true
    if not trees_by_entity.has(entity_id):
        trees_by_entity[entity_id] = []
    var expanded := tree_source.duplicate(true)
    var expanded_skills: Array[Dictionary] = []
    var source_ids: Array = tree_source.get("source_skill_ids", [])
    var names: Array = tree_source.get("names", [])
    var powers: Array = tree_source.get("power_0_5", [])
    var precisions: Array = tree_source.get("precision_pct", [])
    var levels: Array = node_schema.get("levels", [])
    var types: Array = node_schema.get("types", [])
    var roles: Array = node_schema.get("roles", [])
    var tags := _split_tags(str(tree_source.get("tags", "")))
    for index in range(15):
        if index >= source_ids.size() or index >= names.size() or index >= powers.size() or index >= precisions.size():
            continue
        var source_id := str(source_ids[index])
        var runtime_id := "%s:%s" % [entity_id, source_id]
        var skill_record := {
            "runtime_skill_id": runtime_id,
            "source_skill_id": source_id,
            "entity_id": entity_id,
            "entity_name": str(tree_source.get("entity_name", entity_id)),
            "tree": tree_name,
            "node": index + 1,
            "level": int(levels[index]) if index < levels.size() else 0,
            "skill_name": str(names[index]),
            "skill_type": str(types[index]) if index < types.size() else "",
            "node_role": str(roles[index]) if index < roles.size() else "",
            "positions": str(tree_source.get("positions", "")),
            "tags": tags.duplicate(),
            "power_0_5": float(powers[index]),
            "precision_pct": int(precisions[index])
        }
        if skills_by_runtime_id.has(runtime_id):
            push_error("VeilleursEnemySkillRuntime: duplicate runtime skill id %s" % runtime_id)
            continue
        skills_by_runtime_id[runtime_id] = skill_record
        expanded_skills.append(skill_record)
    expanded["skills"] = expanded_skills
    (trees_by_entity[entity_id] as Array).append(expanded)

func _channel_allowed(skill_record: Dictionary, context: Dictionary) -> bool:
    var skill_type := str(skill_record.get("skill_type", ""))
    match skill_type:
        "Active": return true
        "Passif": return false
        "Réaction": return bool(context.get("reaction_window", false))
        "Interaction": return bool(context.get("environment_interaction_available", false))
        "Posture": return bool(context.get("posture_window", false))
        "Synergie": return bool(context.get("synergy_active", false))
        "Maîtresse": return bool(context.get("major_action_window", false))
        "Transformation": return bool(context.get("transformation_window", false))
    return false

func _position_allowed(skill_record: Dictionary, context: Dictionary) -> bool:
    var rank := int(context.get("actor_rank", 0))
    if rank <= 0:
        return true
    var positions := str(skill_record.get("positions", ""))
    return positions.contains("P%d" % rank)

func _target_for(action: Dictionary, heroes: Array, rng: RandomNumberGenerator) -> Dictionary:
    var intent := str(action.get("intent", ""))
    if intent in ["defense", "repositionnement"]:
        return {"side": "self", "index": -1}
    if intent == "soutien":
        return {"side": "ally", "index": -1}
    if intent == "environnement":
        return {"side": "world", "index": -1}
    var living: Array[int] = []
    for index in range(heroes.size()):
        if heroes[index] is Dictionary and int((heroes[index] as Dictionary).get("hp", 0)) > 0:
            living.append(index)
    if living.is_empty():
        return {"side": "hero", "index": -1}
    var tags: Array = action.get("tags", [])
    if tags.has("CIBLE_BLESSÉE"):
        var weakest := living[0]
        var weakest_ratio := 2.0
        for index: int in living:
            var hero: Dictionary = heroes[index]
            var max_hp := maxf(1.0, float(hero.get("max_hp", hero.get("hp", 1))))
            var ratio := float(hero.get("hp", 0)) / max_hp
            if ratio < weakest_ratio:
                weakest_ratio = ratio
                weakest = index
        return {"side": "hero", "index": weakest}
    return {"side": "hero", "index": living[rng.randi_range(0, living.size() - 1)]}

func _tree_exists(entity_id: String, tree_name: String) -> bool:
    for tree: Dictionary in trees_for_entity(entity_id):
        if str(tree.get("tree", "")) == tree_name:
            return true
    return false

func _entity_id(enemy: Dictionary) -> String:
    for key: String in ["veilleurs_entity_id", "species_id", "entity_id", "creature_id"]:
        var value := str(enemy.get(key, ""))
        if recognizes_entity(value):
            return value
    return ""

func _instance_key(enemy: Dictionary, entity_id: String) -> String:
    for key: String in ["remanence_id", "instance_id"]:
        var value := str(enemy.get(key, ""))
        if not value.is_empty():
            return value
    return "%s:%s" % [entity_id, str(enemy.get("identity_seed", enemy.get("seed", 0)))]

func _split_tags(text: String) -> Array[String]:
    var result: Array[String] = []
    for part: String in text.split(";"):
        var value := part.strip_edges()
        if not value.is_empty():
            result.append(value)
    return result

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
