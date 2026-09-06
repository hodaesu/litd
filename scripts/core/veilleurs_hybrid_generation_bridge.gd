extends RefCounted
class_name VeilleursHybridGenerationBridge

const RULES_PATH := "res://data/veilleurs/v06/hybrid_generation_rules.json"
const ENCOUNTERS_PATH := "res://data/veilleurs/v06/encounters_64.json"
const CONTENT_DB_SCRIPT := preload("res://scripts/core/content_db.gd")
const ASHLANDS_LAYOUT_SCRIPT := preload("res://scripts/world/ashlands_layout_generator.gd")

const FAMILY_ARCHETYPE := {
    "GOULES":"blood_hunt",
    "PORTE_CENDRES":"ash_line",
    "ECHOS":"echo_pressure",
    "PARASITES":"parasite_nest",
    "BETES_ALTEREES":"altered_pack",
    "HUMAINS_DEVOYES":"human_screen"
}

var content_db: VeilleursContentDB
var rules: Dictionary = {}
var encounters_by_id: Dictionary = {}
var encounter_rows: Array[Dictionary] = []
var load_errors: Array[String] = []

func _init() -> void:
    content_db = CONTENT_DB_SCRIPT.new() as VeilleursContentDB
    content_db.reload()
    rules = _load_dictionary(RULES_PATH)
    _load_encounters()

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

func encounter_count() -> int:
    return encounter_rows.size()

func encounter(encounter_id: String) -> Dictionary:
    return (encounters_by_id.get(encounter_id, {}) as Dictionary).duplicate(true)

func select_encounter(seed_value: int, tier: int, archetype: String = "") -> Dictionary:
    var candidates: Array[Dictionary] = []
    for row: Dictionary in encounter_rows:
        if int(row.get("tier", 0)) != clampi(tier, 1, 8):
            continue
        if archetype != "" and str(row.get("archetype", "")) != archetype:
            continue
        candidates.append(row)
    if candidates.is_empty():
        return {}
    var index := posmod(str(seed_value).hash(), candidates.size())
    return candidates[index].duplicate(true)

func generate_encounter(family: String, band: String, variant: int, seed_value: int) -> Dictionary:
    var archetype := str(FAMILY_ARCHETYPE.get(family, ""))
    var tier := _tier_for_band(band, variant)
    var authored := select_encounter(seed_value, tier, archetype)
    if authored.is_empty():
        authored = select_encounter(seed_value, tier)
    if authored.is_empty():
        return {}
    return _materialize(authored, seed_value)

func build_existing_ashlands_layout(parent: Node3D, zone_id: String, zone_data: Dictionary) -> void:
    ASHLANDS_LAYOUT_SCRIPT.generate(parent, zone_id, zone_data)

func _materialize(authored: Dictionary, seed_value: int) -> Dictionary:
    var composition: Array[Dictionary] = []
    var total := 0.0
    for enemy_id_value: Variant in authored.get("enemy_ids", []):
        var enemy_id := str(enemy_id_value)
        var definition := content_db.enemy(enemy_id)
        if definition.is_empty():
            continue
        var threat := float(definition.get("threat_value", 1.0))
        composition.append({"definition_id":enemy_id, "threat":threat})
        total += threat
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    if bool(authored.get("memoriel_allowed", false)):
        _inject_memorial(composition, 1.0 if str(authored.get("archetype", "")) == "mixed_memory" else 0.35, rng)
    return {
        "template_id": str(authored.get("encounter_id", "")),
        "archetype": str(authored.get("archetype", "")),
        "tier": int(authored.get("tier", 1)),
        "target_threat": float(authored.get("threat_budget", total)),
        "actual_threat": total,
        "composition": composition,
        "objective": str(authored.get("objective", "survive")),
        "terrain_tags": (authored.get("terrain_tags", []) as Array).duplicate(),
        "counterplay": str(authored.get("counterplay", "")),
        "escape_route_required": bool(authored.get("retreat_viable", true)),
        "seed_salt": str(authored.get("seed_salt", ""))
    }

func _load_encounters() -> void:
    encounters_by_id.clear()
    encounter_rows.clear()
    var payload := _load_dictionary(ENCOUNTERS_PATH)
    for value: Variant in payload.get("encounters", []):
        if not (value is Dictionary):
            continue
        var row: Dictionary = (value as Dictionary).duplicate(true)
        var encounter_id := str(row.get("encounter_id", ""))
        if encounter_id == "" or encounters_by_id.has(encounter_id):
            load_errors.append("invalid_or_duplicate_encounter:%s" % encounter_id)
            continue
        var valid := true
        for enemy_id_value: Variant in row.get("enemy_ids", []):
            if content_db.enemy(str(enemy_id_value)).is_empty():
                valid = false
                load_errors.append("unknown_enemy:%s:%s" % [encounter_id, str(enemy_id_value)])
        if valid:
            encounters_by_id[encounter_id] = row
            encounter_rows.append(row)
    if encounter_rows.size() != 64:
        load_errors.append("encounter_count:%d" % encounter_rows.size())

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

func _tier_for_band(band: String, variant: int) -> int:
    var base := {"LOW":1, "STANDARD":3, "HIGH":5, "SEVERE":7}.get(band, 3)
    return clampi(int(base) + clampi(variant, 1, 2) - 1, 1, 8)

func _pick_family(values: Array, rng: RandomNumberGenerator) -> String:
    return _pick_string(values, rng)

func _pick_string(values: Array, rng: RandomNumberGenerator) -> String:
    if values.is_empty():
        return ""
    return str(values[rng.randi_range(0, values.size() - 1)])

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        load_errors.append("missing:%s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        load_errors.append("invalid_json:%s" % path)
        return {}
    return parsed as Dictionary
