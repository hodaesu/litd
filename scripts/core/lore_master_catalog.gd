class_name LoreMasterCatalog
extends RefCounted

const HISTORY_PATH := "res://data/canonical_history.json"
const ANCIENT_MYSTERIES_PATH := "res://data/canon/ancient_periods_and_mysteries.json"
const LAST_WAR_PATH := "res://data/canon/last_war.json"
const LAST_WAR_BATTLES_PATH := "res://data/canon/last_war_battles.json"
const TRIAD_PATH := "res://data/canon/litd2_triad.json"
const NIGHT_OF_SARN_PATH := "res://data/canon/night_of_sarn.json"
const LITD2_EPILOGUE_PATH := "res://data/canon/litd2_epilogue.json"
const POST_SARN_PATH := "res://data/canon/post_sarn_concorde.json"
const VEILLEURS_EARLY_PATH := "res://data/canon/les_veilleurs_acts_1_2.json"
const VEILLEURS_LATE_PATH := "res://data/canon/les_veilleurs_acts_3_5.json"
const VEILLEURS_QUARTET_PATH := "res://data/canon/les_veilleurs_quartet.json"
const PROJECT_THRESHOLD_PATH := "res://data/canon/project_threshold_and_fall.json"
const POST_FALL_PATH := "res://data/canon/post_fall_litd1.json"
const COMPLETION_PATH := "res://data/canon/lore_completion_manifest.json"
const WORLD_GEOGRAPHY_PATH := "res://universe/lore/world_geography.json"
const LANGUAGE_ATLAS_PATH := "res://universe/lore/language_atlas.json"
const CULTURAL_ATLAS_PATH := "res://universe/lore/concorde_cultural_atlas.json"
const HISTORICAL_BESTIARY_PATH := "res://universe/lore/historical_bestiary.json"
const SEVEN_BIOGRAPHIES_PATH := "res://universe/lore/legendary_seven_biographies.json"
const ENCYCLOPEDIA_COMPLETION_PATH := "res://universe/lore/encyclopedia_completion_manifest.json"

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Lore canonique manquant: " + path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Impossible d'ouvrir le lore canonique: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_error("JSON de lore invalide: " + path)
    return {}

static func history() -> Dictionary:
    return _load_json(HISTORY_PATH)

static func ancient_periods_and_mysteries() -> Dictionary:
    return _load_json(ANCIENT_MYSTERIES_PATH)

static func last_war() -> Dictionary:
    return _load_json(LAST_WAR_PATH)

static func last_war_battles() -> Dictionary:
    return _load_json(LAST_WAR_BATTLES_PATH)

static func litd2_triad() -> Dictionary:
    return _load_json(TRIAD_PATH)

static func night_of_sarn() -> Dictionary:
    return _load_json(NIGHT_OF_SARN_PATH)

static func litd2_epilogue() -> Dictionary:
    return _load_json(LITD2_EPILOGUE_PATH)

static func post_sarn_concorde() -> Dictionary:
    return _load_json(POST_SARN_PATH)

static func veilleurs_acts_1_2() -> Dictionary:
    return _load_json(VEILLEURS_EARLY_PATH)

static func veilleurs_acts_3_5() -> Dictionary:
    return _load_json(VEILLEURS_LATE_PATH)

static func veilleurs_quartet() -> Dictionary:
    return _load_json(VEILLEURS_QUARTET_PATH)

static func project_threshold_and_fall() -> Dictionary:
    return _load_json(PROJECT_THRESHOLD_PATH)

static func post_fall_litd1() -> Dictionary:
    return _load_json(POST_FALL_PATH)

static func completion_manifest() -> Dictionary:
    return _load_json(COMPLETION_PATH)

static func world_geography() -> Dictionary:
    return _load_json(WORLD_GEOGRAPHY_PATH)

static func language_atlas() -> Dictionary:
    return _load_json(LANGUAGE_ATLAS_PATH)

static func cultural_atlas() -> Dictionary:
    return _load_json(CULTURAL_ATLAS_PATH)

static func historical_bestiary() -> Dictionary:
    return _load_json(HISTORICAL_BESTIARY_PATH)

static func legendary_seven_biographies() -> Dictionary:
    return _load_json(SEVEN_BIOGRAPHIES_PATH)

static func encyclopedia_completion_manifest() -> Dictionary:
    return _load_json(ENCYCLOPEDIA_COMPLETION_PATH)

static func master_chronology() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values: Variant = completion_manifest().get("master_chronology", [])
    if values is Array:
        for value: Variant in values:
            if value is Dictionary:
                result.append(value.duplicate(true))
    return result

static func core_lore_complete() -> bool:
    return bool(completion_manifest().get("core_canon_completion", false))

static func encyclopedia_v1_complete() -> bool:
    return bool(encyclopedia_completion_manifest().get("encyclopedia_v1_complete", false))

static func intentionally_bounded_unknowns() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = completion_manifest().get("intentionally_bounded_unknowns", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

static func resolved_legacy_pending_topics() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = completion_manifest().get("resolved_legacy_pending_topics", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

static func still_expandable_topics() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = completion_manifest().get("still_expandable_without_changing_core_canon", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

static func encyclopedia_intentionally_open() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = encyclopedia_completion_manifest().get("intentionally_open_after_v1", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

static func mystery(mystery_id: String) -> Dictionary:
    var values: Variant = ancient_periods_and_mysteries().get("mysteries", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == mystery_id:
                return item.duplicate(true)
    return {}

static func concorde_city(city_id: String) -> Dictionary:
    var geography: Dictionary = world_geography()
    var concorde: Variant = geography.get("concorde_geography", {})
    if concorde is not Dictionary:
        return {}
    var values: Variant = concorde.get("six_reference_cities", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == city_id:
                return item.duplicate(true)
    return {}

static func cultural_city(city_id: String) -> Dictionary:
    var values: Variant = cultural_atlas().get("cities", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == city_id:
                return item.duplicate(true)
    return {}

static func regional_language(language_id: String) -> Dictionary:
    var values: Variant = language_atlas().get("regional_languages", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == language_id:
                return item.duplicate(true)
    return {}

static func religious_tradition(tradition_id: String) -> Dictionary:
    var values: Variant = cultural_atlas().get("religious_traditions", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == tradition_id:
                return item.duplicate(true)
    return {}

static func martial_lineage(lineage_id: String) -> Dictionary:
    var values: Variant = cultural_atlas().get("martial_lineages", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == lineage_id:
                return item.duplicate(true)
    return {}

static func historical_bestiary_entry(entry_id: String) -> Dictionary:
    var values: Variant = historical_bestiary().get("entries", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == entry_id:
                return item.duplicate(true)
    return {}

static func legendary_biography(hero_id: String) -> Dictionary:
    var values: Variant = legendary_seven_biographies().get("heroes", [])
    if values is Array:
        for value: Variant in values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("id", "")) == hero_id:
                return item.duplicate(true)
    return {}

static func historical_battle_locations() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var geography: Dictionary = world_geography()
    var war: Variant = geography.get("last_war_geography", {})
    if war is not Dictionary:
        return result
    var values: Variant = war.get("battle_corridor", [])
    if values is Array:
        for value: Variant in values:
            if value is Dictionary:
                result.append(value.duplicate(true))
    return result

static func geography_open_cartography() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = world_geography().get("open_cartography", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

static func effective_pending_lore_topics() -> Array[String]:
    # The historical file can preserve old pending lists for traceability.
    # Effective pending topics are now only expandable encyclopedic detail,
    # not the resolved spine or intentionally bounded mysteries.
    return still_expandable_topics()
