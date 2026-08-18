extends Node

signal chapter_six_changed
signal signal_discovered(signal_data: Dictionary)
signal hypothesis_confirmed(hypothesis_id: String)
signal creature_reaction_recorded(node_id: String, direct: bool)
signal anchor_stabilized(anchor_id: String)
signal saen_contact_established
signal final_choice_required
signal chapter_six_completed

const CHAPTER_PATH := "res://data/levels/chapter_06_absent.json"
const WORLD_PATH := "res://data/levels/chapter_06_world.json"

var chapter: Dictionary = {}
var world: Dictionary = {}
var discovered_signals: Dictionary = {}
var confirmed_hypotheses: Dictionary = {}
var reaction_records: Dictionary = {}
var stabilized_anchors: Dictionary = {}
var completed_stages: Dictionary = {}
var saen_contact := false
var final_choice := ""
var rewards_claimed := false

func _ready() -> void:
    chapter = _load_json(CHAPTER_PATH)
    world = _load_json(WORLD_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(func(_id): refresh_progress())
    AshlandsRuntime.campfire_used.connect(func(_id): refresh_progress())
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)
    CreatureManager.creatures_changed.connect(func(): refresh_progress())

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    discovered_signals = {}
    confirmed_hypotheses = {}
    reaction_records = {}
    stabilized_anchors = {}
    completed_stages = {}
    saen_contact = false
    final_choice = ""
    rewards_claimed = false
    chapter_six_changed.emit()

func signals() -> Array: return world.get("signals", [])
func hypotheses() -> Array: return world.get("hypotheses", [])
func signal_count() -> int: return discovered_signals.size()
func anchor_count() -> int: return stabilized_anchors.size()

func get_signal(signal_id: String) -> Dictionary:
    for value in signals():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == signal_id: return entry
    return {}

func collect_signal(signal_id: String) -> bool:
    if discovered_signals.has(signal_id): return false
    var entry := get_signal(signal_id)
    if entry.is_empty(): return false
    discovered_signals[signal_id] = entry.duplicate(true)
    signal_discovered.emit(entry.duplicate(true))
    GameState.add_log("Signal des Absents — %s" % String(entry.get("title", signal_id)))
    _recalculate_hypotheses()
    refresh_progress()
    chapter_six_changed.emit()
    return true

func independent_source_family_count() -> int:
    var groups := {}
    for value in discovered_signals.values():
        groups[String((value as Dictionary).get("source_family", "unknown"))] = true
    return groups.size()

func direct_reaction_count() -> int:
    var total := 0
    for value in reaction_records.values():
        if bool((value as Dictionary).get("direct", false)): total += 1
    return total

func proxy_reaction_count() -> int:
    var total := 0
    for value in reaction_records.values():
        if not bool((value as Dictionary).get("direct", false)): total += 1
    return total

func record_creature_reaction(node_id: String) -> bool:
    if reaction_records.has(node_id): return false
    var direct := not CreatureManager.active_creature().is_empty()
    reaction_records[node_id] = {"direct":direct, "creature":CreatureManager.active_creature() if direct else {}}
    if direct:
        CampaignState.add_metric("creature_relations", 1)
        var creature := CreatureManager.active_creature()
        GameState.add_log("%s reconnaît quelque chose que le groupe ne perçoit pas encore." % String(creature.get("name", "La créature")))
    else:
        GameState.add_log("La balise de Meira enregistre une résonance indirecte. Une mesure supplémentaire sera nécessaire.")
    creature_reaction_recorded.emit(node_id, direct)
    _try_confirm_carried_memory()
    refresh_progress()
    chapter_six_changed.emit()
    return true

func _try_confirm_carried_memory() -> void:
    if bool(confirmed_hypotheses.get("carried_memory", false)): return
    var direct_ok := direct_reaction_count() >= 2
    var proxy_ok := direct_reaction_count() == 0 and proxy_reaction_count() >= 3
    if direct_ok or proxy_ok:
        confirmed_hypotheses["carried_memory"] = true
        CampaignState.discovered_revelations["c06_carried_memory"] = "Certaines créatures reconnaissent ou transportent des empreintes mémorielles qui ne correspondent pas à leur propre histoire."
        CampaignState.add_metric("veil_knowledge", 3)
        hypothesis_confirmed.emit("carried_memory")

func stabilize_anchor(anchor_id: String) -> bool:
    if stabilized_anchors.has(anchor_id): return false
    if anchor_id not in ["c06_anchor_body","c06_anchor_spirit","c06_anchor_city"]: return false
    stabilized_anchors[anchor_id] = true
    CampaignState.add_metric("stabilizer_nodes", 1)
    anchor_stabilized.emit(anchor_id)
    GameState.add_log("Ancrage stabilisé — %d/3." % anchor_count())
    refresh_progress()
    chapter_six_changed.emit()
    return true

func establish_saen_contact() -> bool:
    if saen_contact: return false
    if signal_count() < 8 or independent_source_family_count() < 4 or not bool(confirmed_hypotheses.get("stable_contact", false)):
        GameState.add_log("La réponse est encore trop instable pour maintenir Saen dans le même instant que le groupe.")
        return false
    saen_contact = true
    CampaignState.add_metric("absent_contact", 6)
    CampaignState.set_chapter_flag("c06_saen_contact")
    GameState.add_log("Saen : « Ne dites pas que je suis mort. Je ne sais pas si ce mot atteint jusqu'ici. »")
    saen_contact_established.emit()
    refresh_progress()
    chapter_six_changed.emit()
    return true

func _recalculate_hypotheses() -> void:
    for value in hypotheses():
        var h: Dictionary = value
        var id := String(h.get("id", ""))
        if id == "carried_memory" or bool(confirmed_hypotheses.get(id, false)): continue
        var support := 0
        var families := {}
        for signal_value in discovered_signals.values():
            var entry: Dictionary = signal_value
            if id in entry.get("supports", []):
                support += 1
                families[String(entry.get("source_family", "unknown"))] = true
        if support >= int(h.get("required_support", 1)) and families.size() >= int(h.get("independent_sources", 1)):
            confirmed_hypotheses[id] = true
            CampaignState.discovered_revelations["c06_%s" % id] = String(h.get("title", id))
            CampaignState.add_metric("veil_knowledge", 3)
            hypothesis_confirmed.emit(id)

func active_stage() -> Dictionary:
    for value in chapter.get("stages", []):
        var stage: Dictionary = value
        if not bool(completed_stages.get(String(stage.get("id", "")), false)): return stage
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), chapter.get("stages", []).size()]

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c06_boss_boundary" and final_choice == "": call_deferred("_request_choice")
    refresh_progress()

func _request_choice() -> void: final_choice_required.emit()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_06_absent": return
    _complete_if("c06_stage_01_garden", AshlandsRuntime.is_zone_discovered("c06_timeless_garden"))
    _complete_if("c06_stage_02_voices", signal_count() >= 4 and independent_source_family_count() >= 2 and bool(confirmed_hypotheses.get("conscious_survival", false)))
    var reaction_ok := direct_reaction_count() >= 2 or (direct_reaction_count() == 0 and proxy_reaction_count() >= 3)
    _complete_if("c06_stage_03_creatures", AshlandsRuntime.is_zone_discovered("c06_creature_hollow") and reaction_ok and bool(confirmed_hypotheses.get("carried_memory", false)))
    _complete_if("c06_stage_04_camp", AshlandsRuntime.was_campfire_used_this_run("c06_overlap_hamlet"))
    _complete_if("c06_stage_05_wayfarer", AshlandsRuntime.is_encounter_cleared("c06_shifted_wayfarer"))
    _complete_if("c06_stage_06_saen", saen_contact and signal_count() >= 8 and independent_source_family_count() >= 4)
    _complete_if("c06_stage_07_boundary", anchor_count() >= 3 and AshlandsRuntime.is_encounter_cleared("c06_boss_boundary") and final_choice != "")
    _complete_if("c06_stage_08_return", GameState.current_screen == "sanctuary" and final_choice != "" and bool(confirmed_hypotheses.get("closure_risk", false)))
    _sync_main_quests()
    _try_finish()
    chapter_six_changed.emit()

func _complete_if(id: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(id, false)):
        completed_stages[id] = true
        GameState.add_log("Chapitre VI — %s" % id)

func choose_final_outcome(choice_id: String) -> bool:
    if not AshlandsRuntime.is_encounter_cleared("c06_boss_boundary"): return false
    for value in chapter.get("boss_choices", []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id: continue
        final_choice = choice_id
        var effects: Dictionary = choice.get("effects", {})
        for metric in ["absent_contact","creature_relations","veil_knowledge","justice_integrity","stabilizer_nodes"]:
            if effects.has(metric): CampaignState.add_metric(metric, int(effects[metric]))
        if effects.has("tension"):
            PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
        if effects.has("trust"):
            PoliticalState.trust = clampi(PoliticalState.trust + int(effects["trust"]), 0, 100)
        CampaignState.set_chapter_flag("c06_boundary_%s" % choice_id)
        PoliticalState.politics_changed.emit()
        refresh_progress()
        return true
    return false

func _sync_main_quests() -> void:
    var bindings: Dictionary = chapter.get("main_quest_bindings", {})
    for quest_id in bindings.keys():
        if CampaignState.is_main_quest_completed(String(quest_id)): continue
        var done := true
        for stage_id in bindings[quest_id]:
            if not bool(completed_stages.get(String(stage_id), false)):
                done = false
                break
        if done: CampaignState.complete_main_quest(String(quest_id))

func _try_finish() -> void:
    if rewards_claimed or completed_stages.size() < chapter.get("stages", []).size(): return
    rewards_claimed = true
    CampaignState.set_chapter_flag("chapter_06_vertical_slice_complete")
    CampaignState.discovered_revelations["chapter_06_end"] = String(chapter.get("end_revelation", ""))
    CampaignState.add_metric("absent_contact", 5)
    GameState.gold += 110
    GameState.essence += 16
    GameState.add_log("Chapitre VI terminé : certains Absents répondent encore.")
    chapter_six_completed.emit()

func serialize() -> Dictionary:
    return {"discovered_signals":discovered_signals.duplicate(true),"confirmed_hypotheses":confirmed_hypotheses.duplicate(true),"reaction_records":reaction_records.duplicate(true),"stabilized_anchors":stabilized_anchors.duplicate(true),"completed_stages":completed_stages.duplicate(true),"saen_contact":saen_contact,"final_choice":final_choice,"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    discovered_signals = payload.get("discovered_signals", {}).duplicate(true)
    confirmed_hypotheses = payload.get("confirmed_hypotheses", {}).duplicate(true)
    reaction_records = payload.get("reaction_records", {}).duplicate(true)
    stabilized_anchors = payload.get("stabilized_anchors", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    saen_contact = bool(payload.get("saen_contact", false))
    final_choice = String(payload.get("final_choice", ""))
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_six_changed.emit()
