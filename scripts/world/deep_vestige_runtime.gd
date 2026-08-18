extends Node

signal vestige_changed
signal fragment_collected(fragment_id: String)
signal vestige_unlocked(vestige_id: String)
signal vestige_completed(vestige_id: String)

const INDEX_PATH := "res://data/world/deep_vestiges.json"
const ASHAI_PATH := "res://data/levels/vestige_ashai_seven_resonances.json"

var index_data: Dictionary = {}
var ash_data: Dictionary = {}
var unlocked: Dictionary = {}
var completed: Dictionary = {}
var fragments: Dictionary = {}
var rewards_claimed: Dictionary = {}

func _ready() -> void:
    index_data = _load_json(INDEX_PATH)
    ash_data = _load_json(ASHAI_PATH)
    reset_new_game()
    CampaignState.campaign_changed.connect(refresh_unlocks)
    AshlandsRuntime.encounter_cleared.connect(_on_encounter_cleared)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func reset_new_game() -> void:
    unlocked = {}
    completed = {}
    fragments = {}
    rewards_claimed = {}
    refresh_unlocks()
    vestige_changed.emit()

func refresh_unlocks() -> void:
    for value in index_data.get("vestiges", []):
        var vestige: Dictionary = value
        var id := String(vestige.get("id", ""))
        if id == "":
            continue
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

func collect_fragment(fragment_id: String) -> bool:
    if fragments.has(fragment_id):
        return false
    for value in ash_data.get("fragments", []):
        var fragment: Dictionary = value
        if String(fragment.get("id", "")) == fragment_id:
            fragments[fragment_id] = fragment.duplicate(true)
            fragment_collected.emit(fragment_id)
            GameState.add_log("Vestige profond — %s" % String(fragment.get("title", fragment_id)))
            vestige_changed.emit()
            return true
    return false

func ash_fragment_count() -> int:
    return fragments.size()

func _on_encounter_cleared(encounter_id: String) -> void:
    if encounter_id == "vestige_ashai_boss_seventh_voice":
        _try_complete_ashai()

func _try_complete_ashai() -> void:
    var id := "vestige_ashai_seven_resonances"
    if bool(completed.get(id, false)):
        return
    var required := int(ash_data.get("completion_requirements", {}).get("fragments_min", 7))
    if AshlandsRuntime.is_encounter_cleared("vestige_ashai_boss_seventh_voice") and ash_fragment_count() >= required:
        completed[id] = true
        _grant_ashai_rewards()
        vestige_completed.emit(id)
        vestige_changed.emit()

func _grant_ashai_rewards() -> void:
    var id := "vestige_ashai_seven_resonances"
    if bool(rewards_claimed.get(id, false)):
        return
    rewards_claimed[id] = true
    var reward: Dictionary = ash_data.get("rewards", {})
    GameState.gold += int(reward.get("gold", 0))
    GameState.essence += int(reward.get("essence", 0))
    CampaignState.set_chapter_flag("deep_vestige_ashai_complete")
    CampaignState.discovered_revelations["deep_truth_ashai"] = String(reward.get("deep_truth", {}).get("text", ""))
    CampaignState.add_metric("veil_knowledge", 10)
    GameState.add_log("Vérité Profonde obtenue : les Ashaï et l'accord vivant.")

func serialize() -> Dictionary:
    return {"unlocked":unlocked.duplicate(true),"completed":completed.duplicate(true),"fragments":fragments.duplicate(true),"rewards_claimed":rewards_claimed.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    unlocked = payload.get("unlocked", {}).duplicate(true)
    completed = payload.get("completed", {}).duplicate(true)
    fragments = payload.get("fragments", {}).duplicate(true)
    rewards_claimed = payload.get("rewards_claimed", {}).duplicate(true)
    refresh_unlocks()
    vestige_changed.emit()
