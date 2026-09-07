extends RefCounted
class_name VeilleursRemanencePolicy

signal rank_changed(entity_id: String, previous_rank: String, new_rank: String, state: Dictionary)
signal memory_changed(entity_id: String, state: Dictionary)

const CONTRACT_PATH := "res://data/veilleurs/remanence_adaptation_hooks_v1.json"
const RANK_ORDER := ["normal", "memorial", "veteran", "elite", "nemesis"]
const PROMOTION_EVENTS := [
    "survival",
    "watcher_kill",
    "mutilation",
    "escape",
    "failed_capture",
    "important_item_taken_or_recovered",
    "forced_retreat",
    "repeated_encounter"
]
const MAJOR_ANCHORS := [
    "watcher_kill",
    "mutilation",
    "failed_capture",
    "important_item_taken_or_recovered",
    "forced_retreat"
]
const REQUIRES_ALIVE := [
    "survival",
    "watcher_kill",
    "mutilation",
    "escape",
    "failed_capture",
    "forced_retreat"
]
const CHANNELS := ["threat_family", "positioning", "capture", "relationship"]

var contract: Dictionary = {}
var entity_states: Dictionary = {}
var sequence := 0

func _init() -> void:
    contract = _load_dictionary(CONTRACT_PATH)

func reset() -> void:
    entity_states.clear()
    sequence = 0

func serialize() -> Dictionary:
    return {
        "version": 1,
        "sequence": sequence,
        "entity_states": entity_states.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    reset()
    if payload.is_empty():
        return
    sequence = maxi(0, int(payload.get("sequence", 0)))
    var incoming: Dictionary = payload.get("entity_states", {})
    for entity_id_value: Variant in incoming.keys():
        restore_entity_state(str(entity_id_value), incoming.get(entity_id_value, {}))

func restore_entity_state(entity_id: String, payload: Dictionary) -> bool:
    if entity_id.is_empty() or payload.is_empty():
        return false
    var restored := payload.duplicate(true)
    restored["entity_id"] = entity_id
    var rank_value := str(restored.get("memory_rank", "normal"))
    if not rank_value in RANK_ORDER:
        restored["memory_rank"] = "normal"
    var channels: Dictionary = restored.get("memory_channels", {})
    for channel: String in CHANNELS:
        if not channels.has(channel) or not (channels.get(channel) is Dictionary):
            channels[channel] = {}
    restored["memory_channels"] = channels
    for array_key: String in ["events", "applied_lessons", "group_influence", "major_anchors"]:
        if not (restored.get(array_key, []) is Array):
            restored[array_key] = []
    restored["last_promotion_seq"] = maxi(0, int(restored.get("last_promotion_seq", 0)))
    entity_states[entity_id] = restored
    sequence = maxi(sequence, _max_state_sequence(restored))
    return true

func ensure_entity(entity_id: String, species_id: String = "") -> Dictionary:
    if entity_id.is_empty():
        return {}
    if not entity_states.has(entity_id):
        entity_states[entity_id] = {
            "entity_id": entity_id,
            "species_id": species_id,
            "memory_rank": "normal",
            "events": [],
            "memory_channels": {
                "threat_family": {},
                "positioning": {},
                "capture": {},
                "relationship": {}
            },
            "applied_lessons": [],
            "group_influence": [],
            "major_anchors": [],
            "last_promotion_seq": 0
        }
    elif not species_id.is_empty():
        var existing: Dictionary = entity_states[entity_id]
        existing["species_id"] = species_id
        entity_states[entity_id] = existing
    return state(entity_id)

func note_event(entity_id: String, event_type: String, payload: Dictionary = {}) -> Dictionary:
    if entity_id.is_empty() or not event_type in PROMOTION_EVENTS:
        return {"ok": false, "reason": "invalid_promotion_event", "entity_id": entity_id, "event_type": event_type}
    if event_type in REQUIRES_ALIVE and payload.has("entity_alive") and not bool(payload.get("entity_alive", false)):
        return {"ok": false, "reason": "event_requires_living_entity", "entity_id": entity_id, "event_type": event_type}
    ensure_entity(entity_id, str(payload.get("species_id", "")))
    sequence += 1
    var current: Dictionary = entity_states[entity_id]
    var event := {
        "seq": sequence,
        "type": event_type,
        "payload": payload.duplicate(true)
    }
    (current["events"] as Array).append(event)

    _learn_from_event(current, event_type, payload, sequence)
    if event_type in MAJOR_ANCHORS and _is_shared_history_event(event_type, payload):
        (current["major_anchors"] as Array).append({
            "seq": sequence,
            "type": event_type,
            "payload": payload.duplicate(true)
        })

    entity_states[entity_id] = current
    if str(current.get("memory_rank", "normal")) == "normal" and _is_shared_history_event(event_type, payload):
        _promote(entity_id, "memorial")
    elif str(current.get("memory_rank", "normal")) == "elite" and event_type == "repeated_encounter":
        _try_nemesis_promotion(entity_id, event)

    memory_changed.emit(entity_id, state(entity_id))
    return {"ok": true, "event": event, "state": state(entity_id)}

func apply_lesson(entity_id: String, channel: String, context: Dictionary = {}) -> Dictionary:
    if not entity_states.has(entity_id):
        return {"ok": false, "reason": "unknown_entity"}
    if not channel in CHANNELS:
        return {"ok": false, "reason": "invalid_memory_channel"}
    var current: Dictionary = entity_states[entity_id]
    var learned: Dictionary = (current.get("memory_channels", {}) as Dictionary).get(channel, {})
    if learned.is_empty():
        return {"ok": false, "reason": "no_lived_lesson_in_channel", "channel": channel}
    if not bool(context.get("later_encounter", false)):
        return {"ok": false, "reason": "lesson_must_be_reused_in_later_encounter"}
    if not bool(context.get("changed_decision", false)):
        return {"ok": false, "reason": "lesson_did_not_change_decision"}

    sequence += 1
    var application := {
        "seq": sequence,
        "channel": channel,
        "lesson": learned.duplicate(true),
        "context": context.duplicate(true)
    }
    (current["applied_lessons"] as Array).append(application)
    entity_states[entity_id] = current
    if str(current.get("memory_rank", "normal")) == "memorial":
        _promote(entity_id, "veteran")
    memory_changed.emit(entity_id, state(entity_id))
    return {"ok": true, "application": application, "state": state(entity_id)}

func note_group_influence(entity_id: String, channel: String, context: Dictionary = {}) -> Dictionary:
    if not entity_states.has(entity_id):
        return {"ok": false, "reason": "unknown_entity"}
    var current: Dictionary = entity_states[entity_id]
    if str(current.get("memory_rank", "normal")) != "veteran":
        return {"ok": false, "reason": "veteran_required"}
    if not channel in CHANNELS:
        return {"ok": false, "reason": "invalid_memory_channel"}
    var learned: Dictionary = (current.get("memory_channels", {}) as Dictionary).get(channel, {})
    if learned.is_empty():
        return {"ok": false, "reason": "group_influence_requires_lived_lesson"}
    if not bool(context.get("later_encounter", false)):
        return {"ok": false, "reason": "group_influence_requires_later_encounter"}
    if not bool(context.get("used_existing_skill", false)):
        return {"ok": false, "reason": "group_influence_must_use_existing_skill"}
    if not bool(context.get("influenced_group", false)):
        return {"ok": false, "reason": "no_material_group_influence"}

    sequence += 1
    var influence := {
        "seq": sequence,
        "channel": channel,
        "lesson": learned.duplicate(true),
        "context": context.duplicate(true)
    }
    (current["group_influence"] as Array).append(influence)
    entity_states[entity_id] = current
    _promote(entity_id, "elite")
    memory_changed.emit(entity_id, state(entity_id))
    return {"ok": true, "influence": influence, "state": state(entity_id)}

func state(entity_id: String) -> Dictionary:
    return (entity_states.get(entity_id, {}) as Dictionary).duplicate(true)

func rank(entity_id: String) -> String:
    return str((entity_states.get(entity_id, {}) as Dictionary).get("memory_rank", "normal"))

func _learn_from_event(current: Dictionary, event_type: String, payload: Dictionary, seq: int) -> void:
    var candidates: Array[String] = []
    match event_type:
        "survival": candidates = ["threat_family", "positioning"]
        "watcher_kill": candidates = ["relationship", "threat_family"]
        "mutilation": candidates = ["threat_family", "relationship"]
        "escape": candidates = ["positioning", "relationship"]
        "failed_capture": candidates = ["capture", "relationship"]
        "important_item_taken_or_recovered": candidates = ["relationship", "positioning"]
        "forced_retreat": candidates = ["threat_family", "positioning", "relationship"]
        "repeated_encounter": candidates = [] # Re-encounter reuses existing proof; it never invents new knowledge.
    for channel: String in candidates:
        var value := _channel_value(channel, payload)
        if value.is_empty():
            continue
        var channels: Dictionary = current["memory_channels"]
        var existing: Dictionary = channels.get(channel, {})
        var salience := int(payload.get("salience", 1))
        if existing.is_empty() or salience >= int(existing.get("salience", 0)):
            channels[channel] = {
                "value": value,
                "source_event": event_type,
                "source_seq": seq,
                "salience": salience
            }
        current["memory_channels"] = channels

func _channel_value(channel: String, payload: Dictionary) -> String:
    match channel:
        "threat_family":
            for key: String in ["intent_family", "source_intent_family", "trigger_intent_family", "last_player_intent_family"]:
                var value := str(payload.get(key, ""))
                if not value.is_empty(): return value
        "positioning":
            for key: String in ["exit_axis", "positioning", "terrain_factor", "cover_type"]:
                var value := str(payload.get(key, ""))
                if not value.is_empty(): return value
        "capture":
            return str(payload.get("capture_method", ""))
        "relationship":
            for key: String in ["watcher_id", "initiator", "responsible_actor_if_known", "opposing_actor", "source_actor", "pursuer"]:
                var value := str(payload.get(key, ""))
                if not value.is_empty(): return value
    return ""

func _is_shared_history_event(event_type: String, payload: Dictionary) -> bool:
    if bool(payload.get("shared_history", false)):
        return true
    if event_type in MAJOR_ANCHORS:
        return bool(payload.get("direct_exchange", true))
    if event_type in ["survival", "escape"]:
        return bool(payload.get("direct_exchange", false))
    if event_type == "repeated_encounter":
        return bool(payload.get("direct_confrontation", false)) or not (payload.get("recognized_watchers", []) as Array).is_empty()
    return false

func _try_nemesis_promotion(entity_id: String, reencounter_event: Dictionary) -> void:
    var current: Dictionary = entity_states[entity_id]
    if not bool((reencounter_event.get("payload", {}) as Dictionary).get("direct_confrontation", false)):
        return
    var anchors: Array = current.get("major_anchors", [])
    if anchors.is_empty():
        return
    var last_anchor_seq := int((anchors.back() as Dictionary).get("seq", 0))
    if int(reencounter_event.get("seq", 0)) <= last_anchor_seq:
        return
    _promote(entity_id, "nemesis")

func _promote(entity_id: String, new_rank: String) -> void:
    if not entity_states.has(entity_id) or not new_rank in RANK_ORDER:
        return
    var current: Dictionary = entity_states[entity_id]
    var previous := str(current.get("memory_rank", "normal"))
    if RANK_ORDER.find(new_rank) <= RANK_ORDER.find(previous):
        return
    current["memory_rank"] = new_rank
    current["last_promotion_seq"] = sequence
    entity_states[entity_id] = current
    rank_changed.emit(entity_id, previous, new_rank, state(entity_id))

func _max_state_sequence(payload: Dictionary) -> int:
    var maximum := int(payload.get("last_promotion_seq", 0))
    for array_key: String in ["events", "applied_lessons", "group_influence", "major_anchors"]:
        for value: Variant in payload.get(array_key, []):
            if value is Dictionary:
                maximum = maxi(maximum, int((value as Dictionary).get("seq", 0)))
    for channel_value: Variant in (payload.get("memory_channels", {}) as Dictionary).values():
        if channel_value is Dictionary:
            maximum = maxi(maximum, int((channel_value as Dictionary).get("source_seq", 0)))
    return maximum

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
