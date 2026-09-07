extends RefCounted
class_name VeilleursVerticalSliceRuntimeV08

const CAMPAIGN_SCRIPT := preload("res://scripts/core/veilleurs_campaign_runtime_v07.gd")
const TACTICAL_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v08.gd")
const AUTHORED_SCRIPT := preload("res://scripts/core/veilleurs_authored_encounter_runtime_v08.gd")

var campaign: VeilleursCampaignRuntimeV07
var combat: Variant = null
var combat_kind := ""
var combat_node_id := ""
var last_resolution: Dictionary = {}

func _init() -> void:
    campaign = CAMPAIGN_SCRIPT.new() as VeilleursCampaignRuntimeV07

func start_dungeon(dungeon_id: String, seed: int = 0) -> Dictionary:
    combat = null
    combat_kind = ""
    combat_node_id = ""
    last_resolution.clear()
    return campaign.start_dungeon(dungeon_id, seed)

func enter_next(node_id: String) -> Dictionary:
    if combat != null:
        return {"ok":false, "reason":"combat_active"}
    return campaign.dungeon.choose_next(node_id)

func launch_current_encounter(context: Dictionary = {}) -> Dictionary:
    if combat != null:
        return {"ok":false, "reason":"combat_already_active"}
    var encounter: Dictionary = campaign.dungeon.active_encounter
    if encounter.is_empty():
        return {"ok":false, "reason":"node_has_no_encounter", "node_id":campaign.dungeon.current_node}
    combat_node_id = campaign.dungeon.current_node
    var region_id := campaign.current_dungeon_id.to_lower()
    if bool(encounter.get("boss", false)):
        combat_kind = "boss"
        combat = TACTICAL_SCRIPT.new() as VeilleursTacticalCombatRuntimeV08
        var boss_context := context.duplicate(true)
        boss_context["region_id"] = region_id
        return combat.setup_boss_combat(str(encounter.get("boss_id", "")), boss_context)
    combat_kind = "authored"
    combat = AUTHORED_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeV08
    return combat.setup_authored_encounter(encounter, region_id)

func resolve_active_combat(outcome: String, extra_context: Dictionary = {}) -> Dictionary:
    if combat == null:
        return {"ok":false, "reason":"no_active_combat"}
    var watcher_aftermath := _watcher_aftermath()
    var enemy_aftermath := _enemy_aftermath(outcome)
    var threat_value := _combined_enemy_threat()
    var remanence_result: Dictionary = {}
    if combat.has_method("finish_remanence"):
        remanence_result = combat.call("finish_remanence", outcome, {"region_id":campaign.current_dungeon_id.to_lower(), "zone_id":combat_node_id, "summary":"%s — %s" % [combat_node_id, outcome]}) as Dictionary
    var context := extra_context.duplicate(true)
    context["watcher_aftermath"] = watcher_aftermath
    context["enemy_aftermath"] = enemy_aftermath
    context["threat_value"] = threat_value
    context["remanence"] = remanence_result
    context["combat_kind"] = combat_kind
    context["combat_node_id"] = combat_node_id
    var campaign_result := campaign.resolve_current_node(outcome, context)
    last_resolution = {"ok":bool(campaign_result.get("ok", false)), "campaign":campaign_result, "remanence":remanence_result, "watcher_aftermath":watcher_aftermath, "enemy_aftermath":enemy_aftermath, "combat_kind":combat_kind, "node_id":combat_node_id}
    combat = null
    combat_kind = ""
    combat_node_id = ""
    return last_resolution.duplicate(true)

func attempt_recruit_from_last(enemy_index: int = 0, context: Dictionary = {}) -> Dictionary:
    var enemies: Array = last_resolution.get("enemy_aftermath", [])
    if enemy_index < 0 or enemy_index >= enemies.size():
        return {"ok":false, "reason":"enemy_index"}
    var candidate: Dictionary = enemies[enemy_index]
    if int(candidate.get("hp", 0)) <= 0:
        return {"ok":false, "reason":"candidate_dead"}
    var result := campaign.attempt_recruit(candidate, context)
    if bool(result.get("ok", false)) and candidate.has("remanence_id") and RemanenceRuntime != null:
        RemanenceRuntime.set_entity_status(str(candidate.get("remanence_id", "")), "recruited")
    return result

func current_snapshot() -> Dictionary:
    return {"dungeon":campaign.dungeon.current(), "progress":campaign.dungeon.progress_summary(), "active_encounter":campaign.dungeon.active_encounter.duplicate(true), "combat_active":combat != null, "combat_kind":combat_kind, "combat_node_id":combat_node_id}

func serialize() -> Dictionary:
    return {"version":"0.8.0", "campaign":campaign.serialize(), "combat_kind":combat_kind, "combat_node_id":combat_node_id, "combat":combat.serialize() if combat != null and combat.has_method("serialize") else {}, "last_resolution":last_resolution.duplicate(true)}

func deserialize(payload: Dictionary) -> bool:
    if not campaign.deserialize(payload.get("campaign", {})):
        return false
    combat_kind = str(payload.get("combat_kind", ""))
    combat_node_id = str(payload.get("combat_node_id", ""))
    last_resolution = (payload.get("last_resolution", {}) as Dictionary).duplicate(true)
    var combat_payload: Dictionary = payload.get("combat", {})
    if combat_kind == "":
        combat = null
        return true
    if combat_kind == "boss":
        combat = TACTICAL_SCRIPT.new() as VeilleursTacticalCombatRuntimeV08
    elif combat_kind == "authored":
        combat = AUTHORED_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeV08
    else:
        return false
    return combat.deserialize(combat_payload)

func _watcher_aftermath() -> Dictionary:
    var result: Dictionary = {}
    for watcher_id: String in combat.alive_ids("watcher"):
        pass
    for watcher_id: String in ["ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA"]:
        if not combat.combatants.has(watcher_id):
            continue
        var row: Dictionary = combat.combatants[watcher_id]
        var body: Variant = row.get("body")
        result[watcher_id] = {"hp":int(row.get("hp", 0)), "max_hp":int(row.get("max_hp", 0)), "body":body.call("serialize") if body != null and body.has_method("serialize") else {}, "statuses":row.get("statuses", {}).duplicate(true), "level":int(row.get("level", 1)), "chosen_tree":str(row.get("chosen_tree", "")), "ultimate_charges":int(row.get("ultimate_charges", 0))}
    return result

func _enemy_aftermath(outcome: String) -> Array:
    var result: Array = []
    for entity_id_value: Variant in combat.combatants.keys():
        var entity_id := str(entity_id_value)
        var row: Dictionary = combat.combatants[entity_id]
        if str(row.get("team", "")) != "enemy":
            continue
        var body: Variant = row.get("body")
        result.append({"entity_id":str(row.get("definition_id", entity_id)), "runtime_id":entity_id, "remanence_id":str(row.get("remanence_id", "")), "remanence_stage":str(row.get("remanence_stage", "normal")), "name":str(row.get("name", entity_id)), "family":str(row.get("family", "")), "hp":int(row.get("hp", 0)), "max_hp":int(row.get("max_hp", 0)), "body":body.call("serialize") if body != null and body.has_method("serialize") else {}, "outcome":"killed" if int(row.get("hp", 0)) <= 0 else outcome, "level":int(row.get("level", 1)), "chosen_tree":str(row.get("chosen_tree", ""))})
    return result

func _combined_enemy_threat() -> float:
    var total := 0.0
    for entity_id_value: Variant in combat.combatants.keys():
        var row: Dictionary = combat.combatants[str(entity_id_value)]
        if str(row.get("team", "")) == "enemy":
            total += float(row.get("threat_value", 1.0))
    return total
