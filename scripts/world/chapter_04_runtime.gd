extends Node

signal chapter_four_changed
signal fragment_discovered(fragment: Dictionary)
signal hypothesis_confirmed(hypothesis_id: String)
signal final_choice_required
signal chapter_four_completed

const CHAPTER_PATH := "res://data/levels/chapter_04_first_rupture.json"
const WORLD_PATH := "res://data/levels/chapter_04_world.json"

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
    AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)
    AshlandsRuntime.campfire_used.connect(_on_campfire_used)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    discovered_fragments = {}
    confirmed_hypotheses = {}
    completed_stages = {}
    final_choice = ""
    rewards_claimed = false
    chapter_four_changed.emit()

func fragments() -> Array:
    return world.get("fragments", [])

func get_fragment(fragment_id: String) -> Dictionary:
    for value in fragments():
        var fragment: Dictionary = value
        if String(fragment.get("id", "")) == fragment_id:
            return fragment
    return {}

func collect_fragment(fragment_id: String) -> bool:
    if discovered_fragments.has(fragment_id):
        return false
    var fragment := get_fragment(fragment_id)
    if fragment.is_empty():
        return false
    discovered_fragments[fragment_id] = fragment.duplicate(true)
    fragment_discovered.emit(fragment.duplicate(true))
    _recalculate_hypotheses()
    refresh_progress()
    chapter_four_changed.emit()
    return true

func fragment_count() -> int:
    return discovered_fragments.size()

func independent_source_family_count() -> int:
    var groups: Dictionary = {}
    for value in discovered_fragments.values():
        var fragment: Dictionary = value
        groups[String(fragment.get("source_family", "unknown"))] = true
    return groups.size()

func contradiction_count() -> int:
    var total := 0
    for value in discovered_fragments.values():
        if bool((value as Dictionary).get("contradiction", false)):
            total += 1
    return total

func hypotheses() -> Array:
    return world.get("hypotheses", [])

func _recalculate_hypotheses() -> void:
    for value in hypotheses():
        var hypothesis: Dictionary = value
        var hypothesis_id := String(hypothesis.get("id", ""))
        if bool(confirmed_hypotheses.get(hypothesis_id, false)):
            continue
        var support := 0
        var groups: Dictionary = {}
        for fragment_value in discovered_fragments.values():
            var fragment: Dictionary = fragment_value
            if hypothesis_id in fragment.get("supports", []):
                support += 1
                groups[String(fragment.get("source_family", "unknown"))] = true
        if support >= int(hypothesis.get("required_support", 1)) and groups.size() >= int(hypothesis.get("independent_sources", 1)):
            confirmed_hypotheses[hypothesis_id] = true
            CampaignState.discovered_revelations["c04_%s" % hypothesis_id] = String(hypothesis.get("title", hypothesis_id))
            CampaignState.add_metric("veil_knowledge", 4)
            hypothesis_confirmed.emit(hypothesis_id)

func active_stage() -> Dictionary:
    for value in chapter.get("stages", []):
        var entry: Dictionary = value
        if not bool(completed_stages.get(String(entry.get("id", "")), false)):
            return entry
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), chapter.get("stages", []).size()]

func _on_zone_discovered(_zone_id: String) -> void:
    refresh_progress()

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c04_boss_unfinished_chorus" and final_choice == "":
        call_deferred("_request_final_choice")
    refresh_progress()

func _request_final_choice() -> void:
    final_choice_required.emit()

func _on_campfire_used(_zone_id: String) -> void:
    refresh_progress()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_04_first_rupture":
        return
    _complete_if("c04_stage_01_descent", AshlandsRuntime.is_zone_discovered("c04_buried_city"))
    _complete_if("c04_stage_02_resonance", fragment_count() >= 3 and AshlandsRuntime.is_zone_discovered("c04_resonance_halls"))
    _complete_if("c04_stage_03_silences", AshlandsRuntime.is_zone_discovered("c04_seven_silences") and bool(confirmed_hypotheses.get("consciousness_measurement", false)))
    _complete_if("c04_stage_04_camp", AshlandsRuntime.was_campfire_used_this_run("c04_echo_camp"))
    _complete_if("c04_stage_05_miniboss", AshlandsRuntime.is_encounter_cleared("c04_faceless_measure"))
    var investigation: Dictionary = chapter.get("investigation", {})
    _complete_if("c04_stage_06_first_rupture", fragment_count() >= int(investigation.get("required_fragments", 6)) and independent_source_family_count() >= int(investigation.get("independent_source_families", 3)) and contradiction_count() >= int(investigation.get("contradictions_required", 2)) and bool(confirmed_hypotheses.get("first_rupture", false)))
    _complete_if("c04_stage_07_chorus", AshlandsRuntime.is_encounter_cleared("c04_boss_unfinished_chorus") and final_choice != "")
    _complete_if("c04_stage_08_return", GameState.current_screen == "sanctuary" and final_choice != "" and bool(confirmed_hypotheses.get("not_a_door", false)))
    _sync_main_quests()
    _try_finish()
    chapter_four_changed.emit()

func _complete_if(stage_id: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(stage_id, false)):
        completed_stages[stage_id] = true
        GameState.add_log("Chapitre IV — %s" % stage_id)

func choose_final_outcome(choice_id: String) -> bool:
    if not AshlandsRuntime.is_encounter_cleared("c04_boss_unfinished_chorus"):
        return false
    for value in chapter.get("boss_choices", []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id:
            continue
        final_choice = choice_id
        var effects: Dictionary = choice.get("effects", {})
        if effects.has("veil_knowledge"):
            CampaignState.add_metric("veil_knowledge", int(effects["veil_knowledge"]))
        if effects.has("ancient_preservation"):
            CampaignState.add_metric("ancient_preservation", int(effects["ancient_preservation"]))
        if effects.has("tension"):
            PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
        if effects.has("madness_all"):
            for hero in GameState.party:
                hero["madness"] = clampi(int(hero.get("madness", 0)) + int(effects["madness_all"]), 0, 100)
        if effects.has("hope_all"):
            for hero in GameState.party:
                hero["hope"] = clampi(int(hero.get("hope", 0)) + int(effects["hope_all"]), 0, 100)
        CampaignState.set_chapter_flag("c04_chorus_%s" % choice_id)
        PoliticalState.politics_changed.emit()
        refresh_progress()
        return true
    return false

func _sync_main_quests() -> void:
    var bindings := {
        "c04_ashai_song": ["c04_stage_01_descent", "c04_stage_02_resonance", "c04_stage_03_silences"],
        "c04_first_rupture": ["c04_stage_04_camp", "c04_stage_05_miniboss", "c04_stage_06_first_rupture"],
        "c04_not_a_door": ["c04_stage_07_chorus", "c04_stage_08_return"]
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
    if rewards_claimed or completed_stages.size() < chapter.get("stages", []).size():
        return
    rewards_claimed = true
    CampaignState.set_chapter_flag("chapter_04_vertical_slice_complete")
    CampaignState.discovered_revelations["chapter_04_end"] = String(chapter.get("end_revelation", ""))
    GameState.add_log("Chapitre IV terminé : le Projet Seuil répétait une erreur ancienne.")
    chapter_four_completed.emit()

func serialize() -> Dictionary:
    return {"discovered_fragments":discovered_fragments.duplicate(true),"confirmed_hypotheses":confirmed_hypotheses.duplicate(true),"completed_stages":completed_stages.duplicate(true),"final_choice":final_choice,"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    discovered_fragments = payload.get("discovered_fragments", {}).duplicate(true)
    confirmed_hypotheses = payload.get("confirmed_hypotheses", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    final_choice = String(payload.get("final_choice", ""))
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_four_changed.emit()
