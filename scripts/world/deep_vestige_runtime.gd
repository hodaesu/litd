extends Node

signal vestige_changed
signal fragment_collected(fragment_id: String)
signal vestige_unlocked(vestige_id: String)
signal vestige_completed(vestige_id: String)

const INDEX_PATH := "res://data/world/deep_vestiges.json"

var index_data: Dictionary = {}
var vestige_data: Dictionary = {}
var unlocked: Dictionary = {}
var completed: Dictionary = {}
var fragments: Dictionary = {}
var rewards_claimed: Dictionary = {}
var pending_vestige_id := ""
var pending_zone_id := ""

func _ready() -> void:
    index_data = _load_json(INDEX_PATH)
    _load_all_vestiges()
    reset_new_game()
    CampaignState.campaign_changed.connect(refresh_unlocks)
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _load_all_vestiges() -> void:
    vestige_data = {}
    for value in index_data.get("vestiges", []):
        var entry: Dictionary = value
        var id := String(entry.get("id", ""))
        var path := String(entry.get("data_path", ""))
        if id == "" or path == "": continue
        vestige_data[id] = _load_json(path)

func reset_new_game() -> void:
    unlocked = {}
    completed = {}
    fragments = {}
    rewards_claimed = {}
    pending_vestige_id = ""
    pending_zone_id = ""
    refresh_unlocks()
    vestige_changed.emit()

func index_entries() -> Array:
    return index_data.get("vestiges", [])

func index_entry(vestige_id: String) -> Dictionary:
    for value in index_entries():
        var entry: Dictionary = value
        if String(entry.get("id", "")) == vestige_id: return entry
    return {}

func refresh_unlocks() -> void:
    for value in index_entries():
        var vestige: Dictionary = value
        var id := String(vestige.get("id", ""))
        if id == "": continue
        var unlock: Dictionary = vestige.get("unlock", {})
        var chapter_id := String(unlock.get("chapter", ""))
        var flag_id := String(unlock.get("flag", ""))
        var chapter_reached := CampaignState.chapter_index(CampaignState.current_chapter_id) >= CampaignState.chapter_index(chapter_id)
        var flag_ok := flag_id == "" or bool(CampaignState.chapter_flags.get(flag_id, false))
        if chapter_reached and flag_ok and not bool(unlocked.get(id, false)):
            unlocked[id] = true
            vestige_unlocked.emit(id)
    vestige_changed.emit()

func is_unlocked(vestige_id: String) -> bool:
    return bool(unlocked.get(vestige_id, false))

func data_for(vestige_id: String) -> Dictionary:
    return vestige_data.get(vestige_id, {})

func total_fragments_for(vestige_id: String) -> int:
    return data_for(vestige_id).get("fragments", []).size()

func entry_zone_for(vestige_id: String) -> String:
    var data := data_for(vestige_id)
    if data.has("entry_zone"): return String(data.get("entry_zone", ""))
    var zones: Array = data.get("zones", [])
    return String((zones[0] as Dictionary).get("id", "")) if not zones.is_empty() else ""

func vestige_id_for_zone(zone_id: String) -> String:
    for vestige_id in vestige_data.keys():
        for value in (vestige_data[vestige_id] as Dictionary).get("zones", []):
            if String((value as Dictionary).get("id", "")) == zone_id: return String(vestige_id)
    return ""

func has_zone(zone_id: String) -> bool:
    return vestige_id_for_zone(zone_id) != ""

func data_path_for_zone(zone_id: String) -> String:
    var id := vestige_id_for_zone(zone_id)
    if id == "": return ""
    return String(index_entry(id).get("data_path", ""))

func prepare_zone(zone_id: String) -> bool:
    var id := vestige_id_for_zone(zone_id)
    if id == "": return false
    pending_vestige_id = id
    pending_zone_id = zone_id
    return true

func collect_fragment(fragment_id: String) -> bool:
    if fragments.has(fragment_id): return false
    for vestige_id in vestige_data.keys():
        var data: Dictionary = vestige_data[vestige_id]
        for value in data.get("fragments", []):
            var fragment: Dictionary = value
            if String(fragment.get("id", "")) == fragment_id:
                var stored := fragment.duplicate(true)
                stored["vestige_id"] = vestige_id
                fragments[fragment_id] = stored
                fragment_collected.emit(fragment_id)
                GameState.add_log("Vestige profond — %s" % String(fragment.get("title", fragment_id)))
                vestige_changed.emit()
                return true
    return false

func fragment_count_for(vestige_id: String) -> int:
    var total := 0
    for value in fragments.values():
        if String((value as Dictionary).get("vestige_id", "")) == vestige_id: total += 1
    return total

func ash_fragment_count() -> int:
    return fragment_count_for("vestige_ashai_seven_resonances")

func _on_encounter_cleared(encounter_id: String) -> void:
    for vestige_id in vestige_data.keys():
        var data: Dictionary = vestige_data[vestige_id]
        var req: Dictionary = data.get("completion_requirements", {})
        if String(req.get("boss", "")) == encounter_id: _try_complete(String(vestige_id))

func _try_complete(vestige_id: String) -> void:
    if bool(completed.get(vestige_id, false)): return
    var data := data_for(vestige_id)
    var req: Dictionary = data.get("completion_requirements", {})
    var boss_id := String(req.get("boss", ""))
    var required := int(req.get("fragments_min", 6))
    if boss_id != "" and AshlandsRuntime.is_encounter_cleared(boss_id) and fragment_count_for(vestige_id) >= required:
        completed[vestige_id] = true
        _grant_rewards(vestige_id)
        vestige_completed.emit(vestige_id)
        vestige_changed.emit()

func _grant_rewards(vestige_id: String) -> void:
    if bool(rewards_claimed.get(vestige_id, false)): return
    rewards_claimed[vestige_id] = true
    var data := data_for(vestige_id)
    var reward: Dictionary = data.get("rewards", {})
    GameState.gold += int(reward.get("gold", 0))
    GameState.essence += int(reward.get("essence", 0))
    var deep_truth: Dictionary = reward.get("deep_truth", {})
    var truth_id := String(deep_truth.get("id", "deep_truth_%s" % vestige_id))
    CampaignState.discovered_revelations[truth_id] = String(deep_truth.get("text", ""))
    CampaignState.add_metric("veil_knowledge", 10)
    CampaignState.set_chapter_flag("deep_%s_complete" % vestige_id)
    GameState.add_log("Vérité Profonde obtenue : %s" % String(data.get("name", vestige_id)))

func serialize() -> Dictionary:
    return {"unlocked":unlocked.duplicate(true),"completed":completed.duplicate(true),"fragments":fragments.duplicate(true),"rewards_claimed":rewards_claimed.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    unlocked = payload.get("unlocked", {}).duplicate(true)
    completed = payload.get("completed", {}).duplicate(true)
    fragments = payload.get("fragments", {}).duplicate(true)
    rewards_claimed = payload.get("rewards_claimed", {}).duplicate(true)
    refresh_unlocks()
    vestige_changed.emit()
