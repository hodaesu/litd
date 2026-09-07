extends Node
class_name VeilleursContentDB

const ROOT := "res://data/veilleurs/v06"
const WATCHERS_PATH := ROOT + "/watchers.json"
const ENEMIES_PATH := ROOT + "/enemies_24_definitions.json"
const CONSTANTS_PATH := ROOT + "/combat_constants.json"
const LOADOUTS_PATH := ROOT + "/starter_loadouts_watchers.json"
const SKILL_CATALOG_PATH := ROOT + "/watcher_tree_catalog.json"
const CANONICAL_SKILL_PATHS := {
    "ENT_WATCHER_NAYRA": "res://data/veilleurs/skills/nayra_orun.json",
    "ENT_WATCHER_TAREK": "res://data/veilleurs/skills/tarek_senn.json",
    "ENT_WATCHER_AISHA": "res://data/veilleurs/skills/aisha_maren.json",
    "ENT_WATCHER_IDRIS": "res://data/veilleurs/skills/idris_vael.json"
}
const PROFILE_BY_TREE := {
    "Bastion": "guard",
    "Brisure": "impact",
    "Serment": "support",
    "Traque": "observe",
    "Entaille": "anatomy",
    "Disparition": "mobility",
    "Anatomie": "anatomy",
    "Suture": "sustain",
    "Hémocorde": "anatomy",
    "Sentence": "control",
    "Concorde": "support",
    "Dissidence": "psych"
}

var watchers_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var skills_by_id: Dictionary = {}
var skills_by_entity: Dictionary = {}
var combat_constants: Dictionary = {}
var starter_loadouts: Dictionary = {}
var load_errors: Array[String] = []

func _ready() -> void:
    reload()

func reload() -> void:
    watchers_by_id.clear()
    enemies_by_id.clear()
    skills_by_id.clear()
    skills_by_entity.clear()
    load_errors.clear()
    combat_constants = _load_dictionary(CONSTANTS_PATH)
    starter_loadouts = _load_dictionary(LOADOUTS_PATH)
    _index_entities(_load_dictionary(WATCHERS_PATH).get("watchers", []), watchers_by_id)
    _index_entities(_load_dictionary(ENEMIES_PATH).get("enemies", []), enemies_by_id)
    _load_canonical_skill_catalog()
    _validate()

func watcher(entity_id: String) -> Dictionary:
    return (watchers_by_id.get(entity_id, {}) as Dictionary).duplicate(true)

func enemy(entity_id: String) -> Dictionary:
    return (enemies_by_id.get(entity_id, {}) as Dictionary).duplicate(true)

func entity(entity_id: String) -> Dictionary:
    if watchers_by_id.has(entity_id):
        return watcher(entity_id)
    return enemy(entity_id)

func skill(skill_id: String) -> Dictionary:
    return (skills_by_id.get(skill_id, {}) as Dictionary).duplicate(true)

func skills_for(entity_id: String) -> Array:
    return (skills_by_entity.get(entity_id, []) as Array).duplicate(true)

func starter_loadout(entity_id: String) -> Dictionary:
    return (starter_loadouts.get(entity_id, {}) as Dictionary).duplicate(true)

func summary() -> Dictionary:
    return {
        "watchers": watchers_by_id.size(),
        "enemies": enemies_by_id.size(),
        "skills": skills_by_id.size(),
        "watcher_skill_counts": _watcher_skill_counts(),
        "grid": combat_constants.get("grid", {}),
        "load_errors": load_errors.duplicate()
    }

func _load_canonical_skill_catalog() -> void:
    # watcher_tree_catalog.json reste un manifeste lisible par QA, mais les lignes de
    # compétences proviennent directement du référentiel canonique unique.
    var manifest: Dictionary = _load_dictionary(SKILL_CATALOG_PATH)
    if int(manifest.get("tree_count", 0)) != 12 or int(manifest.get("skill_count", 0)) != 180:
        load_errors.append("canonical_manifest_contract")
    for entity_id_value: Variant in CANONICAL_SKILL_PATHS.keys():
        var entity_id := str(entity_id_value)
        if not watchers_by_id.has(entity_id):
            load_errors.append("canonical_watcher_missing:%s" % entity_id)
            continue
        var payload: Dictionary = _load_dictionary(str(CANONICAL_SKILL_PATHS[entity_id]))
        if payload.is_empty():
            continue
        var fields: Array = payload.get("fields", [])
        var tree_order: Array = payload.get("tree_order", [])
        var trees: Dictionary = payload.get("trees", {})
        var watcher_definition: Dictionary = watchers_by_id.get(entity_id, {})
        var tree_ids: Array = watcher_definition.get("tree_ids", [])
        if tree_order.size() != 3 or tree_ids.size() != 3:
            load_errors.append("canonical_tree_partition:%s" % entity_id)
            continue
        for tree_index in range(tree_order.size()):
            var branch_key := str(tree_order[tree_index])
            var tree: Dictionary = trees.get(branch_key, {})
            var branch_name := str(tree.get("name", branch_key.capitalize()))
            var rows: Array = tree.get("skills", [])
            if rows.size() != 15:
                load_errors.append("canonical_tree_size:%s:%s" % [entity_id, branch_key])
                continue
            var tree_id := str(tree_ids[tree_index])
            var profile := str(PROFILE_BY_TREE.get(branch_name, "assault"))
            for index in range(rows.size()):
                var row_value: Variant = rows[index]
                if not (row_value is Array):
                    load_errors.append("canonical_skill_row:%s:%s:%d" % [entity_id, branch_key, index])
                    continue
                var raw := _row_to_dictionary(fields, row_value as Array)
                var skill_id := str(raw.get("ID", ""))
                var canonical_type := str(raw.get("Type", "Active"))
                var action := _canonical_action(branch_name, skill_id, canonical_type)
                var skill := {
                    "skill_id": skill_id,
                    "entity_id": entity_id,
                    "tree_id": tree_id,
                    "tree_name": branch_name,
                    "skill_index": index + 1,
                    "unlock_level": int(raw.get("Niveau", 1)),
                    "name_fr": str(raw.get("Nom", "Technique")),
                    "mechanical_profile": profile,
                    "activation_type": _canonical_activation(canonical_type),
                    "action_type": action,
                    "target_type": _target_for(action),
                    "precision_mod": int(raw.get("Précision base %", 86)) - 86,
                    "dismemberment_rules": _dismemberment_for(profile, index),
                    "effect_spec": _effect_for(profile, index),
                    "canonical_type": canonical_type,
                    "canonical_function": str(raw.get("Fonction", "")),
                    "canonical_positions": str(raw.get("Positions", "")),
                    "canonical_target": str(raw.get("Cible", "")),
                    "canonical_impacts": str(raw.get("Impacts", "")),
                    "canonical_power_0_5": float(raw.get("Puissance 0-5", 0.0)),
                    "canonical_accuracy_pct": int(raw.get("Précision base %", 100)),
                    "canonical_tags": _split_tags(str(raw.get("Tags", ""))),
                    "canonical_cooldown": str(raw.get("Cooldown", "—")),
                    "canonical_charges": str(raw.get("Charges", "—")),
                    "canonical_conditions": str(raw.get("Conditions", ""))
                }
                _index_skill(skill)

func _canonical_activation(canonical_type: String) -> String:
    match canonical_type:
        "Passif": return "passive"
        "Réaction": return "reaction"
        "Posture": return "stance"
        "Transformation": return "transformation"
        "Maîtresse": return "mastery"
        _: return "active"

func _canonical_action(branch_name: String, skill_id: String, canonical_type: String) -> String:
    if canonical_type in ["Passif", "Transformation"]:
        return "passive_modifier"
    if canonical_type == "Posture":
        match branch_name:
            "Bastion": return "guard"
            "Serment", "Suture", "Concorde": return "support"
            "Traque", "Anatomie", "Hémocorde": return "observe"
            "Disparition": return "move"
            "Sentence": return "control"
            "Dissidence": return "psychological"
            _: return "passive_modifier"
    match branch_name:
        "Bastion": return "guard"
        "Brisure": return "attack"
        "Serment": return "support"
        "Traque":
            return "attack" if skill_id in ["TA-TRA-04", "TA-TRA-13"] else "observe"
        "Entaille": return "attack"
        "Disparition":
            if skill_id in ["TA-DIS-05", "TA-DIS-14"]:
                return "attack_move"
            if skill_id == "TA-DIS-09":
                return "control"
            return "move"
        "Anatomie":
            return "observe" if skill_id in ["AÏ-ANA-01", "AÏ-ANA-02", "AÏ-ANA-08", "AÏ-ANA-12"] else "attack"
        "Suture": return "heal"
        "Hémocorde":
            return "observe" if skill_id in ["AÏ-HÉM-06", "AÏ-HÉM-08"] else "attack"
        "Sentence": return "control"
        "Concorde": return "support"
        "Dissidence": return "psychological"
        _: return "attack"

func _row_to_dictionary(fields: Array, row: Array) -> Dictionary:
    var result: Dictionary = {}
    var count := mini(fields.size(), row.size())
    for index in range(count):
        result[str(fields[index])] = row[index]
    return result

func _split_tags(text: String) -> Array[String]:
    var result: Array[String] = []
    for part: String in text.split(";", false):
        var tag := part.strip_edges()
        if tag == "MEMRE_BLESSÉ":
            tag = "MEMBRE_BLESSÉ"
        if tag != "" and not result.has(tag):
            result.append(tag)
    return result

func _index_skill(skill: Dictionary) -> void:
    var skill_id := str(skill.get("skill_id", ""))
    var entity_id := str(skill.get("entity_id", ""))
    if skill_id == "" or entity_id == "":
        load_errors.append("invalid_skill")
        return
    if skills_by_id.has(skill_id):
        load_errors.append("duplicate_skill:%s" % skill_id)
        return
    skills_by_id[skill_id] = skill
    if not skills_by_entity.has(entity_id):
        skills_by_entity[entity_id] = []
    (skills_by_entity[entity_id] as Array).append(skill)

func _target_for(action: String) -> String:
    if action == "guard":
        return "self"
    if action in ["heal", "support"]:
        return "ally_single"
    if action == "passive_modifier":
        return "none"
    if action == "move":
        return "enemy_single"
    return "enemy_single"

func _precision_for(profile: String, index: int) -> int:
    var tier: int = 1 + int(index / 3)
    match profile:
        "impact": return -4 + tier
        "anatomy": return 7 + tier
        "observe": return 3 + tier * 2
        "mobility": return 4 + tier
        "psych": return 5 + tier
        _: return 0

func _dismemberment_for(profile: String, index: int) -> Dictionary:
    var allowed := profile == "anatomy" and index >= 11
    return {"allowed": allowed, "min_body_state": "L4" if allowed else "", "power": 2 + int(index >= 12) + int(index >= 14) if allowed else 0}

func _effect_for(profile: String, index: int) -> Dictionary:
    var tier: int = 1 + int(index / 3)
    var scale := float(index) / 14.0
    var result := {"damage_multiplier": 0.0, "trauma_multiplier": 0.0, "forced_move": 0, "knowledge_reveal": 0, "guard_delta": 0, "resolve_delta": 0}
    match profile:
        "impact":
            result["damage_multiplier"] = 0.85 + 0.65 * scale
            result["trauma_multiplier"] = 1.15 + 0.65 * scale
            result["forced_move"] = 0 if index < 3 else (1 if index < 9 else 2)
        "anatomy":
            result["damage_multiplier"] = 0.65 + 0.45 * scale
            result["trauma_multiplier"] = 1.0 + 0.70 * scale
        "mobility":
            result["damage_multiplier"] = 0.65 + 0.50 * scale
            result["trauma_multiplier"] = 0.65 + 0.25 * scale
        "guard":
            result["guard_delta"] = 10 + tier * 5
        "sustain":
            result["guard_delta"] = 3 + tier * 2
        "support":
            result["guard_delta"] = 4 + tier * 2
            result["resolve_delta"] = 4 + tier * 2
        "observe":
            result["knowledge_reveal"] = mini(3, 1 + int(index >= 7) + int(index >= 12))
        "psych":
            result["resolve_delta"] = -(5 + tier * 3)
        "control":
            result["resolve_delta"] = -(2 + tier)
        _:
            result["damage_multiplier"] = 0.8 + 0.55 * scale
            result["trauma_multiplier"] = 0.85 + 0.40 * scale
    return result

func _index_entities(values: Array, destination: Dictionary) -> void:
    for value: Variant in values:
        if not (value is Dictionary):
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        var entity_id := str(row.get("entity_id", ""))
        if entity_id == "":
            load_errors.append("entity_without_id")
            continue
        if destination.has(entity_id):
            load_errors.append("duplicate_entity:%s" % entity_id)
            continue
        destination[entity_id] = row

func _watcher_skill_counts() -> Dictionary:
    var result: Dictionary = {}
    for entity_id_value: Variant in watchers_by_id.keys():
        var entity_id := str(entity_id_value)
        result[entity_id] = (skills_by_entity.get(entity_id, []) as Array).size()
    return result

func _validate() -> void:
    if watchers_by_id.size() != 4:
        load_errors.append("watcher_count:%d" % watchers_by_id.size())
    if enemies_by_id.size() != 24:
        load_errors.append("enemy_count:%d" % enemies_by_id.size())
    if skills_by_id.size() != 180:
        load_errors.append("watcher_skill_count:%d" % skills_by_id.size())
    for entity_id_value: Variant in watchers_by_id.keys():
        var entity_id := str(entity_id_value)
        if (skills_by_entity.get(entity_id, []) as Array).size() != 45:
            load_errors.append("watcher_skill_partition:%s" % entity_id)
    var grid: Dictionary = combat_constants.get("grid", {})
    if int(grid.get("width", 0)) != 6 or int(grid.get("height", 0)) != 5:
        load_errors.append("grid_contract")

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        load_errors.append("missing:%s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        load_errors.append("invalid_json:%s" % path)
        return {}
    return parsed as Dictionary
