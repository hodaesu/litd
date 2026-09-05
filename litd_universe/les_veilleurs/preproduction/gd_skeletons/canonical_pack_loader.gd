class_name LITDCanonicalPackLoader
extends RefCounted

## Preproduction skeleton: NOT compile-validated.
## Loads JSON exported from the canonical pre-PC pack without rewriting source values.

const REQUIRED_CURRENT_FILES := [
    "competences_180.json",
    "ultimes_12.json",
    "progression_1_50.json",
    "remanence_blessures.json",
    "traces_psychologiques.json",
    "bestiaire_confirme.json",
    "comp_bestiaire_585.json",
    "ult_bestiaire_39.json",
    "actes_ii_v_bestiaire.json",
    "comp_ii_v_720.json",
    "ult_ii_v_48.json",
    "compositions_64.json",
    "profondeur_spawn.json",
    "synergies_ennemis.json",
    "dangers_combat.json",
    "boss_5_phases.json",
    "tests_48.json"
]

var pack_root: String
var manifest: Dictionary = {}
var cache: Dictionary = {}

func _init(root_path: String = "") -> void:
    pack_root = root_path

func load_manifest() -> PackedStringArray:
    var errors := PackedStringArray()
    var result := _read_json_file(_join(pack_root, "MANIFEST.json"))
    if not result.ok:
        errors.append(result.error)
        return errors
    manifest = result.data
    return errors

func validate_required_files() -> PackedStringArray:
    var errors := PackedStringArray()
    for file_name in REQUIRED_CURRENT_FILES:
        var path := _join(_join(pack_root, "current"), file_name)
        if not FileAccess.file_exists(path):
            errors.append("Missing canonical file: %s" % path)
    return errors

func load_sheet(file_name: String) -> Dictionary:
    if cache.has(file_name):
        return cache[file_name]
    var path := _join(_join(pack_root, "current"), file_name)
    var result := _read_json_file(path)
    if result.ok:
        cache[file_name] = result.data
    return result

func get_records(file_name: String) -> Array:
    var result := load_sheet(file_name)
    if not result.get("ok", false):
        return []
    return result.data.get("records", [])

func make_runtime_id(entity_id: StringName, source_id: String) -> StringName:
    # Important: Comp_bestiaire_585 reuses 15 raw IDs across two Act-I entities.
    # Runtime identity must therefore include the entity scope.
    return StringName("%s::%s" % [String(entity_id), source_id])

func _read_json_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "error": "File not found: %s" % path, "data": {}}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "error": "Cannot open: %s" % path, "data": {}}
    var text := file.get_as_text()
    var parsed = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        return {"ok": false, "error": "Invalid JSON object: %s" % path, "data": {}}
    return {"ok": true, "error": "", "data": parsed}

func _join(left: String, right: String) -> String:
    if left.ends_with("/"):
        return left + right
    return left + "/" + right
