extends RefCounted
class_name AshlandsAssetRegistry

const HANDOFF_PATH := "res://data/levels/ashlands_blender_handoff.json"
const IMPORT_REGISTRY_PATH := "res://data/blender/godot_import_registry.json"

static var _data: Dictionary = {}
static var _imports: Dictionary = {}

static func get_handoff() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(HANDOFF_PATH):
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF_PATH))
        if typeof(parsed) == TYPE_DICTIONARY:
            _data = parsed
    return _data

static func get_zone_kit(zone_id: String) -> String:
    return str(get_handoff().get("zone_kits", {}).get(zone_id, "common_ruins"))

static func get_asset_folder(slot: String) -> String:
    return str(get_handoff().get("asset_slots", {}).get(slot, {}).get("folder", ""))

static func expected_glb_path(zone_id: String, slot: String, asset_name: String, variant := "a") -> String:
    var folder := get_asset_folder(slot)
    if folder == "":
        return ""
    var kit := get_zone_kit(zone_id)
    return "%s/SM_%s_%s_%s.glb" % [folder, kit, asset_name, variant]

static func load_if_available(zone_id: String, slot: String, asset_name: String, variant := "a") -> PackedScene:
    var path := expected_glb_path(zone_id, slot, asset_name, variant)
    if path != "" and ResourceLoader.exists(path):
        return ResourceLoader.load(path) as PackedScene
    return null

static func get_import_registry() -> Dictionary:
    if _imports.is_empty() and FileAccess.file_exists(IMPORT_REGISTRY_PATH):
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(IMPORT_REGISTRY_PATH))
        if typeof(parsed) == TYPE_DICTIONARY:
            _imports = parsed
    return _imports

static func get_job_import_path(job_id: String) -> String:
    for asset in get_import_registry().get("assets", []):
        if str(asset.get("job_id", "")) == job_id:
            return str(asset.get("godot_path", ""))
    return ""

static func load_job_if_available(job_id: String) -> PackedScene:
    var path := get_job_import_path(job_id)
    if path != "" and ResourceLoader.exists(path):
        return ResourceLoader.load(path) as PackedScene
    return null
