extends Node

var failures: Array[String] = []

func run() -> void:
    AudioDirector.reset_runtime()
    NarrativeAudioDirector.reset_runtime()
    await get_tree().process_frame

    GameState.request_screen("sanctuary")
    await get_tree().process_frame
    var sanctuary: Dictionary = NarrativeAudioDirector.snapshot()
    _check(str(sanctuary.get("space_id", "")) == "sanctuary", "Sanctuary screen must activate its audio context")
    _check(str(sanctuary.get("music_cue", "")) == "sanctuary_day", "Sanctuary must request sanctuary_day music")
    var sanctuary_loops_variant: Variant = sanctuary.get("loop_cues", [])
    var sanctuary_loops: Array = sanctuary_loops_variant if sanctuary_loops_variant is Array else []
    _check(sanctuary_loops.has("sanctuary_crowd"), "Sanctuary must keep a lived-in roomtone loop")
    _check(PrototypeAudioBank.has_cue("sanctuary_crowd", "sfx"), "Sanctuary roomtone must resolve to local prototype audio")
    _check(PrototypeAudioBank.has_cue("sanctuary_day", "music"), "Sanctuary music must resolve to local prototype audio")

    var music_bus: int = AudioServer.get_bus_index("Music")
    var base_music_db: float = float(AudioDirector.bus_levels_db.get("Music", -8.0))
    NarrativeAudioDirector.begin_dialogue("smoke_dialogue")
    await get_tree().create_timer(0.22).timeout
    _check(bool(NarrativeAudioDirector.snapshot().get("dialogue_active", false)), "Dialogue must become active")
    if music_bus >= 0:
        _check(AudioServer.get_bus_volume_db(music_bus) <= base_music_db - 8.0, "Dialogue must duck music clearly")
    NarrativeAudioDirector.end_dialogue("smoke_dialogue")
    await get_tree().create_timer(0.36).timeout
    _check(not bool(NarrativeAudioDirector.snapshot().get("dialogue_active", true)), "Dialogue must release cleanly")
    if music_bus >= 0:
        _check(absf(AudioServer.get_bus_volume_db(music_bus) - base_music_db) < 0.75, "Dialogue release must restore the AudioDirector base mix")

    NarrativeAudioDirector.scripted_silence(0.08)
    await get_tree().create_timer(0.03).timeout
    _check(bool(NarrativeAudioDirector.snapshot().get("silence_active", false)), "Scripted silence must become an authored audio state")
    await get_tree().create_timer(0.12).timeout
    _check(not bool(NarrativeAudioDirector.snapshot().get("silence_active", true)), "Scripted silence must restore the mix")

    GameState.request_screen("tavern")
    await get_tree().process_frame
    var tavern: Dictionary = NarrativeAudioDirector.snapshot()
    _check(str(tavern.get("music_cue", "")) == "tavern", "Tavern must have its own music cue")
    var tavern_loops_variant: Variant = tavern.get("loop_cues", [])
    var tavern_loops: Array = tavern_loops_variant if tavern_loops_variant is Array else []
    _check(tavern_loops.has("tavern_roomtone"), "Tavern must have its own roomtone")

    GameState.request_screen("chapel")
    await get_tree().process_frame
    _check(str(NarrativeAudioDirector.snapshot().get("music_cue", "")) == "chapel", "Chapel must have a contemplative cue")
    GameState.request_screen("memorial")
    await get_tree().process_frame
    _check(str(NarrativeAudioDirector.snapshot().get("music_cue", "")) == "memorial", "Memorial must have its own cue")

    _check(NarrativeAudioDirector.quest_motif("q_iven_erased_days") == "ancient_archive", "Iven quest must keep a recurring musical motif")
    _check(NarrativeAudioDirector.quest_motif("q_yoren_false_exit") == "discovery_revelation", "Yoren quest must keep a recurring musical motif")

    NarrativeAudioDirector.trigger_beat("choice", {"choice_id": "smoke"})
    await get_tree().create_timer(0.04).timeout
    var choice_history: Array[Dictionary] = NarrativeAudioDirector.history()
    _check(_history_has(choice_history, "beat"), "Narrative choices must create an audio beat without a morality score")

    NarrativeAudioDirector.trigger_beat("revelation", {"source": "smoke"})
    await get_tree().create_timer(0.08).timeout
    _check(bool(NarrativeAudioDirector.snapshot().get("silence_active", false)), "Revelation must be able to begin in silence")
    await get_tree().create_timer(0.72).timeout
    _check(str(AudioDirector.active_music_cue) == "discovery_revelation", "Revelation must transition to its music cue after silence")

    NarrativeAudioDirector.reset_runtime()
    GameState.request_screen("sanctuary")
    await get_tree().process_frame

    var iven_hook: Dictionary = NarrativeAudioDirector.scene_hook_definition("evidence:ev_korem_redaction")
    _check(str(iven_hook.get("beat", "")) == "revelation", "Iven evidence must be authored as a revelation scene")
    var political_hook: Dictionary = NarrativeAudioDirector.scene_hook_definition("political:ashlands_refugee_gate:welcome")
    _check(str(political_hook.get("beat", "")) == "choice", "Political wildcard must resolve to a neutral choice beat")

    Chapter03Runtime.evidence_discovered.emit({"id": "ev_korem_redaction", "title": "Archive Kor-Em censurée"})
    await get_tree().process_frame
    var evidence_history: Array[Dictionary] = NarrativeAudioDirector.history()
    _check(_history_has_scene(evidence_history, "evidence:ev_korem_redaction"), "Real Chapter III evidence must trigger its narrative audio scene")
    _check(_scene_value(evidence_history, "evidence:ev_korem_redaction", "motif") == "ancient_archive", "Iven revelation must reuse the quest motif")

    RelationshipRuntime.relationship_changed.emit("aurelien", "lysandra", "sanctuary_reconcile")
    await get_tree().process_frame
    _check(_history_has_scene(NarrativeAudioDirector.history(), "relationship:sanctuary_reconcile"), "Companion reconciliation must trigger a relationship audio scene")

    RelationshipRuntime.relationship_moment.emit("La chute de Lysandra n'a pas le même poids pour ceux qui l'avaient laissée entrer dans leur vie.")
    await get_tree().process_frame
    _check(_history_has_scene(NarrativeAudioDirector.history(), "relationship:hero_fallen"), "Hero loss must trigger the loss beat through the real relationship moment")

    FieldEncounterRuntime.encounter_resolved.emit("c03_survivor_outpost", "returned")
    await get_tree().process_frame
    _check(_history_has_scene(NarrativeAudioDirector.history(), "field:c03_survivor_outpost:returned"), "Three Marks return must trigger a reunion beat")

    _check(
        NarrativeAudioDirector.trigger_scene_hook(
            "political:ashlands_refugee_gate:welcome",
            {"quest_id": "ashlands_refugee_gate", "choice_id": "welcome"}
        ),
        "A real political choice key must resolve through the wildcard hook"
    )
    await get_tree().process_frame
    _check(_history_has_scene(NarrativeAudioDirector.history(), "political:ashlands_refugee_gate:welcome"), "Political choice must be recorded as a scene hook")
    _check(_scene_value(NarrativeAudioDirector.history(), "political:ashlands_refugee_gate:welcome", "rule") == "neutral_weight_no_moral_answer", "Political audio must remain morally neutral")

    NarrativeAudioDirector.reset_runtime()
    AudioDirector.reset_runtime()
    await get_tree().process_frame
    _finish()

func _history_has(entries: Array[Dictionary], kind: String) -> bool:
    for entry: Dictionary in entries:
        if str(entry.get("kind", "")) == kind:
            return true
    return false

func _history_has_scene(entries: Array[Dictionary], scene_key: String) -> bool:
    for entry: Dictionary in entries:
        if str(entry.get("kind", "")) == "scene_hook" and str(entry.get("scene_key", "")) == scene_key:
            return true
    return false

func _scene_value(entries: Array[Dictionary], scene_key: String, key: String) -> String:
    for index in range(entries.size() - 1, -1, -1):
        var entry: Dictionary = entries[index]
        if str(entry.get("kind", "")) == "scene_hook" and str(entry.get("scene_key", "")) == scene_key:
            return str(entry.get(key, ""))
    return ""

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("NARRATIVE_AUDIO_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("NARRATIVE_AUDIO_SMOKE: " + failure)
    print("NARRATIVE_AUDIO_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
