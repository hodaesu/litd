extends Node

const DATA_PATH := "res://data/sfx_library.json"

var data: Dictionary = {}

func _ready() -> void:
    data = _load_dictionary(DATA_PATH)

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func license_policy() -> Dictionary:
    var value: Variant = data.get("license_policy", {})
    return value.duplicate(true) if value is Dictionary else {}

func sources() -> Array[Dictionary]:
    return _dictionary_array("source_pools")

func source(source_id: String) -> Dictionary:
    for value in sources():
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == source_id:
            return item.duplicate(true)
    return {}

func candidate_packs() -> Array[Dictionary]:
    return _dictionary_array("candidate_packs")

func candidate_pack(pack_id: String) -> Dictionary:
    for value in candidate_packs():
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == pack_id:
            return item.duplicate(true)
    return {}

func shipping_candidate_packs(include_amber: bool = false) -> Array[Dictionary]:
    var accepted: Array[String] = ["green"]
    if include_amber:
        accepted.append("amber")
    var result: Array[Dictionary] = []
    for value in candidate_packs():
        var item: Dictionary = value if value is Dictionary else {}
        if accepted.has(str(item.get("tier", "red"))):
            result.append(item.duplicate(true))
    return result

func cue_domains() -> Dictionary:
    var value: Variant = data.get("cue_domains", {})
    return value.duplicate(true) if value is Dictionary else {}

func domains() -> Array[String]:
    var result: Array[String] = []
    for key: Variant in cue_domains().keys():
        result.append(str(key))
    result.sort()
    return result

func cue_ids() -> Array[String]:
    var result: Array[String] = []
    var grouped: Dictionary = cue_domains()
    for key: Variant in grouped.keys():
        var values_variant: Variant = grouped.get(key, [])
        var values: Array = values_variant if values_variant is Array else []
        for value: Variant in values:
            var cue_id: String = str(value)
            if cue_id != "" and not result.has(cue_id):
                result.append(cue_id)
    return result

func cues_for_domain(domain_id: String) -> Array[String]:
    var grouped: Dictionary = cue_domains()
    var values_variant: Variant = grouped.get(domain_id, [])
    var values: Array = values_variant if values_variant is Array else []
    var result: Array[String] = []
    for value: Variant in values:
        result.append(str(value))
    return result

func has_cue(cue_id: String) -> bool:
    return cue_ids().has(cue_id)

func cue_domain(cue_id: String) -> String:
    var grouped: Dictionary = cue_domains()
    for key: Variant in grouped.keys():
        var domain_id: String = str(key)
        if cues_for_domain(domain_id).has(cue_id):
            return domain_id
    return ""

func cue_metadata(cue_id: String) -> Dictionary:
    var all_metadata_variant: Variant = data.get("cue_metadata", {})
    var all_metadata: Dictionary = all_metadata_variant if all_metadata_variant is Dictionary else {}
    var value: Variant = all_metadata.get(cue_id, {})
    var result: Dictionary = value.duplicate(true) if value is Dictionary else {}
    var domain_id: String = cue_domain(cue_id)
    if domain_id == "":
        return result
    if not result.has("spatial"):
        result["spatial"] = "2d" if domain_id in ["ui", "psychology", "narrative", "boss"] else "3d"
    if not result.has("variants_min"):
        result["variants_min"] = 4 if domain_id in ["exploration", "combat", "creature", "ambience", "environment"] else 2
    result["domain"] = domain_id
    return result

func packs_for_cue(cue_id: String, include_amber: bool = false) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in shipping_candidate_packs(include_amber):
        var item: Dictionary = value if value is Dictionary else {}
        var covers_variant: Variant = item.get("covers", [])
        var covers: Array = covers_variant if covers_variant is Array else []
        if covers.has(cue_id) or covers.has(cue_domain(cue_id)):
            result.append(item.duplicate(true))
    return result

func layering_presets() -> Array[Dictionary]:
    return _dictionary_array("layering_presets")

func implementation_rules() -> Array[String]:
    return _string_array("implementation_rules")

func ingestion_checklist() -> Array[String]:
    return _string_array("ingestion_checklist")

func excluded_license_classes() -> Array[Dictionary]:
    return _dictionary_array("excluded_license_classes")

func mix_priorities() -> Dictionary:
    var value: Variant = data.get("mix_priorities", {})
    return value.duplicate(true) if value is Dictionary else {}

func naming_convention() -> Dictionary:
    var value: Variant = data.get("naming_convention", {})
    return value.duplicate(true) if value is Dictionary else {}

func attribution_lines() -> Array[String]:
    var result: Array[String] = []
    for value in candidate_packs():
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("tier", "")) != "amber":
            continue
        var line: String = "%s — %s — %s" % [str(item.get("name", "")), str(item.get("creator", "")), str(item.get("license", ""))]
        if line.strip_edges() != "" and not result.has(line):
            result.append(line)
    return result

func coverage() -> Dictionary:
    var green_count: int = 0
    var amber_count: int = 0
    var red_count: int = 0
    for value in candidate_packs():
        var item: Dictionary = value if value is Dictionary else {}
        match str(item.get("tier", "red")):
            "green":
                green_count += 1
            "amber":
                amber_count += 1
            _:
                red_count += 1
    return {
        "cue_families": cue_ids().size(),
        "domains": domains().size(),
        "sources": sources().size(),
        "packs": candidate_packs().size(),
        "green": green_count,
        "amber": amber_count,
        "red": red_count,
        "layering_presets": layering_presets().size(),
        "implementation_rules": implementation_rules().size(),
        "ingestion_steps": ingestion_checklist().size(),
    }

func _dictionary_array(key: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values_variant: Variant = data.get(key, [])
    var values: Array = values_variant if values_variant is Array else []
    for value: Variant in values:
        var item: Dictionary = value if value is Dictionary else {}
        if not item.is_empty():
            result.append(item.duplicate(true))
    return result

func _string_array(key: String) -> Array[String]:
    var result: Array[String] = []
    var values_variant: Variant = data.get(key, [])
    var values: Array = values_variant if values_variant is Array else []
    for value: Variant in values:
        var text: String = str(value)
        if text != "":
            result.append(text)
    return result
