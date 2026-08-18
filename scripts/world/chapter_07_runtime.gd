extends Node

signal chapter_seven_changed
signal testimony_discovered(entry: Dictionary)
signal interview_completed(actor_id: String)
signal provisional_choice_required(actor_id: String)
signal counter_ritual_stabilized(anchor_id: String)
signal final_choice_required
signal chapter_seven_completed

const CHAPTER_PATH := "res://data/levels/chapter_07_living_responsible.json"
const WORLD_PATH := "res://data/levels/chapter_07_world.json"

var chapter: Dictionary = {}
var world: Dictionary = {}
var collected_testimonies: Dictionary = {}
var interviews: Dictionary = {}
var provisional_choices: Dictionary = {}
var disabled_pilgrim_seals: Dictionary = {}
var counter_rituals: Dictionary = {}
var completed_stages: Dictionary = {}
var final_choice := ""
var rewards_claimed := false

func _ready() -> void:
    chapter = _load_json(CHAPTER_PATH)
    world = _load_json(WORLD_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(func(_id): refresh_progress())
    AshlandsRuntime.campfire_used.connect(func(_id): refresh_progress())
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    collected_testimonies = {}
    interviews = {}
    provisional_choices = {}
    disabled_pilgrim_seals = {}
    counter_rituals = {}
    completed_stages = {}
    final_choice = ""
    rewards_claimed = false
    chapter_seven_changed.emit()

func testimonies() -> Array: return world.get("testimonies", [])
func testimony_count() -> int: return collected_testimonies.size()
func counter_ritual_count() -> int: return counter_rituals.size()
func pilgrim_seal_count() -> int: return disabled_pilgrim_seals.size()

func get_testimony(id_value: String) -> Dictionary:
    for value in testimonies():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == id_value: return entry
    return {}

func collect_testimony(id_value: String) -> bool:
    if collected_testimonies.has(id_value): return false
    var entry := get_testimony(id_value)
    if entry.is_empty(): return false
    collected_testimonies[id_value] = entry.duplicate(true)
    testimony_discovered.emit(entry.duplicate(true))
    GameState.add_log("Dossier de responsabilité — %s" % String(entry.get("title", id_value)))
    refresh_progress()
    chapter_seven_changed.emit()
    return true

func testimony_count_for_actor(actor_id: String) -> int:
    var total := 0
    for value in collected_testimonies.values():
        if String((value as Dictionary).get("actor", "")) == actor_id: total += 1
    return total

func independent_source_count_for_actor(actor_id: String) -> int:
    var families := {}
    for value in collected_testimonies.values():
        var entry: Dictionary = value
        if String(entry.get("actor", "")) == actor_id:
            families[String(entry.get("source_family", "unknown"))] = true
    return families.size()

func foreign_chain_count() -> int:
    var total := 0
    for value in collected_testimonies.values():
        if "foreign_chain" in (value as Dictionary).get("supports", []): total += 1
    return total

func interview_actor(actor_id: String) -> bool:
    if actor_id not in ["bram","veyra"] or bool(interviews.get(actor_id, false)): return false
    var data_id := "bram_torgun" if actor_id == "bram" else "veyra_oss"
    var old_link := int(Chapter03Runtime.actor_links.get(data_id, 0)) >= 1
    if not old_link or testimony_count_for_actor(data_id) < 3 or independent_source_count_for_actor(data_id) < 2: return false
    interviews[actor_id] = true
    GameState.add_log("Déposition enregistrée : %s." % ("Bram Torgun" if actor_id == "bram" else "Veyra Oss"))
    interview_completed.emit(actor_id)
    provisional_choice_required.emit(actor_id)
    refresh_progress()
    chapter_seven_changed.emit()
    return true

func can_resolve_actor(actor_id: String) -> bool:
    if not bool(interviews.get(actor_id, false)): return false
    var data_id := "bram_torgun" if actor_id == "bram" else "veyra_oss"
    var old_link := int(Chapter03Runtime.actor_links.get(data_id, 0)) >= 1
    return old_link and testimony_count_for_actor(data_id) >= 3 and independent_source_count_for_actor(data_id) >= 2

func choose_provisional_outcome(actor_id: String, choice_id: String) -> bool:
    if actor_id not in ["bram","veyra"] or provisional_choices.has(actor_id) or not can_resolve_actor(actor_id): return false
    for value in chapter.get("provisional_outcomes", {}).get(actor_id, []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id: continue
        provisional_choices[actor_id] = choice_id
        _apply_effects(choice.get("effects", {}))
        CampaignState.set_chapter_flag("c07_%s_%s" % [actor_id, choice_id])
        GameState.add_log("Statut provisoire de %s : %s" % [actor_id, String(choice.get("label", choice_id))])
        refresh_progress()
        chapter_seven_changed.emit()
        return true
    return false

func disable_pilgrim_seal(node_id: String) -> bool:
    if node_id not in ["c07_pilgrim_seal_west","c07_pilgrim_seal_east"] or disabled_pilgrim_seals.has(node_id): return false
    disabled_pilgrim_seals[node_id] = true
    GameState.add_log("Sceau du Pèlerin neutralisé — %d/2." % pilgrim_seal_count())
    chapter_seven_changed.emit()
    return true

func stabilize_counter_ritual(anchor_id: String) -> bool:
    if anchor_id not in ["c07_anchor_bram","c07_anchor_veyra","c07_anchor_saen"] or counter_rituals.has(anchor_id): return false
    if anchor_id == "c07_anchor_bram" and not provisional_choices.has("bram"): return false
    if anchor_id == "c07_anchor_veyra" and not provisional_choices.has("veyra"): return false
    if anchor_id == "c07_anchor_saen" and int(CampaignState.metrics.get("absent_contact", 0)) < 4: return false
    counter_rituals[anchor_id] = true
    CampaignState.add_metric("stabilizer_nodes", 1)
    counter_ritual_stabilized.emit(anchor_id)
    GameState.add_log("Contre-rituel stabilisé — %d/3." % counter_ritual_count())
    chapter_seven_changed.emit()
    return true

func active_stage() -> Dictionary:
    for value in chapter.get("stages", []):
        var stage: Dictionary = value
        if not bool(completed_stages.get(String(stage.get("id", "")), false)): return stage
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), chapter.get("stages", []).size()]

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c07_boss_edras" and final_choice == "": call_deferred("_request_final_choice")
    refresh_progress()

func _request_final_choice() -> void: final_choice_required.emit()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_07_living_responsible": return
    _complete_if("c07_stage_01_bram", AshlandsRuntime.is_zone_discovered("c07_engineer_refuge"))
    _complete_if("c07_stage_02_bram_testimony", provisional_choices.has("bram") and can_resolve_actor("bram"))
    _complete_if("c07_stage_03_veyra", AshlandsRuntime.is_zone_discovered("c07_fractured_monastery"))
    _complete_if("c07_stage_04_veyra_testimony", provisional_choices.has("veyra") and can_resolve_actor("veyra"))
    _complete_if("c07_stage_05_judgment_camp", AshlandsRuntime.was_campfire_used_this_run("c07_relay_camp") and provisional_choices.has("bram") and provisional_choices.has("veyra"))
    _complete_if("c07_stage_06_pilgrim", pilgrim_seal_count() >= 2 and AshlandsRuntime.is_encounter_cleared("c07_opening_pilgrim"))
    _complete_if("c07_stage_07_edras", counter_ritual_count() >= 3 and AshlandsRuntime.is_encounter_cleared("c07_boss_edras") and final_choice != "")
    _complete_if("c07_stage_08_hearing", GameState.current_screen == "sanctuary" and final_choice != "" and provisional_choices.size() >= 2 and foreign_chain_count() >= 3)
    _sync_main_quests()
    _try_finish()
    chapter_seven_changed.emit()

func _complete_if(id_value: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(id_value, false)):
        completed_stages[id_value] = true
        GameState.add_log("Chapitre VII — %s" % id_value)

func available_boss_choices() -> Array:
    var result: Array = []
    for value in chapter.get("boss_choices", []):
        var choice: Dictionary = value
        if _boss_choice_available(choice): result.append(choice)
    return result

func _boss_choice_available(choice: Dictionary) -> bool:
    if String(choice.get("id", "")) != "controlled_trial": return true
    var req: Dictionary = choice.get("requirements", {})
    return counter_ritual_count() >= int(req.get("anchors", 3)) and int(CampaignState.metrics.get("absent_contact", 0)) >= int(req.get("absent_contact_min", 8)) and int(CampaignState.metrics.get("justice_integrity", 0)) >= int(req.get("justice_integrity_min", 45)) and provisional_choices.has("bram") and provisional_choices.has("veyra")

func choose_final_outcome(choice_id: String) -> bool:
    if final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c07_boss_edras") or counter_ritual_count() < 3: return false
    for value in chapter.get("boss_choices", []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id or not _boss_choice_available(choice): continue
        final_choice = choice_id
        _apply_effects(choice.get("effects", {}))
        CampaignState.set_chapter_flag("c07_edras_%s" % choice_id)
        refresh_progress()
        return true
    return false

func _apply_effects(effects: Dictionary) -> void:
    for metric in ["justice_integrity","veil_knowledge","absent_contact","creature_relations","foreign_alliances","stabilizer_nodes"]:
        if effects.has(metric): CampaignState.add_metric(metric, int(effects[metric]))
    if effects.has("trust"): PoliticalState.trust = clampi(PoliticalState.trust + int(effects["trust"]), 0, 100)
    if effects.has("tension"): PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
    PoliticalState.politics_changed.emit()

func _sync_main_quests() -> void:
    for quest_id in chapter.get("main_quest_bindings", {}).keys():
        if CampaignState.is_main_quest_completed(String(quest_id)): continue
        var done := true
        for stage_id in chapter.get("main_quest_bindings", {})[quest_id]:
            if not bool(completed_stages.get(String(stage_id), false)):
                done = false
                break
        if done: CampaignState.complete_main_quest(String(quest_id))

func _try_finish() -> void:
    if rewards_claimed or completed_stages.size() < chapter.get("stages", []).size(): return
    rewards_claimed = true
    CampaignState.set_chapter_flag("chapter_07_vertical_slice_complete")
    CampaignState.set_chapter_flag("sanctuary_public_hearing_unlocked")
    CampaignState.set_chapter_flag("c07_foreign_command_chain_confirmed")
    CampaignState.discovered_revelations["chapter_07_end"] = String(chapter.get("end_revelation", ""))
    CampaignState.add_metric("foreign_alliances", 3)
    GameState.gold += 125
    GameState.essence += 18
    GameState.add_log("Chapitre VII terminé : les responsabilités individuelles et la chaîne étrangère sont documentées.")
    chapter_seven_completed.emit()

func serialize() -> Dictionary:
    return {"collected_testimonies":collected_testimonies.duplicate(true),"interviews":interviews.duplicate(true),"provisional_choices":provisional_choices.duplicate(true),"disabled_pilgrim_seals":disabled_pilgrim_seals.duplicate(true),"counter_rituals":counter_rituals.duplicate(true),"completed_stages":completed_stages.duplicate(true),"final_choice":final_choice,"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    collected_testimonies = payload.get("collected_testimonies", {}).duplicate(true)
    interviews = payload.get("interviews", {}).duplicate(true)
    provisional_choices = payload.get("provisional_choices", {}).duplicate(true)
    disabled_pilgrim_seals = payload.get("disabled_pilgrim_seals", {}).duplicate(true)
    counter_rituals = payload.get("counter_rituals", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    final_choice = String(payload.get("final_choice", ""))
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_seven_changed.emit()
