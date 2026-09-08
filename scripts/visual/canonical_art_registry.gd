class_name CanonicalArtRegistry
extends RefCounted

const MANIFEST_PATH := "res://data/canonical_art_v41.json"

var _manifest: Dictionary = {}

func manifest() -> Dictionary:
    _ensure_loaded()
    return _manifest.duplicate(true)

func version() -> int:
    _ensure_loaded()
    return int(_manifest.get("version", 0))

func token(group: String, key: String, fallback: Variant = null) -> Variant:
    _ensure_loaded()
    var tokens: Dictionary = _manifest.get("tokens", {})
    var values: Dictionary = tokens.get(group, {})
    return values.get(key, fallback)

func screen_contract(screen_name: String) -> Dictionary:
    _ensure_loaded()
    var screens: Dictionary = _manifest.get("screen_composition", {})
    return (screens.get(screen_name, {}) as Dictionary).duplicate(true)

func morphology_contract(morphology: String) -> Dictionary:
    _ensure_loaded()
    var contracts: Dictionary = _manifest.get("morphology_contracts", {})
    var key := morphology.strip_edges().to_upper()
    if contracts.has(key):
        return (contracts[key] as Dictionary).duplicate(true)
    if key.contains("HUMANOID"):
        return (contracts.get("HUMANOID", {}) as Dictionary).duplicate(true)
    return (contracts.get("BOSS_CUSTOM", {}) as Dictionary).duplicate(true)

func functional_state_contract(state: String) -> Dictionary:
    _ensure_loaded()
    var states: Dictionary = _manifest.get("functional_body_states", {})
    var key := state.strip_edges().to_upper()
    return (states.get(key, states.get("F0", {})) as Dictionary).duplicate(true)

func injury_visual_rules() -> Dictionary:
    _ensure_loaded()
    return (_manifest.get("injury_visual_rules", {}) as Dictionary).duplicate(true)

func asset_slot(slot_id: String, bindings: Dictionary = {}) -> Dictionary:
    _ensure_loaded()
    var slots: Dictionary = _manifest.get("asset_slots", {})
    if not slots.has(slot_id):
        return {}
    var slot: Dictionary = (slots[slot_id] as Dictionary).duplicate(true)
    for field in ["primary_path", "fallback_path"]:
        if slot.has(field):
            slot[field] = _bind_path(str(slot[field]), bindings)
    return slot

func resolve_asset(slot_id: String, bindings: Dictionary = {}) -> Dictionary:
    var slot := asset_slot(slot_id, bindings)
    if slot.is_empty():
        return {"slot_id": slot_id, "status": "missing", "path": "", "reason": "unknown_slot"}

    var primary := str(slot.get("primary_path", ""))
    var fallback := str(slot.get("fallback_path", ""))
    if primary != "" and not primary.contains("{") and ResourceLoader.exists(primary):
        return {"slot_id": slot_id, "status": "final", "path": primary, "source": "primary", "contract": slot}
    if fallback != "" and not fallback.contains("{") and ResourceLoader.exists(fallback):
        return {"slot_id": slot_id, "status": "placeholder", "path": fallback, "source": "fallback", "contract": slot}
    return {"slot_id": slot_id, "status": "missing", "path": "", "source": "procedural_or_text", "contract": slot}

func character_visual_contract(character: Dictionary, profile: Dictionary = {}) -> Dictionary:
    var morphology := _character_morphology(character)
    var state := _functional_state(character, profile)
    var contract := {
        "entity_id": str(character.get("id", character.get("entity_id", ""))),
        "morphology": morphology,
        "morphology_contract": morphology_contract(morphology),
        "functional_state": state,
        "functional_contract": functional_state_contract(state),
        "injury_rules": injury_visual_rules()
    }
    var body_slot := resolve_asset("body.active_entity", {"morphology": _diagram_name(contract["morphology_contract"])})
    contract["body_asset"] = body_slot
    return contract

func screen_asset_status(screen_name: String, bindings: Dictionary = {}) -> Dictionary:
    var contract := screen_contract(screen_name)
    var result := {"screen": screen_name, "assets": {}}
    for field in ["background_slot", "portrait_slot", "body_diagram_slot"]:
        var slot_id := str(contract.get(field, ""))
        if slot_id != "":
            result["assets"][field] = resolve_asset(slot_id, bindings)
    return result

func _ensure_loaded() -> void:
    if not _manifest.is_empty():
        return
    if not FileAccess.file_exists(MANIFEST_PATH):
        push_error("CanonicalArtRegistry: manifest missing: %s" % MANIFEST_PATH)
        return
    var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null:
        push_error("CanonicalArtRegistry: cannot open manifest")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        _manifest = (parsed as Dictionary).duplicate(true)
    else:
        push_error("CanonicalArtRegistry: invalid JSON manifest")

func _bind_path(path: String, bindings: Dictionary) -> String:
    var result := path
    for key_value: Variant in bindings.keys():
        var key := str(key_value)
        result = result.replace("{%s}" % key, str(bindings[key_value]))
    return result

func _character_morphology(character: Dictionary) -> String:
    for key in ["morphology", "anatomy_profile", "body_profile", "anatomy_type"]:
        var value := str(character.get(key, "")).strip_edges()
        if value != "":
            return value.to_upper()
    return "HUMANOID"

func _functional_state(character: Dictionary, profile: Dictionary) -> String:
    for source in [profile, character]:
        for key in ["functional_state", "body_function_state", "worst_functional_state"]:
            var value := str(source.get(key, "")).strip_edges().to_upper()
            if value in ["F0", "F1", "F2", "F3", "F4"]:
                return value
    var physical := str(profile.get("physical_state", "")).to_lower()
    match physical:
        "dead": return "F4"
        "critical": return "F3"
        "mobility_impaired": return "F2"
        "injured": return "F1"
        _: return "F0"

func _diagram_name(contract: Dictionary) -> String:
    return str(contract.get("diagram", "boss_declared_profile")).to_lower()
