extends Node

signal contextual_choice_recorded(quest_id: String, choice_id: String)
signal external_trigger_recorded(trigger_id: String, context: Dictionary)
signal cross_event_applied(event_id: String, payload: Dictionary)
signal cascade_applied(cascade_id: String, payload: Dictionary)
signal systemic_state_changed

const REGISTRY_PATH := "res://universe/lore/contextual_quest_cross_ramifications.json"
const PRESENTATION_PATH := "res://data/narrative/systemic_cross_runtime.json"
const DIALOGUE_HISTORY_LIMIT := 12

var registry: Dictionary = {}
var presentation: Dictionary = {}
var contextual_choices: Dictionary = {}
var external_trigger_contexts: Dictionary = {}
var applied_events: Dictionary = {}
var applied_cascades: Dictionary = {}
var recent_dialogues: Array[Dictionary] = []
var _known_choice_pairs: Dictionary = {}
var _known_choices_by_quest: Dictionary = {}
var _evaluating: bool = false
var _sync_scheduled: bool = false

func _ready() -> void:
    _load_data()
    reset_new_game()
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not CampaignState.campaign_changed.is_connected(_on_campaign_changed):
        CampaignState.campaign_changed.connect(_on_campaign_changed)
    call_deferred("_sync_campaign_flags_and_evaluate")

func _load_data() -> void:
    registry = _load_json_dictionary(REGISTRY_PATH)
    presentation = _load_json_dictionary(PRESENTATION_PATH)
    _index_known_choices()

func _load_json_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("SystemicCrossRuntime: missing data file " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _index_known_choices() -> void:
    _known_choice_pairs.clear()
    _known_choices_by_quest.clear()
    for event_value in registry.get("cross_events", []):
        var event: Dictionary = event_value if event_value is Dictionary else {}
        for pair_value in event.get("all_choices", []):
            if not (pair_value is Array) or pair_value.size() != 2:
                continue
            var quest_id := str(pair_value[0])
            var choice_id := str(pair_value[1])
            _known_choice_pairs[_pair_key(quest_id, choice_id)] = true
            var choices_value: Variant = _known_choices_by_quest.get(quest_id, [])
            var choices: Array = choices_value if choices_value is Array else []
            if not choices.has(choice_id):
                choices.append(choice_id)
            _known_choices_by_quest[quest_id] = choices

func reset_new_game() -> void:
    contextual_choices = {}
    external_trigger_contexts = {}
    applied_events = {}
    applied_cascades = {}
    recent_dialogues = []
    systemic_state_changed.emit()

func _on_new_game_reset() -> void:
    reset_new_game()

func _on_campaign_changed() -> void:
    if _sync_scheduled:
        return
    _sync_scheduled = true
    call_deferred("_sync_campaign_flags_and_evaluate")

func _sync_campaign_flags_and_evaluate() -> void:
    _sync_scheduled = false
    _sync_applied_flags()
    var changed := false
    for quest_key in _known_choices_by_quest.keys():
        var quest_id := str(quest_key)
        var current := str(contextual_choices.get(quest_id, ""))
        var choices_value: Variant = _known_choices_by_quest.get(quest_id, [])
        var choices: Array = choices_value if choices_value is Array else []
        for choice_value in choices:
            var choice_id := str(choice_value)
            if not bool(CampaignState.chapter_flags.get(_source_choice_flag(quest_id, choice_id), false)):
                continue
            if current == "":
                contextual_choices[quest_id] = choice_id
                current = choice_id
                changed = true
            elif current != choice_id:
                push_warning("SystemicCrossRuntime: conflicting saved choices for %s; keeping %s" % [quest_id, current])
    _evaluate_all()
    if changed:
        systemic_state_changed.emit()

func record_contextual_choice(quest_id: String, choice_id: String) -> bool:
    if not bool(_known_choice_pairs.get(_pair_key(quest_id, choice_id), false)):
        return false
    var previous := str(contextual_choices.get(quest_id, ""))
    if previous == choice_id:
        _evaluate_all()
        return false
    if previous != "" and previous != choice_id:
        push_warning("SystemicCrossRuntime: refusing second choice for %s (%s -> %s)" % [quest_id, previous, choice_id])
        return false
    contextual_choices[quest_id] = choice_id
    contextual_choice_recorded.emit(quest_id, choice_id)
    _evaluate_all()
    systemic_state_changed.emit()
    return true

func record_external_trigger(trigger_id: String, context: Dictionary = {}) -> bool:
    var allowed: Array = registry.get("external_triggers", [])
    if not allowed.has(trigger_id):
        return false
    var already := external_trigger_contexts.has(trigger_id)
    external_trigger_contexts[trigger_id] = context.duplicate(true)
    if not already:
        external_trigger_recorded.emit(trigger_id, context.duplicate(true))
    _evaluate_all()
    systemic_state_changed.emit()
    return not already

func has_contextual_choice(quest_id: String, choice_id: String) -> bool:
    return str(contextual_choices.get(quest_id, "")) == choice_id

func has_external_trigger(trigger_id: String) -> bool:
    return external_trigger_contexts.has(trigger_id)

func event_applied(event_id: String) -> bool:
    return applied_events.has(event_id)

func cascade_is_applied(cascade_id: String) -> bool:
    return applied_cascades.has(cascade_id)

func applied_event_ids() -> Array[String]:
    var result: Array[String] = []
    for value in applied_events.keys():
        result.append(str(value))
    result.sort()
    return result

func applied_cascade_ids() -> Array[String]:
    var result: Array[String] = []
    for value in applied_cascades.keys():
        result.append(str(value))
    result.sort()
    return result

func recent_dialogue_lines(limit: int = 4) -> Array[String]:
    var result: Array[String] = []
    for index in range(recent_dialogues.size() - 1, -1, -1):
        if result.size() >= limit:
            break
        var entry: Dictionary = recent_dialogues[index]
        var speaker := str(entry.get("speaker", ""))
        var text := str(entry.get("text", ""))
        if text == "":
            continue
        result.append("%s — %s" % [speaker, text] if speaker != "" else text)
    return result

func state_summary() -> String:
    return "%d choix · %d croisement(s) · %d cascade(s)" % [contextual_choices.size(), applied_events.size(), applied_cascades.size()]

func _evaluate_all() -> void:
    if _evaluating:
        return
    _evaluating = true
    var progress := true
    while progress:
        progress = false
        for event_value in registry.get("cross_events", []):
            var event: Dictionary = event_value if event_value is Dictionary else {}
            var event_id := str(event.get("id", ""))
            if event_id == "" or applied_events.has(event_id):
                continue
            if not _event_ready(event):
                continue
            _apply_event(event)
            progress = true
        for cascade_value in registry.get("compound_cascades", []):
            var cascade: Dictionary = cascade_value if cascade_value is Dictionary else {}
            var cascade_id := str(cascade.get("id", ""))
            if cascade_id == "" or applied_cascades.has(cascade_id):
                continue
            if not _cascade_ready(cascade):
                continue
            _apply_cascade(cascade)
            progress = true
    _evaluating = false

func _event_ready(event: Dictionary) -> bool:
    if CampaignState.current_chapter_number() < int(event.get("first_possible_chapter", 1)):
        return false
    for pair_value in event.get("all_choices", []):
        if not (pair_value is Array) or pair_value.size() != 2:
            return false
        if not has_contextual_choice(str(pair_value[0]), str(pair_value[1])):
            return false
    for trigger_value in event.get("external_triggers", []):
        if not has_external_trigger(str(trigger_value)):
            return false
    if bool(event.get("requires_prior_contextual_choice", false)) and contextual_choices.is_empty():
        return false
    return true

func _cascade_ready(cascade: Dictionary) -> bool:
    var required_events: Array = cascade.get("requires_any_cross_events", [])
    if required_events.is_empty():
        return false
    var any_event := false
    for event_value in required_events:
        if applied_events.has(str(event_value)):
            any_event = true
            break
    if not any_event:
        return false
    for trigger_value in cascade.get("requires_external", []):
        if not has_external_trigger(str(trigger_value)):
            return false
    return true

func _apply_event(event: Dictionary) -> void:
    var event_id := str(event.get("id", ""))
    var payload := _presentation_for(event_id, false)
    applied_events[event_id] = {
        "chapter_id": CampaignState.current_chapter_id,
        "context": _combined_external_context(event.get("external_triggers", []))
    }
    CampaignState.chapter_flags[_event_flag(event_id)] = true
    var title := str(payload.get("title", event_id))
    var hero_ids: Array = event.get("hero_followups", [])
    var source_choices: Array = event.get("all_choices", [])
    var context := _combined_external_context(event.get("external_triggers", []))
    context["family"] = str(event.get("family", ""))
    context["possible_death"] = bool(event.get("possible_death", false))
    CommunityRuntime.record_systemic_cross_event(event_id, payload, "event")
    DecisionMemoryRuntime.record_contextual_cross_event(event_id, title, source_choices, hero_ids)
    FieldMemoryRuntime.record_contextual_cross_event(event_id, title, str(event.get("family", "")), hero_ids, context)
    RelationshipRuntime.record_contextual_cross_event(event_id, hero_ids, str(payload.get("relationship_profile", "none")), context)
    PsychologyRuntime.record_contextual_cross_event(event_id, hero_ids, str(payload.get("psychology_profile", "none")), context)
    _emit_dialogues(event_id, payload)
    GameState.add_log("CONSÉQUENCE CROISÉE — %s" % title)
    cross_event_applied.emit(event_id, payload.duplicate(true))
    systemic_state_changed.emit()

func _apply_cascade(cascade: Dictionary) -> void:
    var cascade_id := str(cascade.get("id", ""))
    var payload := _presentation_for(cascade_id, true)
    applied_cascades[cascade_id] = {"chapter_id": CampaignState.current_chapter_id}
    CampaignState.chapter_flags[_cascade_flag(cascade_id)] = true
    var title := str(payload.get("title", cascade_id))
    var hero_ids := _cascade_hero_ids(cascade)
    var context := _combined_external_context(cascade.get("requires_external", []))
    context["cascade"] = true
    context["source_cross_events"] = cascade.get("requires_any_cross_events", []).duplicate()
    CommunityRuntime.record_systemic_cross_event(cascade_id, payload, "cascade")
    DecisionMemoryRuntime.record_contextual_cross_event(cascade_id, title, [], hero_ids)
    FieldMemoryRuntime.record_contextual_cross_event(cascade_id, title, "cascade", hero_ids, context)
    RelationshipRuntime.record_contextual_cross_event(cascade_id, hero_ids, str(payload.get("relationship_profile", "none")), context)
    PsychologyRuntime.record_contextual_cross_event(cascade_id, hero_ids, str(payload.get("psychology_profile", "none")), context)
    _emit_dialogues(cascade_id, payload)
    GameState.add_log("CASCADE SYSTÉMIQUE — %s" % title)
    cascade_applied.emit(cascade_id, payload.duplicate(true))
    systemic_state_changed.emit()

func _presentation_for(item_id: String, cascade: bool) -> Dictionary:
    var section_name := "cascades" if cascade else "events"
    var section_value: Variant = presentation.get(section_name, {})
    var section: Dictionary = section_value if section_value is Dictionary else {}
    var payload_value: Variant = section.get(item_id, {})
    return payload_value.duplicate(true) if payload_value is Dictionary else {}

func _emit_dialogues(event_id: String, payload: Dictionary) -> void:
    for line_value in payload.get("dialogue", []):
        var line: Dictionary = line_value if line_value is Dictionary else {}
        var hero := _alive_hero(str(line.get("speaker_id", "")))
        if hero.is_empty():
            continue
        var text := str(line.get("text", ""))
        if text == "":
            continue
        var entry := {
            "event_id": event_id,
            "speaker_id": str(hero.get("id", "")),
            "speaker": str(hero.get("name", "Héros")),
            "text": text,
            "chapter_id": CampaignState.current_chapter_id
        }
        recent_dialogues.append(entry)
        while recent_dialogues.size() > DIALOGUE_HISTORY_LIMIT:
            recent_dialogues.pop_front()
        GameState.add_log("%s — %s" % [str(entry.get("speaker", "Héros")), text])

func _alive_hero(registry_id: String) -> Dictionary:
    var normalized := _normalize_hero_id(registry_id)
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value if hero_value is Dictionary else {}
        if _normalize_hero_id(str(hero.get("id", ""))) == normalized:
            return hero
    return {}

func _cascade_hero_ids(cascade: Dictionary) -> Array:
    var result: Array = []
    for event_value in cascade.get("requires_any_cross_events", []):
        var event := _event_definition(str(event_value))
        for hero_value in event.get("hero_followups", []):
            var hero_id := str(hero_value)
            if not result.has(hero_id):
                result.append(hero_id)
    return result

func _event_definition(event_id: String) -> Dictionary:
    for event_value in registry.get("cross_events", []):
        var event: Dictionary = event_value if event_value is Dictionary else {}
        if str(event.get("id", "")) == event_id:
            return event
    return {}

func _combined_external_context(trigger_values: Array) -> Dictionary:
    var result: Dictionary = {}
    for trigger_value in trigger_values:
        var trigger_id := str(trigger_value)
        var context_value: Variant = external_trigger_contexts.get(trigger_id, {})
        var context: Dictionary = context_value if context_value is Dictionary else {}
        result[trigger_id] = context.duplicate(true)
        for key_value in context.keys():
            var key := str(key_value)
            if not result.has(key):
                result[key] = context.get(key_value)
    return result

func _sync_applied_flags() -> void:
    for event_value in registry.get("cross_events", []):
        var event: Dictionary = event_value if event_value is Dictionary else {}
        var event_id := str(event.get("id", ""))
        if event_id != "" and bool(CampaignState.chapter_flags.get(_event_flag(event_id), false)) and not applied_events.has(event_id):
            applied_events[event_id] = {"chapter_id": CampaignState.current_chapter_id, "restored_from_flag": true}
    for cascade_value in registry.get("compound_cascades", []):
        var cascade: Dictionary = cascade_value if cascade_value is Dictionary else {}
        var cascade_id := str(cascade.get("id", ""))
        if cascade_id != "" and bool(CampaignState.chapter_flags.get(_cascade_flag(cascade_id), false)) and not applied_cascades.has(cascade_id):
            applied_cascades[cascade_id] = {"chapter_id": CampaignState.current_chapter_id, "restored_from_flag": true}

func _source_choice_flag(quest_id: String, choice_id: String) -> String:
    return "%s_%s" % [quest_id, choice_id]

func _event_flag(event_id: String) -> String:
    return "systemic_cross_event_%s" % _safe_id(event_id)

func _cascade_flag(cascade_id: String) -> String:
    return "systemic_cross_cascade_%s" % _safe_id(cascade_id)

func _safe_id(value: String) -> String:
    return value.replace(".", "_").replace(":", "_").replace("/", "_")

func _pair_key(quest_id: String, choice_id: String) -> String:
    return quest_id + "|" + choice_id

func _normalize_hero_id(value: String) -> String:
    return value.trim_prefix("hero.").to_lower()

func serialize() -> Dictionary:
    return {
        "contextual_choices": contextual_choices.duplicate(true),
        "external_trigger_contexts": external_trigger_contexts.duplicate(true),
        "applied_events": applied_events.duplicate(true),
        "applied_cascades": applied_cascades.duplicate(true),
        "recent_dialogues": recent_dialogues.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    contextual_choices = payload.get("contextual_choices", {}).duplicate(true)
    external_trigger_contexts = payload.get("external_trigger_contexts", {}).duplicate(true)
    applied_events = payload.get("applied_events", {}).duplicate(true)
    applied_cascades = payload.get("applied_cascades", {}).duplicate(true)
    recent_dialogues = []
    var dialogues_value: Variant = payload.get("recent_dialogues", [])
    if dialogues_value is Array:
        for value in dialogues_value:
            if value is Dictionary:
                recent_dialogues.append(value.duplicate(true))
    _sync_campaign_flags_and_evaluate()
    systemic_state_changed.emit()
