extends Node

const PATH := "res://data/enemy_body_profiles.json"

var data: Dictionary = {}
var profiles_by_owner: Dictionary = {}
var profiles_by_enemy_id: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> bool:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    data = parsed if parsed is Dictionary else {}
    profiles_by_owner.clear()
    profiles_by_enemy_id.clear()
    for value: Variant in data.get("profiles", []):
        if not value is Dictionary:
            continue
        var profile: Dictionary = value
        profiles_by_owner[str(profile.get("owner", ""))] = profile
        profiles_by_enemy_id[int(profile.get("enemy_id", 0))] = profile
    return profiles_by_owner.size() == 39

func profile_for_owner(owner: String) -> Dictionary:
    return (profiles_by_owner.get(owner, {}) as Dictionary).duplicate(true)

func profile_for_enemy(enemy_id: int) -> Dictionary:
    return (profiles_by_enemy_id.get(enemy_id, {}) as Dictionary).duplicate(true)

func compose(owner: String, physical_state: String = "healthy", psychological_state: String = "neutral", combat_intent: String = "idle") -> Dictionary:
    var profile: Dictionary = profile_for_owner(owner)
    if profile.is_empty():
        return {}
    var archetype_id: String = str(profile.get("archetype", ""))
    var temperament_id: String = str(profile.get("temperament", ""))
    var archetypes: Dictionary = data.get("archetypes", {})
    var temperaments: Dictionary = data.get("temperaments", {})
    var roles: Dictionary = data.get("tactical_roles", {})
    var modifiers: Dictionary = data.get("state_modifiers", {})
    var result: Dictionary = {
        "owner": owner,
        "signature_key": str(profile.get("signature_key", "")),
        "archetype": (archetypes.get(archetype_id, {}) as Dictionary).duplicate(true),
        "temperament": (temperaments.get(temperament_id, {}) as Dictionary).duplicate(true),
        "tactical_role": (roles.get(str(profile.get("tactical_role", "")), {}) as Dictionary).duplicate(true),
        "asymmetry": str(profile.get("asymmetry", "")),
        "tempo_scale": float(profile.get("tempo_scale", 1.0)),
        "phase_offset": float(profile.get("phase_offset", 0.0)),
        "boss": bool(profile.get("boss", false)),
        "layers": []
    }
    var layers: Array = result["layers"]
    _append_state_layer(layers, modifiers, "physical", physical_state)
    if psychological_state in ["tense", "terrified", "panic"]:
        _append_state_layer(layers, modifiers, "fear", psychological_state)
    elif psychological_state == "fractured":
        _append_state_layer(layers, modifiers, "madness", psychological_state)
    _append_state_layer(layers, modifiers, "intent", combat_intent)
    return result

func movement_variant(owner: String, base_action: String, physical_state: String = "healthy", psychological_state: String = "neutral", combat_intent: String = "idle") -> Dictionary:
    var body: Dictionary = compose(owner, physical_state, psychological_state, combat_intent)
    if body.is_empty():
        return {}
    body["base_action"] = base_action
    body["movement_id"] = "%s.%s" % [owner, base_action]
    return body

func _append_state_layer(layers: Array, modifiers: Dictionary, family: String, state: String) -> void:
    var family_values: Dictionary = modifiers.get(family, {})
    if family_values.has(state):
        layers.append({
            "family": family,
            "state": state,
            "values": (family_values[state] as Dictionary).duplicate(true)
        })

func diversity_summary() -> Dictionary:
    var archetypes: Dictionary = {}
    var temperaments: Dictionary = {}
    var roles: Dictionary = {}
    for value: Variant in profiles_by_owner.values():
        var profile: Dictionary = value
        _count(archetypes, str(profile.get("archetype", "")))
        _count(temperaments, str(profile.get("temperament", "")))
        _count(roles, str(profile.get("tactical_role", "")))
    return {
        "profiles": profiles_by_owner.size(),
        "archetypes": archetypes,
        "temperaments": temperaments,
        "roles": roles
    }

func _count(target: Dictionary, key: String) -> void:
    target[key] = int(target.get(key, 0)) + 1
