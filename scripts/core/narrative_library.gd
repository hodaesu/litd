extends Node

const DATA_PATH := "res://data/narrative_library.json"
const FOLKLORE_PATH := "res://data/global_folklore_atlas.json"
const DIALOGUE_PATH := "res://data/dialogue_library.json"

var data: Dictionary = {}
var folklore_data: Dictionary = {}
var dialogue_data: Dictionary = {}

func _ready() -> void:
    data = _load_dictionary(DATA_PATH)
    folklore_data = _load_dictionary(FOLKLORE_PATH)
    dialogue_data = _load_dictionary(DIALOGUE_PATH)

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func quality_axes() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in data.get("quality_axes", []):
        var item: Dictionary = value if value is Dictionary else {}
        result.append(item.duplicate(true))
    return result

func device(device_id: String) -> Dictionary:
    for value in data.get("narrative_devices", []):
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == device_id:
            return item.duplicate(true)
    return {}

func quest_narrative(quest: Dictionary) -> Dictionary:
    var value: Variant = quest.get("narrative", {})
    return value.duplicate(true) if value is Dictionary else {}

func quest_state_text(quest: Dictionary, state: String) -> String:
    var narrative: Dictionary = quest_narrative(quest)
    if narrative.is_empty():
        return str(quest.get("summary", ""))
    match state:
        "offered":
            return str(narrative.get("hook", quest.get("summary", "")))
        "active":
            return str(narrative.get("active", narrative.get("dramatic_question", quest.get("summary", ""))))
        "completed":
            return str(narrative.get("resolution", narrative.get("reframe", quest.get("summary", ""))))
        _:
            return str(quest.get("summary", ""))

func quest_reframe(quest: Dictionary) -> String:
    return str(quest_narrative(quest).get("reframe", ""))

func quest_theme(quest: Dictionary) -> String:
    return str(quest_narrative(quest).get("theme", ""))

func quest_dramatic_question(quest: Dictionary) -> String:
    return str(quest_narrative(quest).get("dramatic_question", ""))

func quest_devices(quest: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var narrative: Dictionary = quest_narrative(quest)
    var values: Variant = narrative.get("devices", [])
    var devices: Array = values if values is Array else []
    for value in devices:
        var device_id := str(value)
        if device_id != "" and not result.has(device_id):
            result.append(device_id)
    return result

func originality_rules() -> Dictionary:
    var value: Variant = data.get("originality_protocol", {})
    return value.duplicate(true) if value is Dictionary else {}

func folklore_regions() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in folklore_data.get("regions", []):
        var item: Dictionary = value if value is Dictionary else {}
        if not item.is_empty():
            result.append(item.duplicate(true))
    return result

func folklore_region(region_id: String) -> Dictionary:
    for region in folklore_regions():
        if str(region.get("id", "")) == region_id:
            return region
    return {}

func folklore_reference_clusters() -> Array[String]:
    var result: Array[String] = []
    for region in folklore_regions():
        var values: Variant = region.get("reference_clusters", [])
        var clusters: Array = values if values is Array else []
        for value in clusters:
            var text := str(value)
            if text != "" and not result.has(text):
                result.append(text)
    return result

func folklore_access_level(region_id: String) -> String:
    return str(folklore_region(region_id).get("access", ""))

func folklore_cultural_protocol() -> Dictionary:
    var value: Variant = folklore_data.get("cultural_protocol", {})
    return value.duplicate(true) if value is Dictionary else {}

func folklore_design_rules() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = folklore_data.get("design_extraction_rules", [])
    var rules: Array = values if values is Array else []
    for value in rules:
        var text := str(value)
        if text != "":
            result.append(text)
    return result

func folklore_coverage() -> Dictionary:
    return {
        "regions": folklore_regions().size(),
        "reference_clusters": folklore_reference_clusters().size(),
        "narrative_forms": folklore_data.get("narrative_forms", []).size(),
        "motif_families": folklore_data.get("motif_families", []).size(),
    }

func dialogue_quality_axes() -> Array[Dictionary]:
    return _dialogue_dictionary_array("quality_axes")

func dialogue_techniques() -> Array[Dictionary]:
    return _dialogue_dictionary_array("dialogue_techniques")

func dialogue_technique(technique_id: String) -> Dictionary:
    for item in dialogue_techniques():
        if str(item.get("id", "")) == technique_id:
            return item
    return {}

func staging_techniques() -> Array[Dictionary]:
    return _dialogue_dictionary_array("staging_techniques")

func staging_technique(technique_id: String) -> Dictionary:
    for item in staging_techniques():
        if str(item.get("id", "")) == technique_id:
            return item
    return {}

func dialogue_scene_patterns() -> Array[Dictionary]:
    return _dialogue_dictionary_array("scene_patterns")

func dialogue_public_domain_corpus() -> Array[Dictionary]:
    return _dialogue_dictionary_array("public_domain_corpus")

func dialogue_modern_reference_policy() -> Dictionary:
    var value: Variant = dialogue_data.get("copyrighted_or_modern_reference_only", {})
    return value.duplicate(true) if value is Dictionary else {}

func dialogue_originality_protocol() -> Dictionary:
    var value: Variant = dialogue_data.get("rights_and_originality_protocol", {})
    return value.duplicate(true) if value is Dictionary else {}

func dialogue_voice_fields() -> Array[String]:
    return _dialogue_string_array("voice_design_fields")

func dialogue_production_checklist() -> Array[String]:
    return _dialogue_string_array("production_checklist")

func dialogue_anti_patterns() -> Array[String]:
    return _dialogue_string_array("anti_patterns")

func dialogue_coverage() -> Dictionary:
    var public_references: int = 0
    for family in dialogue_public_domain_corpus():
        var refs: Variant = family.get("references", [])
        if refs is Array:
            public_references += refs.size()
    var modern: Dictionary = dialogue_modern_reference_policy()
    var modern_values: Variant = modern.get("references", [])
    var modern_count: int = modern_values.size() if modern_values is Array else 0
    return {
        "quality_axes": dialogue_quality_axes().size(),
        "dialogue_techniques": dialogue_techniques().size(),
        "staging_techniques": staging_techniques().size(),
        "scene_patterns": dialogue_scene_patterns().size(),
        "public_domain_families": dialogue_public_domain_corpus().size(),
        "public_domain_references": public_references,
        "modern_reference_only": modern_count,
    }

func _dialogue_dictionary_array(key: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values: Variant = dialogue_data.get(key, [])
    var items: Array = values if values is Array else []
    for value in items:
        var item: Dictionary = value if value is Dictionary else {}
        if not item.is_empty():
            result.append(item.duplicate(true))
    return result

func _dialogue_string_array(key: String) -> Array[String]:
    var result: Array[String] = []
    var values: Variant = dialogue_data.get(key, [])
    var items: Array = values if values is Array else []
    for value in items:
        var text := str(value)
        if text != "":
            result.append(text)
    return result
