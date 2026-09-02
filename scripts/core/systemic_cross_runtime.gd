extends Node

signal contextual_choice_recorded(quest_id: String, choice_id: String)
signal external_trigger_recorded(trigger_id: String, context: Dictionary)
signal cross_event_applied(event_id: String, payload: Dictionary)
signal cascade_applied(cascade_id: String, payload: Dictionary)
signal systemic_state_changed

const REGISTRY_PATH := "res://universe/lore/contextual_quest_cross_ramifications.json"
const PRESENTATION_PATH := "res://data/narrative/systemic_cross_runtime.json"
const DIALOGUE_HISTORY_LIMIT := 12
const RELATIONSHIP_HISTORY_LIMIT := 16
const FALLBACK_MEMORY_LIMIT := 20

var registry: Dictionary = {}
var presentation: Dictionary = {}
var contextual_choices: Dictionary = {}
var external_trigger_contexts: Dictionary = {}
var applied_events: Dictionary = {}
var applied_cascades: Dictionary = {}
var recent_dialogues: Array[Dictionary] = []
var route_states: Dictionary = {}
var economy_tags: Array[String] = []
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
    route_states = {}
    economy_tags = []
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
    CampaignState.chapter_flags[_source_choice_flag(quest_id, choice_id)] = true
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
    CampaignState.chapter_flags["systemic_external_" + _safe_id(trigger_id)] = true
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

func route_state(route_id: String) -> String:
    return str(route_states.get(route_id, "unknown"))

func active_economy_tags() -> Array[String]:
    return economy_tags.duplicate()

func market_price_modifier() -> float:
    var modifier := 1.0
    for tag in economy_tags:
        match tag:
            "grain_flow_recovered": modifier -= 0.03
            "food_prices_tense": modifier += 0.02
            "distributed_supply_fragile": modifier += 0.01
            "refugee_capacity_pressure": modifier += 0.02
            "winter_capacity_pressure": modifier += 0.05
            "resource_detour_cost": modifier += 0.03
            "survival_reuse_relief": modifier -= 0.01
    return clampf(modifier, 0.90, 1.15)

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
    var context := _combined_external_context(event.get("external_triggers", []))
    if event_id == "cross.relationship.named_death_after_difficult_choice":
        payload = _named_death_payload(payload, context)
    applied_events[event_id] = {
        "chapter_id": CampaignState.current_chapter_id,
        "context": context.duplicate(true)
    }
    CampaignState.chapter_flags[_event_flag(event_id)] = true
    var title := str(payload.get("title", event_id))
    var hero_ids: Array = event.get("hero_followups", [])
    var source_choices: Array = event.get("all_choices", [])
    context["family"] = str(event.get("family", ""))
    context["possible_death"] = bool(event.get("possible_death", false))
    _apply_world_state(event_id)
    CommunityRuntime.record_systemic_cross_event(event_id, payload, "event")
    _record_decision_memory(event_id, title, source_choices, hero_ids)
    _record_field_memory(event_id, title, str(event.get("family", "")), hero_ids, context)
    _apply_relationship_profile(event_id, hero_ids, str(payload.get("relationship_profile", "none")))
    _apply_psychology_profile(event_id, hero_ids, str(payload.get("psychology_profile", "none")), context)
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
    _apply_world_state(cascade_id)
    CommunityRuntime.record_systemic_cross_event(cascade_id, payload, "cascade")
    _record_decision_memory(cascade_id, title, [], hero_ids)
    _record_field_memory(cascade_id, title, "cascade", hero_ids, context)
    _apply_relationship_profile(cascade_id, hero_ids, str(payload.get("relationship_profile", "none")))
    _apply_psychology_profile(cascade_id, hero_ids, str(payload.get("psychology_profile", "none")), context)
    _emit_dialogues(cascade_id, payload)
    GameState.add_log("CASCADE SYSTÉMIQUE — %s" % title)
    cascade_applied.emit(cascade_id, payload.duplicate(true))
    systemic_state_changed.emit()

func _named_death_payload(source: Dictionary, context: Dictionary) -> Dictionary:
    var payload := source.duplicate(true)
    var dead_name := str(context.get("name", context.get("dead_name", "")))
    var cause := str(context.get("cause", context.get("material_cause", "")))
    if dead_name != "":
        var fact := "Le Mémorial inscrit %s" % dead_name
        if cause != "":
            fact += " avec la cause matérielle consignée : %s" % cause
        fact += "."
        payload["fact"] = fact
        var visual_value: Variant = payload.get("visual", [])
        var visual: Array = visual_value.duplicate() if visual_value is Array else []
        visual.append("nom de %s ajouté au Mémorial sans verdict moral" % dead_name)
        payload["visual"] = visual
    return payload

func _record_decision_memory(event_id: String, title: String, source_choices: Array, hero_ids: Array) -> void:
    DecisionMemoryRuntime.prepare_party()
    var memory_id := "decision:systemic_cross:" + _safe_id(event_id)
    var limit := int(DecisionMemoryRuntime.data.get("history_limit", FALLBACK_MEMORY_LIMIT))
    for hero in _resolve_heroes(hero_ids):
        var memories_value: Variant = hero.get("decision_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        if _memory_exists(memories, memory_id):
            continue
        memories.append({
            "id": memory_id,
            "type": "systemic_cross_event",
            "choice_label": "la conséquence « %s »" % title,
            "chapter_id": CampaignState.current_chapter_id,
            "initial_score": 0,
            "score": 0,
            "initial_stance": "uncertain",
            "stance": "uncertain",
            "source_choices": source_choices.duplicate(true),
            "reevaluations": []
        })
        while memories.size() > limit:
            memories.pop_front()
        hero["decision_memories"] = memories
        DecisionMemoryRuntime.decision_memory_recorded.emit(str(hero.get("id", "")), memory_id)
    DecisionMemoryRuntime.collective_memory.emit("Les conséquences de plusieurs décisions se rencontrent : %s." % title)

func _record_field_memory(event_id: String, title: String, family: String, hero_ids: Array, context: Dictionary) -> void:
    FieldMemoryRuntime.prepare_party()
    var memory_id := "field:systemic_cross:" + _safe_id(event_id)
    var limit := int(FieldMemoryRuntime.data.get("history_limit", FALLBACK_MEMORY_LIMIT))
    for hero in _resolve_heroes(hero_ids):
        var memories_value: Variant = hero.get("field_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        if _memory_exists(memories, memory_id):
            continue
        memories.append({
            "id": memory_id,
            "type": "systemic_cross_event",
            "choice_label": "la conséquence « %s »" % title,
            "chapter_id": CampaignState.current_chapter_id,
            "zone_id": AshlandsRuntime.current_zone_id,
            "witness_mode": "direct",
            "family": family,
            "context": context.duplicate(true),
            "initial_score": 0,
            "score": 0,
            "initial_stance": "uncertain",
            "stance": "uncertain",
            "reevaluations": []
        })
        while memories.size() > limit:
            memories.pop_front()
        hero["field_memories"] = memories
        FieldMemoryRuntime.field_memory_recorded.emit(str(hero.get("id", "")), memory_id)
    FieldMemoryRuntime.field_memory_moment.emit("Le terrain relie désormais plusieurs décisions : %s." % title)

func _memory_exists(memories: Array, memory_id: String) -> bool:
    for value in memories:
        var memory: Dictionary = value if value is Dictionary else {}
        if str(memory.get("id", "")) == memory_id:
            return true
    return false

func _apply_relationship_profile(event_id: String, hero_ids: Array, profile_name: String) -> void:
    var profiles_value: Variant = presentation.get("relationship_profiles", {})
    var profiles: Dictionary = profiles_value if profiles_value is Dictionary else {}
    var profile_value: Variant = profiles.get(profile_name, {})
    var profile: Dictionary = profile_value if profile_value is Dictionary else {}
    if profile.is_empty():
        return
    var heroes := _resolve_heroes(hero_ids)
    if heroes.size() < 2:
        return
    var mode := str(profile.get("mode", "mutual"))
    for left_index in range(heroes.size()):
        for right_index in range(left_index + 1, heroes.size()):
            var left: Dictionary = heroes[left_index]
            var right: Dictionary = heroes[right_index]
            var delta: Dictionary = {}
            if mode == "adaptive_grief":
                var pair := RelationshipRuntime.pair_state(left, right)
                if int(pair.get("trust", 0)) >= 60:
                    delta["trust"] = int(profile.get("trust", 1))
                elif int(pair.get("tension", 0)) >= 45:
                    delta["mistrust"] = int(profile.get("mistrust", 1))
            else:
                for metric in ["trust", "admiration", "mistrust", "resentment"]:
                    if profile.has(metric):
                        delta[metric] = int(profile.get(metric, 0))
            _apply_relation_delta(left, right, delta, event_id)
            _apply_relation_delta(right, left, delta, event_id)
    RelationshipRuntime.relationship_moment.emit("Les héros ne vivent pas de la même manière la conséquence « %s »." % event_id)

func _apply_relation_delta(source: Dictionary, target: Dictionary, delta: Dictionary, event_id: String) -> void:
    if source.is_empty() or target.is_empty():
        return
    var state := RelationshipRuntime.relation(source, target)
    for metric in ["trust", "admiration", "mistrust", "resentment"]:
        if delta.has(metric):
            state[metric] = clampi(int(state.get(metric, 0)) + int(delta.get(metric, 0)), 0, 100)
    var history_value: Variant = state.get("history", [])
    var history: Array = history_value if history_value is Array else []
    var history_id := "systemic_cross:" + event_id
    var seen := false
    for value in history:
        var entry: Dictionary = value if value is Dictionary else {}
        if str(entry.get("event_id", "")) == history_id:
            seen = true
            break
    if not seen:
        history.append({"event_id": history_id, "chapter": CampaignState.current_chapter_id})
    while history.size() > RELATIONSHIP_HISTORY_LIMIT:
        history.pop_front()
    state["history"] = history
    var relationships_value: Variant = source.get("relationships", {})
    var relationships: Dictionary = relationships_value if relationships_value is Dictionary else {}
    relationships[str(target.get("id", ""))] = state
    source["relationships"] = relationships
    RelationshipRuntime.relationship_changed.emit(str(source.get("id", "")), str(target.get("id", "")), history_id)

func _apply_psychology_profile(event_id: String, hero_ids: Array, profile_name: String, context: Dictionary) -> void:
    var profiles_value: Variant = presentation.get("psychology_profiles", {})
    var profiles: Dictionary = profiles_value if profiles_value is Dictionary else {}
    var profile_value: Variant = profiles.get(profile_name, {})
    var profile: Dictionary = profile_value if profile_value is Dictionary else {}
    var fear_delta := int(profile.get("fear_delta", 0))
    if fear_delta <= 0:
        return
    for hero in _resolve_heroes(hero_ids):
        var before := int(hero.get("fear", 0))
        hero["fear"] = clampi(before + fear_delta, 0, 100)
        PsychologyRuntime.record_external_fear(hero, before, "systemic_cross", {
            "event_id": event_id,
            "profile": profile_name,
            "context": context.duplicate(true)
        })
        PsychologyRuntime.hero_psychology_changed.emit(str(hero.get("id", "")), event_id)

func _apply_world_state(item_id: String) -> void:
    match item_id:
        "cross.food.local_security_and_grain_bridge":
            route_states["dhor_khal_grain_bridge"] = "open"
            _add_economy_tag("grain_flow_recovered")
        "cross.food.refugee_seed_and_high_passage":
            route_states["dhor_khal_high_passage"] = "strained"
            _add_economy_tag("food_prices_tense")
        "cross.food.distributed_risk_and_local_repairs":
            route_states["regional_local_routes"] = "distributed"
            _add_economy_tag("distributed_supply_fragile")
        "cross.funeral.body_return_and_medical_corridor":
            route_states["dhor_khal_high_passage"] = "contested_capacity"
        "cross.azravel.survival_and_anonymity", "cross.azravel.distributed_convoy_and_households":
            route_states["azravel_refugee_network"] = "distributed"
            _add_economy_tag("refugee_capacity_pressure")
        "cross.dragon.restraint_under_scarcity":
            route_states["dragon_site_supply_detour"] = "active"
            _add_economy_tag("resource_detour_cost")
        "cross.dragon.extraction_and_survival_first_policy":
            route_states["dragon_site_supply_detour"] = "avoided_by_extraction"
            _add_economy_tag("survival_reuse_relief")
        "cross.consent.refusal_precedent_meets_new_refusal", "cross.consent.reversible_protocol_meets_uncertain_response", "cascade.corridor_of_consent":
            route_states["nonhuman_contact_corridor"] = "regulated"
        "cascade.winter_refugee_pressure":
            _add_economy_tag("winter_capacity_pressure")
        "cascade.memorial_network_under_loss":
            route_states["memorial_network"] = "distributed"

func _add_economy_tag(tag: String) -> void:
    if tag != "" and not economy_tags.has(tag):
        economy_tags.append(tag)

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

func _resolve_heroes(registry_ids: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for registry_value in registry_ids:
        var hero := _alive_hero(str(registry_value))
        if not hero.is_empty() and not result.has(hero):
            result.append(hero)
    return result

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
    var normalized := value.to_lower()
    if normalized.begins_with("hero."):
        normalized = normalized.substr(5)
    return normalized

func serialize() -> Dictionary:
    return {
        "contextual_choices": contextual_choices.duplicate(true),
        "external_trigger_contexts": external_trigger_contexts.duplicate(true),
        "applied_events": applied_events.duplicate(true),
        "applied_cascades": applied_cascades.duplicate(true),
        "recent_dialogues": recent_dialogues.duplicate(true),
        "route_states": route_states.duplicate(true),
        "economy_tags": economy_tags.duplicate()
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
    route_states = payload.get("route_states", {}).duplicate(true)
    economy_tags = _string_array(payload.get("economy_tags", []))
    _sync_campaign_flags_and_evaluate()
    systemic_state_changed.emit()

func _string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for item in value:
            var text := str(item)
            if text != "" and not result.has(text):
                result.append(text)
    return result
