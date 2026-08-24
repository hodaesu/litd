extends Node

signal contextual_explanation_available(explanation_id: String, event_id: String)
signal capability_unlocked(capability_id: String)

const DATA_PATH := "res://data/content_scope.json"

var scope: Dictionary = {}
var discovered_contexts: Dictionary = {}
var announced_capabilities: Dictionary = {}
var granted_capabilities: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    scope = parsed if parsed is Dictionary else {}

func reset_new_game() -> void:
    discovered_contexts.clear()
    announced_capabilities.clear()
    granted_capabilities.clear()

func is_world_rule_active(rule_id: String) -> bool:
    return rule_id in scope.get("categories", {}).get("world_rules", {}).get("systems", [])

func company_rank() -> int:
    var highest_level := 1
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        highest_level = maxi(highest_level, int(hero.get("level", 1)))
    var thresholds: Array = scope.get("progression", {}).get("company_rank_level_thresholds", [1])
    var rank := 1
    for threshold_value: Variant in thresholds:
        if highest_level >= int(threshold_value):
            rank += 1
    return clampi(rank - 1, 1, thresholds.size())

func is_unlocked(capability_id: String, chapter: int = -1, rank: int = -1) -> bool:
    var definition: Dictionary = _capability(capability_id)
    if definition.is_empty():
        return false
    if bool(granted_capabilities.get(capability_id, false)):
        return true
    var current_chapter := CampaignState.current_chapter_number() if chapter < 0 else chapter
    var current_rank := company_rank() if rank < 0 else rank
    var chapter_met := current_chapter >= int(definition.get("campaign_chapter", 999))
    var rank_met := current_rank >= int(definition.get("company_rank", 999))
    return chapter_met and rank_met if str(definition.get("logic", "or")) == "and" else chapter_met or rank_met

func grant_capability(capability_id: String) -> bool:
    if _capability(capability_id).is_empty():
        return false
    granted_capabilities[capability_id] = true
    if not announced_capabilities.has(capability_id):
        announced_capabilities[capability_id] = true
        capability_unlocked.emit(capability_id)
    return true

func feature_state(feature_id: String) -> String:
    if is_world_rule_active(feature_id):
        return "active"
    if scope.get("categories", {}).get("contextual_discoveries", {}).get("systems", {}).has(feature_id):
        return "explained" if discovered_contexts.has(feature_id) else "active_unexplained"
    if not _capability(feature_id).is_empty():
        return "unlocked" if is_unlocked(feature_id) else "locked_hidden"
    return "unknown"

func record_context_event(event_id: String) -> Array[String]:
    var revealed: Array[String] = []
    var explanations: Dictionary = scope.get("categories", {}).get("contextual_discoveries", {}).get("systems", {})
    for explanation_value: Variant in explanations.keys():
        var explanation_id := str(explanation_value)
        if str(explanations.get(explanation_value, "")) != event_id or discovered_contexts.has(explanation_id):
            continue
        discovered_contexts[explanation_id] = {"event": event_id, "chapter": CampaignState.current_chapter_number()}
        revealed.append(explanation_id)
        contextual_explanation_available.emit(explanation_id, event_id)
    return revealed

func refresh_unlock_announcements() -> Array[String]:
    var unlocked: Array[String] = []
    for capability_value: Variant in scope.get("categories", {}).get("unlockable_capabilities", {}).keys():
        var capability_id := str(capability_value)
        if is_unlocked(capability_id) and not announced_capabilities.has(capability_id):
            announced_capabilities[capability_id] = true
            unlocked.append(capability_id)
            capability_unlocked.emit(capability_id)
    return unlocked

func visible_capabilities() -> Array[String]:
    var result: Array[String] = []
    for capability_value: Variant in scope.get("categories", {}).get("unlockable_capabilities", {}).keys():
        var capability_id := str(capability_value)
        if is_unlocked(capability_id):
            result.append(capability_id)
    return result

func unlock_requirements(capability_id: String) -> Dictionary:
    return _capability(capability_id).duplicate(true)

func farming_required_for_story() -> bool:
    return bool(scope.get("farming", {}).get("required_for_main_story", false))

func max_primary_choices() -> int:
    return int(scope.get("base_expedition", {}).get("max_primary_choices_per_screen", 4))

func serialize() -> Dictionary:
    return {
        "discovered_contexts": discovered_contexts.duplicate(true),
        "announced_capabilities": announced_capabilities.duplicate(true),
        "granted_capabilities": granted_capabilities.duplicate(true)
    }

func deserialize(payload: Dictionary) -> void:
    discovered_contexts = payload.get("discovered_contexts", {}).duplicate(true)
    announced_capabilities = payload.get("announced_capabilities", {}).duplicate(true)
    granted_capabilities = payload.get("granted_capabilities", {}).duplicate(true)
    refresh_unlock_announcements()

func _capability(capability_id: String) -> Dictionary:
    return scope.get("categories", {}).get("unlockable_capabilities", {}).get(capability_id, {})
