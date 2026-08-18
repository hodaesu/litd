extends Node

signal chapter_five_changed
signal fragment_discovered(fragment: Dictionary)
signal hypothesis_confirmed(hypothesis_id: String)
signal final_choice_required
signal chapter_five_completed

const CHAPTER_PATH := "res://data/levels/chapter_05_great_closure.json"
const WORLD_PATH := "res://data/levels/chapter_05_world.json"

var chapter: Dictionary = {}
var world: Dictionary = {}
var discovered_fragments: Dictionary = {}
var confirmed_hypotheses: Dictionary = {}
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
    discovered_fragments = {}; confirmed_hypotheses = {}; completed_stages = {}; final_choice = ""; rewards_claimed = false
    chapter_five_changed.emit()

func fragments() -> Array: return world.get("fragments", [])
func hypotheses() -> Array: return world.get("hypotheses", [])
func fragment_count() -> int: return discovered_fragments.size()

func get_fragment(fragment_id: String) -> Dictionary:
    for value in fragments():
        var fragment: Dictionary = value
        if String(fragment.get("id", "")) == fragment_id: return fragment
    return {}

func collect_fragment(fragment_id: String) -> bool:
    if discovered_fragments.has(fragment_id): return false
    var fragment := get_fragment(fragment_id)
    if fragment.is_empty(): return false
    discovered_fragments[fragment_id] = fragment.duplicate(true)
    fragment_discovered.emit(fragment.duplicate(true))
    _recalculate_hypotheses(); refresh_progress(); chapter_five_changed.emit()
    return true

func independent_source_family_count() -> int:
    var groups := {}
    for value in discovered_fragments.values(): groups[String((value as Dictionary).get("source_family","unknown"))] = true
    return groups.size()

func category_count(category: String) -> int:
    var total := 0
    for value in discovered_fragments.values():
        if String((value as Dictionary).get("category","")) == category: total += 1
    return total

func _recalculate_hypotheses() -> void:
    for value in hypotheses():
        var h: Dictionary = value
        var id := String(h.get("id",""))
        if bool(confirmed_hypotheses.get(id,false)): continue
        var support := 0
        var sources := {}
        for f_value in discovered_fragments.values():
            var f: Dictionary = f_value
            if id in f.get("supports",[]):
                support += 1
                sources[String(f.get("source_family","unknown"))] = true
        if support >= int(h.get("required_support",1)) and sources.size() >= int(h.get("independent_sources",1)):
            confirmed_hypotheses[id] = true
            CampaignState.discovered_revelations["c05_%s" % id] = String(h.get("title",id))
            CampaignState.set_chapter_flag("c05_%s_confirmed" % id)
            CampaignState.add_metric("veil_knowledge",4)
            DeepVestigeRuntime.refresh_unlocks()
            hypothesis_confirmed.emit(id)

func active_stage() -> Dictionary:
    for value in chapter.get("stages",[]):
        var stage: Dictionary = value
        if not bool(completed_stages.get(String(stage.get("id","")),false)): return stage
    return {}

func progress_text() -> String: return "%d/%d" % [completed_stages.size(), chapter.get("stages",[]).size()]

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c05_boss_silex_general" and final_choice == "": call_deferred("_request_choice")
    refresh_progress()

func _request_choice() -> void: final_choice_required.emit()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_05_great_closure": return
    _complete_if("c05_stage_01_crypts", AshlandsRuntime.is_zone_discovered("c05_black_glass_crypts"))
    _complete_if("c05_stage_02_forge", bool(confirmed_hypotheses.get("weaponized_reality",false)))
    _complete_if("c05_stage_03_bastion", AshlandsRuntime.is_encounter_cleared("c05_glass_strategist"))
    _complete_if("c05_stage_04_saan", bool(confirmed_hypotheses.get("saan_network",false)) and AshlandsRuntime.is_zone_discovered("c05_saan_well"))
    _complete_if("c05_stage_05_camp", AshlandsRuntime.was_campfire_used_this_run("c05_last_watch_camp"))
    var rules: Dictionary = chapter.get("investigation",{})
    _complete_if("c05_stage_06_closure", fragment_count() >= int(rules.get("required_fragments",8)) and independent_source_family_count() >= int(rules.get("independent_source_families",4)) and category_count("civilian") >= int(rules.get("civilian_sources_min",2)) and category_count("saan") >= int(rules.get("saan_sources_min",2)) and bool(confirmed_hypotheses.get("closure_cost",false)))
    _complete_if("c05_stage_07_general", AshlandsRuntime.is_encounter_cleared("c05_boss_silex_general") and final_choice != "")
    _complete_if("c05_stage_08_return", GameState.current_screen == "sanctuary" and final_choice != "")
    _sync_main_quests(); _try_finish(); chapter_five_changed.emit()

func _complete_if(id: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(id,false)):
        completed_stages[id] = true; GameState.add_log("Chapitre V — %s" % id)

func choose_final_outcome(choice_id: String) -> bool:
    if not AshlandsRuntime.is_encounter_cleared("c05_boss_silex_general"): return false
    for value in chapter.get("boss_choices",[]):
        var choice: Dictionary = value
        if String(choice.get("id","")) != choice_id: continue
        final_choice = choice_id
        var effects: Dictionary = choice.get("effects",{})
        for metric in ["veil_knowledge","ancient_preservation","justice_integrity"]:
            if effects.has(metric): CampaignState.add_metric(metric,int(effects[metric]))
        if effects.has("tension"): PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]),0,100)
        CampaignState.set_chapter_flag("c05_general_%s" % choice_id)
        refresh_progress(); return true
    return false

func _sync_main_quests() -> void:
    var bindings := {"c05_weaponized_reality":["c05_stage_01_crypts","c05_stage_02_forge","c05_stage_03_bastion"],"c05_saan_network":["c05_stage_04_saan","c05_stage_05_camp"],"c05_price_of_closure":["c05_stage_06_closure","c05_stage_07_general","c05_stage_08_return"]}
    for quest_id in bindings:
        if CampaignState.is_main_quest_completed(String(quest_id)): continue
        var done := true
        for stage_id in bindings[quest_id]:
            if not bool(completed_stages.get(stage_id,false)): done = false; break
        if done: CampaignState.complete_main_quest(String(quest_id))

func _try_finish() -> void:
    if rewards_claimed or completed_stages.size() < chapter.get("stages",[]).size(): return
    rewards_claimed = true
    CampaignState.set_chapter_flag("chapter_05_vertical_slice_complete")
    CampaignState.discovered_revelations["chapter_05_end"] = String(chapter.get("end_revelation",""))
    DeepVestigeRuntime.refresh_unlocks()
    GameState.add_log("Chapitre V terminé : la Grande Fermeture a sauvé le continent au prix de régions entières.")
    chapter_five_completed.emit()

func serialize() -> Dictionary:
    return {"discovered_fragments":discovered_fragments.duplicate(true),"confirmed_hypotheses":confirmed_hypotheses.duplicate(true),"completed_stages":completed_stages.duplicate(true),"final_choice":final_choice,"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    discovered_fragments = payload.get("discovered_fragments",{}).duplicate(true); confirmed_hypotheses = payload.get("confirmed_hypotheses",{}).duplicate(true); completed_stages = payload.get("completed_stages",{}).duplicate(true); final_choice = String(payload.get("final_choice","")); rewards_claimed = bool(payload.get("rewards_claimed",false)); chapter_five_changed.emit()
