extends Node

signal afterlife_phase_applied(source_id: String, phase: String, payload: Dictionary)
signal relationship_echo_recorded(source_id: String, echo: Dictionary)
signal remanence_emerged(source_id: String, remanence: Dictionary)
signal afterlife_beat_presented(source_id: String, phase: String, payload: Dictionary)
signal afterlife_state_changed

const DATA_PATH := "res://data/narrative/systemic_cross_afterlives.json"

var data: Dictionary = {}
var pending_beats: Array[Dictionary] = []
var _sync_scheduled: bool = false
var _presenting: bool = false
var _immediate_scene_presented_this_entry: bool = false

func _ready() -> void:
    _load_data()
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not CampaignState.campaign_changed.is_connected(_on_campaign_changed):
        CampaignState.campaign_changed.connect(_on_campaign_changed)
    if not SystemicCrossRuntime.cross_event_applied.is_connected(_on_source_applied):
        SystemicCrossRuntime.cross_event_applied.connect(_on_source_applied)
    if not SystemicCrossRuntime.cascade_applied.is_connected(_on_source_applied):
        SystemicCrossRuntime.cascade_applied.connect(_on_source_applied)
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not SystemicCrossNarrativeRuntime.scene_presented.is_connected(_on_immediate_scene_presented):
        SystemicCrossNarrativeRuntime.scene_presented.connect(_on_immediate_scene_presented)
    call_deferred("_schedule_sync")

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("SystemicCrossAfterlifeRuntime: missing data file " + DATA_PATH)
        data = {}
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func reset_new_game() -> void:
    pending_beats = []
    _sync_scheduled = false
    _presenting = false
    _immediate_scene_presented_this_entry = false
    afterlife_state_changed.emit()

func _on_new_game_reset() -> void:
    reset_new_game()

func _on_campaign_changed() -> void:
    _schedule_sync()

func _on_source_applied(_source_id: String, _payload: Dictionary) -> void:
    _schedule_sync()

func _schedule_sync() -> void:
    if _sync_scheduled:
        return
    _sync_scheduled = true
    call_deferred("_sync_due_phases")

func _sync_due_phases() -> void:
    _sync_scheduled = false
    for source_id: String in SystemicCrossRuntime.applied_event_ids():
        _sync_source(source_id, false)
    for source_id: String in SystemicCrossRuntime.applied_cascade_ids():
        _sync_source(source_id, true)
    afterlife_state_changed.emit()

func _sync_source(source_id: String, is_cascade: bool) -> void:
    var source_state: Dictionary = _source_state(source_id, is_cascade)
    if source_state.is_empty():
        return
    var source_index: int = CampaignState.chapter_index(str(source_state.get("chapter_id", "")))
    var current_index: int = CampaignState.chapter_index(CampaignState.current_chapter_id)
    if source_index < 0 or current_index < 0 or current_index <= source_index:
        return
    var rules_value: Variant = data.get("rules", {})
    var rules: Dictionary = rules_value if rules_value is Dictionary else {}
    var echo_offset: int = maxi(1, int(rules.get("echo_chapter_offset", 1)))
    var remanence_offset: int = maxi(echo_offset + 1, int(rules.get("remanence_chapter_offset", 2)))
    var afterlife: Dictionary = _afterlife_state(source_state)

    var echo_target: int = _target_index(source_index, echo_offset)
    if current_index >= echo_target and not bool(afterlife.get("echo_applied", false)):
        _apply_echo(source_id, is_cascade, source_state, afterlife)
        source_state = _source_state(source_id, is_cascade)
        afterlife = _afterlife_state(source_state)
    elif bool(afterlife.get("echo_applied", false)) and not _phase_presented(afterlife, "echo"):
        _queue_beat(source_id, is_cascade, "echo")

    var remanence_target: int = _target_index(source_index, remanence_offset)
    if current_index >= remanence_target and not bool(afterlife.get("remanence_applied", false)):
        _apply_remanence(source_id, is_cascade, source_state, afterlife)
    elif bool(afterlife.get("remanence_applied", false)) and not _phase_presented(afterlife, "remanence"):
        _queue_beat(source_id, is_cascade, "remanence")

func _target_index(source_index: int, offset: int) -> int:
    var final_index: int = maxi(0, CampaignState.chapters().size() - 1)
    var target: int = source_index + offset
    var rules_value: Variant = data.get("rules", {})
    var rules: Dictionary = rules_value if rules_value is Dictionary else {}
    if bool(rules.get("clamp_to_final_chapter", true)):
        target = mini(target, final_index)
    return maxi(source_index + 1, target)

func _apply_echo(source_id: String, is_cascade: bool, source_state: Dictionary, afterlife: Dictionary) -> void:
    var profile: Dictionary = _profile_for(source_id, is_cascade)
    if profile.is_empty():
        return
    var context: Dictionary = _source_context(source_state)
    var title: String = _source_title(source_id, is_cascade, context)
    var rumor_text: String = _replace_tokens(str(profile.get("echo_rumor", "")), title, context)
    var rumor_payload: Dictionary = {
        "rumors": [{
            "reliability": "variable",
            "text": rumor_text
        }]
    }
    if rumor_text != "":
        CommunityRuntime.record_systemic_cross_event("afterlife.echo." + source_id, rumor_payload, "afterlife_echo")

    var relationship_profile: String = str(_source_presentation(source_id, is_cascade).get("relationship_profile", "none"))
    var relationship_echo: Dictionary = _build_relationship_echo(source_id, is_cascade, relationship_profile, profile)
    if not relationship_echo.is_empty():
        var echoes_value: Variant = afterlife.get("relationship_echoes", [])
        var echoes: Array = echoes_value if echoes_value is Array else []
        if not _echo_exists(echoes, str(relationship_echo.get("id", ""))):
            echoes.append(relationship_echo)
            afterlife["relationship_echoes"] = echoes
            relationship_echo_recorded.emit(source_id, relationship_echo.duplicate(true))

    afterlife["echo_applied"] = true
    afterlife["echo_chapter_id"] = CampaignState.current_chapter_id
    afterlife["source_title"] = title
    source_state["afterlife"] = afterlife
    _store_source_state(source_id, is_cascade, source_state)
    _queue_beat(source_id, is_cascade, "echo")
    var payload: Dictionary = {
        "title": title,
        "rumor": rumor_text,
        "relationship_echo": relationship_echo.duplicate(true)
    }
    afterlife_phase_applied.emit(source_id, "echo", payload)

func _apply_remanence(source_id: String, is_cascade: bool, source_state: Dictionary, afterlife: Dictionary) -> void:
    var profile: Dictionary = _profile_for(source_id, is_cascade)
    if profile.is_empty():
        return
    var context: Dictionary = _source_context(source_state)
    var title: String = _source_title(source_id, is_cascade, context)
    var source_presentation: Dictionary = _source_presentation(source_id, is_cascade)
    var source_definition: Dictionary = _source_definition(source_id, is_cascade)
    var future_seed: String = str(profile.get("remanence_future", source_definition.get("remanence_future", "")))
    var remanence_rumor: String = _replace_tokens(str(profile.get("remanence_rumor", "")), title, context)
    var relationship_echoes_value: Variant = afterlife.get("relationship_echoes", [])
    var relationship_echoes: Array = relationship_echoes_value if relationship_echoes_value is Array else []
    var remanence: Dictionary = {
        "id": "remanence:" + _safe_id(source_id),
        "status": "emergent_not_objective_truth",
        "SOURCE": {
            "event_id": source_id,
            "chapter_id": str(source_state.get("chapter_id", "")),
            "title": title,
            "fact": _replace_tokens(str(source_presentation.get("fact", "")), title, context)
        },
        "TRANSMISSION": {
            "echo_chapter_id": str(afterlife.get("echo_chapter_id", "")),
            "rumor_source_id": "afterlife.echo." + source_id,
            "relationship_echoes": relationship_echoes.duplicate(true),
            "source_trace_preserved": true
        },
        "REMANENCE": {
            "label": str(profile.get("remanence_label", title)),
            "form": str(profile.get("remanence_form", "memoire_collective")),
            "material_trace": str(profile.get("remanence_trace", "")),
            "future_seed": future_seed,
            "interpretation_may_change": true
        }
    }
    afterlife["remanence_applied"] = true
    afterlife["remanence_chapter_id"] = CampaignState.current_chapter_id
    afterlife["remanence"] = remanence
    source_state["afterlife"] = afterlife
    _store_source_state(source_id, is_cascade, source_state)

    var public_payload: Dictionary = {
        "rumors": [{
            "reliability": "reported",
            "text": remanence_rumor
        }],
        "visual": [str(profile.get("remanence_trace", ""))]
    }
    CommunityRuntime.record_systemic_cross_event("afterlife.remanence." + source_id, public_payload, "remanence")
    _queue_beat(source_id, is_cascade, "remanence")
    remanence_emerged.emit(source_id, remanence.duplicate(true))
    afterlife_phase_applied.emit(source_id, "remanence", remanence.duplicate(true))

func _build_relationship_echo(source_id: String, is_cascade: bool, profile_name: String, profile: Dictionary) -> Dictionary:
    var hero_ids: Array[String] = _hero_followups(source_id, is_cascade, profile)
    if hero_ids.size() < 2:
        return {}
    var meanings_value: Variant = data.get("relationship_meanings", {})
    var meanings: Dictionary = meanings_value if meanings_value is Dictionary else {}
    var meaning_value: Variant = meanings.get(profile_name, meanings.get("none", {}))
    var meaning: Dictionary = meaning_value if meaning_value is Dictionary else {}
    return {
        "id": "relationship_echo:" + _safe_id(source_id),
        "pair": [hero_ids[0], hero_ids[1]],
        "tag": str(meaning.get("tag", "memoire_commune")),
        "description": str(meaning.get("description", "")),
        "topic": str(profile.get("relationship_topic", "")),
        "chapter_id": CampaignState.current_chapter_id,
        "numeric_score": false
    }

func _hero_followups(source_id: String, is_cascade: bool, profile: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var source_values: Variant = profile.get("hero_followups", []) if is_cascade else _source_definition(source_id, false).get("hero_followups", [])
    var values: Array = source_values if source_values is Array else []
    for value: Variant in values:
        var hero_id: String = str(value)
        if hero_id != "" and not result.has(hero_id):
            result.append(hero_id)
    return result

func _echo_exists(echoes: Array, echo_id: String) -> bool:
    for value: Variant in echoes:
        var echo: Dictionary = value if value is Dictionary else {}
        if str(echo.get("id", "")) == echo_id:
            return true
    return false

func relation_history_for(left_id: String, right_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var left: String = _normalize_hero_id(left_id)
    var right: String = _normalize_hero_id(right_id)
    for source_id: String in SystemicCrossRuntime.applied_event_ids():
        _collect_relation_history(result, _source_state(source_id, false), left, right)
    for source_id: String in SystemicCrossRuntime.applied_cascade_ids():
        _collect_relation_history(result, _source_state(source_id, true), left, right)
    return result

func _collect_relation_history(result: Array[Dictionary], source_state: Dictionary, left: String, right: String) -> void:
    var afterlife: Dictionary = _afterlife_state(source_state)
    var echoes_value: Variant = afterlife.get("relationship_echoes", [])
    var echoes: Array = echoes_value if echoes_value is Array else []
    for value: Variant in echoes:
        var echo: Dictionary = value if value is Dictionary else {}
        var pair_value: Variant = echo.get("pair", [])
        var pair: Array = pair_value if pair_value is Array else []
        if pair.size() != 2:
            continue
        var a: String = _normalize_hero_id(str(pair[0]))
        var b: String = _normalize_hero_id(str(pair[1]))
        if (a == left and b == right) or (a == right and b == left):
            result.append(echo.duplicate(true))

func remanences() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for source_id: String in SystemicCrossRuntime.applied_event_ids():
        _append_remanence(result, _source_state(source_id, false))
    for source_id: String in SystemicCrossRuntime.applied_cascade_ids():
        _append_remanence(result, _source_state(source_id, true))
    return result

func _append_remanence(result: Array[Dictionary], source_state: Dictionary) -> void:
    var afterlife: Dictionary = _afterlife_state(source_state)
    var remanence_value: Variant = afterlife.get("remanence", {})
    if remanence_value is Dictionary and not (remanence_value as Dictionary).is_empty():
        result.append((remanence_value as Dictionary).duplicate(true))

func pending_beat_count() -> int:
    return pending_beats.size()

func _queue_beat(source_id: String, is_cascade: bool, phase: String) -> void:
    for value: Variant in pending_beats:
        var beat: Dictionary = value if value is Dictionary else {}
        if str(beat.get("source_id", "")) == source_id and str(beat.get("phase", "")) == phase:
            return
    var source_state: Dictionary = _source_state(source_id, is_cascade)
    var afterlife: Dictionary = _afterlife_state(source_state)
    if _phase_presented(afterlife, phase):
        return
    pending_beats.append({
        "source_id": source_id,
        "is_cascade": is_cascade,
        "phase": phase
    })

func _phase_presented(afterlife: Dictionary, phase: String) -> bool:
    var presented_value: Variant = afterlife.get("presented_phases", [])
    var presented: Array = presented_value if presented_value is Array else []
    return presented.has(phase)

func _on_screen_requested(screen_name: String) -> void:
    if screen_name != "sanctuary":
        return
    _immediate_scene_presented_this_entry = false
    call_deferred("_present_after_sanctuary_entry")

func _on_immediate_scene_presented(_scene_id: String, _payload: Dictionary) -> void:
    _immediate_scene_presented_this_entry = true

func _present_after_sanctuary_entry() -> void:
    if _immediate_scene_presented_this_entry:
        return
    if SystemicCrossNarrativeRuntime.has_pending_scene():
        return
    present_next_pending_beat()

func present_next_pending_beat() -> Dictionary:
    if _presenting or GameState.current_screen != "sanctuary" or pending_beats.is_empty():
        return {}
    _presenting = true
    var beat_value: Variant = pending_beats.pop_front()
    var beat: Dictionary = beat_value if beat_value is Dictionary else {}
    var source_id: String = str(beat.get("source_id", ""))
    var is_cascade: bool = bool(beat.get("is_cascade", false))
    var phase: String = str(beat.get("phase", ""))
    var source_state: Dictionary = _source_state(source_id, is_cascade)
    var afterlife: Dictionary = _afterlife_state(source_state)
    if source_id == "" or _phase_presented(afterlife, phase):
        _presenting = false
        return {}
    var payload: Dictionary = _resolved_beat(source_id, is_cascade, phase, source_state)
    if payload.is_empty():
        _presenting = false
        return {}
    var presented_value: Variant = afterlife.get("presented_phases", [])
    var presented: Array = presented_value if presented_value is Array else []
    if not presented.has(phase):
        presented.append(phase)
    afterlife["presented_phases"] = presented
    source_state["afterlife"] = afterlife
    _store_source_state(source_id, is_cascade, source_state)
    _log_beat(payload)
    afterlife_beat_presented.emit(source_id, phase, payload.duplicate(true))
    afterlife_state_changed.emit()
    _presenting = false
    return payload

func _resolved_beat(source_id: String, is_cascade: bool, phase: String, source_state: Dictionary) -> Dictionary:
    var profile: Dictionary = _profile_for(source_id, is_cascade)
    if profile.is_empty():
        return {}
    var context: Dictionary = _source_context(source_state)
    var title: String = _source_title(source_id, is_cascade, context)
    if phase == "echo":
        var dialogue: Dictionary = _select_living_dialogue(source_id, is_cascade, profile, title, context)
        return {
            "source_id": source_id,
            "phase": phase,
            "title": title,
            "opening": _replace_tokens(str(profile.get("echo_opening", "")), title, context),
            "dialogue": dialogue,
            "silence": _replace_tokens(str(profile.get("silence", "")), title, context),
            "closing": _replace_tokens(str(profile.get("echo_closing", "")), title, context)
        }
    if phase == "remanence":
        var afterlife: Dictionary = _afterlife_state(source_state)
        var remanence_value: Variant = afterlife.get("remanence", {})
        var remanence: Dictionary = remanence_value if remanence_value is Dictionary else {}
        return {
            "source_id": source_id,
            "phase": phase,
            "title": str(remanence.get("REMANENCE", {}).get("label", title)),
            "source": remanence.get("SOURCE", {}).duplicate(true) if remanence.get("SOURCE", {}) is Dictionary else {},
            "transmission": remanence.get("TRANSMISSION", {}).duplicate(true) if remanence.get("TRANSMISSION", {}) is Dictionary else {},
            "remanence": remanence.get("REMANENCE", {}).duplicate(true) if remanence.get("REMANENCE", {}) is Dictionary else {}
        }
    return {}

func _select_living_dialogue(source_id: String, is_cascade: bool, profile: Dictionary, title: String, context: Dictionary) -> Dictionary:
    var dialogue_value: Variant = profile.get("dialogue", {})
    var dialogue: Dictionary = dialogue_value if dialogue_value is Dictionary else {}
    var hero_ids: Array[String] = _hero_followups(source_id, is_cascade, profile)
    for hero_id: String in hero_ids:
        if not dialogue.has(hero_id):
            continue
        var hero: Dictionary = _alive_hero(hero_id)
        if hero.is_empty():
            continue
        var text: String = _replace_tokens(str(dialogue.get(hero_id, "")), title, context)
        if text == "":
            continue
        return {
            "speaker_id": hero_id,
            "speaker": str(hero.get("name", _normalize_hero_id(hero_id).capitalize())),
            "text": text
        }
    return {}

func _log_beat(payload: Dictionary) -> void:
    var phase: String = str(payload.get("phase", ""))
    if phase == "echo":
        GameState.add_log("ÉCHO DIFFÉRÉ — %s" % str(payload.get("title", "Conséquence")))
        var opening: String = str(payload.get("opening", ""))
        if opening != "":
            GameState.add_log(opening)
        var dialogue_value: Variant = payload.get("dialogue", {})
        var dialogue: Dictionary = dialogue_value if dialogue_value is Dictionary else {}
        if not dialogue.is_empty():
            GameState.add_log("%s — %s" % [str(dialogue.get("speaker", "Héros")), str(dialogue.get("text", ""))])
        else:
            var silence: String = str(payload.get("silence", ""))
            if silence != "":
                GameState.add_log(silence)
        var closing: String = str(payload.get("closing", ""))
        if closing != "":
            GameState.add_log(closing)
        return
    if phase == "remanence":
        GameState.add_log("RÉMANENCE ÉMERGENTE — %s" % str(payload.get("title", "Rémanence")))
        var source_value: Variant = payload.get("source", {})
        var source: Dictionary = source_value if source_value is Dictionary else {}
        var remanence_value: Variant = payload.get("remanence", {})
        var remanence: Dictionary = remanence_value if remanence_value is Dictionary else {}
        var source_fact: String = str(source.get("fact", ""))
        if source_fact != "":
            GameState.add_log("SOURCE — " + source_fact)
        var trace: String = str(remanence.get("material_trace", ""))
        if trace != "":
            GameState.add_log("TRANSMISSION — " + trace)
        var future_seed: String = str(remanence.get("future_seed", ""))
        if future_seed != "":
            GameState.add_log("RÉMANENCE — interprétation future possible, non vérité établie.")

func _source_state(source_id: String, is_cascade: bool) -> Dictionary:
    var value: Variant = SystemicCrossRuntime.applied_cascades.get(source_id, {}) if is_cascade else SystemicCrossRuntime.applied_events.get(source_id, {})
    return value if value is Dictionary else {}

func _store_source_state(source_id: String, is_cascade: bool, source_state: Dictionary) -> void:
    if is_cascade:
        SystemicCrossRuntime.applied_cascades[source_id] = source_state
    else:
        SystemicCrossRuntime.applied_events[source_id] = source_state

func _afterlife_state(source_state: Dictionary) -> Dictionary:
    var value: Variant = source_state.get("afterlife", {})
    return value if value is Dictionary else {}

func _source_context(source_state: Dictionary) -> Dictionary:
    var value: Variant = source_state.get("context", {})
    return value.duplicate(true) if value is Dictionary else {}

func _source_definition(source_id: String, is_cascade: bool) -> Dictionary:
    var key: String = "compound_cascades" if is_cascade else "cross_events"
    for value: Variant in SystemicCrossRuntime.registry.get(key, []):
        var item: Dictionary = value if value is Dictionary else {}
        if str(item.get("id", "")) == source_id:
            return item
    return {}

func _source_presentation(source_id: String, is_cascade: bool) -> Dictionary:
    var key: String = "cascades" if is_cascade else "events"
    var values_value: Variant = SystemicCrossRuntime.presentation.get(key, {})
    var values: Dictionary = values_value if values_value is Dictionary else {}
    var item_value: Variant = values.get(source_id, {})
    return item_value if item_value is Dictionary else {}

func _profile_for(source_id: String, is_cascade: bool) -> Dictionary:
    if is_cascade:
        var cascades_value: Variant = data.get("cascade_profiles", {})
        var cascades: Dictionary = cascades_value if cascades_value is Dictionary else {}
        var profile_value: Variant = cascades.get(source_id, {})
        return profile_value if profile_value is Dictionary else {}
    var definition: Dictionary = _source_definition(source_id, false)
    var family: String = str(definition.get("family", ""))
    var families_value: Variant = data.get("family_profiles", {})
    var families: Dictionary = families_value if families_value is Dictionary else {}
    var profile_value: Variant = families.get(family, {})
    return profile_value if profile_value is Dictionary else {}

func _source_title(source_id: String, is_cascade: bool, context: Dictionary) -> String:
    var presentation: Dictionary = _source_presentation(source_id, is_cascade)
    return _replace_tokens(str(presentation.get("title", source_id)), str(presentation.get("title", source_id)), context)

func _replace_tokens(text: String, title: String, context: Dictionary) -> String:
    var dead_name: String = str(context.get("name", context.get("dead_name", "le nom inscrit")))
    var cause: String = str(context.get("cause", context.get("material_cause", "cause matérielle consignée")))
    return text.replace("{title}", title).replace("{dead_name}", dead_name).replace("{cause}", cause)

func _alive_hero(registry_id: String) -> Dictionary:
    var normalized: String = _normalize_hero_id(registry_id)
    for value: Variant in GameState.alive_heroes():
        var hero: Dictionary = value if value is Dictionary else {}
        if _normalize_hero_id(str(hero.get("id", ""))) == normalized:
            return hero
    return {}

func _normalize_hero_id(value: String) -> String:
    var normalized: String = value.strip_edges().to_lower()
    if normalized.begins_with("hero."):
        normalized = normalized.trim_prefix("hero.")
    return normalized

func _safe_id(value: String) -> String:
    return value.replace(".", "_").replace(":", "_").replace("/", "_")
