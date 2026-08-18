extends Node

signal chapter_two_changed
signal clue_discovered(clue: Dictionary)
signal hypothesis_confirmed(hypothesis_id: String)
signal final_choice_required
signal chapter_two_completed

const SLICE_PATH := "res://data/levels/chapter_02_vertical_slice.json"
const WORLD_PATH := "res://data/levels/chapter_02_world.json"

var slice: Dictionary = {}
var world: Dictionary = {}
var discovered_clues: Dictionary = {}
var confirmed_hypotheses: Dictionary = {}
var completed_stages: Dictionary = {}
var final_choice := ""
var rewards_claimed := false

func _ready() -> void:
    slice = _load_json(SLICE_PATH)
    world = _load_json(WORLD_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)
    AshlandsRuntime.campfire_used.connect(_on_campfire_used)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    discovered_clues = {}
    confirmed_hypotheses = {}
    completed_stages = {}
    final_choice = ""
    rewards_claimed = false
    chapter_two_changed.emit()

func clues() -> Array:
    return world.get("clues", [])

func get_clue(clue_id: String) -> Dictionary:
    for value in clues():
        var clue: Dictionary = value
        if String(clue.get("id", "")) == clue_id:
            return clue
    return {}

func collect_clue(clue_id: String) -> bool:
    if discovered_clues.has(clue_id):
        return false
    var clue := get_clue(clue_id)
    if clue.is_empty():
        return false
    discovered_clues[clue_id] = clue.duplicate(true)
    clue_discovered.emit(clue.duplicate(true))
    _recalculate_hypotheses()
    refresh_progress()
    chapter_two_changed.emit()
    return true

func is_clue_discovered(clue_id: String) -> bool:
    return discovered_clues.has(clue_id)

func clue_count() -> int:
    return discovered_clues.size()

func independent_source_count() -> int:
    var sources: Dictionary = {}
    for value in discovered_clues.values():
        var clue: Dictionary = value
        if String(clue.get("authenticity", "")) == "false":
            continue
        sources[String(clue.get("source_group", "unknown"))] = true
    return sources.size()

func _recalculate_hypotheses() -> void:
    for value in world.get("hypotheses", []):
        var hypothesis: Dictionary = value
        var hypothesis_id := String(hypothesis.get("id", ""))
        if bool(confirmed_hypotheses.get(hypothesis_id, false)):
            continue
        var supporting := 0
        var source_groups: Dictionary = {}
        for clue_value in discovered_clues.values():
            var clue: Dictionary = clue_value
            if String(clue.get("authenticity", "")) == "false":
                continue
            if hypothesis_id in clue.get("supports", []):
                supporting += 1
                source_groups[String(clue.get("source_group", "unknown"))] = true
        if supporting >= int(hypothesis.get("required_support", 1)) and source_groups.size() >= int(hypothesis.get("independent_sources", 1)):
            confirmed_hypotheses[hypothesis_id] = true
            CampaignState.discovered_revelations["c02_%s" % hypothesis_id] = String(hypothesis.get("title", hypothesis_id))
            CampaignState.add_metric("veil_knowledge", 3)
            hypothesis_confirmed.emit(hypothesis_id)

func active_stage() -> Dictionary:
    for value in slice.get("stages", []):
        var entry: Dictionary = value
        if not bool(completed_stages.get(String(entry.get("id", "")), false)):
            return entry
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), slice.get("stages", []).size()]

func _on_zone_discovered(_zone_id: String) -> void:
    refresh_progress()

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c02_marker_warden" and final_choice == "":
        final_choice_required.emit()
    refresh_progress()

func _on_campfire_used(_zone_id: String) -> void:
    refresh_progress()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_02_before_fall":
        return
    _complete_if("c02_stage_01_archive", clue_count() >= 3)
    _complete_if("c02_stage_02_old_road", AshlandsRuntime.is_zone_discovered("c02_old_road"))
    _complete_if("c02_stage_03_watchpost", AshlandsRuntime.is_encounter_cleared("c02_watchpost_ambush"))
    _complete_if("c02_stage_04_camp", AshlandsRuntime.was_campfire_used_this_run("c02_quarry_camp"))
    _complete_if("c02_stage_05_miniboss", AshlandsRuntime.is_encounter_cleared("c02_broken_curator"))
    _complete_if("c02_stage_06_inquiry", clue_count() >= int(slice.get("investigation", {}).get("required_clues", 5)) and independent_source_count() >= int(slice.get("investigation", {}).get("independent_sources_min", 2)))
    _complete_if("c02_stage_07_boss", AshlandsRuntime.is_encounter_cleared("c02_marker_warden") and final_choice != "")
    _complete_if("c02_stage_08_return", GameState.current_screen == "sanctuary" and final_choice != "")
    _sync_main_quests()
    _try_finish()
    chapter_two_changed.emit()

func _complete_if(stage_id: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(stage_id, false)):
        completed_stages[stage_id] = true
        GameState.add_log("Chapitre II — %s" % stage_id)

func choose_final_outcome(choice_id: String) -> bool:
    if not AshlandsRuntime.is_encounter_cleared("c02_marker_warden"):
        return false
    for value in slice.get("final_choice", []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id:
            continue
        final_choice = choice_id
        var effects: Dictionary = choice.get("effects", {})
        if effects.has("trust"):
            PoliticalState.trust = clampi(PoliticalState.trust + int(effects["trust"]), 0, 100)
        if effects.has("tension"):
            PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
        if effects.has("veil_knowledge"):
            CampaignState.add_metric("veil_knowledge", int(effects["veil_knowledge"]))
        if effects.has("justice_integrity"):
            CampaignState.add_metric("justice_integrity", int(effects["justice_integrity"]))
        PoliticalState.politics_changed.emit()
        refresh_progress()
        return true
    return false

func _sync_main_quests() -> void:
    var bindings := {
        "c02_old_instruments": ["c02_stage_01_archive", "c02_stage_02_old_road"],
        "c02_deleted_pages": ["c02_stage_03_watchpost", "c02_stage_05_miniboss", "c02_stage_06_inquiry"],
        "c02_false_accident": ["c02_stage_04_camp", "c02_stage_07_boss", "c02_stage_08_return"]
    }
    for quest_id in bindings.keys():
        if CampaignState.is_main_quest_completed(String(quest_id)):
            continue
        var done := true
        for stage_id in bindings[quest_id]:
            if not bool(completed_stages.get(stage_id, false)):
                done = false
                break
        if done:
            CampaignState.complete_main_quest(String(quest_id))

func _try_finish() -> void:
    if rewards_claimed or completed_stages.size() < slice.get("stages", []).size():
        return
    rewards_claimed = true
    CampaignState.set_chapter_flag("chapter_02_vertical_slice_complete")
    CampaignState.discovered_revelations["chapter_02_end"] = String(slice.get("completion", {}).get("revelation", ""))
    GameState.add_log("Chapitre II terminé : les anomalies formaient un réseau.")
    chapter_two_completed.emit()

func serialize() -> Dictionary:
    return {"discovered_clues": discovered_clues.duplicate(true), "confirmed_hypotheses": confirmed_hypotheses.duplicate(true), "completed_stages": completed_stages.duplicate(true), "final_choice": final_choice, "rewards_claimed": rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    discovered_clues = payload.get("discovered_clues", {}).duplicate(true)
    confirmed_hypotheses = payload.get("confirmed_hypotheses", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    final_choice = String(payload.get("final_choice", ""))
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_two_changed.emit()
