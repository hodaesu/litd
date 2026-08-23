extends Node

signal quests_changed
signal quest_state_changed(quest_id: String, state: String)
signal quest_objective_changed(quest_id: String, objective_id: String, current: int, required: int)
signal tracked_quest_changed(quest_id: String, target_id: String)

const PATH := "res://data/quests.json"

var definitions: Dictionary = {}
var states: Dictionary = {}
var tracked_quest_id := ""

func _ready() -> void:
    _load()
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(func(target: String): record_event("zone_discovered", target))
    AshlandsRuntime.resource_collected.connect(func(target: String): record_event("collect", target))
    AshlandsRuntime.encounter_cleared.connect(func(target: String): record_event("encounter_cleared", target))
    AshlandsRuntime.campfire_used.connect(func(target: String): record_event("campfire_used", target))
    AshlandsRuntime.interaction_recorded.connect(func(target: String): record_event("interaction", target))
    AshlandsRuntime.dialogue_recorded.connect(func(target: String): record_event("dialogue", target))
    AshlandsRuntime.choice_recorded.connect(func(target: String, choice_id: String): record_choice(target, choice_id))

func _load() -> void:
    definitions.clear()
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if parsed is not Array:
        return
    for value: Variant in parsed:
        if value is Dictionary:
            definitions[String(value.get("id", ""))] = value.duplicate(true)

func reset_new_game() -> void:
    states.clear()
    tracked_quest_id = ""
    for quest_id_value: Variant in definitions.keys():
        var quest_id := String(quest_id_value)
        var quest: Dictionary = definitions[quest_id]
        var progress: Dictionary = {}
        for objective_value: Variant in quest.get("objectives", []):
            var objective: Dictionary = objective_value
            progress[String(objective.get("id", ""))] = 0
        states[quest_id] = {
            "state":"offered",
            "progress":progress,
            "choice":"",
            "reward_claimed":false,
            "optional_success":true
        }
    quests_changed.emit()

func quest(quest_id: String) -> Dictionary:
    return (definitions.get(quest_id, {}) as Dictionary).duplicate(true)

func state(quest_id: String) -> Dictionary:
    return (states.get(quest_id, {}) as Dictionary).duplicate(true)

func status(quest_id: String) -> String:
    return String(states.get(quest_id, {}).get("state", "locked"))

func accept(quest_id: String) -> bool:
    if status(quest_id) not in ["offered", "refused"]:
        return false
    states[quest_id]["state"] = "active"
    if tracked_quest_id == "":
        track(quest_id)
    GameState.add_log("Quête acceptée : %s." % String(quest(quest_id).get("name", quest_id)))
    quest_state_changed.emit(quest_id, "active")
    quests_changed.emit()
    return true

func refuse(quest_id: String) -> bool:
    if status(quest_id) != "offered":
        return false
    states[quest_id]["state"] = "refused"
    GameState.add_log("Quête refusée : %s." % String(quest(quest_id).get("name", quest_id)))
    quest_state_changed.emit(quest_id, "refused")
    quests_changed.emit()
    return true

func fail(quest_id: String) -> bool:
    if status(quest_id) != "active":
        return false
    states[quest_id]["state"] = "failed"
    if tracked_quest_id == quest_id:
        tracked_quest_id = ""
    quest_state_changed.emit(quest_id, "failed")
    quests_changed.emit()
    return true

func track(quest_id: String) -> bool:
    if status(quest_id) not in ["active", "completed"]:
        return false
    tracked_quest_id = quest_id
    var target := current_target(quest_id)
    tracked_quest_changed.emit(quest_id, target)
    if target != "":
        HUDDirector.request_world_guidance(target, ["cendre"], {"source":"tracked_quest","quest_id":quest_id})
    quests_changed.emit()
    return true

func current_target(quest_id: String) -> String:
    var quest_definition := quest(quest_id)
    var quest_state := state(quest_id)
    var progress: Dictionary = quest_state.get("progress", {})
    for objective_value: Variant in quest_definition.get("objectives", []):
        var objective: Dictionary = objective_value
        var objective_id := String(objective.get("id", ""))
        if int(progress.get(objective_id, 0)) < int(objective.get("count", 1)):
            return String(objective.get("target", ""))
    return ""

func record_event(event_id: String, target_id: String, amount: int = 1) -> void:
    for quest_id_value: Variant in states.keys():
        var quest_id := String(quest_id_value)
        if status(quest_id) != "active":
            continue
        var quest_definition := quest(quest_id)
        for objective_value: Variant in quest_definition.get("objectives", []):
            var objective: Dictionary = objective_value
            if String(objective.get("event", "")) != event_id or String(objective.get("target", "")) != target_id:
                continue
            _advance(quest_id, objective, amount)

func record_choice(target_id: String, choice_id: String) -> void:
    for quest_id_value: Variant in states.keys():
        var quest_id := String(quest_id_value)
        if status(quest_id) != "active":
            continue
        var quest_definition := quest(quest_id)
        for objective_value: Variant in quest_definition.get("objectives", []):
            var objective: Dictionary = objective_value
            if String(objective.get("event", "")) == "choice" and String(objective.get("target", "")) == target_id:
                states[quest_id]["choice"] = choice_id
                _apply_choice(quest_definition, choice_id)
                _advance(quest_id, objective, 1)

func record_forbidden_choice(choice_id: String) -> void:
    for quest_id_value: Variant in states.keys():
        var quest_id := String(quest_id_value)
        var quest_definition := quest(quest_id)
        var constraint: Dictionary = quest_definition.get("optional_constraint", {})
        if status(quest_id) == "active" and String(constraint.get("target", "")) == choice_id:
            states[quest_id]["optional_success"] = false
            quests_changed.emit()

func _advance(quest_id: String, objective: Dictionary, amount: int) -> void:
    var objective_id := String(objective.get("id", ""))
    var required := int(objective.get("count", 1))
    var progress: Dictionary = states[quest_id].get("progress", {})
    progress[objective_id] = mini(required, int(progress.get(objective_id, 0)) + maxi(0, amount))
    states[quest_id]["progress"] = progress
    quest_objective_changed.emit(quest_id, objective_id, int(progress[objective_id]), required)
    if _all_objectives_complete(quest_id):
        _complete(quest_id)
    elif tracked_quest_id == quest_id:
        track(quest_id)
    quests_changed.emit()

func _all_objectives_complete(quest_id: String) -> bool:
    var progress: Dictionary = states[quest_id].get("progress", {})
    for objective_value: Variant in quest(quest_id).get("objectives", []):
        var objective: Dictionary = objective_value
        if int(progress.get(String(objective.get("id", "")), 0)) < int(objective.get("count", 1)):
            return false
    return true

func _complete(quest_id: String) -> void:
    states[quest_id]["state"] = "completed"
    if not bool(states[quest_id].get("reward_claimed", false)):
        _apply_reward(quest(quest_id).get("reward", {}), bool(states[quest_id].get("optional_success", true)))
        states[quest_id]["reward_claimed"] = true
    GameState.add_log("Quête accomplie : %s." % String(quest(quest_id).get("name", quest_id)))
    quest_state_changed.emit(quest_id, "completed")
    if tracked_quest_id == quest_id:
        tracked_quest_id = ""
        tracked_quest_changed.emit("", "")
    _apply_sanctuary_consequence(quest_id)

func _apply_reward(reward: Dictionary, optional_success: bool) -> void:
    GameState.gold += int(reward.get("gold", 0))
    GameState.essence += int(reward.get("essence", 0))
    GameState.supplies += int(reward.get("supplies", 0))
    var hope := int(reward.get("hope", 0))
    if hope > 0:
        for hero_value: Variant in GameState.party:
            var hero: Dictionary = hero_value
            hero["hope"] = mini(100, int(hero.get("hope", 0)) + hope)
    if reward.has("reputation"):
        PoliticalState.reputation += int(reward.get("reputation", 0))
        PoliticalState.politics_changed.emit()
    if reward.has("infirmary_stock") and optional_success:
        CampaignState.set_chapter_flag("c01_infirmary_stock_restored")
    if reward.has("veil_knowledge"):
        CampaignState.add_metric("veil_knowledge", int(reward.get("veil_knowledge", 0)))

func _apply_choice(quest_definition: Dictionary, choice_id: String) -> void:
    for value: Variant in quest_definition.get("choices", []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id:
            continue
        var effect: Dictionary = choice.get("effect", {})
        for key_value: Variant in effect.keys():
            var key := String(key_value)
            var amount := int(effect[key_value])
            if key in ["trust", "tension", "reputation"]:
                PoliticalState.set(key, int(PoliticalState.get(key)) + amount)
                PoliticalState.politics_changed.emit()
            else:
                CampaignState.add_metric(key, amount)
        CampaignState.set_chapter_flag("%s_%s" % [String(quest_definition.get("id", "quest")), choice_id])
        return

func _apply_sanctuary_consequence(quest_id: String) -> void:
    CampaignState.set_chapter_flag("%s_completed" % quest_id)
    match quest_id:
        "c01_side_buried_bell":
            CampaignState.set_chapter_flag("sanctuary_bell_or_road_warning_active")
        "c01_side_names_in_ash":
            CampaignState.set_chapter_flag("memorial_five_names_restored")
        "c01_side_last_medic":
            CampaignState.set_chapter_flag("infirmary_tools_restored")
        "c01_side_quiet_creature":
            CampaignState.set_chapter_flag("ash_creature_outcome_recorded")
        "c01_side_three_testimonies":
            CampaignState.set_chapter_flag("marker_contradictions_archived")

func serialize() -> Dictionary:
    return {"states":states.duplicate(true),"tracked_quest_id":tracked_quest_id}

func deserialize(payload: Dictionary) -> void:
    reset_new_game()
    var saved: Variant = payload.get("states", {})
    if saved is Dictionary:
        for quest_id_value: Variant in saved.keys():
            var quest_id := String(quest_id_value)
            if definitions.has(quest_id) and saved[quest_id_value] is Dictionary:
                states[quest_id] = saved[quest_id_value].duplicate(true)
    tracked_quest_id = String(payload.get("tracked_quest_id", ""))
    quests_changed.emit()
