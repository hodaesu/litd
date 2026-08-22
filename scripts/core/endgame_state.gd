extends Node

signal endgame_changed
signal operation_completed(operation_id: String)
signal new_cycle_started(cycle: int, perk_id: String)

const EPILOGUES_PATH := "res://data/world/endgame_epilogues.json"
const POSTGAME_PATH := "res://data/world/postgame_operations.json"
const NG_PLUS_PATH := "res://data/world/new_game_plus.json"

var epilogue_data: Dictionary = {}
var postgame_data: Dictionary = {}
var ng_plus_data: Dictionary = {}
var completed_operations: Dictionary = {}
var legacy_points := 0
var active_cycle := 0
var selected_legacy_perk := ""
var ending_history: Array = []
var legacy_perk_history: Array = []
var epilogue_archive: Array = []
var postgame_choice_presented := false
var postgame_continuation_selected := false

func _ready() -> void:
    epilogue_data = _load_json(EPILOGUES_PATH)
    postgame_data = _load_json(POSTGAME_PATH)
    ng_plus_data = _load_json(NG_PLUS_PATH)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_profile_progress() -> void:
    completed_operations = {}
    legacy_points = 0
    active_cycle = 0
    selected_legacy_perk = ""
    ending_history = []
    legacy_perk_history = []
    epilogue_archive = []
    postgame_choice_presented = false
    postgame_continuation_selected = false
    endgame_changed.emit()

func is_postgame_unlocked() -> bool:
    return bool(CampaignState.chapter_flags.get("campaign_complete", false)) and Chapter10Runtime.final_orientation != ""

func current_ending_id() -> String:
    return Chapter10Runtime.final_orientation

func record_current_ending() -> void:
    if not is_postgame_unlocked(): return
    var ending_id := current_ending_id()
    for value in ending_history:
        var entry: Dictionary = value
        if int(entry.get("cycle", -1)) == active_cycle and String(entry.get("ending_id", "")) == ending_id: return
    var record := {"cycle":active_cycle,"ending_id":ending_id,"name":String(Chapter10Runtime.final_record.get("name", ending_id))}
    ending_history.append(record)
    epilogue_archive.append({"cycle":active_cycle,"ending_id":ending_id,"sections":current_epilogue().duplicate(true),"vignettes":visible_vignettes().duplicate(true)})
    endgame_changed.emit()

func mark_postgame_choice_presented() -> void:
    if not is_postgame_unlocked() or postgame_choice_presented:
        return
    postgame_choice_presented = true
    endgame_changed.emit()

func choose_continue_postgame() -> bool:
    if not is_postgame_unlocked():
        return false
    record_current_ending()
    postgame_choice_presented = true
    postgame_continuation_selected = true
    GameState.add_log("Le monde d'après continue — le Nouveau Cycle+ restera disponible depuis le Sanctuaire.")
    endgame_changed.emit()
    return true

func current_epilogue() -> Dictionary:
    var ending_id := current_ending_id()
    for value in epilogue_data.get("epilogues", []):
        var entry: Dictionary = value
        if String(entry.get("ending_id", "")) == ending_id: return entry
    return {}

func visible_vignettes() -> Array:
    var result: Array = []
    for value in epilogue_data.get("conditional_vignettes", []):
        var entry: Dictionary = value
        if _requirements_met(entry.get("when", {})): result.append(entry)
    return result

func operations() -> Array:
    return postgame_data.get("operations", [])

func operation(operation_id: String) -> Dictionary:
    for value in operations():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == operation_id: return entry
    return {}

func operation_count() -> int:
    return completed_operations.size()

func operation_available(operation_id: String) -> bool:
    if not is_postgame_unlocked() or completed_operations.has(operation_id): return false
    var entry := operation(operation_id)
    if entry.is_empty() or not _requirements_met(entry.get("requirements", {})): return false
    return _can_pay(entry.get("cost", {}))

func complete_operation(operation_id: String) -> bool:
    if not operation_available(operation_id): return false
    var entry := operation(operation_id)
    _pay(entry.get("cost", {}))
    _apply_reward(entry.get("reward", {}))
    completed_operations[operation_id] = true
    var flag_id := String(entry.get("flag", ""))
    if flag_id != "": CampaignState.set_chapter_flag(flag_id)
    GameState.add_log("Monde d'après — %s" % String(entry.get("name", operation_id)))
    operation_completed.emit(operation_id)
    endgame_changed.emit()
    return true

func ng_plus_unlocked() -> bool:
    # La fin de campagne suffit. Les opérations du monde d'après sont désormais
    # un choix de préparation/héritage et jamais une porte obligatoire vers NG+.
    return is_postgame_unlocked()

func perks() -> Array:
    return ng_plus_data.get("perks", [])

func perk(perk_id: String) -> Dictionary:
    for value in perks():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == perk_id: return entry
    return {}

func perk_available(perk_id: String) -> bool:
    var entry := perk(perk_id)
    return ng_plus_unlocked() and not entry.is_empty() and legacy_points >= int(entry.get("cost", 0))

func can_begin_new_game_plus(perk_id: String = "") -> bool:
    if not ng_plus_unlocked():
        return false
    if perk_id == "":
        return true
    return perk_available(perk_id)

func begin_new_game_plus(perk_id: String = "") -> bool:
    if not can_begin_new_game_plus(perk_id): return false
    record_current_ending()
    postgame_choice_presented = true
    postgame_continuation_selected = false

    var entry: Dictionary = {}
    if perk_id != "":
        entry = perk(perk_id)
        legacy_points -= int(entry.get("cost", 0))

    active_cycle += 1
    selected_legacy_perk = perk_id
    legacy_perk_history.append({"cycle":active_cycle,"perk_id":perk_id if perk_id != "" else "none"})
    completed_operations = {}
    GameState.reset_new_game()
    if not entry.is_empty():
        _apply_legacy_effects(entry.get("effects", {}))
    CampaignState.set_chapter_flag("ng_plus_active")
    CampaignState.set_chapter_flag("ng_plus_cycle_%d" % active_cycle)
    var legacy_name := String(entry.get("name", "Sans héritage")) if not entry.is_empty() else "Sans héritage"
    GameState.add_log("Nouveau Cycle+ %d — %s" % [active_cycle, legacy_name])
    new_cycle_started.emit(active_cycle, perk_id)
    endgame_changed.emit()
    return true

func cycle_label() -> String:
    if active_cycle <= 0: return "Cycle initial"
    var labels: Array = ng_plus_data.get("cycle_labels", [])
    if labels.is_empty(): return "Cycle %d" % active_cycle
    return String(labels[mini(active_cycle - 1, labels.size() - 1)])

func enemy_hp_multiplier() -> float:
    return 1.0 + (float(active_cycle) * float(ng_plus_data.get("difficulty_per_cycle", {}).get("enemy_hp_pct", 18)) / 100.0)

func enemy_damage_multiplier() -> float:
    return 1.0 + (float(active_cycle) * float(ng_plus_data.get("difficulty_per_cycle", {}).get("enemy_damage_pct", 12)) / 100.0)

func enemy_fear_multiplier() -> float:
    return 1.0 + (float(active_cycle) * float(ng_plus_data.get("difficulty_per_cycle", {}).get("enemy_fear_pct", 8)) / 100.0)

func apply_enemy_scaling(enemy: Dictionary) -> void:
    if active_cycle <= 0 or int(enemy.get("ng_plus_scaled_cycle", 0)) == active_cycle: return
    var hp := maxi(1, int(round(float(enemy.get("max_hp", enemy.get("hp", 1))) * enemy_hp_multiplier())))
    enemy["hp"] = hp
    enemy["max_hp"] = hp
    var damage: Array = enemy.get("damage", [1, 2])
    if damage.size() >= 2:
        enemy["damage"] = [maxi(1, int(round(float(damage[0]) * enemy_damage_multiplier()))), maxi(1, int(round(float(damage[1]) * enemy_damage_multiplier())))]
    enemy["fear"] = maxi(0, int(round(float(enemy.get("fear", 0)) * enemy_fear_multiplier())))
    enemy["ng_plus_scaled_cycle"] = active_cycle

func _requirements_met(requirements: Dictionary) -> bool:
    if requirements.is_empty(): return true
    var campaign_flag := String(requirements.get("campaign_flag", ""))
    if campaign_flag != "" and not bool(CampaignState.chapter_flags.get(campaign_flag, false)): return false
    var political_flag := String(requirements.get("political_flag", ""))
    if political_flag != "" and not PoliticalState.is_flag_set(political_flag): return false
    var any_flags: Array = requirements.get("political_any_flag", [])
    if not any_flags.is_empty():
        var found := false
        for flag_value in any_flags:
            if PoliticalState.is_flag_set(String(flag_value)): found = true
        if not found: return false
    return true

func _can_pay(cost: Dictionary) -> bool:
    return GameState.gold >= int(cost.get("gold", 0)) and GameState.essence >= int(cost.get("essence", 0)) and GameState.supplies >= int(cost.get("supplies", 0))

func _pay(cost: Dictionary) -> void:
    GameState.gold -= int(cost.get("gold", 0))
    GameState.essence -= int(cost.get("essence", 0))
    GameState.supplies -= int(cost.get("supplies", 0))
    GameState.state_changed.emit()

func _apply_reward(reward: Dictionary) -> void:
    GameState.gold += int(reward.get("gold", 0))
    GameState.essence += int(reward.get("essence", 0))
    GameState.supplies += int(reward.get("supplies", 0))
    legacy_points += int(reward.get("legacy_points", 0))
    for metric_id in ["justice_integrity","absent_contact","creature_relations","foreign_alliances","stabilizer_nodes","veil_knowledge"]:
        if reward.has(metric_id): CampaignState.add_metric(metric_id, int(reward[metric_id]))
    GameState.state_changed.emit()

func _apply_legacy_effects(effects: Dictionary) -> void:
    GameState.gold += int(effects.get("gold", 0))
    GameState.essence += int(effects.get("essence", 0))
    GameState.supplies += int(effects.get("supplies", 0))
    if effects.has("trust"): PoliticalState.trust = clampi(PoliticalState.trust + int(effects["trust"]), 0, 100)
    if effects.has("city"): PoliticalState.three_awakenings["city"] = clampi(int(PoliticalState.three_awakenings.get("city", 50)) + int(effects["city"]), 0, 100)
    for metric_id in ["veil_knowledge","absent_contact","creature_relations","foreign_alliances","justice_integrity","stabilizer_nodes"]:
        if effects.has(metric_id): CampaignState.add_metric(metric_id, int(effects[metric_id]))
    PoliticalState.politics_changed.emit()
    GameState.state_changed.emit()

func serialize() -> Dictionary:
    return {
        "completed_operations":completed_operations.duplicate(true),
        "legacy_points":legacy_points,
        "active_cycle":active_cycle,
        "selected_legacy_perk":selected_legacy_perk,
        "ending_history":ending_history.duplicate(true),
        "legacy_perk_history":legacy_perk_history.duplicate(true),
        "epilogue_archive":epilogue_archive.duplicate(true),
        "postgame_choice_presented":postgame_choice_presented,
        "postgame_continuation_selected":postgame_continuation_selected
    }

func deserialize(payload: Dictionary) -> void:
    completed_operations = payload.get("completed_operations", {}).duplicate(true)
    legacy_points = maxi(0, int(payload.get("legacy_points", 0)))
    active_cycle = maxi(0, int(payload.get("active_cycle", 0)))
    selected_legacy_perk = String(payload.get("selected_legacy_perk", ""))
    ending_history = payload.get("ending_history", []).duplicate(true)
    legacy_perk_history = payload.get("legacy_perk_history", []).duplicate(true)
    epilogue_archive = payload.get("epilogue_archive", []).duplicate(true)
    postgame_choice_presented = bool(payload.get("postgame_choice_presented", false))
    postgame_continuation_selected = bool(payload.get("postgame_continuation_selected", false))
    endgame_changed.emit()
