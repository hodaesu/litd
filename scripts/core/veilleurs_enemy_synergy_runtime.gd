extends RefCounted

const SYNERGY_PATH := "res://data/veilleurs/enemy_synergies_21.json"

var payload: Dictionary = {}
var synergies: Array[Dictionary] = []

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SYNERGY_PATH))
    if not (parsed is Dictionary):
        return
    payload = parsed
    for value: Variant in payload.get("synergies", []):
        if value is Dictionary:
            synergies.append((value as Dictionary).duplicate(true))

func synergy_count() -> int:
    return synergies.size()

func evaluate(actors: Array, act_id: String = "") -> Dictionary:
    var available_species: Dictionary = {}
    for value: Variant in actors:
        if not (value is Dictionary):
            continue
        var actor: Dictionary = value
        if not _actor_can_contribute(actor):
            continue
        var species := str(actor.get("species", ""))
        if species == "":
            continue
        available_species[species] = int(available_species.get(species, 0)) + 1

    var active: Array[Dictionary] = []
    for synergy: Dictionary in synergies:
        if act_id != "" and str(synergy.get("act_id", "")) != act_id:
            continue
        var required: Array = synergy.get("species", [])
        if required.size() != 2:
            continue
        if _requirements_present(required, available_species):
            var resolved := synergy.duplicate(true)
            resolved["active"] = true
            resolved["telegraphed"] = true
            resolved["counterplay_visible"] = str(resolved.get("counterplay", "")) != ""
            active.append(resolved)

    active.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_strength := int(left.get("strength", 0))
        var right_strength := int(right.get("strength", 0))
        if left_strength == right_strength:
            return str(left.get("id", "")) < str(right.get("id", ""))
        return left_strength > right_strength
    )
    return {
        "active": active,
        "active_count": active.size(),
        "species_present": available_species,
        "max_strength": int(active[0].get("strength", 0)) if not active.is_empty() else 0,
        "hidden_stat_bonus": false
    }

func break_by_species_loss(actors: Array, lost_species: String, act_id: String = "") -> Dictionary:
    var changed: Array = actors.duplicate(true)
    for index in range(changed.size()):
        if not (changed[index] is Dictionary):
            continue
        var actor: Dictionary = changed[index]
        if str(actor.get("species", "")) == lost_species:
            actor["synergy_disabled"] = true
            changed[index] = actor
            break
    var result := evaluate(changed, act_id)
    result["actors"] = changed
    result["lost_species"] = lost_species
    return result

func validate_contract() -> Dictionary:
    var errors: Array[String] = []
    if synergy_count() != int(payload.get("synergy_count", 21)):
        errors.append("synergy_count")
    var ids: Dictionary = {}
    for synergy: Dictionary in synergies:
        var synergy_id := str(synergy.get("id", ""))
        if synergy_id == "" or ids.has(synergy_id):
            errors.append("id:%s" % synergy_id)
        ids[synergy_id] = true
        if (synergy.get("species", []) as Array).size() != 2:
            errors.append("pair:%s" % synergy_id)
        if int(synergy.get("strength", 0)) < 1 or int(synergy.get("strength", 0)) > 3:
            errors.append("strength:%s" % synergy_id)
        if str(synergy.get("mechanic", "")) == "":
            errors.append("mechanic:%s" % synergy_id)
        if str(synergy.get("counterplay", "")) == "":
            errors.append("counterplay:%s" % synergy_id)
    return {"valid": errors.is_empty(), "errors": errors, "synergy_count": synergy_count()}

func _requirements_present(required: Array, available: Dictionary) -> bool:
    var needed: Dictionary = {}
    for value: Variant in required:
        var species := str(value)
        needed[species] = int(needed.get(species, 0)) + 1
    for species: Variant in needed.keys():
        if int(available.get(species, 0)) < int(needed[species]):
            return false
    return true

func _actor_can_contribute(actor: Dictionary) -> bool:
    if bool(actor.get("synergy_disabled", false)):
        return false
    if bool(actor.get("dead", false)):
        return false
    if int(actor.get("hp", 1)) <= 0:
        return false
    return str(actor.get("status", "active")) == "active"
