class_name LITDEncounterGenerator
extends RefCounted

## Preproduction skeleton: NOT compile-validated.
## Source columns expected from compositions_64.json:
## Acte, Rencontre, Type, Profondeur min/max, Acteurs, Menace, Composition,
## Danger terrain, Leçon tactique, Notes.

const STANDARD_MOBILE_ENEMY_ACTOR_MAX := 4

var templates: Array = []
var spawn_rows: Array = []
var synergy_rows: Array = []
var hazard_rows: Array = []

func configure(
        encounter_templates: Array,
        depth_spawn_rows: Array,
        synergies: Array,
        hazards: Array
    ) -> void:
    templates = encounter_templates
    spawn_rows = depth_spawn_rows
    synergy_rows = synergies
    hazard_rows = hazards

func select_encounter(state: LITDEncounterRuntimeState) -> Dictionary:
    var eligible := _eligible_templates(state)
    if eligible.is_empty():
        return {"ok": false, "error": "No eligible encounter template", "template": {}}

    var preferred := []
    for row in eligible:
        var encounter_id := StringName(_stable_template_id(row))
        if not state.has_recently_seen(encounter_id):
            preferred.append(row)
    var pool := preferred if not preferred.is_empty() else eligible

    # Deterministic placeholder selection. The PC implementation must replace
    # this with the project's isolated ENCOUNTER RNG stream, not global RNG.
    var index := abs(state.encounter_seed) % pool.size()
    var chosen: Dictionary = pool[index]

    var actor_count := int(chosen.get("Acteurs", 0))
    if actor_count > STANDARD_MOBILE_ENEMY_ACTOR_MAX and String(chosen.get("Type", "")) == "Standard":
        return {"ok": false, "error": "Standard mobile encounter exceeds actor cap", "template": chosen}

    state.encounter_id = StringName(_stable_template_id(chosen))
    state.remember_encounter(state.encounter_id)
    return {"ok": true, "error": "", "template": chosen}

func _eligible_templates(state: LITDEncounterRuntimeState) -> Array:
    var result := []
    for row in templates:
        if not _act_matches(row, state.act_id):
            continue
        var min_depth := int(row.get("Profondeur min", 1))
        var max_depth := int(row.get("Profondeur max", 5))
        if state.depth < min_depth or state.depth > max_depth:
            continue
        result.append(row)
    return result

func _act_matches(row: Dictionary, act_id: StringName) -> bool:
    var source_act := String(row.get("Acte", ""))
    var runtime_act := String(act_id)
    return source_act == runtime_act or source_act.begins_with(runtime_act + " ")

func _stable_template_id(row: Dictionary) -> String:
    # Do not use localized encounter title as final persistence key in production.
    # PC integration should provide a versioned mapping table.
    return "%s::%s" % [String(row.get("Acte", "")), String(row.get("Rencontre", ""))]
