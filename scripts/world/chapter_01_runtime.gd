extends Node

signal chapter_one_changed
signal stage_completed(stage_id: String)
signal boss_choice_required
signal vertical_slice_completed

const DATA_PATH := "res://data/levels/chapter_01_vertical_slice.json"

var data: Dictionary = {}
var completed_stages: Dictionary = {}
var boss_choice := ""
var rewards_claimed := false

func _ready() -> void:
    data = _load_json(DATA_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)
    AshlandsRuntime.campfire_used.connect(_on_campfire_used)
    AshlandsRuntime.lore_discovered.connect(_on_lore_discovered)
    CreatureManager.creatures_changed.connect(_on_creatures_changed)
    PoliticalState.politics_changed.connect(_on_politics_changed)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    completed_stages = {}
    boss_choice = ""
    rewards_claimed = false
    chapter_one_changed.emit()

func stages() -> Array:
    return data.get("stages", [])

func stage(stage_id: String) -> Dictionary:
    for value in stages():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == stage_id:
            return entry
    return {}

func is_stage_completed(stage_id: String) -> bool:
    return bool(completed_stages.get(stage_id, false))

func active_stage() -> Dictionary:
    for value in stages():
        var entry: Dictionary = value
        if not is_stage_completed(String(entry.get("id", ""))):
            return entry
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), stages().size()]

func _on_zone_discovered(_zone_id: String) -> void:
    refresh_progress()

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "c01_boss_ash_witness" and boss_choice == "":
        boss_choice_required.emit()
    refresh_progress()

func _on_campfire_used(_zone_id: String) -> void:
    refresh_progress()

func _on_lore_discovered(_entry: Dictionary) -> void:
    refresh_progress()

func _on_creatures_changed() -> void:
    refresh_progress()

func _on_politics_changed() -> void:
    refresh_progress()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_01_ashlands":
        return
    var changed := true
    while changed:
        changed = false
        for value in stages():
            var entry: Dictionary = value
            var stage_id := String(entry.get("id", ""))
            if stage_id == "" or is_stage_completed(stage_id):
                continue
            if _stage_satisfied(entry):
                _complete_stage(entry)
                changed = true
    _sync_main_quests()
    _try_finish_slice()

func _stage_satisfied(entry: Dictionary) -> bool:
    var requirements: Dictionary = entry.get("completion", {})
    if requirements.has("zone_discovered"):
        var zone_id := String(requirements["zone_discovered"])
        if zone_id == "sanctuary":
            if GameState.current_screen != "sanctuary" and not AshlandsRuntime.is_zone_discovered(zone_id):
                return false
        elif not AshlandsRuntime.is_zone_discovered(zone_id):
            return false
    if requirements.has("encounter_cleared") and not AshlandsRuntime.is_encounter_cleared(String(requirements["encounter_cleared"])):
        return false
    if requirements.has("campfire_used") and not AshlandsRuntime.was_campfire_used_this_run(String(requirements["campfire_used"])):
        return false
    if requirements.has("creature_recruited_min") and CreatureManager.captured_creatures.size() < int(requirements["creature_recruited_min"]):
        if not _optional_alternative_satisfied(entry.get("optional_alternative", {})):
            return false
    if requirements.has("lore_min") and AshlandsRuntime.lore_count() < int(requirements["lore_min"]):
        return false
    if requirements.has("political_quests_completed_min") and PoliticalState.completed_quests().size() < int(requirements["political_quests_completed_min"]):
        return false
    if String(entry.get("id", "")) == "c01_stage_07_witness" and boss_choice == "":
        return false
    return true

func _optional_alternative_satisfied(alternative: Dictionary) -> bool:
    for flag_value in alternative.get("flag_any", []):
        if PoliticalState.is_flag_set(String(flag_value)):
            return true
    return false

func choose_boss_outcome(choice_id: String) -> bool:
    var boss_stage := stage("c01_stage_07_witness")
    if boss_stage.is_empty() or not AshlandsRuntime.is_encounter_cleared("c01_boss_ash_witness"):
        return false
    for choice_value in boss_stage.get("boss_choices", []):
        var choice: Dictionary = choice_value
        if String(choice.get("id", "")) != choice_id:
            continue
        boss_choice = choice_id
        var effects: Dictionary = choice.get("effects", {})
        var flag_id := String(effects.get("campaign_flag", ""))
        if flag_id != "":
            CampaignState.set_chapter_flag(flag_id)
        if effects.has("creature_relations"):
            CampaignState.add_metric("creature_relations", int(effects["creature_relations"]))
        if effects.has("veil_knowledge"):
            CampaignState.add_metric("veil_knowledge", int(effects["veil_knowledge"]))
        if effects.has("justice_integrity"):
            CampaignState.add_metric("justice_integrity", int(effects["justice_integrity"]))
        if effects.has("tension"):
            PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
            PoliticalState.politics_changed.emit()
        refresh_progress()
        return true
    return false

func _complete_stage(entry: Dictionary) -> void:
    var stage_id := String(entry.get("id", ""))
    completed_stages[stage_id] = true
    _apply_reward(entry.get("reward", {}))
    GameState.add_log("Chapitre I — %s" % String(entry.get("name", stage_id)))
    stage_completed.emit(stage_id)
    chapter_one_changed.emit()

func _apply_reward(reward: Dictionary) -> void:
    if reward.has("gold"):
        GameState.gold += int(reward["gold"])
    if reward.has("essence"):
        GameState.essence += int(reward["essence"])
    if reward.has("supplies"):
        GameState.supplies += int(reward["supplies"])
    if reward.has("light"):
        GameState.light = clampi(GameState.light + int(reward["light"]), 0, 100)
    var flag_id := String(reward.get("campaign_flag", ""))
    if flag_id != "":
        CampaignState.set_chapter_flag(flag_id)
    var metric_reward: Dictionary = reward.get("campaign_metric", {})
    for key in metric_reward.keys():
        CampaignState.add_metric(String(key), int(metric_reward[key]))

func _sync_main_quests() -> void:
    var bindings: Dictionary = data.get("main_quest_bindings", {})
    for quest_id_value in bindings.keys():
        var quest_id := String(quest_id_value)
        if CampaignState.is_main_quest_completed(quest_id):
            continue
        var all_done := true
        for stage_id_value in bindings[quest_id]:
            if not is_stage_completed(String(stage_id_value)):
                all_done = false
                break
        if all_done:
            CampaignState.complete_main_quest(quest_id)

func _try_finish_slice() -> void:
    if rewards_claimed or completed_stages.size() < stages().size():
        return
    rewards_claimed = true
    var reward: Dictionary = data.get("completion_rewards", {})
    GameState.gold += int(reward.get("gold", 0))
    GameState.essence += int(reward.get("essence", 0))
    GameState.supplies += int(reward.get("supplies", 0))
    CampaignState.set_chapter_flag("chapter_01_vertical_slice_complete")
    GameState.add_log("Chapitre I terminé : les cendres cachent une histoire plus ancienne.")
    vertical_slice_completed.emit()
    chapter_one_changed.emit()

func serialize() -> Dictionary:
    return {
        "completed_stages": completed_stages.duplicate(true),
        "boss_choice": boss_choice,
        "rewards_claimed": rewards_claimed
    }

func deserialize(payload: Dictionary) -> void:
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    boss_choice = String(payload.get("boss_choice", ""))
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_one_changed.emit()
