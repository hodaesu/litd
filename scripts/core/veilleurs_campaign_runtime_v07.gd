extends RefCounted
class_name VeilleursCampaignRuntimeV07

const DB_SCRIPT := preload("res://scripts/core/veilleurs_content_db_v07_runtime.gd")
const PROGRESSION_SCRIPT := preload("res://scripts/core/veilleurs_progression_runtime.gd")
const RECRUITMENT_SCRIPT := preload("res://scripts/core/veilleurs_recruitment_runtime.gd")
const ARCHIVES_SCRIPT := preload("res://scripts/core/veilleurs_archives_runtime.gd")
const REFUGE_SCRIPT := preload("res://scripts/core/veilleurs_refuge_runtime.gd")
const DUNGEON_SCRIPT := preload("res://scripts/core/veilleurs_dungeon_runtime_v07.gd")
const WATCHERS: Array[String] = ["ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA"]

var content_db: VeilleursContentDBV07Runtime
var progression: VeilleursProgressionRuntime
var recruitment: VeilleursRecruitmentRuntime
var archives: VeilleursArchivesRuntime
var refuge: VeilleursRefugeRuntime
var dungeon: VeilleursDungeonRuntimeV07
var current_dungeon_id := ""
var watcher_progress: Dictionary = {}
var recruit_progress: Dictionary = {}
var recruits_this_expedition := 0
var expeditions_started := 0

func _init() -> void:
    content_db = DB_SCRIPT.new() as VeilleursContentDBV07Runtime
    content_db.reload()
    progression = PROGRESSION_SCRIPT.new() as VeilleursProgressionRuntime
    progression.configure(content_db.progression)
    recruitment = RECRUITMENT_SCRIPT.new() as VeilleursRecruitmentRuntime
    recruitment.configure(content_db.recruitment)
    archives = ARCHIVES_SCRIPT.new() as VeilleursArchivesRuntime
    archives.configure(content_db.archives)
    refuge = REFUGE_SCRIPT.new() as VeilleursRefugeRuntime
    refuge.configure_v07(content_db.economy)
    dungeon = DUNGEON_SCRIPT.new() as VeilleursDungeonRuntimeV07
    for watcher_id: String in WATCHERS:
        watcher_progress[watcher_id] = progression.new_state(watcher_id, 1)

func start_dungeon(dungeon_id: String, seed: int = 0) -> Dictionary:
    if not dungeon.configure(content_db, dungeon_id):
        return {"ok":false, "reason":"dungeon_config", "errors":dungeon.load_errors.duplicate()}
    current_dungeon_id = dungeon_id
    recruits_this_expedition = 0
    expeditions_started += 1
    return dungeon.start(seed)

func resolve_current_node(outcome: String, combat_context: Dictionary = {}) -> Dictionary:
    if current_dungeon_id == "":
        return {"ok":false, "reason":"no_active_dungeon"}
    var progress_result: Dictionary = _apply_combat_progress(combat_context)
    var archive_result: Dictionary = _record_combat_archives(combat_context)
    var dungeon_result: Dictionary = dungeon.complete_current(outcome, combat_context)
    return {"ok":bool(dungeon_result.get("ok", false)), "dungeon":dungeon_result, "progress":progress_result, "archives":archive_result}

func attempt_recruit(candidate: Dictionary, context: Dictionary = {}) -> Dictionary:
    var entry_id := str(candidate.get("remanence_id", candidate.get("entity_id", "")))
    var dossier: Dictionary = archives.dossier(entry_id)
    var merged := context.duplicate(true)
    merged["refuge_slots_free"] = refuge.recruit_slots_free()
    merged["recruits_this_expedition"] = recruits_this_expedition
    merged["knowledge_level"] = maxi(int(merged.get("knowledge_level", 0)), int(dossier.get("knowledge_level", 0)))
    var result: Dictionary = recruitment.recruit(candidate, merged, refuge.recruits)
    if not bool(result.get("ok", false)):
        return result
    var recruit_row: Dictionary = result.get("recruit", {})
    var added: Dictionary = refuge.add_recruit(recruit_row)
    if not bool(added.get("ok", false)):
        return {"ok":false, "reason":"refuge_rejected_recruit", "evaluation":result.get("evaluation", {}), "refuge":added}
    recruits_this_expedition += 1
    var recruit_key := str(recruit_row.get("remanence_id", recruit_row.get("entity_id", "")))
    recruit_progress[recruit_key] = progression.new_state(str(recruit_row.get("definition_id", recruit_row.get("entity_id", ""))), int(recruit_row.get("level", 1)))
    archives.record_history_event(entry_id, {"event_id":"RECRUITED", "dungeon_id":current_dungeon_id, "expedition":expeditions_started})
    return {"ok":true, "recruit":recruit_row, "slots_free":refuge.recruit_slots_free(), "recruits_this_expedition":recruits_this_expedition}

func complete_expedition(rewards: Dictionary = {}) -> Dictionary:
    var gold := int(rewards.get("gold", 0))
    var materials := int(rewards.get("materials", 0))
    var essence := int(rewards.get("essence", 0))
    refuge.complete_expedition(gold, materials, essence)
    var summary := {"ok":true, "dungeon_id":current_dungeon_id, "gold":gold, "materials":materials, "essence":essence, "recruits":recruits_this_expedition, "refuge":refuge.serialize()}
    current_dungeon_id = ""
    recruits_this_expedition = 0
    return summary

func gain_entity_xp(entity_key: String, amount: int) -> Dictionary:
    if watcher_progress.has(entity_key):
        watcher_progress[entity_key] = progression.gain_xp(watcher_progress[entity_key], amount)
        return (watcher_progress[entity_key] as Dictionary).duplicate(true)
    if recruit_progress.has(entity_key):
        recruit_progress[entity_key] = progression.gain_xp(recruit_progress[entity_key], amount)
        return (recruit_progress[entity_key] as Dictionary).duplicate(true)
    return {}

func serialize() -> Dictionary:
    return {
        "version":"0.7.0",
        "current_dungeon_id":current_dungeon_id,
        "watcher_progress":watcher_progress.duplicate(true),
        "recruit_progress":recruit_progress.duplicate(true),
        "recruits_this_expedition":recruits_this_expedition,
        "expeditions_started":expeditions_started,
        "archives":archives.serialize(),
        "refuge":refuge.serialize(),
        "dungeon":dungeon.serialize() if current_dungeon_id != "" else {}
    }

func deserialize(payload: Dictionary) -> bool:
    watcher_progress = (payload.get("watcher_progress", {}) as Dictionary).duplicate(true)
    recruit_progress = (payload.get("recruit_progress", {}) as Dictionary).duplicate(true)
    recruits_this_expedition = maxi(0, int(payload.get("recruits_this_expedition", 0)))
    expeditions_started = maxi(0, int(payload.get("expeditions_started", 0)))
    archives.deserialize(payload.get("archives", {}))
    refuge.deserialize(payload.get("refuge", {}))
    current_dungeon_id = str(payload.get("current_dungeon_id", ""))
    if current_dungeon_id != "":
        if not dungeon.configure(content_db, current_dungeon_id):
            return false
        if not dungeon.deserialize(payload.get("dungeon", {})):
            return false
    return true

func _apply_combat_progress(context: Dictionary) -> Dictionary:
    var threat := float(context.get("threat_value", 1.0))
    var xp := maxi(25, 45 + int(round(threat * 25.0)))
    var result: Dictionary = {"xp":xp, "watchers":{}}
    for watcher_id: String in WATCHERS:
        var aftermath: Dictionary = (context.get("watcher_aftermath", {}) as Dictionary).get(watcher_id, {})
        if aftermath.is_empty() or int(aftermath.get("hp", 1)) > 0:
            watcher_progress[watcher_id] = progression.gain_xp(watcher_progress.get(watcher_id, progression.new_state(watcher_id, 1)), xp)
            (result["watchers"] as Dictionary)[watcher_id] = (watcher_progress[watcher_id] as Dictionary).duplicate(true)
    return result

func _record_combat_archives(context: Dictionary) -> Dictionary:
    var recorded := 0
    for enemy_value: Variant in context.get("enemy_aftermath", []):
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        var entry_id := str(enemy.get("remanence_id", enemy.get("entity_id", "")))
        if entry_id == "":
            continue
        archives.record_identity(entry_id, "enemy", {"name":str(enemy.get("name", enemy.get("entity_id", ""))), "definition_id":str(enemy.get("entity_id", "")), "family":str(enemy.get("family", ""))})
        if enemy.has("body"):
            archives.record_body(entry_id, enemy.get("body", {}))
        archives.record_history_event(entry_id, {"event_id":str(enemy.get("outcome", "ENCOUNTERED")), "dungeon_id":current_dungeon_id, "node_id":dungeon.current_node})
        if enemy.has("last_skill_id"):
            archives.record_combat_observation(entry_id, {"skill_id":str(enemy.get("last_skill_id", "")), "round":int(enemy.get("round", 0))})
        recorded += 1
    return {"recorded":recorded}
