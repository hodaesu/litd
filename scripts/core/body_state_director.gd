extends Node

signal body_state_changed(character_id: String, profile: Dictionary)

const CONTRACT_PATH := "res://data/body_state_animation_contract.json"
const PHYSICAL_BIBLE_PATH := "res://data/physical_bible.json"

var contract: Dictionary = {}
var physical_bible: Dictionary = {}
var party_profiles: Dictionary = {}

func _ready() -> void:
    _load_contracts()
    if not GameState.state_changed.is_connected(refresh_party):
        GameState.state_changed.connect(refresh_party)
    call_deferred("refresh_party")

func _load_contracts() -> bool:
    var parsed_contract: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
    var parsed_bible: Variant = JSON.parse_string(FileAccess.get_file_as_string(PHYSICAL_BIBLE_PATH))
    contract = parsed_contract if parsed_contract is Dictionary else {}
    physical_bible = parsed_bible if parsed_bible is Dictionary else {}
    return not contract.is_empty() and not physical_bible.is_empty()

func refresh_party() -> void:
    for value: Variant in GameState.party:
        if not value is Dictionary:
            continue
        var character: Dictionary = value
        var character_id: String = str(character.get("id", character.get("name", "character")))
        var next_profile: Dictionary = evaluate(character)
        if party_profiles.get(character_id, {}) != next_profile:
            party_profiles[character_id] = next_profile
            body_state_changed.emit(character_id, next_profile.duplicate(true))

func evaluate(character: Dictionary, context: Dictionary = {}) -> Dictionary:
    if contract.is_empty():
        _load_contracts()
    var hp: int = int(character.get("hp", 0))
    var max_hp: int = maxi(1, int(character.get("max_hp", hp if hp > 0 else 1)))
    var hp_ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
    var fear: int = clampi(int(character.get("fear", 0)), 0, 100)
    var psychology: Dictionary = character.get("psychology", {}) if character.get("psychology", {}) is Dictionary else {}
    var madness: int = clampi(int(character.get("madness", psychology.get("madness_exposure", 0))), 0, 100)
    var hope: int = clampi(int(character.get("hope", int(psychology.get("resolve_charges", 0)) * 70)), 0, 100)
    var affliction: String = str(character.get("affliction", character.get("mental_state", ""))).to_lower()
    var physical_state: String = _physical_state(character, hp_ratio)
    var psychological_state: String = _psychological_state(hp, fear, madness, hope, affliction)
    var relation_state: String = str(context.get("relation_intent", "none"))
    if not (contract.get("relation_layers", {}) as Dictionary).has(relation_state):
        relation_state = "none"
    var locomotion_state: String = _locomotion_state(character, physical_state, context)
    var psyche_rule: Dictionary = contract.get("psychological_states", {}).get(psychological_state, {})
    var physical_rule: Dictionary = contract.get("physical_states", {}).get(physical_state, {})
    var relation_rule: Dictionary = contract.get("relation_layers", {}).get(relation_state, {})
    var character_id: String = str(character.get("id", character.get("name", "character")))
    return {
        "character_id": character_id,
        "psychological_state": psychological_state,
        "physical_state": physical_state,
        "locomotion_state": locomotion_state,
        "relation_state": relation_state,
        "fear": fear,
        "madness": madness,
        "hope": hope,
        "hp_ratio": hp_ratio,
        "base_signature": character_signature(character_id),
        "layers": {
            "base_action": str(context.get("action", "idle")),
            "psychology": psyche_rule.get("pose", psychological_state),
            "physical": physical_rule.get("pose", physical_state),
            "reaction": str(context.get("reaction", "none")),
            "personality": character_signature(character_id).get("neutral_posture", "generic"),
            "relation": relation_rule.get("pose_additive", "none")
        },
        "parameters": {
            "shoulders": float(psyche_rule.get("shoulders", 0.0)),
            "gaze_scan": float(psyche_rule.get("gaze_scan", 0.0)),
            "guard_compaction": float(psyche_rule.get("guard_compaction", 0.0)),
            "gesture_noise": float(psyche_rule.get("gesture_noise", 0.0)),
            "stance_height": float(physical_rule.get("stance_height", 1.0)),
            "stride_scale": float(physical_rule.get("stride", 1.0)),
            "recovery_visual_scale": float(physical_rule.get("recovery", 1.0)),
            "breath_intensity": float(physical_rule.get("breath", 0.15)),
            "relation_orientation_bias": float(relation_rule.get("orientation_bias", 0.0)),
            "relation_spacing_bias": float(relation_rule.get("spacing_bias", 0.0))
        },
        "gameplay_timing_scale": 1.0
    }

func combat_action_plan(character: Dictionary, action_id: String, context: Dictionary = {}) -> Dictionary:
    var profile: Dictionary = evaluate(character, context.merged({"action": action_id}, true))
    var action: Dictionary = contract.get("combat_actions", {}).get(action_id, {})
    return {
        "action_id": action_id,
        "valid": not action.is_empty(),
        "phases": (action.get("phases", []) as Array).duplicate(),
        "required_markers": (action.get("required_markers", []) as Array).duplicate(),
        "profile": profile,
        "gameplay_timing_scale": 1.0,
        "visual_recovery_scale": float(profile.get("parameters", {}).get("recovery_visual_scale", 1.0)),
        "root_motion_allowed": action_id in ["rank_move"]
    }

func hit_reaction(character: Dictionary, body_part: String, severity: String = "light") -> Dictionary:
    var reactions: Dictionary = contract.get("hit_reactions", {})
    var part_rules: Dictionary = reactions.get(body_part, reactions.get("default", {}))
    return {
        "clip": str(part_rules.get(severity, reactions.get("default", {}).get(severity, "hit"))),
        "body_part": body_part,
        "severity": severity,
        "profile": evaluate(character, {"reaction": "hit_%s" % body_part})
    }

func character_signature(character_id: String) -> Dictionary:
    var characters: Dictionary = physical_bible.get("characters", {})
    if characters.has(character_id):
        return (characters.get(character_id, {}) as Dictionary).duplicate(true)
    return {
        "neutral_posture": "generic_grounded",
        "laban": {"space": "direct", "weight": "light", "time": "sustained", "flow": "bound"},
        "stillness_budget": "medium"
    }

func _physical_state(character: Dictionary, hp_ratio: float) -> String:
    if int(character.get("hp", 0)) <= 0:
        return "dead"
    var injuries: Dictionary = character.get("applied_injury_states", {}) if character.get("applied_injury_states", {}) is Dictionary else {}
    var critical_parts: Array = character.get("critically_disabled_parts", [])
    var mobility: String = str(character.get("mobility_injury", ""))
    if mobility != "" or _has_leg_loss(character):
        return "mobility_impaired"
    if not critical_parts.is_empty() or injuries.values().has("critical") or hp_ratio <= float(contract.get("thresholds", {}).get("hp_critical_max", 0.25)):
        return "critical"
    if not injuries.is_empty() or hp_ratio <= float(contract.get("thresholds", {}).get("hp_injured_max", 0.60)):
        return "injured"
    return "healthy"

func _psychological_state(hp: int, fear: int, madness: int, hope: int, affliction: String) -> String:
    if hp <= 0:
        return "neutral"
    var thresholds: Dictionary = contract.get("thresholds", {})
    if fear >= int(thresholds.get("fear_panic_min", 100)):
        return "panic"
    if madness >= int(thresholds.get("madness_fractured_min", 75)):
        return "fractured"
    if fear >= int(thresholds.get("fear_terrified_min", 75)):
        return "terrified"
    if affliction in ["despair", "desespoir", "hopeless"]:
        return "despair"
    if affliction in ["anger", "colere", "rage"]:
        return "anger"
    if hope >= int(thresholds.get("hope_manifest_min", 70)):
        return "hope"
    if fear >= int(thresholds.get("fear_tense_min", 35)):
        return "tense"
    return "neutral"

func _locomotion_state(character: Dictionary, physical_state: String, context: Dictionary) -> String:
    if physical_state == "dead":
        return "idle"
    if physical_state == "mobility_impaired":
        return "limp_walk"
    if bool(context.get("retreating", false)):
        return "retreat"
    var requested: String = str(context.get("locomotion", "idle"))
    return requested if requested in ["idle", "walk", "run", "tactical_step", "retreat"] else "idle"

func _has_leg_loss(character: Dictionary) -> bool:
    for value: Variant in character.get("dismembered_parts", []):
        var part: String = str(value).to_lower()
        if "leg" in part or "jambe" in part:
            return true
    return false
