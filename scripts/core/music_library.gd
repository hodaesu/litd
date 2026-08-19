extends Node

const DATA_PATH := "res://data/music_library.json"

var data: Dictionary = {}

func _ready() -> void:
    data = _load_dictionary(DATA_PATH)

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func tracks() -> Array[Dictionary]:
    return _dictionary_array("tracks")

func track(track_id: String) -> Dictionary:
    for value in tracks():
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == track_id:
            return item.duplicate(true)
    return {}

func cues() -> Array[Dictionary]:
    return _dictionary_array("cue_families")

func cue(cue_id: String) -> Dictionary:
    for value in cues():
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == cue_id:
            return item.duplicate(true)
    return {}

func sources() -> Array[Dictionary]:
    return _dictionary_array("sources")

func source(source_id: String) -> Dictionary:
    for value in sources():
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == source_id:
            return item.duplicate(true)
    return {}

func license_policy() -> Dictionary:
    var value: Variant = data.get("license_policy", {})
    return value.duplicate(true) if value is Dictionary else {}

func adaptive_score_rules() -> Array[String]:
    return _string_array("adaptive_score_rules")

func ingestion_checklist() -> Array[String]:
    return _string_array("ingestion_checklist")

func excluded_sources() -> Array[Dictionary]:
    return _dictionary_array("excluded_sources")

func tracks_for_cue(cue_id: String, legal_tiers: Array[String] = ["green"]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in tracks():
        var item: Dictionary = value if value is Dictionary else {}
        var tier: String = str(item.get("legal_tier", "red"))
        if not legal_tiers.has(tier):
            continue
        var cue_values_variant: Variant = item.get("cues", [])
        var cue_values: Array = cue_values_variant if cue_values_variant is Array else []
        if cue_values.has(cue_id):
            result.append(item.duplicate(true))
    result.sort_custom(_sort_track_priority)
    return result

func shipping_candidates(include_amber: bool = false) -> Array[Dictionary]:
    var tiers: Array[String] = ["green"]
    if include_amber:
        tiers.append("amber")
    var result: Array[Dictionary] = []
    for value in tracks():
        var item: Dictionary = value if value is Dictionary else {}
        if tiers.has(str(item.get("legal_tier", "red"))):
            result.append(item.duplicate(true))
    return result

func content_id_candidates() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in tracks():
        var item: Dictionary = value if value is Dictionary else {}
        var content_id_value: Variant = item.get("content_id", false)
        if content_id_value is bool and bool(content_id_value):
            result.append(item.duplicate(true))
    return result

func source_is_excluded(source_id: String) -> bool:
    for value in excluded_sources():
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("source", "")) == source_id:
            return true
    return false

func credits_lines() -> Array[String]:
    var result: Array[String] = []
    for value in tracks():
        var item: Dictionary = value if value is Dictionary else {}
        if bool(item.get("attribution_required", false)):
            var line: String = "%s — %s — %s" % [str(item.get("title", "")), str(item.get("artist", "")), str(item.get("license_id", ""))]
            if not result.has(line):
                result.append(line)
    return result

func mix_priorities() -> Dictionary:
    var value: Variant = data.get("mix_priorities", {})
    return value.duplicate(true) if value is Dictionary else {}

func coverage() -> Dictionary:
    var green_count: int = 0
    var amber_count: int = 0
    var red_count: int = 0
    var content_id_count: int = 0
    var mapped_cues: Dictionary = {}
    for value in tracks():
        var item: Dictionary = value if value is Dictionary else {}
        var tier: String = str(item.get("legal_tier", "red"))
        match tier:
            "green":
                green_count += 1
            "amber":
                amber_count += 1
            _:
                red_count += 1
        var content_id_value: Variant = item.get("content_id", false)
        if content_id_value is bool and bool(content_id_value):
            content_id_count += 1
        var cue_values_variant: Variant = item.get("cues", [])
        var cue_values: Array = cue_values_variant if cue_values_variant is Array else []
        for cue_value in cue_values:
            mapped_cues[str(cue_value)] = true
    return {
        "tracks": tracks().size(),
        "cue_families": cues().size(),
        "mapped_cues": mapped_cues.size(),
        "sources": sources().size(),
        "green": green_count,
        "amber": amber_count,
        "red": red_count,
        "content_id": content_id_count,
        "adaptive_rules": adaptive_score_rules().size(),
        "ingestion_steps": ingestion_checklist().size(),
    }

func _dictionary_array(key: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values_variant: Variant = data.get(key, [])
    var values: Array = values_variant if values_variant is Array else []
    for value in values:
        var item: Dictionary = value if value is Dictionary else {}
        if not item.is_empty():
            result.append(item.duplicate(true))
    return result

func _string_array(key: String) -> Array[String]:
    var result: Array[String] = []
    var values_variant: Variant = data.get(key, [])
    var values: Array = values_variant if values_variant is Array else []
    for value in values:
        var text: String = str(value)
        if text != "":
            result.append(text)
    return result

func _sort_track_priority(a: Dictionary, b: Dictionary) -> bool:
    var a_energy: int = int(a.get("energy", 0))
    var b_energy: int = int(b.get("energy", 0))
    if a_energy != b_energy:
        return a_energy < b_energy
    return str(a.get("title", "")) < str(b.get("title", ""))
