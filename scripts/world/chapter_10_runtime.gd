extends Node

signal chapter_ten_changed
signal stake_discovered(entry: Dictionary)
signal node_activated(node_id: String)
signal final_choice_required
signal final_orientation_chosen(ending_id: String)
signal chapter_ten_completed

const CHAPTER_PATH := "res://data/levels/chapter_10_final_choice.json"
const WORLD_PATH := "res://data/levels/chapter_10_world.json"

var chapter: Dictionary = {}
var world: Dictionary = {}
var collected_stakes: Dictionary = {}
var active_nodes: Dictionary = {}
var completed_stages: Dictionary = {}
var final_orientation := ""
var final_record: Dictionary = {}
var rewards_claimed := false

func _ready() -> void:
    chapter = _load_json(CHAPTER_PATH)
    world = _load_json(WORLD_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(func(_id): refresh_progress())
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)
    GameState.screen_requested.connect(_on_screen_requested)
    CampaignState.campaign_changed.connect(func(): chapter_ten_changed.emit())

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    collected_stakes = {}
    active_nodes = {}
    completed_stages = {}
    final_orientation = ""
    final_record = {}
    rewards_claimed = false
    chapter_ten_changed.emit()

func stakes() -> Array: return world.get("stakes", [])
func stake_count() -> int: return collected_stakes.size()

func stake(id_value: String) -> Dictionary:
    for value in stakes():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == id_value: return entry
    return {}

func is_stake_collected(id_value: String) -> bool:
    return collected_stakes.has(id_value)

func collect_stake(id_value: String) -> bool:
    if collected_stakes.has(id_value): return false
    var entry := stake(id_value)
    if entry.is_empty(): return false
    collected_stakes[id_value] = entry.duplicate(true)
    stake_discovered.emit(entry.duplicate(true))
    GameState.add_log("Enjeu final — %s" % String(entry.get("title", id_value)))
    refresh_progress()
    chapter_ten_changed.emit()
    return true

func stake_family_count() -> int:
    var families := {}
    for value in collected_stakes.values():
        families[String((value as Dictionary).get("source_family", "unknown"))] = true
    return families.size()

func _node_data(node_id: String) -> Dictionary:
    for value in world.get("nodes", []):
        var data: Dictionary = value
        if String(data.get("id", "")) == node_id: return data
    return {}

func _council_group(group_id: String) -> Dictionary:
    for value in chapter.get("council_groups", []):
        var data: Dictionary = value
        if String(data.get("id", "")) == group_id: return data
    return {}

func council_group_available(group_id: String) -> bool:
    var group := _council_group(group_id)
    if group.is_empty(): return false
    if bool(group.get("always", false)): return true
    var metric := String(group.get("metric", ""))
    if metric == "": return false
    return int(CampaignState.metrics.get(metric, 0)) >= int(group.get("min", 0))

func node_available(node_id: String) -> bool:
    var data := _node_data(node_id)
    if data.is_empty(): return false
    if String(data.get("type", "")) == "council": return council_group_available(String(data.get("group", "")))
    return true

func activate_node(node_id: String) -> bool:
    if active_nodes.has(node_id) or not node_available(node_id): return false
    var data := _node_data(node_id)
    if data.is_empty(): return false
    active_nodes[node_id] = true
    node_activated.emit(node_id)
    GameState.add_log("Dernier chapitre — %s" % String(data.get("label", node_id)))
    refresh_progress()
    chapter_ten_changed.emit()
    return true

func is_node_active(node_id: String) -> bool:
    return active_nodes.has(node_id)

func node_count(node_type: String) -> int:
    var total := 0
    for node_id in active_nodes.keys():
        if String(_node_data(String(node_id)).get("type", "")) == node_type: total += 1
    return total

func council_count() -> int: return node_count("council")
func route_count() -> int: return node_count("route")
func cost_count() -> int: return node_count("cost")
func world_anchor_count() -> int: return node_count("world_anchor")

func active_stage() -> Dictionary:
    for value in chapter.get("stages", []):
        var stage: Dictionary = value
        if not bool(completed_stages.get(String(stage.get("id", "")), false)): return stage
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), chapter.get("stages", []).size()]

func available_orientations() -> Array:
    return CampaignState.available_endings()

func _failure_state() -> Dictionary:
    var failure_by_id := {}
    for value in CampaignState.ending_data.get("failure_states", []):
        var entry: Dictionary = value
        failure_by_id[String(entry.get("id", ""))] = entry
    var city := int(PoliticalState.three_awakenings.get("city", 50))
    if PoliticalState.tension >= 75 and city < 50: return failure_by_id.get("authoritarian_order", {})
    if int(CampaignState.metrics.get("veil_knowledge", 0)) < 60: return failure_by_id.get("veil_dissolution", {})
    return failure_by_id.get("fractured_survival", {})

func final_choices() -> Array:
    var endings := available_orientations()
    if not endings.is_empty(): return endings
    var failure := _failure_state().duplicate(true)
    if not failure.is_empty():
        failure["name"] = String(failure.get("id", "failure")).replace("_", " ").capitalize()
        failure["principle"] = String(failure.get("outcome", ""))
        failure["costs"] = [String(failure.get("condition", ""))]
        failure["is_failure"] = true
        return [failure]
    return []

func unavailable_orientations() -> Array:
    var available := {}
    for value in available_orientations(): available[String((value as Dictionary).get("id", ""))] = true
    var result: Array = []
    for value in CampaignState.ending_data.get("endings", []):
        var ending: Dictionary = value
        var ending_id := String(ending.get("id", ""))
        if available.has(ending_id): continue
        var item := ending.duplicate(true)
        item["missing"] = _missing_requirements(ending.get("requirements", {}))
        result.append(item)
    return result

func _missing_requirements(requirements: Dictionary) -> Array:
    var ctx := CampaignState.ending_score_context()
    var map := {"trust_min":"trust","body_min":"body","spirit_min":"spirit","city_min":"city","creature_relations_min":"creature_relations","absent_contact_min":"absent_contact","foreign_alliances_min":"foreign_alliances","justice_integrity_min":"justice_integrity","veil_knowledge_min":"veil_knowledge","stabilizer_nodes_min":"stabilizer_nodes"}
    var missing: Array = []
    for req_key in requirements.keys():
        var ctx_key := String(map.get(String(req_key), ""))
        if ctx_key == "": continue
        var current := int(ctx.get(ctx_key, 0)); var required := int(requirements[req_key])
        if current < required: missing.append("%s %d/%d" % [ctx_key, current, required])
    return missing

func choose_final_orientation(ending_id: String) -> bool:
    if final_orientation != "" or not AshlandsRuntime.is_encounter_cleared("c10_boss_final"): return false
    for value in final_choices():
        var choice: Dictionary = value
        if String(choice.get("id", "")) != ending_id: continue
        final_orientation = ending_id
        final_record = choice.duplicate(true)
        CampaignState.set_chapter_flag("ending_%s" % ending_id)
        CampaignState.set_chapter_flag("campaign_complete")
        CampaignState.discovered_revelations["final_orientation"] = String(choice.get("name", ending_id))
        GameState.add_log("Orientation finale — %s" % String(choice.get("name", ending_id)))
        final_orientation_chosen.emit(ending_id)
        refresh_progress()
        chapter_ten_changed.emit()
        return true
    return false

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c10_boss_final":
        GameState.add_log("La Rupture est stabilisée. La décision appartient maintenant au Conseil du monde.")
    refresh_progress()

func _on_screen_requested(screen_name: String) -> void:
    if CampaignState.current_chapter_id != "chapter_10_final_choice": return
    if screen_name == "sanctuary" and AshlandsRuntime.is_encounter_cleared("c10_boss_final") and final_orientation == "":
        call_deferred("_request_final_choice")
    refresh_progress()

func _request_final_choice() -> void:
    final_choice_required.emit()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_10_final_choice": return
    var rules: Dictionary = chapter.get("decision_rules", {})
    _complete_if("c10_stage_01_council", AshlandsRuntime.is_zone_discovered("c10_world_council") and council_count() >= int(rules.get("minimum_council_groups", 3)))
    _complete_if("c10_stage_02_roots", AshlandsRuntime.is_zone_discovered("c10_sanctuary_roots") and is_stake_collected("c10_stake_infirmary") and is_stake_collected("c10_stake_workers"))
    _complete_if("c10_stage_03_elsewhere", AshlandsRuntime.is_zone_discovered("c10_border_of_absent") and is_stake_collected("c10_stake_absent_consent") and is_stake_collected("c10_stake_creature_home"))
    _complete_if("c10_stage_04_routes", AshlandsRuntime.is_zone_discovered("c10_shared_routes") and route_count() >= 3 and is_stake_collected("c10_stake_foreign_sovereignty"))
    _complete_if("c10_stage_05_cost", cost_count() >= 3 and AshlandsRuntime.is_encounter_cleared("c10_unpaid_cost"))
    _complete_if("c10_stage_06_node", AshlandsRuntime.is_zone_discovered("c10_central_node") and world_anchor_count() >= int(rules.get("world_anchors_required", 3)) and stake_count() >= int(rules.get("stakes_required", 8)) and stake_family_count() >= int(rules.get("stake_families_required", 5)))
    _complete_if("c10_stage_07_rupture", world_anchor_count() >= 3 and AshlandsRuntime.is_encounter_cleared("c10_boss_final"))
    _complete_if("c10_stage_08_choice", GameState.current_screen == "sanctuary" and final_orientation != "")
    _sync_main_quests()
    _try_finish()
    chapter_ten_changed.emit()

func _complete_if(id_value: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(id_value, false)):
        completed_stages[id_value] = true
        GameState.add_log("Chapitre X — %s" % id_value)

func _sync_main_quests() -> void:
    for quest_id in chapter.get("main_quest_bindings", {}).keys():
        if CampaignState.is_main_quest_completed(String(quest_id)): continue
        var done := true
        for stage_id in chapter.get("main_quest_bindings", {})[quest_id]:
            if not bool(completed_stages.get(String(stage_id), false)):
                done = false; break
        if done: CampaignState.complete_main_quest(String(quest_id))

func _try_finish() -> void:
    if rewards_claimed or completed_stages.size() < chapter.get("stages", []).size(): return
    rewards_claimed = true
    CampaignState.set_chapter_flag("chapter_10_complete")
    CampaignState.discovered_revelations["chapter_10_end"] = String(chapter.get("end_revelation", ""))
    GameState.add_log("Campagne terminée — %s" % String(final_record.get("name", final_orientation)))
    chapter_ten_completed.emit()

func serialize() -> Dictionary:
    return {"collected_stakes":collected_stakes.duplicate(true),"active_nodes":active_nodes.duplicate(true),"completed_stages":completed_stages.duplicate(true),"final_orientation":final_orientation,"final_record":final_record.duplicate(true),"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    collected_stakes = payload.get("collected_stakes", {}).duplicate(true)
    active_nodes = payload.get("active_nodes", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    final_orientation = String(payload.get("final_orientation", ""))
    final_record = payload.get("final_record", {}).duplicate(true)
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_ten_changed.emit()
