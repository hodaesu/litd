class_name LegendarySevenFateCatalog
extends RefCounted

const FATES_PATH := "res://universe/lore/legendary_seven_post_campaign_fates.json"
const MANIFEST_PATH := "res://universe/lore/legendary_seven_post_campaign_manifest.json"

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Destin des Sept manquant: " + path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Impossible d'ouvrir le destin des Sept: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_error("JSON du destin des Sept invalide: " + path)
    return {}

static func data() -> Dictionary:
    return _load_json(FATES_PATH)

static func manifest() -> Dictionary:
    return _load_json(MANIFEST_PATH)

static func complete() -> bool:
    return bool(manifest().get("complete", false))

static func shared_fate() -> Dictionary:
    var value: Variant = data().get("shared_fate", {})
    return value.duplicate(true) if value is Dictionary else {}

static func hero_fate(hero_id: String) -> Dictionary:
    var values: Variant = data().get("heroes", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == hero_id:
                return item.duplicate(true)
    return {}

static func formation_order() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = data().get("formation_order", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

static func later_memory() -> Dictionary:
    var value: Variant = data().get("later_memory", {})
    return value.duplicate(true) if value is Dictionary else {}

static func still_open() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = data().get("still_open", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

static func precedence() -> Dictionary:
    var value: Variant = manifest().get("source_precedence", {})
    return value.duplicate(true) if value is Dictionary else {}
