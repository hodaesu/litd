extends Node

signal chapter_nine_changed
signal observation_discovered(entry: Dictionary)
signal model_confirmed(model_id: String)
signal node_activated(node_id: String)
signal final_choice_required
signal chapter_nine_completed

const CHAPTER_PATH := "res://data/levels/chapter_09_veil_nature.json"
const WORLD_PATH := "res://data/levels/chapter_09_world.json"

var chapter: Dictionary = {}
var world: Dictionary = {}
var collected_observations: Dictionary = {}
var active_nodes: Dictionary = {}
var confirmed_models: Dictionary = {}
var completed_stages: Dictionary = {}
var final_choice := ""
var rewards_claimed := false

func _ready() -> void:
    chapter = _load_json(CHAPTER_PATH)
    world = _load_json(WORLD_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(func(_id): refresh_progress())
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)
    CampaignState.campaign_changed.connect(_recalculate_models)
    DeepVestigeRuntime.vestige_changed.connect(_recalculate_models)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    collected_observations = {}
    active_nodes = {}
    confirmed_models = {}
    completed_stages = {}
    final_choice = ""
    rewards_claimed = false
    chapter_nine_changed.emit()

func observations() -> Array: return world.get("observations", [])
func observation_count() -> int: return collected_observations.size()

func observation(id_value: String) -> Dictionary:
    for value in observations():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == id_value: return entry
    return {}

func is_observation_collected(id_value: String) -> bool:
    return collected_observations.has(id_value)

func collect_observation(id_value: String) -> bool:
    if collected_observations.has(id_value): return false
    var entry := observation(id_value)
    if entry.is_empty(): return false
    collected_observations[id_value] = entry.duplicate(true)
    observation_discovered.emit(entry.duplicate(true))
    GameState.add_log("Observation du Voile — %s" % String(entry.get("title", id_value)))
    _recalculate_models()
    refresh_progress()
    chapter_nine_changed.emit()
    return true

func source_family_count() -> int:
    var families := {}
    for value in collected_observations.values():
        families[String((value as Dictionary).get("source_family", "unknown"))] = true
    return families.size()

func support_count(model_id: String) -> int:
    var total := 0
    for value in collected_observations.values():
        if model_id in (value as Dictionary).get("supports", []): total += 1
    return total

func support_family_count(model_id: String) -> int:
    var families := {}
    for value in collected_observations.values():
        var entry: Dictionary = value
        if model_id in entry.get("supports", []): families[String(entry.get("source_family", "unknown"))] = true
    return families.size()

func deep_truth_count() -> int:
    var total := 0
    for value in chapter.get("ancient_lenses", []):
        var lens: Dictionary = value
        if bool(CampaignState.chapter_flags.get(String(lens.get("deep_truth_flag", "")), false)): total += 1
    return total

func ancient_lenses_seen() -> int:
    var seen := 0
    var ids := ["c09_obs_ashai","c09_obs_silex","c09_obs_vaor","c09_obs_lyr","c09_obs_sahmir","c09_obs_ydris"]
    for id_value in ids:
        if is_observation_collected(id_value): seen += 1
    if is_observation_collected("c09_obs_saan_boundary") or is_observation_collected("c09_obs_saan_root"): seen += 1
    return mini(7, seen)

func _model_data(model_id: String) -> Dictionary:
    for value in chapter.get("models", []):
        var data: Dictionary = value
        if String(data.get("id", "")) == model_id: return data
    return {}

func _recalculate_models() -> void:
    if chapter.is_empty(): return
    for value in chapter.get("models", []):
        var model: Dictionary = value
        var model_id := String(model.get("id", ""))
        var enough := support_count(model_id) >= int(model.get("required_support", 99)) and support_family_count(model_id) >= int(model.get("required_families", 99))
        if enough and not bool(confirmed_models.get(model_id, false)):
            confirmed_models[model_id] = true
            model_confirmed.emit(model_id)
            GameState.add_log("Modèle confirmé avec réserve — %s" % String(model.get("name", model_id)))
    chapter_nine_changed.emit()

func confirmed_model_count() -> int:
    return confirmed_models.size()

func confidence_for(model_id: String) -> int:
    var model := _model_data(model_id)
    if model.is_empty(): return 0
    var support_ratio := minf(1.0, float(support_count(model_id)) / float(maxi(1, int(model.get("required_support", 1)))))
    var family_ratio := minf(1.0, float(support_family_count(model_id)) / float(maxi(1, int(model.get("required_families", 1)))))
    var bonus := mini(20, deep_truth_count() * int(chapter.get("model_rules", {}).get("deep_truth_bonus_per_vestige", 2)))
    return clampi(int(round((support_ratio * 45.0) + (family_ratio * 35.0))) + bonus, 0, 100)

func _node_data(node_id: String) -> Dictionary:
    for value in world.get("nodes", []):
        var data: Dictionary = value
        if String(data.get("id", "")) == node_id: return data
    return {}

func activate_node(node_id: String) -> bool:
    if active_nodes.has(node_id): return false
    var data := _node_data(node_id)
    if data.is_empty(): return false
    active_nodes[node_id] = true
    node_activated.emit(node_id)
    GameState.add_log("Ancrage activé — %s" % String(data.get("label", node_id)))
    refresh_progress()
    chapter_nine_changed.emit()
    return true

func is_node_active(node_id: String) -> bool:
    return active_nodes.has(node_id)

func node_count(node_type: String) -> int:
    var total := 0
    for node_id in active_nodes.keys():
        if String(_node_data(String(node_id)).get("type", "")) == node_type: total += 1
    return total

func active_stage() -> Dictionary:
    for value in chapter.get("stages", []):
        var stage: Dictionary = value
        if not bool(completed_stages.get(String(stage.get("id", "")), false)): return stage
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), chapter.get("stages", []).size()]

func available_final_choices() -> Array:
    var result: Array = []
    for value in chapter.get("boss_choices", []):
        var choice: Dictionary = value
        if _choice_available(choice): result.append(choice)
    return result

func _choice_available(choice: Dictionary) -> bool:
    var req: Dictionary = choice.get("requirements", {})
    if confirmed_model_count() < int(req.get("models_confirmed", 0)): return false
    if deep_truth_count() < int(req.get("deep_truths", 0)): return false
    if int(CampaignState.metrics.get("justice_integrity", 50)) < int(req.get("justice_integrity_min", 0)): return false
    if int(CampaignState.metrics.get("absent_contact", 0)) < int(req.get("absent_contact_min", 0)): return false
    return true

func choose_final_outcome(choice_id: String) -> bool:
    if final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c09_boss_consensus"): return false
    for value in chapter.get("boss_choices", []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id or not _choice_available(choice): continue
        final_choice = choice_id
        _apply_effects(choice.get("effects", {}))
        CampaignState.set_chapter_flag("c09_consensus_%s" % choice_id)
        GameState.add_log("Consensus Brisé — %s" % String(choice.get("label", choice_id)))
        refresh_progress()
        chapter_nine_changed.emit()
        return true
    return false

func _apply_effects(effects: Dictionary) -> void:
    for metric in ["justice_integrity","veil_knowledge","absent_contact","creature_relations","foreign_alliances","stabilizer_nodes"]:
        if effects.has(metric): CampaignState.add_metric(metric, int(effects[metric]))
    if effects.has("tension"):
        PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
        PoliticalState.politics_changed.emit()

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c09_boss_consensus" and final_choice == "": call_deferred("_request_choice")
    refresh_progress()

func _request_choice() -> void:
    final_choice_required.emit()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_09_veil_nature": return
    _recalculate_models()
    _complete_if("c09_stage_01_tree", AshlandsRuntime.is_zone_discovered("c09_tree_node") and is_observation_collected("c09_obs_tree_light") and is_observation_collected("c09_obs_saan_root"))
    _complete_if("c09_stage_02_lenses", AshlandsRuntime.is_zone_discovered("c09_seven_lenses") and ancient_lenses_seen() >= 7)
    _complete_if("c09_stage_03_living_witnesses", AshlandsRuntime.is_zone_discovered("c09_living_resonance") and is_observation_collected("c09_obs_creature_memory") and is_observation_collected("c09_obs_saen_reply") and is_observation_collected("c09_obs_human_recall"))
    _complete_if("c09_stage_04_saan", AshlandsRuntime.is_zone_discovered("c09_saan_network") and node_count("stabilizer") >= 3)
    _complete_if("c09_stage_05_fear", AshlandsRuntime.is_zone_discovered("c09_fear_basin") and AshlandsRuntime.is_encounter_cleared("c09_fear_echo") and is_observation_collected("c09_obs_fear_not_creation"))
    var rules: Dictionary = chapter.get("model_rules", {})
    _complete_if("c09_stage_06_limit", AshlandsRuntime.is_zone_discovered("c09_deep_overlap") and observation_count() >= int(rules.get("observations_required", 12)) and source_family_count() >= int(rules.get("source_families_required", 6)) and confirmed_model_count() >= 4 and is_observation_collected("c09_obs_no_origin"))
    _complete_if("c09_stage_07_consensus", node_count("perspective") >= 3 and AshlandsRuntime.is_encounter_cleared("c09_boss_consensus") and final_choice != "")
    _complete_if("c09_stage_08_return", GameState.current_screen == "sanctuary" and final_choice != "" and confirmed_model_count() >= 4)
    _sync_main_quests()
    _try_finish()
    chapter_nine_changed.emit()

func _complete_if(id_value: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(id_value, false)):
        completed_stages[id_value] = true
        GameState.add_log("Chapitre IX — %s" % id_value)

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
    CampaignState.set_chapter_flag("chapter_09_vertical_slice_complete")
    CampaignState.set_chapter_flag("sanctuary_model_chamber_unlocked")
    CampaignState.set_chapter_flag("c09_operational_veil_model")
    CampaignState.discovered_revelations["chapter_09_end"] = String(chapter.get("end_revelation", ""))
    CampaignState.add_metric("veil_knowledge", 8)
    GameState.gold += 170
    GameState.essence += 24
    GameState.add_log("Chapitre IX terminé : un modèle opératoire existe, mais l'origine ultime du Voile demeure inconnue.")
    chapter_nine_completed.emit()

func serialize() -> Dictionary:
    return {"collected_observations":collected_observations.duplicate(true),"active_nodes":active_nodes.duplicate(true),"confirmed_models":confirmed_models.duplicate(true),"completed_stages":completed_stages.duplicate(true),"final_choice":final_choice,"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    collected_observations = payload.get("collected_observations", {}).duplicate(true)
    active_nodes = payload.get("active_nodes", {}).duplicate(true)
    confirmed_models = payload.get("confirmed_models", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    final_choice = String(payload.get("final_choice", ""))
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    _recalculate_models()
    chapter_nine_changed.emit()
