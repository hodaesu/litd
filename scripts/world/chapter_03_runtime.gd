extends Node

signal chapter_three_changed
signal evidence_discovered(evidence: Dictionary)
signal echo_choice_required
signal chapter_three_completed

const DATA_PATH := "res://data/levels/chapter_03_threshold.json"
const WORLD_PATH := "res://data/levels/chapter_03_world.json"

var data: Dictionary = {}
var world: Dictionary = {}
var collected_evidence: Dictionary = {}
var completed_stages: Dictionary = {}
var actor_links: Dictionary = {}
var echo_choice := ""
var rewards_claimed := false

func _ready() -> void:
    data = _load_json(DATA_PATH)
    world = _load_json(WORLD_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(_on_world_changed)
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)
    AshlandsRuntime.campfire_used.connect(_on_campfire)

func _load_json(path: String) -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    collected_evidence = {}
    completed_stages = {}
    actor_links = {}
    echo_choice = ""
    rewards_claimed = false
    chapter_three_changed.emit()

func evidence_entries() -> Array:
    return world.get("evidence", [])

func get_evidence(id_value: String) -> Dictionary:
    for value in evidence_entries():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == id_value:
            return entry
    return {}

func collect_evidence(id_value: String) -> bool:
    if collected_evidence.has(id_value):
        return false
    var entry := get_evidence(id_value)
    if entry.is_empty():
        return false
    collected_evidence[id_value] = entry.duplicate(true)
    for actor in entry.get("actors", []):
        var actor_id := String(actor)
        actor_links[actor_id] = int(actor_links.get(actor_id, 0)) + 1
    evidence_discovered.emit(entry.duplicate(true))
    GameState.add_log("Preuve : %s" % String(entry.get("title", id_value)))
    refresh_progress()
    chapter_three_changed.emit()
    return true

func is_evidence_collected(id_value: String) -> bool:
    return collected_evidence.has(id_value)

func evidence_count() -> int:
    return collected_evidence.size()

func actor_count_with_evidence() -> int:
    var count := 0
    for actor_value in data.get("actors", []):
        var actor: Dictionary = actor_value
        if int(actor_links.get(String(actor.get("id", "")), 0)) >= 1:
            count += 1
    return count

func independent_source_count() -> int:
    var groups: Dictionary = {}
    for value in collected_evidence.values():
        groups[String(value.get("source_group", "unknown"))] = true
    return groups.size()

func active_stage() -> Dictionary:
    for value in data.get("stages", []):
        var stage: Dictionary = value
        if not bool(completed_stages.get(String(stage.get("id", "")), false)):
            return stage
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), data.get("stages", []).size()]

func _on_world_changed(_zone_id: String) -> void:
    refresh_progress()

func _on_campfire(_zone_id: String) -> void:
    refresh_progress()

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c03_boss_threshold_echo" and echo_choice == "":
        call_deferred("_request_echo_choice")
    refresh_progress()

func _request_echo_choice() -> void:
    echo_choice_required.emit()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_03_threshold":
        return
    _complete_if("c03_stage_01_relay", AshlandsRuntime.is_zone_discovered("c03_abandoned_relay"))
    _complete_if("c03_stage_02_korem", _zone_has_evidence("c03_korem_lab", 2))
    _complete_if("c03_stage_03_diplomatic", _zone_has_evidence("c03_diplomatic_post", 3))
    _complete_if("c03_stage_04_defense", AshlandsRuntime.is_encounter_cleared("c03_threshold_sentinel"))
    _complete_if("c03_stage_05_abort", is_evidence_collected("ev_bram_abort") and is_evidence_collected("ev_eline_copy"))
    var rules: Dictionary = data.get("evidence_rules", {})
    _complete_if("c03_stage_06_responsibility", evidence_count() >= int(rules.get("required_evidence", 9)) and actor_count_with_evidence() >= int(rules.get("required_actor_links", 6)) and independent_source_count() >= int(rules.get("independent_source_groups", 4)))
    _complete_if("c03_stage_07_echo", AshlandsRuntime.is_encounter_cleared("c03_boss_threshold_echo") and echo_choice != "")
    _complete_if("c03_stage_08_return", GameState.current_screen == "sanctuary" and echo_choice != "")
    _sync_main_quests()
    _try_finish()
    chapter_three_changed.emit()

func _zone_has_evidence(zone_id: String, minimum: int) -> bool:
    var ids: Array = []
    for zone_value in world.get("zones", []):
        var zone: Dictionary = zone_value
        if String(zone.get("id", "")) == zone_id:
            ids = zone.get("evidence", [])
            break
    var count := 0
    for id_value in ids:
        if is_evidence_collected(String(id_value)):
            count += 1
    return count >= minimum

func _complete_if(stage_id: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(stage_id, false)):
        completed_stages[stage_id] = true
        GameState.add_log("Chapitre III — %s" % stage_id)

func choose_echo_outcome(choice_id: String) -> bool:
    if not AshlandsRuntime.is_encounter_cleared("c03_boss_threshold_echo"):
        return false
    for value in data.get("boss_choices", []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id:
            continue
        echo_choice = choice_id
        var effects: Dictionary = choice.get("effects", {})
        if effects.has("veil_knowledge"):
            CampaignState.add_metric("veil_knowledge", int(effects["veil_knowledge"]))
        if effects.has("tension"):
            PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
            PoliticalState.politics_changed.emit()
        var madness_delta := int(effects.get("madness_all", 0))
        for hero in GameState.party:
            hero["madness"] = clampi(int(hero.get("madness", 0)) + madness_delta, 0, 100)
        CampaignState.set_chapter_flag("c03_echo_%s" % choice_id)
        if choice_id in ["record", "prolong"]:
            CampaignState.set_chapter_flag("c03_ancient_symbols_seen")
            CampaignState.discovered_revelations["c03_ancient_symbols"] = String(data.get("ancient_symbol_revelation", {}).get("fact", ""))
        if choice_id == "prolong":
            CampaignState.set_chapter_flag("c03_ashai_pattern_match")
            CampaignState.discovered_revelations["c03_ashai_pattern"] = String(data.get("ancient_symbol_revelation", {}).get("strong_reveal", ""))
        refresh_progress()
        return true
    return false

func _sync_main_quests() -> void:
    var bindings := {
        "c03_six_names":["c03_stage_01_relay","c03_stage_02_korem","c03_stage_06_responsibility"],
        "c03_horizon_pact":["c03_stage_03_diplomatic","c03_stage_04_defense"],
        "c03_last_abort":["c03_stage_05_abort","c03_stage_07_echo","c03_stage_08_return"]
    }
    for quest_id in bindings.keys():
        if CampaignState.is_main_quest_completed(String(quest_id)):
            continue
        var all_done := true
        for stage_id in bindings[quest_id]:
            if not bool(completed_stages.get(stage_id, false)):
                all_done = false
                break
        if all_done:
            CampaignState.complete_main_quest(String(quest_id))

func _try_finish() -> void:
    if rewards_claimed or completed_stages.size() < data.get("stages", []).size():
        return
    rewards_claimed = true
    CampaignState.set_chapter_flag("chapter_03_vertical_slice_complete")
    CampaignState.discovered_revelations["chapter_03_end"] = String(data.get("end_revelation", ""))
    GameState.add_log("Chapitre III terminé : le Projet Seuil est nommé et ses responsabilités documentées.")
    chapter_three_completed.emit()

func serialize() -> Dictionary:
    return {"collected_evidence":collected_evidence.duplicate(true),"completed_stages":completed_stages.duplicate(true),"actor_links":actor_links.duplicate(true),"echo_choice":echo_choice,"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    collected_evidence = payload.get("collected_evidence", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    actor_links = payload.get("actor_links", {}).duplicate(true)
    echo_choice = String(payload.get("echo_choice", ""))
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_three_changed.emit()
