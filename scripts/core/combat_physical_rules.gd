extends RefCounted

const ENERGY_RANK := {
    "none": 0,
    "low": 1,
    "medium": 2,
    "high": 3,
    "extreme": 4
}

const SEVERING_IMPACTS: Array[String] = ["cutting", "crushing", "tearing"]
const BLOOD_EFFECTS: Array[String] = ["bleed", "bleeding", "hemorrhage", "haemorrhage", "hémorragie", "hemocord", "hémocorde"]
const BLOODLESS_PHYSIOLOGIES: Array[String] = ["construct", "mineral", "stone", "mechanical", "statue"]

static func skill_availability(actor: Dictionary, skill: Dictionary) -> Dictionary:
    if actor.is_empty() or skill.is_empty():
        return {"usable": false, "reason": "missing_actor_or_skill"}

    var missing_parts: Array[String] = []
    for part_value: Variant in _array_value(skill, ["required_parts", "requires_parts"]):
        var part_id := str(part_value)
        if part_id != "" and not InjuryRuntime.part_functional(actor, part_id):
            missing_parts.append(part_id)

    var disabled_functions := _disabled_functions(actor)
    var missing_functions: Array[String] = []
    for function_value: Variant in _array_value(skill, ["required_functions", "requires_functions", "physical_requirements"]):
        var function_id := str(function_value).to_lower()
        if function_id != "" and disabled_functions.has(function_id):
            missing_functions.append(function_id)

    if bool(skill.get("requires_two_hands", false)) and _one_weapon_arm_missing(actor):
        missing_functions.append("two_hands")

    if not missing_parts.is_empty() or not missing_functions.is_empty():
        return {
            "usable": false,
            "reason": "required_function_unavailable",
            "missing_parts": missing_parts,
            "missing_functions": missing_functions
        }
    return {"usable": true, "reason": "ok", "missing_parts": [], "missing_functions": []}

static func physiology_compatibility(target: Dictionary, effect: Variant) -> Dictionary:
    var effects: Array[String] = []
    if effect is Array:
        for value: Variant in effect:
            effects.append(str(value).to_lower())
    else:
        effects.append(str(effect).to_lower())

    var physiology := _physiology(target)
    var blood_effect := false
    for effect_id: String in effects:
        if BLOOD_EFFECTS.has(effect_id):
            blood_effect = true
            break
    if blood_effect and BLOODLESS_PHYSIOLOGIES.has(physiology):
        return {
            "allowed": false,
            "multiplier": 0.0,
            "reason": "target_has_no_compatible_blood_system",
            "physiology": physiology
        }
    return {"allowed": true, "multiplier": 1.0, "reason": "ok", "physiology": physiology}

static func dismemberment_compatibility(part: Dictionary, context: Dictionary) -> Dictionary:
    if part.is_empty():
        return {"allowed": false, "reason": "unknown_part"}
    if not bool(part.get("severable", true)):
        return {"allowed": false, "reason": "part_not_severable"}
    if bool(part.get("finisher_only", false)) and not bool(context.get("finisher_allowed", false)):
        return {"allowed": false, "reason": "finisher_only"}

    var impact_type := str(context.get("impact_type", "")).to_lower()
    if not SEVERING_IMPACTS.has(impact_type):
        return {"allowed": false, "reason": "impact_incompatible"}

    var zone_id := str(context.get("target_zone", context.get("part_id", "")))
    if zone_id != "" and zone_id != str(part.get("id", "")):
        return {"allowed": false, "reason": "zone_incompatible"}

    var energy_rank := _energy_rank(context.get("energy", context.get("energy_level", "none")))
    var required_energy := _energy_rank(context.get("required_energy", "high"))
    if energy_rank < required_energy:
        return {"allowed": false, "reason": "energy_insufficient", "energy_rank": energy_rank, "required_energy_rank": required_energy}

    var severity := str(context.get("severity", "critical")).to_lower()
    if severity not in ["serious", "critical", "catastrophic"]:
        return {"allowed": false, "reason": "severity_insufficient"}
    if not bool(context.get("gravity_compatible", true)):
        return {"allowed": false, "reason": "gravity_incompatible"}
    if not bool(context.get("angle_compatible", true)):
        return {"allowed": false, "reason": "angle_incompatible"}

    return {"allowed": true, "reason": "ok", "energy_rank": energy_rank, "required_energy_rank": required_energy}

static func resolve_localized_armor_hit(armor_piece: Dictionary, hit: Dictionary) -> Dictionary:
    var zone := str(hit.get("zone", hit.get("target_zone", "")))
    var covered_zones := _armor_zones(armor_piece)
    var armor_after := armor_piece.duplicate(true)
    var durability := maxi(0, int(armor_piece.get("durability", armor_piece.get("max_durability", 0))))
    var max_durability := maxi(durability, int(armor_piece.get("max_durability", durability)))
    var broken_before := bool(armor_piece.get("broken", false)) or str(armor_piece.get("state", "")).to_lower() == "broken" or (max_durability > 0 and durability <= 0)

    if zone == "" or not covered_zones.has(zone):
        return {
            "covered": false,
            "exposed": true,
            "broken_before": broken_before,
            "perforated": true,
            "absorbed": 0.0,
            "trauma_transmitted": float(hit.get("energy", 0.0)),
            "armor_after": armor_after
        }
    if broken_before:
        armor_after["broken"] = true
        armor_after["state"] = "broken"
        armor_after["durability"] = 0
        return {
            "covered": true,
            "exposed": true,
            "broken_before": true,
            "perforated": true,
            "absorbed": 0.0,
            "trauma_transmitted": float(hit.get("energy", 0.0)),
            "armor_after": armor_after
        }

    var energy := maxf(0.0, float(hit.get("energy", 0.0)))
    var protection := maxf(0.0, float(armor_piece.get("protection", armor_piece.get("armor", 0.0))))
    var impact_type := str(hit.get("impact_type", "blunt")).to_lower()
    var material := str(armor_piece.get("material", "plate")).to_lower()
    var is_plate := material in ["plate", "steel_plate", "iron_plate", "stone_plate", "metal_plate"]
    var perforated := energy > protection
    var absorbed := minf(energy, protection)
    var trauma_transmitted := maxf(0.0, energy - absorbed)

    if impact_type == "blunt" and is_plate:
        perforated = energy > protection * 1.5
        # Une plaque peut rester intacte face à la pénétration tout en transmettant
        # une partie substantielle de l'impulsion au corps sous-jacent.
        trauma_transmitted = maxf(1.0 if energy > 0.0 else 0.0, energy * 0.35)
        absorbed = maxf(0.0, energy - trauma_transmitted)

    var durability_loss := maxi(1 if energy > 0.0 else 0, int(round(energy * float(hit.get("durability_factor", 0.25)))))
    var next_durability := maxi(0, durability - durability_loss)
    armor_after["durability"] = next_durability
    armor_after["max_durability"] = max_durability
    var broken_after := max_durability > 0 and next_durability <= 0
    armor_after["broken"] = broken_after
    armor_after["state"] = "broken" if broken_after else str(armor_piece.get("state", "intact"))

    return {
        "covered": true,
        "exposed": broken_after,
        "broken_before": false,
        "broken_after": broken_after,
        "perforated": perforated,
        "absorbed": absorbed,
        "trauma_transmitted": trauma_transmitted,
        "durability_loss": durability_loss,
        "armor_after": armor_after
    }

static func _array_value(source: Dictionary, keys: Array[String]) -> Array:
    for key: String in keys:
        var value: Variant = source.get(key, null)
        if value is Array:
            return value
    return []

static func _disabled_functions(actor: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in actor.get("disabled_functions", []):
        _append_unique(result, str(value).to_lower())
    var lost: Array = actor.get("dismembered_parts", [])
    var critical: Array = actor.get("critically_disabled_parts", [])
    for value: Variant in lost + critical:
        var part := str(value).to_lower()
        if "arm" in part or "hand" in part or part == "weapon_arm" or part == "offensive_limb":
            _append_unique(result, "weapon_arm")
            _append_unique(result, "gesture")
            _append_unique(result, "two_hands")
        if "leg" in part or "foot" in part or part == "support_leg":
            _append_unique(result, "mobility")
        if "eye" in part or "head" in part or "sensor" in part:
            _append_unique(result, "sensor")
    return result

static func _one_weapon_arm_missing(actor: Dictionary) -> bool:
    var disabled := _disabled_functions(actor)
    return disabled.has("two_hands")

static func _physiology(target: Dictionary) -> String:
    var explicit := str(target.get("physiology", target.get("anatomy_profile", target.get("dismemberment_profile", "")))).to_lower()
    if explicit != "":
        return explicit
    var tags: Array = target.get("tags", [])
    for value: Variant in tags:
        var tag := str(value).to_lower()
        if BLOODLESS_PHYSIOLOGIES.has(tag):
            return tag
    return "organic"

static func _energy_rank(value: Variant) -> int:
    if value is int or value is float:
        var numeric := float(value)
        if numeric >= 100.0:
            return 4
        if numeric >= 60.0:
            return 3
        if numeric >= 30.0:
            return 2
        if numeric > 0.0:
            return 1
        return 0
    return int(ENERGY_RANK.get(str(value).to_lower(), 0))

static func _armor_zones(armor_piece: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var raw: Variant = armor_piece.get("zones", armor_piece.get("covered_zones", []))
    if raw is Array:
        for value: Variant in raw:
            result.append(str(value))
    else:
        var single := str(armor_piece.get("zone", raw))
        if single != "":
            result.append(single)
    return result

static func _append_unique(values: Array[String], value: String) -> void:
    if value != "" and not values.has(value):
        values.append(value)
