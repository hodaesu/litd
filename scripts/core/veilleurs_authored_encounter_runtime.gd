extends "res://scripts/core/veilleurs_tactical_combat_runtime_v2.gd"
class_name VeilleursAuthoredEncounterRuntime

const ENEMY_START_CELLS: Array[Vector2i] = [
    Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4),
    Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)
]

var encounter_template: Dictionary = {}

func setup_authored_encounter(encounter: Dictionary) -> Dictionary:
    encounter_template = encounter.duplicate(true)
    combatants.clear()
    action_log.clear()
    round_index = 1
    grid = GRID_SCRIPT.new() as VeilleursTacticalGrid

    for index in range(WATCHER_IDS.size()):
        var watcher_id := WATCHER_IDS[index]
        var watcher_definition := content_db.watcher(watcher_id)
        if watcher_definition.is_empty():
            return {"ok":false, "reason":"missing_watcher", "entity_id":watcher_id}
        _register(watcher_definition, "watcher")
        var pos: Array = watcher_definition.get("starter_position", [0, index])
        if not grid.place(watcher_id, Vector2i(int(pos[0]), int(pos[1]))):
            return {"ok":false, "reason":"watcher_placement", "entity_id":watcher_id}

    var composition: Array = encounter.get("composition", [])
    if composition.is_empty():
        return {"ok":false, "reason":"empty_encounter"}
    if composition.size() > ENEMY_START_CELLS.size():
        return {"ok":false, "reason":"encounter_too_large", "count":composition.size(), "cap":ENEMY_START_CELLS.size()}

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
        _register_as(definition, "enemy", runtime_id)
        if member.has("remanence_id"):
            var row: Dictionary = combatants[runtime_id]
            row["remanence_id"] = str(member.get("remanence_id", ""))
            row["remanence_stage"] = str(member.get("remanence_stage", "memoriel"))
            combatants[runtime_id] = row
            apply_remanence_state(runtime_id, str(member.get("remanence_id", "")))
        if not grid.place(runtime_id, ENEMY_START_CELLS[index]):
            return {"ok":false, "reason":"enemy_placement", "entity_id":runtime_id}
        spawned_ids.append(runtime_id)

    for entity_id_value: Variant in combatants.keys():
        var entity_id := str(entity_id_value)
        var row: Dictionary = combatants[entity_id]
        var stats: Dictionary = row.get("stats", {})
        row["resolve_current"] = int(stats.get("RES", 60))
        row["statuses"] = row.get("statuses", {})
        row["passive_effects"] = row.get("passive_effects", {})
        row["observed_by"] = row.get("observed_by", {})
        row["guard_bonus"] = int(row.get("guard_bonus", 0))
        row["evasive_bonus"] = int(row.get("evasive_bonus", 0))
        row["adaptations"] = (row.get("adaptations", []) as Array).duplicate()
        combatants[entity_id] = row

    return {
        "ok":true,
        "template_id":str(encounter.get("template_id", "")),
        "objective":str(encounter.get("objective", "survive")),
        "counterplay":str(encounter.get("counterplay", "")),
        "watchers":WATCHER_IDS.duplicate(),
        "enemies":spawned_ids,
        "grid":grid.snapshot()
    }

func serialize() -> Dictionary:
    var payload := super.serialize()
    payload["encounter_template"] = encounter_template.duplicate(true)
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    encounter_template = (payload.get("encounter_template", {}) as Dictionary).duplicate(true)
    return true

func _register_as(definition: Dictionary, team: String, runtime_id: String) -> void:
    var stats: Dictionary = (definition.get("stats", {}) as Dictionary).duplicate(true)
    var body_integrity: Dictionary = (definition.get("body_integrity", content_db.combat_constants.get("body_integrity_reference", {})) as Dictionary).duplicate(true)
    var vigor := int(stats.get("VIG", 60))
    combatants[runtime_id] = {
        "entity_id":runtime_id,
        "definition_id":str(definition.get("entity_id", runtime_id)),
        "name":str(definition.get("name_fr", runtime_id)),
        "team":team,
        "family":str(definition.get("family", "")),
        "combat_role":str(definition.get("combat_role", "assault")),
        "threat_value":float(definition.get("threat_value", 1.0)),
        "remanence_stage":str(definition.get("remanence_stage", "normal")),
        "stats":stats,
        "hp":80 + vigor,
        "max_hp":80 + vigor,
        "armor":20,
        "weapon_power":24,
        "body":BODY_SCRIPT.new(body_integrity)
    }
