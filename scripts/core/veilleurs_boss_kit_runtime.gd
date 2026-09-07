extends RefCounted
class_name VeilleursBossKitRuntime

const TREE_INDEX_PATH := "res://data/veilleurs/boss_tree_index_v1.json"
const PHASES_PATH := "res://data/veilleurs/boss_phase_catalog_v1.json"

var tree_data: Dictionary = {}
var phase_data: Dictionary = {}

func _init() -> void:
    tree_data = _load_dictionary(TREE_INDEX_PATH)
    phase_data = _load_dictionary(PHASES_PATH)

func validation_report() -> Dictionary:
    var errors: Array[String] = []
    var bosses: Array = tree_data.get("bosses", [])
    if bosses.size() != 5:
        errors.append("boss_count:%d" % bosses.size())
    var tree_count := 0
    var ultimate_count := 0
    for boss_value: Variant in bosses:
        if not (boss_value is Dictionary):
            continue
        var trees: Array = (boss_value as Dictionary).get("trees", [])
        tree_count += trees.size()
        for tree_value: Variant in trees:
            if tree_value is Dictionary and not ((tree_value as Dictionary).get("ultimate", {}) as Dictionary).is_empty():
                ultimate_count += 1
    if tree_count != 15:
        errors.append("tree_count:%d" % tree_count)
    if ultimate_count != 15:
        errors.append("ultimate_count:%d" % ultimate_count)
    if int((tree_data.get("full_skill_source", {}) as Dictionary).get("boss_skill_rows", 0)) != 225:
        errors.append("boss_skill_rows")

    for phase_value: Variant in phase_data.get("records", []):
        if not (phase_value is Dictionary):
            continue
        var phase: Dictionary = phase_value
        var boss_id := _boss_id(str(phase.get("boss", "")))
        var phase_number := int(phase.get("phase", 0))
        if boss_id == "le_copiste" and phase_number == 4:
            continue
        var tree := tree_by_name(boss_id, str(phase.get("doctrine", "")))
        if tree.is_empty():
            errors.append("phase_tree_unbound:%s:%d" % [boss_id, phase_number])
    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "bosses": bosses.size(),
        "trees": tree_count,
        "ultimates": ultimate_count,
        "boss_skill_rows_source": int((tree_data.get("full_skill_source", {}) as Dictionary).get("boss_skill_rows", 0))
    }

func boss_kit(boss_id: String) -> Dictionary:
    var normalized := _boss_id(boss_id)
    for value: Variant in tree_data.get("bosses", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == normalized:
            return (value as Dictionary).duplicate(true)
    return {}

func tree_by_name(boss_id: String, tree_name: String) -> Dictionary:
    var kit := boss_kit(boss_id)
    for value: Variant in kit.get("trees", []):
        if value is Dictionary and str((value as Dictionary).get("name", "")) == tree_name:
            return (value as Dictionary).duplicate(true)
    return {}

func phase_kit(boss_id: String, phase_number: int) -> Dictionary:
    var normalized := _boss_id(boss_id)
    var phase := _phase_definition(normalized, phase_number)
    if phase.is_empty():
        return {"success": false, "reason": "unknown_phase", "boss_id": normalized, "phase": phase_number}
    if normalized == "le_copiste" and phase_number == 4:
        var kit := boss_kit(normalized)
        return {
            "success": true,
            "boss_id": normalized,
            "phase": phase_number,
            "phase_title": phase.get("title", ""),
            "mode": "synthesis",
            "doctrine": phase.get("doctrine", ""),
            "trees": (kit.get("trees", []) as Array).duplicate(true),
            "full_skill_source": tree_data.get("full_skill_source", {}).duplicate(true),
            "mechanics": phase.get("mechanics", ""),
            "counterplay": phase.get("counterplay", "")
        }
    var tree := tree_by_name(normalized, str(phase.get("doctrine", "")))
    if tree.is_empty():
        return {"success": false, "reason": "canonical_tree_not_found", "boss_id": normalized, "phase": phase_number}
    return {
        "success": true,
        "boss_id": normalized,
        "phase": phase_number,
        "phase_title": phase.get("title", ""),
        "mode": "single_tree",
        "doctrine": phase.get("doctrine", ""),
        "tree": tree,
        "ultimate": (tree.get("ultimate", {}) as Dictionary).duplicate(true),
        "full_skill_source": tree_data.get("full_skill_source", {}).duplicate(true),
        "mechanics": phase.get("mechanics", ""),
        "counterplay": phase.get("counterplay", "")
    }

func ultimate_for_phase(boss_id: String, phase_number: int) -> Dictionary:
    var kit := phase_kit(boss_id, phase_number)
    if str(kit.get("mode", "")) == "single_tree":
        return (kit.get("ultimate", {}) as Dictionary).duplicate(true)
    return {}

func _phase_definition(boss_id: String, phase_number: int) -> Dictionary:
    for value: Variant in phase_data.get("records", []):
        if not (value is Dictionary):
            continue
        var phase: Dictionary = value
        if _boss_id(str(phase.get("boss", ""))) == boss_id and int(phase.get("phase", 0)) == phase_number:
            return phase.duplicate(true)
    return {}

func _boss_id(value: String) -> String:
    var normalized := value.to_lower().strip_edges().replace("boss.", "")
    normalized = normalized.replace("ishar, gardien du passage", "ishar_gardien_du_passage")
    normalized = normalized.replace("orateur sans voix", "orateur_sans_voix")
    normalized = normalized.replace("mère des veines", "mere_des_veines")
    normalized = normalized.replace("porte-cendres blanc", "porte_cendres_blanc")
    normalized = normalized.replace("le copiste", "le_copiste")
    return normalized

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
