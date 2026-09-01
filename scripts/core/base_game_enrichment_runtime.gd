extends Node

signal enrichment_selected(payload: Dictionary)
signal enrichment_exhausted(category: String, trigger: String)

const DATA_PATH := "res://data/narrative/base_game_enrichment.json"

var data: Dictionary = {}
var used_ids: Dictionary = {}
var trigger_counts: Dictionary = {}

func _ready() -> void:
    _load()

func _load() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("BaseGameEnrichmentRuntime: missing " + DATA_PATH)
        data = {}
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func is_cycle_zero() -> bool:
    return EndgameState.active_cycle <= 0

func request_optional(trigger: String, context: Dictionary = {}) -> Dictionary:
    return _request_from("optional_conversations", trigger, context)

func request_rare(event_id: String, context: Dictionary = {}) -> Dictionary:
    return _request_from("rare_reactions", event_id, context, "event")

func request_banter(trigger: String, context: Dictionary = {}) -> Dictionary:
    return _request_from("expedition_banter", trigger, context)

func request_relationship(trigger: String, relation_id: String, relation_state: String, context: Dictionary = {}) -> Dictionary:
    var enriched := context.duplicate(true)
    enriched["relation"] = relation_id
    enriched["state"] = relation_state
    return _request_from("relationship_variants", trigger, enriched)

func _request_from(category: String, trigger: String, context: Dictionary, trigger_key: String = "trigger") -> Dictionary:
    if not is_cycle_zero():
        return {"mode":"silence", "reason":"cycle_initial_only", "category":category}
    var candidates: Array[Dictionary] = []
    var current_chapter := int(context.get("chapter", CampaignState.current_chapter_number()))
    for value: Variant in data.get(category, []):
        var entry: Dictionary = value if value is Dictionary else {}
        if str(entry.get(trigger_key, "")) != trigger:
            continue
        if int(entry.get("chapter", current_chapter)) != current_chapter:
            continue
        var entry_id := str(entry.get("id", ""))
        if entry_id == "" or bool(used_ids.get(entry_id, false)):
            continue
        if not _conditions_match(entry, context):
            continue
        candidates.append(entry.duplicate(true))
    if candidates.is_empty():
        enrichment_exhausted.emit(category, trigger)
        return {"mode":"silence", "category":category, "trigger":trigger}
    candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return str(left.get("id", "")) < str(right.get("id", ""))
    )
    var count_key := category + "|" + trigger
    var count := int(trigger_counts.get(count_key, 0))
    var selected := candidates[count % candidates.size()].duplicate(true)
    trigger_counts[count_key] = count + 1
    var selected_id := str(selected.get("id", ""))
    used_ids[selected_id] = true
    selected["mode"] = "enrichment"
    selected["category"] = category
    enrichment_selected.emit(selected.duplicate(true))
    return selected

func _conditions_match(entry: Dictionary, context: Dictionary) -> bool:
    for value: Variant in entry.get("requires_flags", []):
        var flag := str(value)
        if not bool(CampaignState.chapter_flags.get(flag, false)):
            return false
    var any_flags: Array = entry.get("requires_any_flags", [])
    if not any_flags.is_empty():
        var found := false
        for value: Variant in any_flags:
            if bool(CampaignState.chapter_flags.get(str(value), false)):
                found = true
                break
        if not found:
            return false
    var forbidden_flags: Array = entry.get("forbids_flags", [])
    for value: Variant in forbidden_flags:
        if bool(CampaignState.chapter_flags.get(str(value), false)):
            return false
    if entry.has("relation") and str(entry.get("relation", "")) != str(context.get("relation", "")):
        return false
    if entry.has("state") and str(entry.get("state", "")) != str(context.get("state", "")):
        return false
    return true

func log_payload(payload: Dictionary) -> void:
    if str(payload.get("mode", "")) != "enrichment":
        return
    if payload.has("lines"):
        for value: Variant in payload.get("lines", []):
            if value is Dictionary:
                var line: Dictionary = value
                GameState.add_log("%s — %s" % [str(line.get("speaker", "")), str(line.get("text", ""))])
            elif str(payload.get("speaker", "")) != "":
                GameState.add_log("%s — %s" % [str(payload.get("speaker", "")), str(value)])
    elif payload.has("text"):
        GameState.add_log("%s — %s" % [str(payload.get("speaker", "Narration")), str(payload.get("text", ""))])

func record_side_story_event(event_id: String, target_id: String, amount: int = 1) -> void:
    SideQuestRuntime.record_event(event_id, target_id, amount)

func record_side_story_choice(target_id: String, choice_id: String) -> void:
    SideQuestRuntime.record_choice(target_id, choice_id)

func reset_session() -> void:
    used_ids.clear()
    trigger_counts.clear()

func serialize() -> Dictionary:
    return {"used_ids":used_ids.duplicate(true), "trigger_counts":trigger_counts.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    used_ids = payload.get("used_ids", {}).duplicate(true)
    trigger_counts = payload.get("trigger_counts", {}).duplicate(true)
