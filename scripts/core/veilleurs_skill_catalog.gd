extends Node

const DATA_PATHS := {
    "nayra_orun": "res://data/veilleurs/skills/nayra_orun.json",
    "tarek_senn": "res://data/veilleurs/skills/tarek_senn.json",
    "aisha_maren": "res://data/veilleurs/skills/aisha_maren.json",
    "idris_vael": "res://data/veilleurs/skills/idris_vael.json"
}
const COSTS: Array[int] = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5]
const EXPECTED_LEVELS: Array[int] = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 44, 49]
const MANUAL_TYPES := ["Active", "Posture", "Maîtresse"]

var catalogs: Dictionary = {}
var load_errors: Array[String] = []

func _ready() -> void:
    reload()

func reload() -> void:
    catalogs.clear()
    load_errors.clear()
    for watcher_id_value: Variant in DATA_PATHS.keys():
        var watcher_id := str(watcher_id_value)
        var path := str(DATA_PATHS[watcher_id])
        if not FileAccess.file_exists(path):
            load_errors.append("missing:%s" % path)
            continue
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not (parsed is Dictionary):
            load_errors.append("invalid_json:%s" % path)
            continue
        var catalog: Dictionary = parsed
        if str(catalog.get("watcher_id", "")) != watcher_id:
            load_errors.append("wrong_watcher:%s" % path)
            continue
        catalogs[watcher_id] = catalog

func is_watcher(hero: Dictionary) -> bool:
    return catalogs.has(str(hero.get("id", "")))

func watcher_ids() -> Array[String]:
    var result: Array[String] = []
    for value: Variant in DATA_PATHS.keys():
        result.append(str(value))
    return result

func branches_for(hero: Dictionary) -> Array[String]:
    var catalog := _catalog(hero)
    var result: Array[String] = []
    for value: Variant in catalog.get("tree_order", []):
        result.append(str(value))
    return result

func branch_label(hero: Dictionary, branch: String) -> String:
    var tree := _tree(hero, branch)
    return str(tree.get("name", branch.capitalize()))

func skill_nodes(hero: Dictionary, branch: String) -> Array:
    var catalog := _catalog(hero)
    var tree := _tree(hero, branch)
    var fields: Array = catalog.get("fields", [])
    var rows: Array = tree.get("skills", [])
    var result: Array = []
    var previous := ""
    for index in range(rows.size()):
        var row_value: Variant = rows[index]
        if not (row_value is Array):
            continue
        var raw := _row_to_dictionary(fields, row_value as Array)
        var node := {
            "id": str(raw.get("ID", "")),
            "name": str(raw.get("Nom", "Technique")),
            "description": str(raw.get("Fonction", "")),
            "required_level": int(raw.get("Niveau", 1)),
            "cost": COSTS[mini(index, COSTS.size() - 1)],
            "requires": previous,
            "branch": branch,
            "branch_name": str(raw.get("Arbre", branch_label(hero, branch))),
            "canonical_type": str(raw.get("Type", "Active")),
            "canonical_function": str(raw.get("Fonction", "")),
            "canonical_positions": str(raw.get("Positions", "")),
            "canonical_target": str(raw.get("Cible", "")),
            "canonical_impacts": str(raw.get("Impacts", "")),
            "power_0_5": float(raw.get("Puissance 0-5", 0.0)),
            "base_accuracy_pct": int(raw.get("Précision base %", 100)),
            "canonical_tags": _split_tags(str(raw.get("Tags", ""))),
            "cooldown_text": str(raw.get("Cooldown", "—")),
            "charges_text": str(raw.get("Charges", "—")),
            "canonical_conditions": str(raw.get("Conditions", "")),
            "godot_note": str(raw.get("Note Godot", "")),
            "production_state": "canonical",
            "available_in_current_release": true
        }
        node["manual_combat_usable"] = manual_combat_usable(node)
        node["contextual_only"] = _contextual_only(node)
        result.append(node)
        previous = str(node.get("id", ""))
    return result

func ultimate_for(hero: Dictionary, branch: String) -> Dictionary:
    var tree := _tree(hero, branch)
    var ultimate: Dictionary = tree.get("ultimate", {}).duplicate(true)
    if ultimate.is_empty():
        return {}
    ultimate["branch"] = branch
    ultimate["branch_name"] = branch_label(hero, branch)
    ultimate["unlock_level"] = 16
    ultimate["available_charges"] = ultimate_charges(int(hero.get("level", 1)))
    ultimate["activation_limit_per_encounter"] = 1
    ultimate["execution_state"] = "metadata_ready_runtime_pending"
    return ultimate

func ultimate_charges(level: int) -> int:
    if level >= 48:
        return 3
    if level >= 32:
        return 2
    if level >= 16:
        return 1
    return 0

func manual_combat_usable(node: Dictionary) -> bool:
    if str(node.get("canonical_type", "")) not in MANUAL_TYPES:
        return false
    if _contextual_only(node):
        return false
    return true

func combat_profile(hero: Dictionary, node: Dictionary) -> Dictionary:
    if not is_watcher(hero) or node.is_empty():
        return {}
    var result := {
        "id": str(node.get("id", "")),
        "name": str(node.get("name", "Technique")),
        "description": str(node.get("description", "")),
        "branch": str(node.get("branch", "")),
        "canonical_type": str(node.get("canonical_type", "")),
        "canonical_function": str(node.get("canonical_function", "")),
        "canonical_positions": str(node.get("canonical_positions", "")),
        "canonical_target": str(node.get("canonical_target", "")),
        "canonical_impacts": str(node.get("canonical_impacts", "")),
        "canonical_tags": (node.get("canonical_tags", []) as Array).duplicate(),
        "canonical_conditions": str(node.get("canonical_conditions", "")),
        "base_accuracy_pct": int(node.get("base_accuracy_pct", 100)),
        "power_0_5": float(node.get("power_0_5", 0.0)),
        "manual_combat_usable": manual_combat_usable(node),
        "contextual_only": _contextual_only(node)
    }
    if not bool(result.get("manual_combat_usable", false)):
        result["effect"] = "passive_or_context"
        result["target"] = "none"
        return result

    var tags: Array = result.get("canonical_tags", [])
    var target_text := str(result.get("canonical_target", "")).to_lower()
    var power := float(result.get("power_0_5", 0.0))
    if target_text.contains("allié") and not target_text.contains("ennemi"):
        if tags.has("GARDE") or tags.has("INTERCEPTION") or tags.has("PROTECTION"):
            result["effect"] = "guard"
            result["target"] = "ally"
            result["guard_bonus"] = 10 + int(round(power * 4.0))
        else:
            result["effect"] = "support"
            result["target"] = "ally"
            if tags.has("STABILISATION") or tags.has("SAIGNEMENT") or tags.has("HÉMORRAGIE"):
                result["heal"] = maxi(1, int(round(5.0 + power * 5.0)))
            if tags.has("ESPOIR") or tags.has("PEUR"):
                result["hope_gain"] = maxi(1, int(round(2.0 + power * 3.0)))
                result["fear_reduction"] = maxi(1, int(round(2.0 + power * 2.0)))
        return result

    if target_text.contains("soi") and not target_text.contains("ennemi"):
        result["effect"] = "guard" if tags.has("GARDE") or tags.has("COUVERTURE") else "support"
        result["target"] = "self"
        result["guard_bonus"] = 8 + int(round(power * 3.0)) if result["effect"] == "guard" else 0
        return result

    result["effect"] = "attack"
    result["target"] = "enemy"
    result["power"] = maxf(0.55, 0.65 + power * 0.20)
    result["accuracy_bonus"] = int(result.get("base_accuracy_pct", 100)) - 85
    if tags.has("SAIGNEMENT") or tags.has("HÉMORRAGIE"):
        result["status"] = "bleed"
        result["status_chance"] = clampi(25 + int(round(power * 8.0)), 25, 75)
    elif tags.has("INTERRUPTION") or tags.has("INTERROMPU") or tags.has("AU_SOL"):
        result["status"] = "stun"
        result["status_chance"] = clampi(20 + int(round(power * 7.0)), 20, 70)
    elif tags.has("ARMURE_BRISÉE") or tags.has("FRACTURE"):
        result["status"] = "break"
        result["status_chance"] = clampi(20 + int(round(power * 7.0)), 20, 70)
    if tags.has("PRÉCISION") or tags.has("FAIBLESSE"):
        result["critical_bonus"] = maxi(1, int(round(power * 2.0)))
    return result

func catalog_summary() -> Dictionary:
    var skill_count := 0
    var ultimate_count := 0
    var tree_count := 0
    for watcher_id_value: Variant in catalogs.keys():
        var catalog: Dictionary = catalogs[watcher_id_value]
        for branch_value: Variant in catalog.get("tree_order", []):
            tree_count += 1
            var tree: Dictionary = catalog.get("trees", {}).get(str(branch_value), {})
            skill_count += (tree.get("skills", []) as Array).size()
            if not (tree.get("ultimate", {}) as Dictionary).is_empty():
                ultimate_count += 1
    return {
        "watchers": catalogs.size(),
        "trees": tree_count,
        "skills": skill_count,
        "ultimates": ultimate_count,
        "load_errors": load_errors.duplicate()
    }

func _catalog(hero: Dictionary) -> Dictionary:
    return (catalogs.get(str(hero.get("id", "")), {}) as Dictionary).duplicate(true)

func _tree(hero: Dictionary, branch: String) -> Dictionary:
    var catalog := _catalog(hero)
    return (catalog.get("trees", {}).get(branch, {}) as Dictionary).duplicate(true)

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
        if tag != "" and not result.has(tag):
            result.append(tag)
    return result

func _contextual_only(node: Dictionary) -> bool:
    var target := str(node.get("canonical_target", "")).to_lower()
    if target.contains("cadavre") or target.contains("information") or target.contains("position"):
        return true
    return false
