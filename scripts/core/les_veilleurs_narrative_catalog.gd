class_name LesVeilleursNarrativeCatalog
extends RefCounted

const EARLY_PATH := "res://data/canon/les_veilleurs_acts_1_2.json"
const LATE_PATH := "res://data/canon/les_veilleurs_acts_3_5.json"
const QUARTET_PATH := "res://data/canon/les_veilleurs_quartet.json"

static func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Catalogue narratif Veilleurs manquant: " + path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Impossible d'ouvrir le catalogue narratif Veilleurs: " + path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_error("JSON narratif Veilleurs invalide: " + path)
    return {}

static func early_catalog() -> Dictionary:
    return _load_json(EARLY_PATH)

static func late_catalog() -> Dictionary:
    return _load_json(LATE_PATH)

static func quartet_catalog() -> Dictionary:
    return _load_json(QUARTET_PATH)

static func _find_by_id(values: Variant, id_value: String) -> Dictionary:
    if values is not Array:
        return {}
    for value: Variant in values:
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == id_value:
            return item.duplicate(true)
    return {}

static func act(act_id: String) -> Dictionary:
    var source := early_catalog() if act_id in ["I", "II"] else late_catalog()
    return _find_by_id(source.get("acts", []), act_id)

static func all_acts() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for source: Dictionary in [early_catalog(), late_catalog()]:
        var values: Variant = source.get("acts", [])
        if values is Array:
            for value: Variant in values:
                if value is Dictionary:
                    result.append(value.duplicate(true))
    return result

static func zone(zone_id: String) -> Dictionary:
    for act_value: Dictionary in all_acts():
        var zones: Variant = act_value.get("zones", [])
        var found := _find_by_id(zones, zone_id)
        if not found.is_empty():
            return found
    return {}

static func transition(transition_id: String) -> Dictionary:
    return _find_by_id(late_catalog().get("transitions", []), transition_id)

static func noncombat_encounter(encounter_id: String) -> Dictionary:
    return _find_by_id(late_catalog().get("noncombat_encounters", []), encounter_id)

static func recruit_event(chain_or_family_id: String) -> Dictionary:
    var early := _find_by_id(early_catalog().get("recruit_event_chains", []), chain_or_family_id)
    if not early.is_empty():
        return early
    var late_values: Variant = late_catalog().get("recruit_event_extensions", [])
    if late_values is Array:
        for value: Variant in late_values:
            var item: Dictionary = value if value is Dictionary else {}
            if str(item.get("family_id", "")) == chain_or_family_id:
                return item.duplicate(true)
    return {}

static func remanence_bundle(bundle_id: String) -> Dictionary:
    for source: Dictionary in [early_catalog(), late_catalog()]:
        var found := _find_by_id(source.get("remanence_bundles", []), bundle_id)
        if not found.is_empty():
            return found
    return {}

static func hub_stages() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var early_values: Variant = early_catalog().get("hub_progression", [])
    var late_values: Variant = late_catalog().get("hub_progression_continuation", [])
    for values: Variant in [early_values, late_values]:
        if values is Array:
            for value: Variant in values:
                if value is Dictionary:
                    result.append(value.duplicate(true))
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("order", 0)) < int(b.get("order", 0))
    )
    return result

static func hub_stage(stage_id: String) -> Dictionary:
    for stage: Dictionary in hub_stages():
        if str(stage.get("id", "")) == stage_id:
            return stage.duplicate(true)
    return {}

static func quartet() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values: Variant = quartet_catalog().get("characters", [])
    if values is Array:
        for value: Variant in values:
            if value is Dictionary:
                result.append(value.duplicate(true))
    return result

static func character(character_id_or_name: String) -> Dictionary:
    for value: Dictionary in quartet():
        if str(value.get("id", "")) == character_id_or_name or str(value.get("name", "")) == character_id_or_name:
            return value.duplicate(true)
    return {}

static func party_contract() -> Dictionary:
    var value: Variant = quartet_catalog().get("party_contract", {})
    return value.duplicate(true) if value is Dictionary else {}

static func finale() -> Dictionary:
    var value: Variant = late_catalog().get("finale", {})
    return value.duplicate(true) if value is Dictionary else {}

static func canon_guardrails() -> Array[String]:
    var result: Array[String] = []
    for source: Dictionary in [late_catalog(), quartet_catalog()]:
        var keys: Array[String] = ["canon_guardrails"] if source == late_catalog() else ["rules"]
        for key: String in keys:
            var values: Variant = source.get(key, [])
            if values is Array:
                for value: Variant in values:
                    var text := str(value)
                    if not result.has(text):
                        result.append(text)
    return result

static func runtime_pending() -> Array[String]:
    var result: Array[String] = []
    for source: Dictionary in [early_catalog(), late_catalog(), quartet_catalog()]:
        var values: Variant = source.get("runtime_pending", [])
        if values is Array:
            for value: Variant in values:
                var text := str(value)
                if not result.has(text):
                    result.append(text)
    return result
