extends "res://scripts/core/veilleurs_tactical_combat_runtime_v08.gd"
class_name VeilleursAuthoredEncounterRuntimeV08

const GRID_V08_SCRIPT := preload("res://scripts/core/veilleurs_tactical_grid.gd")
const BODY_V08_SCRIPT := preload("res://scripts/core/veilleurs_body_component.gd")
const ENEMY_START_CELLS: Array[Vector2i] = [
    Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4),
    Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)
]

var encounter_template: Dictionary = {}

func setup_authored_encounter(encounter: Dictionary, region_id: String = "") -> Dictionary:
    encounter_template = encounter.duplicate(true)
    active_region_id = region_id
    active_boss_id = ""
    last_boss_rule.clear()
    last_boss_mechanics.clear()
    terrain_effects.clear()
    summon_requests.clear()
    combatants.clear()
    action_log.clear()
    round_index = 1
    grid = GRID_V08_SCRIPT.new() as VeilleursTacticalGrid
    var balance: Dictionary = content_db.combat_constants.get("v061_balance", {})
    for index in range(WATCHER_IDS.size()):
        var watcher_id := WATCHER_IDS[index]
        var definition := content_db.watcher(watcher_id)
        if definition.is_empty():
            return {"ok":false, "reason":"missing_watcher", "entity_id":watcher_id}
        _register(definition, "watcher")
        var watcher_row: Dictionary = combatants[watcher_id]
        watcher_row["weapon_power"] = int(balance.get("watcher_weapon_power", 30))
        combatants[watcher_id] = watcher_row
        var pos: Array = definition.get("starter_position", [0, index])
        if not grid.place(watcher_id, Vector2i(int(pos[0]), int(pos[1]))):
            return {"ok":false, "reason":"watcher_placement", "entity_id":watcher_id}
    var composition: Array = encounter.get("composition", [])
    if composition.is_empty():
        return {"ok":false, "reason":"empty_encounter"}
    if composition.size() > ENEMY_START_CELLS.size():
        return {"ok":false, "reason":"encounter_too_large", "count":composition.size()}
    var spawned_ids: Array[String] = []
    var spawn_counts: Dictionary = {}
    for index in range(composition.size()):
        var member: Dictionary = composition[index]
        var definition_id := str(member.get("definition_id", ""))
        var definition := content_db.enemy(definition_id)
        if definition.is_empty():
            return {"ok":false, "reason":"missing_enemy", "entity_id":definition_id}
        var count := int(spawn_counts.get(definition_id, 0)) + 1
        spawn_counts[definition_id] = count
        var runtime_id := definition_id if count == 1 else "%s#%02d" % [definition_id, count]
        _register_as(definition, runtime_id, int(balance.get("enemy_weapon_power", 42)))
        var row: Dictionary = combatants[runtime_id]
        if member.has("remanence_id"):
            row["remanence_id"] = str(member.get("remanence_id", ""))
        combatants[runtime_id] = row
        remanence_bridge.prepare_enemy(self, runtime_id, active_region_id)
        row = combatants[runtime_id]
        row["level"] = clampi(int(member.get("level", _initial_enemy_level(row))), 1, 50)
        row["ultimate_charges"] = _ultimate_charges_for_level(int(row["level"]))
        row.erase("chosen_tree")
        combatants[runtime_id] = row
        skill_selector.ensure_tree(self, runtime_id)
        if not grid.place(runtime_id, ENEMY_START_CELLS[index]):
            return {"ok":false, "reason":"enemy_placement", "entity_id":runtime_id}
        spawned_ids.append(runtime_id)
    return {"ok":true, "template_id":str(encounter.get("template_id", "")), "objective":str(encounter.get("objective", "survive")), "counterplay":str(encounter.get("counterplay", "")), "watchers":WATCHER_IDS.duplicate(), "enemies":spawned_ids, "grid":grid.snapshot(), "version":"0.8.0"}

func serialize() -> Dictionary:
    var payload: Dictionary = super.serialize()
    payload["v08_encounter_template"] = encounter_template.duplicate(true)
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    encounter_template = (payload.get("v08_encounter_template", {}) as Dictionary).duplicate(true)
    return true

func _register_as(definition: Dictionary, runtime_id: String, weapon_power: int) -> void:
    var stats: Dictionary = (definition.get("stats", {}) as Dictionary).duplicate(true)
    var body_integrity: Dictionary = (definition.get("body_integrity", content_db.combat_constants.get("body_integrity_reference", {})) as Dictionary).duplicate(true)
    var vigor := int(stats.get("VIG", 60))
    combatants[runtime_id] = {
        "entity_id":runtime_id,
        "definition_id":str(definition.get("entity_id", runtime_id)),
        "name":str(definition.get("name_fr", runtime_id)),
        "team":"enemy",
        "family":str(definition.get("family", "")),
        "combat_role":str(definition.get("combat_role", "assault")),
        "threat_value":float(definition.get("threat_value", 1.0)),
        "remanence_stage":"normal",
        "stats":stats,
        "hp":80 + vigor,
        "max_hp":80 + vigor,
        "armor":20,
        "weapon_power":weapon_power,
        "resolve_current":int(stats.get("RES", 60)),
        "statuses":{},
        "passive_effects":{},
        "observed_by":{},
        "guard_bonus":0,
        "evasive_bonus":0,
        "adaptations":[],
        "body":BODY_V08_SCRIPT.new(body_integrity)
    }
