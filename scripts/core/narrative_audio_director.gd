extends Node

signal narrative_audio_changed(snapshot: Dictionary)
signal dialogue_state_changed(active: bool, tag: String)
signal narrative_beat_started(kind: String, payload: Dictionary)
signal sanctuary_audio_changed(space_id: String)
signal scene_audio_triggered(scene_key: String, payload: Dictionary)

const DATA_PATH := "res://data/narrative_audio.json"
const SILENT_DB: float = -80.0

var data: Dictionary = {}
var current_space_id: String = ""
var dialogue_depth: int = 0
var dialogue_tag: String = ""
var silence_active: bool = false
var silence_buses: Array[String] = []
var event_history: Array[Dictionary] = []

var _connected: bool = false
var _mix_tween: Tween
var _silence_generation: int = 0
var _beat_generation: int = 0

func _ready() -> void:
    data = _load_dictionary(DATA_PATH)
    call_deferred("_connect_sources")

func _load_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _connect_sources() -> void:
    if _connected:
        return
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not CommunityRuntime.quest_changed.is_connected(_on_quest_changed):
        CommunityRuntime.quest_changed.connect(_on_quest_changed)
    if not Chapter03Runtime.evidence_discovered.is_connected(_on_chapter03_evidence):
        Chapter03Runtime.evidence_discovered.connect(_on_chapter03_evidence)
    if not FieldEncounterRuntime.encounter_resolved.is_connected(_on_field_encounter_resolved):
        FieldEncounterRuntime.encounter_resolved.connect(_on_field_encounter_resolved)
    if not RelationshipRuntime.relationship_changed.is_connected(_on_relationship_changed):
        RelationshipRuntime.relationship_changed.connect(_on_relationship_changed)
    if not RelationshipRuntime.relationship_moment.is_connected(_on_relationship_moment):
        RelationshipRuntime.relationship_moment.connect(_on_relationship_moment)
    if not AudioDirector.mix_changed.is_connected(_on_audio_mix_changed):
        AudioDirector.mix_changed.connect(_on_audio_mix_changed)
    _connected = true
    if str(GameState.current_screen) != "":
        enter_screen_context(str(GameState.current_screen))

func enter_screen_context(screen_name: String) -> void:
    var contexts_variant: Variant = data.get("screen_contexts", {})
    var contexts: Dictionary = contexts_variant if contexts_variant is Dictionary else {}
    var context_value: Variant = contexts.get(screen_name, {})
    var context: Dictionary = context_value if context_value is Dictionary else {}
    if context.is_empty():
        if current_space_id != "":
            current_space_id = ""
            SfxRuntime.stop_all_loops()
            sanctuary_audio_changed.emit("")
            _record_event("space_exit", {"screen": screen_name})
        _apply_overlay(0.12)
        _emit_state()
        return

    var changed: bool = current_space_id != screen_name
    current_space_id = screen_name
    var loops: Array[String] = _string_array(context.get("loops", []))
    SfxRuntime.set_loop_cues(loops)

    if AudioDirector.mode not in ["combat", "boss"]:
        var music_cue: String = str(context.get("music", ""))
        if music_cue != "" and music_cue != AudioDirector.active_music_cue:
            AudioDirector.request_music(music_cue, {"reason": "sanctuary_space", "space_id": screen_name})

    if changed:
        var entry_sfx: String = str(context.get("entry_sfx", ""))
        if entry_sfx != "":
            SfxRuntime.play_cue(entry_sfx, {"reason": "sanctuary_entry", "space_id": screen_name, "volume_db": -4.0})
        sanctuary_audio_changed.emit(screen_name)
        _record_event("space_enter", {"space_id": screen_name, "music": str(context.get("music", "")), "loops": loops})

    _apply_overlay(0.18)
    _emit_state()

func begin_dialogue(tag: String = "dialogue") -> void:
    dialogue_depth += 1
    dialogue_tag = tag
    _apply_overlay(float(data.get("dialogue_attack_seconds", 0.16)))
    dialogue_state_changed.emit(true, dialogue_tag)
    _record_event("dialogue_begin", {"tag": dialogue_tag, "depth": dialogue_depth})
    _emit_state()

func end_dialogue(tag: String = "") -> void:
    if dialogue_depth <= 0:
        return
    dialogue_depth = maxi(0, dialogue_depth - 1)
    if dialogue_depth == 0:
        var finished_tag: String = dialogue_tag if tag == "" else tag
        dialogue_tag = ""
        _apply_overlay(float(data.get("dialogue_release_seconds", 0.30)))
        dialogue_state_changed.emit(false, finished_tag)
    else:
        _apply_overlay(0.10)
    _record_event("dialogue_end", {"tag": tag, "depth": dialogue_depth})
    _emit_state()

func play_spoken_moment(tag: String, seconds: float = 1.5) -> void:
    begin_dialogue(tag)
    await get_tree().create_timer(maxf(0.05, seconds)).timeout
    end_dialogue(tag)

func scripted_silence(seconds: float, buses: Array[String] = []) -> void:
    _silence_generation += 1
    var generation: int = _silence_generation
    silence_active = true
    silence_buses = buses.duplicate() if not buses.is_empty() else _string_array(data.get("silence_default_buses", ["Music", "Ambience"]))
    _record_event("silence_begin", {"seconds": seconds, "buses": silence_buses.duplicate()})
    _apply_overlay(0.10)
    _emit_state()
    await get_tree().create_timer(maxf(0.03, seconds)).timeout
    if generation != _silence_generation:
        return
    silence_active = false
    silence_buses.clear()
    _apply_overlay(0.34)
    _record_event("silence_end", {})
    _emit_state()

func trigger_beat(kind: String, context: Dictionary = {}) -> void:
    var beats_variant: Variant = data.get("beats", {})
    var beats: Dictionary = beats_variant if beats_variant is Dictionary else {}
    var beat_value: Variant = beats.get(kind, {})
    var beat: Dictionary = beat_value if beat_value is Dictionary else {}
    if beat.is_empty():
        return
    var payload: Dictionary = context.duplicate(true)
    payload["kind"] = kind
    narrative_beat_started.emit(kind, payload)
    _record_event("beat", payload)

    if kind == "rumor":
        var rumor_sfx: String = str(beat.get("sfx", ""))
        if rumor_sfx != "":
            SfxRuntime.play_cue(rumor_sfx, {"reason": "narrative_beat", "kind": kind, "volume_db": -7.0})
        play_spoken_moment(str(context.get("tag", "rumor")), float(beat.get("dialogue_seconds", 1.5)))
        return

    _beat_generation += 1
    var generation: int = _beat_generation
    _run_beat_sequence(kind, beat, context, generation)

func quest_motif(quest_id: String) -> String:
    var motifs_variant: Variant = data.get("quest_motifs", {})
    var motifs: Dictionary = motifs_variant if motifs_variant is Dictionary else {}
    return str(motifs.get(quest_id, ""))

func scene_hook_definition(scene_key: String) -> Dictionary:
    var hooks_variant: Variant = data.get("scene_hooks", {})
    var hooks: Dictionary = hooks_variant if hooks_variant is Dictionary else {}
    var exact_value: Variant = hooks.get(scene_key, {})
    if exact_value is Dictionary and not exact_value.is_empty():
        return exact_value.duplicate(true)
    var separator: int = scene_key.find(":")
    if separator > 0:
        var wildcard_key: String = scene_key.substr(0, separator) + ":*"
        var wildcard_value: Variant = hooks.get(wildcard_key, {})
        if wildcard_value is Dictionary and not wildcard_value.is_empty():
            return wildcard_value.duplicate(true)
    return {}

func trigger_scene_hook(scene_key: String, context: Dictionary = {}) -> bool:
    var hook: Dictionary = scene_hook_definition(scene_key)
    if hook.is_empty():
        return false
    var beat: String = str(hook.get("beat", ""))
    if beat == "":
        return false

    var payload: Dictionary = context.duplicate(true)
    payload["scene_key"] = scene_key
    var tag: String = str(hook.get("tag", scene_key))
    payload["tag"] = tag
    var quest_id: String = str(hook.get("quest_id", payload.get("quest_id", "")))
    if quest_id != "":
        payload["quest_id"] = quest_id
    var required_quest_state: String = str(hook.get("requires_quest_state", ""))
    if required_quest_state != "" and quest_id != "":
        if str(CommunityRuntime.quest_states.get(quest_id, "")) != required_quest_state:
            return false
    if bool(hook.get("motif_from_quest", false)) and quest_id != "":
        payload["motif"] = quest_motif(quest_id)
    var rule: String = str(hook.get("rule", ""))
    if rule != "":
        payload["rule"] = rule

    scene_audio_triggered.emit(scene_key, payload.duplicate(true))
    _record_event("scene_hook", payload)

    var spoken_seconds: float = maxf(0.0, float(hook.get("spoken_seconds", 0.0)))
    if spoken_seconds > 0.0:
        play_spoken_moment(tag, spoken_seconds)
    trigger_beat(beat, payload)
    return true

func snapshot() -> Dictionary:
    return {
        "space_id": current_space_id,
        "dialogue_active": dialogue_depth > 0,
        "dialogue_depth": dialogue_depth,
        "dialogue_tag": dialogue_tag,
        "silence_active": silence_active,
        "silence_buses": silence_buses.duplicate(),
        "music_cue": AudioDirector.active_music_cue,
        "loop_cues": SfxRuntime.loop_cues(),
        "history_size": event_history.size()
    }

func history() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for item: Dictionary in event_history:
        result.append(item.duplicate(true))
    return result

func reset_runtime() -> void:
    current_space_id = ""
    dialogue_depth = 0
    dialogue_tag = ""
    silence_active = false
    silence_buses.clear()
    event_history.clear()
    _silence_generation += 1
    _beat_generation += 1
    if _mix_tween != null and _mix_tween.is_valid():
        _mix_tween.kill()
    _mix_tween = null
    SfxRuntime.stop_all_loops()
    _apply_overlay(0.0)
    _emit_state()

func _on_screen_requested(screen_name: String) -> void:
    enter_screen_context(screen_name)

func _on_new_game_reset() -> void:
    reset_runtime()

func _on_audio_mix_changed(_levels: Dictionary) -> void:
    _apply_overlay(0.08)

func _on_quest_changed(quest_id: String, state: String) -> void:
    if state == "active":
        trigger_beat("quest_accept", {"quest_id": quest_id, "motif": quest_motif(quest_id)})
    elif state == "completed":
        trigger_beat("quest_complete", {"quest_id": quest_id, "motif": quest_motif(quest_id)})

func _on_chapter03_evidence(evidence: Dictionary) -> void:
    var evidence_id: String = str(evidence.get("id", ""))
    if evidence_id == "":
        return
    trigger_scene_hook("evidence:" + evidence_id, {"evidence_id": evidence_id, "title": str(evidence.get("title", evidence_id))})

func _on_field_encounter_resolved(event_id: String, outcome: String) -> void:
    trigger_scene_hook("field:%s:%s" % [event_id, outcome], {"event_id": event_id, "outcome": outcome})

func _on_relationship_changed(source_id: String, target_id: String, event_id: String) -> void:
    var scene_key: String = "relationship:" + event_id
    if scene_hook_definition(scene_key).is_empty():
        return
    if event_id in ["sanctuary_reconcile", "sanctuary_opening"] and source_id.naturalnocasecmp_to(target_id) > 0:
        return
    trigger_scene_hook(scene_key, {"source_id": source_id, "target_id": target_id, "event_id": event_id})

func _on_relationship_moment(text: String) -> void:
    if text.begins_with("La chute de "):
        trigger_scene_hook("relationship:hero_fallen", {"text": text})

func _run_beat_sequence(kind: String, beat: Dictionary, context: Dictionary, generation: int) -> void:
    var silence_seconds: float = maxf(0.0, float(beat.get("silence_seconds", 0.0)))
    if silence_seconds > 0.0:
        await scripted_silence(silence_seconds)
        if generation != _beat_generation:
            return

    var sfx_cue: String = str(beat.get("sfx", ""))
    if sfx_cue != "":
        SfxRuntime.play_cue(sfx_cue, {"reason": "narrative_beat", "kind": kind, "volume_db": -2.5})

    var motif: String = str(context.get("motif", ""))
    var music_cue: String = motif if motif != "" else str(beat.get("music", ""))
    var hold_seconds: float = maxf(0.0, float(beat.get("hold_seconds", 0.0)))
    if music_cue != "" and AudioDirector.mode not in ["combat", "boss"]:
        await _temporary_music(music_cue, hold_seconds, kind, generation)

func _temporary_music(cue_id: String, hold_seconds: float, reason: String, generation: int) -> void:
    var previous_cue: String = AudioDirector.active_music_cue
    AudioDirector.request_music(cue_id, {"reason": "narrative_beat", "beat": reason})
    if hold_seconds <= 0.0:
        return
    await get_tree().create_timer(hold_seconds).timeout
    if generation != _beat_generation:
        return
    var restore_cue: String = _space_music_cue()
    if restore_cue == "":
        restore_cue = previous_cue
    if restore_cue != "" and restore_cue != AudioDirector.active_music_cue and AudioDirector.mode not in ["combat", "boss"]:
        AudioDirector.request_music(restore_cue, {"reason": "narrative_beat_restore", "beat": reason})

func _space_music_cue() -> String:
    if current_space_id == "":
        return ""
    var contexts_variant: Variant = data.get("screen_contexts", {})
    var contexts: Dictionary = contexts_variant if contexts_variant is Dictionary else {}
    var context_value: Variant = contexts.get(current_space_id, {})
    var context: Dictionary = context_value if context_value is Dictionary else {}
    return str(context.get("music", ""))

func _apply_overlay(seconds: float) -> void:
    var base_levels: Dictionary = AudioDirector.bus_levels_db.duplicate(true)
    var duck_variant: Variant = data.get("dialogue_ducking_db", {})
    var ducking: Dictionary = duck_variant if duck_variant is Dictionary else {}
    if _mix_tween != null and _mix_tween.is_valid():
        _mix_tween.kill()
    _mix_tween = null
    if seconds > 0.0:
        _mix_tween = create_tween()
        _mix_tween.set_parallel(true)

    for bus_value: Variant in AudioDirector.required_buses():
        var bus_name: String = str(bus_value)
        var bus_index: int = AudioServer.get_bus_index(bus_name)
        if bus_index < 0:
            continue
        var base_db: float = float(base_levels.get(bus_name, AudioServer.get_bus_volume_db(bus_index)))
        var target_db: float = base_db
        if dialogue_depth > 0:
            target_db = clampf(target_db + float(ducking.get(bus_name, 0.0)), SILENT_DB, 6.0)
        if silence_active and silence_buses.has(bus_name):
            target_db = SILENT_DB
        var current_db: float = AudioServer.get_bus_volume_db(bus_index)
        if _mix_tween != null:
            _mix_tween.tween_method(Callable(self, "_set_bus_volume").bind(bus_name), current_db, target_db, seconds)
        else:
            AudioServer.set_bus_volume_db(bus_index, target_db)

func _set_bus_volume(value: float, bus_name: String) -> void:
    var bus_index: int = AudioServer.get_bus_index(bus_name)
    if bus_index >= 0:
        AudioServer.set_bus_volume_db(bus_index, clampf(value, SILENT_DB, 6.0))

func _record_event(kind: String, payload: Dictionary) -> void:
    var item: Dictionary = payload.duplicate(true)
    item["kind"] = kind
    event_history.append(item)
    var limit: int = maxi(8, int(data.get("history_limit", 48)))
    while event_history.size() > limit:
        event_history.pop_front()

func _emit_state() -> void:
    narrative_audio_changed.emit(snapshot())

func _string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    var values: Array = value if value is Array else []
    for item: Variant in values:
        var text: String = str(item)
        if text != "":
            result.append(text)
    return result
