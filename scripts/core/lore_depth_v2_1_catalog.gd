class_name LoreDepthV21Catalog
extends RefCounted

const DISTRICT_PATH := "res://universe/lore/city_district_history_v2.json"
const FOREIGN_PATH := "res://universe/lore/late_foreign_microhistory_v2.json"
const DAILY_PATH := "res://universe/lore/regional_daily_life_v2_1.json"
const MANIFEST_PATH := "res://universe/lore/encyclopedia_depth_v2_1_manifest.json"

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Lore V2.1 manquant: " + path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Impossible d'ouvrir le lore V2.1: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_error("JSON V2.1 invalide: " + path)
    return {}

static func district_data() -> Dictionary:
    return _load_json(DISTRICT_PATH)

static func foreign_data() -> Dictionary:
    return _load_json(FOREIGN_PATH)

static func daily_life_data() -> Dictionary:
    return _load_json(DAILY_PATH)

static func manifest() -> Dictionary:
    return _load_json(MANIFEST_PATH)

static func complete() -> bool:
    return bool(manifest().get("depth_v2_1_complete", false))

static func city_districts(city_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var cities: Variant = district_data().get("cities", [])
    if cities is Array:
        for city_value: Variant in cities:
            var city: Dictionary = city_value if city_value is Dictionary else {}
            if str(city.get("id", "")) != city_id:
                continue
            var districts: Variant = city.get("districts", [])
            if districts is Array:
                for district_value: Variant in districts:
                    if district_value is Dictionary:
                        result.append(district_value.duplicate(true))
            break
    return result

static func district(district_id: String) -> Dictionary:
    var cities: Variant = district_data().get("cities", [])
    if cities is Array:
        for city_value: Variant in cities:
            var city: Dictionary = city_value if city_value is Dictionary else {}
            var districts: Variant = city.get("districts", [])
            if districts is Array:
                for district_value: Variant in districts:
                    var item: Dictionary = district_value if district_value is Dictionary else {}
                    if str(item.get("id", "")) == district_id:
                        return item.duplicate(true)
    return {}

static func late_polity(polity_id: String) -> Dictionary:
    var values: Variant = foreign_data().get("polities", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == polity_id:
                return item.duplicate(true)
    return {}

static func late_foreign_city(city_id: String) -> Dictionary:
    var values: Variant = foreign_data().get("polities", [])
    if values is Array:
        for value: Variant in values:
            var polity: Dictionary = value if value is Dictionary else {}
            var cities: Variant = polity.get("cities", [])
            if cities is Array:
                for city_value: Variant in cities:
                    var city: Dictionary = city_value if city_value is Dictionary else {}
                    if str(city.get("id", "")) == city_id:
                        return city.duplicate(true)
    return {}

static func satellite_settlement(settlement_id: String) -> Dictionary:
    return _find_daily("satellite_settlements", settlement_id)

static func trade(trade_id: String) -> Dictionary:
    return _find_daily("trades", trade_id)

static func everyday_object(object_id: String) -> Dictionary:
    return _find_daily("everyday_objects", object_id)

static func quest_bridge(bridge_id: String) -> Dictionary:
    return _find_daily("quest_bridges", bridge_id)

static func _find_daily(key: String, item_id: String) -> Dictionary:
    var values: Variant = daily_life_data().get(key, [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == item_id:
                return item.duplicate(true)
    return {}

static func continuity_guardrails() -> Dictionary:
    var rules: Variant = foreign_data().get("core_rules", {})
    return rules.duplicate(true) if rules is Dictionary else {}

static func intentionally_open() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = manifest().get("still_open", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result
