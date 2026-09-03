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
var les_veilleurs_bestiary_families: Dictionary = {}
var les_veilleurs_bestiary_missing_roles: Dictionary = {}
var les_veilleurs_bestiary_rank_ladders: Dictionary = {}
var les_veilleurs_combat_kits: Dictionary = {}
var les_veilleurs_encounter_compositions: Dictionary = {}
var les_veilleurs_acts_1_2: Dictionary = {}

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
    var veilleurs_bestiary_value = load_json("res://data/canon/les_veilleurs_bestiary_families.json")
    les_veilleurs_bestiary_families = veilleurs_bestiary_value if typeof(veilleurs_bestiary_value) == TYPE_DICTIONARY else {}
    var veilleurs_missing_roles_value = load_json("res://data/canon/les_veilleurs_bestiary_missing_roles.json")
    les_veilleurs_bestiary_missing_roles = veilleurs_missing_roles_value if typeof(veilleurs_missing_roles_value) == TYPE_DICTIONARY else {}
    var veilleurs_rank_ladders_value = load_json("res://data/canon/les_veilleurs_bestiary_rank_ladders.json")
    les_veilleurs_bestiary_rank_ladders = veilleurs_rank_ladders_value if typeof(veilleurs_rank_ladders_value) == TYPE_DICTIONARY else {}
    var veilleurs_combat_kits_value = load_json("res://data/canon/les_veilleurs_combat_kits.json")
    les_veilleurs_combat_kits = veilleurs_combat_kits_value if typeof(veilleurs_combat_kits_value) == TYPE_DICTIONARY else {}
    var veilleurs_encounters_value = load_json("res://data/canon/les_veilleurs_encounter_compositions.json")
    les_veilleurs_encounter_compositions = veilleurs_encounters_value if typeof(veilleurs_encounters_value) == TYPE_DICTIONARY else {}
    var veilleurs_acts_value = load_json("res://data/canon/les_veilleurs_acts_1_2.json")
    les_veilleurs_acts_1_2 = veilleurs_acts_value if typeof(veilleurs_acts_value) == TYPE_DICTIONARY else {}

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

func les_veilleurs_normalize_recruitment_vector_id(vector_id: String) -> String:
    match vector_id:
        "common_interest":
            return "interest"
        "constrained_bond":
            return "binding"
        _:
            return vector_id

func les_veilleurs_recruitment_vector(vector_id: String) -> Dictionary:
    var normalized_id := les_veilleurs_normalize_recruitment_vector_id(vector_id)
    var values: Variant = les_veilleurs_enemy_recruitment.get("recruitment_vectors", [])
    var vectors: Array = values if values is Array else []
    return find_by_id(vectors, normalized_id).duplicate(true)

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

func _les_veilleurs_normalized_family(family: Dictionary) -> Dictionary:
    var result := family.duplicate(true)
    var vectors: Variant = result.get("recruitment_vectors", [])
    if vectors is Array:
        var normalized: Array[String] = []
        for vector: Variant in vectors:
            normalized.append(les_veilleurs_normalize_recruitment_vector_id(str(vector)))
        result["recruitment_vectors"] = normalized
    return result

func _append_les_veilleurs_family_source(result: Array[Dictionary], source: Dictionary) -> void:
    var values: Variant = source.get("families", [])
    if values is Array:
        for value: Variant in values:
            var family: Dictionary = value if value is Dictionary else {}
            result.append(_les_veilleurs_normalized_family(family))

func les_veilleurs_bestiary_family(family_id: String) -> Dictionary:
    for family: Dictionary in les_veilleurs_bestiary_all_families():
        if str(family.get("id", "")) == family_id:
            return family.duplicate(true)
    return {}

func les_veilleurs_bestiary_all_families() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    _append_les_veilleurs_family_source(result, les_veilleurs_bestiary_families)
    _append_les_veilleurs_family_source(result, les_veilleurs_bestiary_missing_roles)
    return result

func les_veilleurs_bestiary_recruitable_families() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for family: Dictionary in les_veilleurs_bestiary_all_families():
        if bool(family.get("recruitable", false)):
            result.append(family)
    return result

func les_veilleurs_bestiary_roles() -> Array[String]:
    var result: Array[String] = []
    for family: Dictionary in les_veilleurs_bestiary_all_families():
        var role := str(family.get("combat_role", ""))
        if not role.is_empty() and not result.has(role):
            result.append(role)
    return result

func les_veilleurs_bestiary_rank_rule(rank_id: String) -> Dictionary:
    var rules: Variant = les_veilleurs_bestiary_rank_ladders.get("rank_rules", {})
    if rules is Dictionary:
        var value: Variant = rules.get(rank_id, {})
        return value.duplicate(true) if value is Dictionary else {}
    return {}

func les_veilleurs_bestiary_rank_ladder(family_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_bestiary_rank_ladders.get("families", [])
    if values is Array:
        for value: Variant in values:
            var ladder: Dictionary = value if value is Dictionary else {}
            if str(ladder.get("family_id", "")) == family_id:
                return ladder.duplicate(true)
    return {}

func les_veilleurs_bestiary_rank(family_id: String, rank_id: String) -> Dictionary:
    var ladder := les_veilleurs_bestiary_rank_ladder(family_id)
    var values: Variant = ladder.get("ranks", [])
    if values is Array:
        for value: Variant in values:
            var rank: Dictionary = value if value is Dictionary else {}
            if str(rank.get("rank", "")) == rank_id:
                return rank.duplicate(true)
    return {}

func les_veilleurs_bestiary_rank_order() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = les_veilleurs_bestiary_rank_ladders.get("rank_order", [])
    if values is Array:
        for value: Variant in values:
            result.append(str(value))
    return result

func les_veilleurs_combat_variant(variant_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_combat_kits.get("variants", [])
    var variants: Array = values if values is Array else []
    return find_by_id(variants, variant_id).duplicate(true)

func les_veilleurs_combat_family_profile(family_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_combat_kits.get("family_profiles", {})
    if values is Dictionary:
        var value: Variant = values.get(family_id, {})
        return value.duplicate(true) if value is Dictionary else {}
    return {}

func les_veilleurs_combat_rank_profile(rank_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_combat_kits.get("rank_profiles", {})
    if values is Dictionary:
        var value: Variant = values.get(rank_id, {})
        return value.duplicate(true) if value is Dictionary else {}
    return {}

func les_veilleurs_combat_kit(variant_id: String) -> Dictionary:
    var variant := les_veilleurs_combat_variant(variant_id)
    if variant.is_empty():
        return {}
    var result := {}
    result.merge(les_veilleurs_combat_family_profile(str(variant.get("family", ""))), true)
    result.merge(les_veilleurs_combat_rank_profile(str(variant.get("rank", ""))), true)
    result.merge(variant, true)
    return result

func les_veilleurs_encounter(encounter_id: String) -> Dictionary:
    var acts: Variant = les_veilleurs_encounter_compositions.get("acts", [])
    if acts is Array:
        for act_value: Variant in acts:
            var act: Dictionary = act_value if act_value is Dictionary else {}
            var encounters: Variant = act.get("encounters", [])
            if encounters is Array:
                for encounter_value: Variant in encounters:
                    var encounter: Dictionary = encounter_value if encounter_value is Dictionary else {}
                    if str(encounter.get("id", "")) == encounter_id:
                        return encounter.duplicate(true)
    return {}

func les_veilleurs_encounters_for_act(act_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var acts: Variant = les_veilleurs_encounter_compositions.get("acts", [])
    if acts is Array:
        for act_value: Variant in acts:
            var act: Dictionary = act_value if act_value is Dictionary else {}
            if str(act.get("act", "")) != act_id:
                continue
            var encounters: Variant = act.get("encounters", [])
            if encounters is Array:
                for encounter_value: Variant in encounters:
                    var encounter: Dictionary = encounter_value if encounter_value is Dictionary else {}
                    result.append(encounter.duplicate(true))
            break
    return result

func les_veilleurs_act(act_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_acts_1_2.get("acts", [])
    var acts: Array = values if values is Array else []
    return find_by_id(acts, act_id).duplicate(true)

func les_veilleurs_zone(zone_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_acts_1_2.get("acts", [])
    if values is Array:
        for act_value: Variant in values:
            var act: Dictionary = act_value if act_value is Dictionary else {}
            var zones: Variant = act.get("zones", [])
            if zones is Array:
                for zone_value: Variant in zones:
                    var zone: Dictionary = zone_value if zone_value is Dictionary else {}
                    if str(zone.get("id", "")) == zone_id:
                        return zone.duplicate(true)
    return {}

func les_veilleurs_recruit_event_chain(chain_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_acts_1_2.get("recruit_event_chains", [])
    var chains: Array = values if values is Array else []
    return find_by_id(chains, chain_id).duplicate(true)

func les_veilleurs_hub_stage(stage_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_acts_1_2.get("hub_progression", [])
    var stages: Array = values if values is Array else []
    return find_by_id(stages, stage_id).duplicate(true)

func les_veilleurs_remanence_bundle(bundle_id: String) -> Dictionary:
    var values: Variant = les_veilleurs_acts_1_2.get("remanence_bundles", [])
    var bundles: Array = values if values is Array else []
    return find_by_id(bundles, bundle_id).duplicate(true)

func les_veilleurs_runtime_pending() -> Array[String]:
    var result: Array[String] = []
    var values: Variant = les_veilleurs_acts_1_2.get("runtime_pending", [])
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
