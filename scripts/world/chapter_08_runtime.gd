extends Node

signal chapter_eight_changed
signal record_discovered(entry: Dictionary)
signal ancient_trace_discovered(entry: Dictionary)
signal authority_node_activated(node_id: String)
signal boss_choice_required(boss_id: String)
signal chapter_eight_completed

const CHAPTER_PATH := "res://data/levels/chapter_08_outer_world.json"
const WORLD_PATH := "res://data/levels/chapter_08_world.json"
const ANCIENT_TRACE_PATH := "res://data/levels/chapter_08_ancient_traces.json"

var chapter: Dictionary = {}
var world: Dictionary = {}
var ancient_trace_data: Dictionary = {}
var collected_records: Dictionary = {}
var collected_ancient_traces: Dictionary = {}
var authority_nodes: Dictionary = {}
var boss_choices: Dictionary = {}
var completed_stages: Dictionary = {}
var rewards_claimed := false

func _ready() -> void:
    chapter = _load_json(CHAPTER_PATH)
    world = _load_json(WORLD_PATH)
    ancient_trace_data = _load_json(ANCIENT_TRACE_PATH)
    reset_new_game()
    AshlandsRuntime.zone_discovered.connect(func(_id): refresh_progress())
    AshlandsRuntime.campfire_used.connect(func(_id): refresh_progress())
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    collected_records = {}
    collected_ancient_traces = {}
    authority_nodes = {}
    boss_choices = {}
    completed_stages = {}
    rewards_claimed = false
    chapter_eight_changed.emit()

func records() -> Array: return world.get("records", [])
func record_count() -> int: return collected_records.size()
func ancient_traces() -> Array: return ancient_trace_data.get("traces", [])
func ancient_trace_count() -> int: return collected_ancient_traces.size()

func get_record(id_value: String) -> Dictionary:
    for value in records():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == id_value: return entry
    return {}

func get_ancient_trace(id_value: String) -> Dictionary:
    for value in ancient_traces():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == id_value: return entry
    return {}

func traces_for_zone(zone_id: String) -> Array:
    var result: Array = []
    for value in ancient_traces():
        var entry: Dictionary = value
        if String(entry.get("zone", "")) == zone_id: result.append(entry)
    return result

func is_record_collected(id_value: String) -> bool:
    return collected_records.has(id_value)

func is_ancient_trace_collected(id_value: String) -> bool:
    return collected_ancient_traces.has(id_value)

func collect_record(id_value: String) -> bool:
    if collected_records.has(id_value): return false
    var entry := get_record(id_value)
    if entry.is_empty(): return false
    collected_records[id_value] = entry.duplicate(true)
    record_discovered.emit(entry.duplicate(true))
    GameState.add_log("Monde extérieur — %s" % String(entry.get("title", id_value)))
    refresh_progress()
    chapter_eight_changed.emit()
    return true

func collect_ancient_trace(id_value: String) -> bool:
    if collected_ancient_traces.has(id_value): return false
    var entry := get_ancient_trace(id_value)
    if entry.is_empty(): return false
    collected_ancient_traces[id_value] = entry.duplicate(true)
    var flag_id := String(entry.get("unlock_flag", ""))
    if flag_id != "": CampaignState.set_chapter_flag(flag_id)
    CampaignState.add_metric("veil_knowledge", 2)
    CampaignState.discovered_revelations["ancient_%s" % id_value] = String(entry.get("text", ""))
    ancient_trace_discovered.emit(entry.duplicate(true))
    GameState.add_log("Civilisation ancienne découverte — %s. Un Vestige profond est désormais localisable." % String(entry.get("civilization", id_value)))
    DeepVestigeRuntime.refresh_unlocks()
    chapter_eight_changed.emit()
    return true

func record_count_for(power_id: String) -> int:
    var total := 0
    for value in collected_records.values():
        if String((value as Dictionary).get("power", "")) == power_id: total += 1
    return total

func civilian_or_dissident_count_for(power_id: String) -> int:
    var total := 0
    for value in collected_records.values():
        var entry: Dictionary = value
        if String(entry.get("power", "")) == power_id and String(entry.get("kind", "")) in ["civilian","dissident"]: total += 1
    return total

func independent_source_family_count() -> int:
    var families := {}
    for value in collected_records.values():
        families[String((value as Dictionary).get("source_family", "unknown"))] = true
    return families.size()

func foreign_command_count() -> int:
    var total := 0
    for value in collected_records.values():
        if "foreign_command_chain" in (value as Dictionary).get("supports", []): total += 1
    return total

func power_understood(power_id: String) -> bool:
    var rules: Dictionary = chapter.get("investigation", {})
    return record_count_for(power_id) >= int(rules.get("minimum_per_power", 3)) and civilian_or_dissident_count_for(power_id) >= int(rules.get("civilian_or_dissident_per_power", 1))

func _node_data(node_id: String) -> Dictionary:
    for value in world.get("nodes", []):
        var data: Dictionary = value
        if String(data.get("id", "")) == node_id: return data
    return {}

func activate_authority_node(node_id: String) -> bool:
    if authority_nodes.has(node_id): return false
    var data := _node_data(node_id)
    if data.is_empty(): return false
    authority_nodes[node_id] = true
    authority_node_activated.emit(node_id)
    GameState.add_log("Autorité contestée — %s" % String(data.get("label", node_id)))
    chapter_eight_changed.emit()
    return true

func is_authority_node_active(node_id: String) -> bool:
    return authority_nodes.has(node_id)

func authority_node_count(power_id: String) -> int:
    var total := 0
    var expected_type := "%s_authority" % power_id
    for node_id in authority_nodes.keys():
        if String(_node_data(String(node_id)).get("type", "")) == expected_type: total += 1
    return total

func active_stage() -> Dictionary:
    for value in chapter.get("stages", []):
        var stage: Dictionary = value
        if not bool(completed_stages.get(String(stage.get("id", "")), false)): return stage
    return {}

func progress_text() -> String:
    return "%d/%d" % [completed_stages.size(), chapter.get("stages", []).size()]

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id in ["c08_boss_varkhane","c08_boss_azravel"] and not boss_choices.has(encounter_id):
        call_deferred("_request_boss_choice", encounter_id)
    refresh_progress()

func _request_boss_choice(boss_id: String) -> void:
    boss_choice_required.emit(boss_id)

func available_boss_choices(boss_id: String) -> Array:
    var result: Array = []
    for value in chapter.get("boss_choices", {}).get(boss_id, []):
        var choice: Dictionary = value
        if _choice_available(boss_id, choice): result.append(choice)
    return result

func _choice_available(boss_id: String, choice: Dictionary) -> bool:
    var req: Dictionary = choice.get("requirements", {})
    if req.is_empty(): return true
    var power_id := "varkhane" if boss_id == "c08_boss_varkhane" else "azravel"
    if authority_node_count(power_id) < int(req.get("authority_nodes", 0)): return false
    if record_count_for(power_id) < int(req.get("records_%s" % power_id, 0)): return false
    return true

func choose_boss_outcome(boss_id: String, choice_id: String) -> bool:
    if boss_choices.has(boss_id) or not AshlandsRuntime.is_encounter_cleared(boss_id): return false
    for value in chapter.get("boss_choices", {}).get(boss_id, []):
        var choice: Dictionary = value
        if String(choice.get("id", "")) != choice_id or not _choice_available(boss_id, choice): continue
        boss_choices[boss_id] = choice_id
        _apply_effects(choice.get("effects", {}))
        CampaignState.set_chapter_flag("c08_%s_%s" % [boss_id.trim_prefix("c08_boss_"), choice_id])
        GameState.add_log("Décision du monde extérieur — %s" % String(choice.get("label", choice_id)))
        refresh_progress()
        chapter_eight_changed.emit()
        return true
    return false

func _apply_effects(effects: Dictionary) -> void:
    for metric in ["justice_integrity","veil_knowledge","absent_contact","creature_relations","foreign_alliances","stabilizer_nodes"]:
        if effects.has(metric): CampaignState.add_metric(metric, int(effects[metric]))
    if effects.has("trust"): PoliticalState.trust = clampi(PoliticalState.trust + int(effects["trust"]), 0, 100)
    if effects.has("tension"): PoliticalState.tension = clampi(PoliticalState.tension + int(effects["tension"]), 0, 100)
    PoliticalState.politics_changed.emit()

func refresh_progress() -> void:
    if CampaignState.current_chapter_id != "chapter_08_outer_world": return
    _complete_if("c08_stage_01_varkhane", AshlandsRuntime.is_zone_discovered("c08_varkhane_border") and record_count_for("varkhane") >= 2)
    _complete_if("c08_stage_02_varkhane_choice", power_understood("varkhane") and authority_node_count("varkhane") >= 3 and AshlandsRuntime.is_encounter_cleared("c08_boss_varkhane") and boss_choices.has("c08_boss_varkhane"))
    _complete_if("c08_stage_03_namar", AshlandsRuntime.is_zone_discovered("c08_namar_refuge_port") and record_count_for("namar") >= 2)
    _complete_if("c08_stage_04_namar_ledger", power_understood("namar") and AshlandsRuntime.is_zone_discovered("c08_namar_ledger_vault"))
    _complete_if("c08_stage_05_azravel", AshlandsRuntime.is_zone_discovered("c08_azravel_shelter_temple") and record_count_for("azravel") >= 2)
    _complete_if("c08_stage_06_azravel_choice", power_understood("azravel") and authority_node_count("azravel") >= 3 and AshlandsRuntime.is_encounter_cleared("c08_boss_azravel") and boss_choices.has("c08_boss_azravel"))
    var rules: Dictionary = chapter.get("investigation", {})
    _complete_if("c08_stage_07_korem", AshlandsRuntime.is_zone_discovered("c08_korem_protocol_archive") and power_understood("kor_em") and record_count() >= int(rules.get("required_records", 12)) and independent_source_family_count() >= int(rules.get("independent_source_families", 6)) and foreign_command_count() >= int(rules.get("foreign_command_records", 4)))
    _complete_if("c08_stage_08_return", GameState.current_screen == "sanctuary" and boss_choices.size() >= 2 and power_understood("varkhane") and power_understood("namar") and power_understood("azravel") and power_understood("kor_em"))
    _sync_main_quests()
    _try_finish()
    chapter_eight_changed.emit()

func _complete_if(id_value: String, condition: bool) -> void:
    if condition and not bool(completed_stages.get(id_value, false)):
        completed_stages[id_value] = true
        GameState.add_log("Chapitre VIII — %s" % id_value)

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
    CampaignState.set_chapter_flag("chapter_08_vertical_slice_complete")
    CampaignState.set_chapter_flag("sanctuary_foreign_house_unlocked")
    CampaignState.set_chapter_flag("c08_shared_catastrophe_confirmed")
    CampaignState.discovered_revelations["chapter_08_end"] = String(chapter.get("end_revelation", ""))
    CampaignState.add_metric("foreign_alliances", 3)
    CampaignState.add_metric("veil_knowledge", 2)
    GameState.gold += 150
    GameState.essence += 20
    GameState.add_log("Chapitre VIII terminé : la catastrophe partagée et les responsabilités transfrontalières sont établies.")
    chapter_eight_completed.emit()

func serialize() -> Dictionary:
    return {"collected_records":collected_records.duplicate(true),"collected_ancient_traces":collected_ancient_traces.duplicate(true),"authority_nodes":authority_nodes.duplicate(true),"boss_choices":boss_choices.duplicate(true),"completed_stages":completed_stages.duplicate(true),"rewards_claimed":rewards_claimed}

func deserialize(payload: Dictionary) -> void:
    collected_records = payload.get("collected_records", {}).duplicate(true)
    collected_ancient_traces = payload.get("collected_ancient_traces", {}).duplicate(true)
    authority_nodes = payload.get("authority_nodes", {}).duplicate(true)
    boss_choices = payload.get("boss_choices", {}).duplicate(true)
    completed_stages = payload.get("completed_stages", {}).duplicate(true)
    rewards_claimed = bool(payload.get("rewards_claimed", false))
    chapter_eight_changed.emit()
