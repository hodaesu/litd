extends Node

var classes: Array = []
var races: Array = []
var heroes: Array = []
var enemies: Array = []
var skills: Array = []
var equipment: Array = []
var equipment_rarities: Array = []
var equipment_affixes: Array = []
var capturable_creatures: Array = []
var quests: Array = []
var events: Array = []
var dialogues: Array = []
var ashlands_lore: Dictionary = {}
var canonical_history: Dictionary = {}
var last_war: Dictionary = {}
var litd2_triad: Dictionary = {}
var les_veilleurs_enemy_recruitment: Dictionary = {}

func _ready() -> void:
    reload_all()

func load_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_error("Fichier manquant: " + path)
        return []
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed == null:
        push_error("JSON invalide: " + path)
        return []
    return parsed

func reload_all() -> void:
    classes = load_json("res://data/classes.json")
    races = load_json("res://data/races.json")
    heroes = load_json("res://data/heroes.json")
    enemies = load_json("res://data/enemies.json")
    skills = load_json("res://data/skills.json")
    equipment = load_json("res://data/equipment.json")
    equipment_rarities = load_json("res://data/equipment_rarities.json")
    equipment_affixes = load_json("res://data/equipment_affixes.json")
    capturable_creatures = load_json("res://data/capturable_creatures.json")
    quests = load_json("res://data/quests.json")
    events = load_json("res://data/events.json")
    dialogues = load_json("res://data/dialogues.json")
    var lore_value = load_json("res://data/levels/ashlands_lore.json")
    ashlands_lore = lore_value if typeof(lore_value) == TYPE_DICTIONARY else {}
    var history_value = load_json("res://data/canonical_history.json")
    canonical_history = history_value if typeof(history_value) == TYPE_DICTIONARY else {}
    var last_war_value = load_json("res://data/canon/last_war.json")
    last_war = last_war_value if typeof(last_war_value) == TYPE_DICTIONARY else {}
    var triad_value = load_json("res://data/canon/litd2_triad.json")
    litd2_triad = triad_value if typeof(triad_value) == TYPE_DICTIONARY else {}
    var veilleurs_recruitment_value = load_json("res://data/canon/les_veilleurs_enemy_recruitment.json")
    les_veilleurs_enemy_recruitment = veilleurs_recruitment_value if typeof(veilleurs_recruitment_value) == TYPE_DICTIONARY else {}

func find_by_id(items: Array, id_value: Variant) -> Dictionary:
    for item in items:
        if item.get("id") == id_value:
            return item
    return {}

func ancient_civilization(civilization_id: String) -> Dictionary:
    var values: Variant = canonical_history.get("ancient_civilizations", [])
    var civilizations: Array = values if values is Array else []
    return find_by_id(civilizations, civilization_id).duplicate(true)

func history_event(event_id: String) -> Dictionary:
    var values: Variant = canonical_history.get("timeline", [])
    var timeline: Array = values if values is Array else []
    return find_by_id(timeline, event_id).duplicate(true)

func history_events_for_era(era_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values: Variant = canonical_history.get("timeline", [])
    var timeline: Array = values if values is Array else []
    for value: Variant in timeline:
        var event: Dictionary = value if value is Dictionary else {}
        if str(event.get("era", "")) == era_id:
            result.append(event.duplicate(true))
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var ay: Variant = a.get("year")
        var by: Variant = b.get("year")
        if ay == null:
            return false
        if by == null:
            return true
        return int(ay) < int(by)
    )
    return result

func pre_last_war_power(power_id: String) -> Dictionary:
    var values: Variant = canonical_history.get("pre_last_war_powers", [])
    var powers: Array = values if values is Array else []
    return find_by_id(powers, power_id).duplicate(true)

func last_war_phase(phase_id: String) -> Dictionary:
    var values: Variant = last_war.get("phases", [])
    var phases: Array = values if values is Array else []
    return find_by_id(phases, phase_id).duplicate(true)

func last_war_phases() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var values: Variant = last_war.get("phases", [])
    var phases: Array = values if values is Array else []
    for value: Variant in phases:
        var phase: Dictionary = value if value is Dictionary else {}
        result.append(phase.duplicate(true))
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("order", 0)) < int(b.get("order", 0))
    )
    return result

func last_war_trigger() -> Dictionary:
    var value: Variant = last_war.get("trigger", {})
    return value.duplicate(true) if value is Dictionary else {}

func last_war_gameplay_translation() -> Dictionary:
    var value: Variant = last_war.get("gameplay_translation", {})
    return value.duplicate(true) if value is Dictionary else {}

func litd2_character(character_id: String) -> Dictionary:
    var values: Variant = litd2_triad.get("characters", [])
    var characters: Array = values if values is Array else []
    return find_by_id(characters, character_id).duplicate(true)

func litd2_encounter(encounter_id: String) -> Dictionary:
    var values: Variant = litd2_triad.get("encounters", [])
    var encounters: Array = values if values is Array else []
    return find_by_id(encounters, encounter_id).duplicate(true)

func litd2_affinity_system() -> Dictionary:
    var value: Variant = litd2_triad.get("affinity_system", {})
    return value.duplicate(true) if value is Dictionary else {}

func litd2_sarn_entry_conditions() -> Dictionary:
    var value: Variant = litd2_triad.get("sarn_entry_conditions", {})
    return value.duplicate(true) if value is Dictionary else {}

func les_veilleurs_recruitment_vector(vector_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_enemy_recruitment.get("recruitment_vectors", [])
    var vectors: Array = values if values is Array else []
    return find_by_id(vectors, vector_id).duplicate(true)

func les_veilleurs_recruitment_mobile_scope() -> Dictionary:
    var value: Variant = les_veilleurs_enemy_recruitment.get("mobile_scope", {})
    return value.duplicate(true) if value is Dictionary else {}

func les_veilleurs_recruitment_progression() -> Dictionary:
    var value: Variant = les_veilleurs_enemy_recruitment.get("progression", {})
    return value.duplicate(true) if value is Dictionary else {}

func les_veilleurs_recruitment_ui_flow() -> Dictionary:
    var value: Variant = les_veilleurs_enemy_recruitment.get("ui_flow", {})
    return value.duplicate(true) if value is Dictionary else {}

func les_veilleurs_recruitment_content_contract() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = les_veilleurs_enemy_recruitment.get("content_contract_per_recruitable_family", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

func knowledge_remanence_stages() -> Array[String]:
    var result: Array[String] = []
    var remanence: Variant = canonical_history.get("knowledge_remanence", {})
    if remanence is not Dictionary:
        return result
    var values: Variant = remanence.get("stages", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

func canon_rules() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = canonical_history.get("canon_rules", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

func pending_canon_topics() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = canonical_history.get("pending_not_implemented_as_canon", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    var war_values: Variant = last_war.get("pending_after_this_file", [])
    if war_values is Array:
        for value: Variant in war_values:
            if not result.has(str(value)):
                result.append(str(value))
    var triad_values: Variant = litd2_triad.get("pending_after_this_file", [])
    if triad_values is Array:
        for value: Variant in triad_values:
            if not result.has(str(value)):
                result.append(str(value))
    return result
