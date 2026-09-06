extends RefCounted
class_name VeilleursHybridGenerationBridge

const RULES_PATH := "res://data/veilleurs/v06/hybrid_generation_rules.json"
const CONTENT_DB_SCRIPT := preload("res://scripts/core/content_db.gd")
const ASHLANDS_LAYOUT_SCRIPT := preload("res://scripts/world/ashlands_layout_generator.gd")

var content_db: VeilleursContentDB
var rules: Dictionary = {}

func _init() -> void:
    content_db = CONTENT_DB_SCRIPT.new() as VeilleursContentDB
    content_db.reload()
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH)) if FileAccess.file_exists(RULES_PATH) else {}
    rules = parsed if parsed is Dictionary else {}

func generate_plan(archetype_id: String, seed_value: int) -> Dictionary:
    var archetype := _archetype(archetype_id)
    if archetype.is_empty():
        return {}
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var room_range: Array = archetype.get("rooms", [10, 18])
    var room_count := rng.randi_range(int(room_range[0]), int(room_range[1]))
    var rooms: Array[Dictionary] = []
    for index in range(room_count):
        var band := _band_for_room(index, room_count)
        var family := _pick_family(archetype.get("families", []), rng)
        var encounter := generate_encounter(family, band, 1 + (index % 2), rng.randi())
        rooms.append({
            "room_index": index,
            "kind": "entry" if index == 0 else ("objective" if index == room_count - 1 else "room"),
            "hazard": _pick_string(archetype.get("hazards", []), rng),
            "encounter": encounter,
            "important": index > 0 and index % 4 == 0,
            "extraction": index == room_count - 1
        })
    return {
        "archetype_id": archetype_id,
        "seed": seed_value,
        "room_count": room_count,
        "rooms": rooms,
        "persistence": str(rules.get("world_persistence", "seed + anchored scars + state flags"))
    }

func generate_encounter(family: String, band: String, variant: int, seed_value: int) -> Dictionary:
    var bands: Dictionary = rules.get("encounter_template_contract", {}).get("bands", {})
    var band_rules: Dictionary = bands.get(band, {})
    if band_rules.is_empty():
        return {}
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var threat_range: Array = band_rules.get("threat", [3.3, 4.2])
    var target_threat := rng.randf_range(float(threat_range[0]), float(threat_range[1]))
    var candidates: Array[Dictionary] = []
    for enemy_id_value: Variant in content_db.enemies_by_id.keys():
        var enemy: Dictionary = content_db.enemy(str(enemy_id_value))
        if str(enemy.get("family", "")) == family:
            candidates.append(enemy)
    if candidates.is_empty():
        return {}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("threat_value", 1.0)) < float(b.get("threat_value", 1.0)))
    var composition: Array[Dictionary] = []
    var total := 0.0
    var cursor := (variant - 1) % candidates.size()
    while total < target_threat * 0.88 and composition.size() < 6:
        var definition: Dictionary = candidates[cursor % candidates.size()]
        var threat := float(definition.get("threat_value", 1.0))
        if total + threat <= target_threat * 1.18 or composition.is_empty():
            composition.append({"definition_id":str(definition.get("entity_id", "")), "threat":threat})
            total += threat
        cursor += 1
        if cursor > 24:
            break
    _inject_memorial(composition, float(band_rules.get("memoriel_chance", 0.0)), rng)
    return {
        "template_id": "ENC_%s_%s_%02d" % [family, band, clampi(variant, 1, 2)],
        "family": family,
        "band": band,
        "target_threat": target_threat,
        "actual_threat": total,
        "composition": composition,
        "escape_route_required": bool(rules.get("encounter_template_contract", {}).get("escape_route_required", true))
    }

func build_existing_ashlands_layout(parent: Node3D, zone_id: String, zone_data: Dictionary) -> void:
    ASHLANDS_LAYOUT_SCRIPT.generate(parent, zone_id, zone_data)

func _inject_memorial(composition: Array[Dictionary], chance: float, rng: RandomNumberGenerator) -> void:
    if composition.is_empty() or rng.randf() > chance:
        return
    for entity_value: Variant in RemanenceRuntime.entities.values():
        if not (entity_value is Dictionary):
            continue
        var record: Dictionary = entity_value
        if str(record.get("status", "active")) != "active" or str(record.get("stage", "normal")) == "normal":
            continue
        var species_id := str(record.get("species_id", ""))
        for member: Dictionary in composition:
            if str(member.get("definition_id", "")) == species_id:
                member["remanence_id"] = str(record.get("id", ""))
                member["remanence_stage"] = str(record.get("stage", "memoriel"))
                return

func _archetype(archetype_id: String) -> Dictionary:
    for value: Variant in rules.get("archetypes", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == archetype_id:
            return (value as Dictionary).duplicate(true)
    return {}

func _band_for_room(index: int, room_count: int) -> String:
    var ratio := float(index) / float(maxi(1, room_count - 1))
    if ratio < 0.25:
        return "LOW"
    if ratio < 0.55:
        return "STANDARD"
    if ratio < 0.82:
        return "HIGH"
    return "SEVERE"

func _pick_family(values: Array, rng: RandomNumberGenerator) -> String:
    return _pick_string(values, rng)

func _pick_string(values: Array, rng: RandomNumberGenerator) -> String:
    if values.is_empty():
        return ""
    return str(values[rng.randi_range(0, values.size() - 1)])
