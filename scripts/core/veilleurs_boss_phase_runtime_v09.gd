extends RefCounted
class_name VeilleursBossPhaseRuntimeV09

const PHASE_2_HP := 0.70
const PHASE_3_HP := 0.35

var boss_id := ""
var current_phase := 1
var pending_phase := 0
var transition_round := -1
var last_event: Dictionary = {}

func begin(value: String) -> Dictionary:
    boss_id = value
    current_phase = 1
    pending_phase = 0
    transition_round = -1
    last_event = {"ok":true, "boss":boss_id, "phase":1, "state":"active", "telegraph":""}
    return snapshot()

func update(runtime: Variant) -> Dictionary:
    if boss_id == "" or runtime == null or not runtime.combatants.has(boss_id):
        return {}
    var row: Dictionary = runtime.combatants[boss_id]
    var max_hp := maxi(1, int(row.get("max_hp", 1)))
    var hp_ratio := float(int(row.get("hp", 0))) / float(max_hp)
    var desired := _desired_phase(hp_ratio)
    var round_index := int(runtime.round_index)
    if pending_phase > current_phase and round_index > transition_round:
        current_phase = pending_phase
        pending_phase = 0
        last_event = _apply_phase(runtime, current_phase)
        last_event["transition"] = true
        last_event["hp_ratio"] = hp_ratio
        return last_event.duplicate(true)
    if desired > current_phase and pending_phase == 0:
        pending_phase = desired
        transition_round = round_index
        last_event = {
            "ok":true,
            "boss":boss_id,
            "phase":current_phase,
            "pending_phase":pending_phase,
            "state":"telegraph",
            "telegraph":_telegraph_for(boss_id, pending_phase),
            "hp_ratio":hp_ratio
        }
        return last_event.duplicate(true)
    last_event = {
        "ok":true,
        "boss":boss_id,
        "phase":current_phase,
        "pending_phase":pending_phase,
        "state":"active",
        "telegraph":"",
        "hp_ratio":hp_ratio
    }
    return last_event.duplicate(true)

func snapshot() -> Dictionary:
    return {
        "boss_id":boss_id,
        "phase":current_phase,
        "pending_phase":pending_phase,
        "transition_round":transition_round,
        "last_event":last_event.duplicate(true)
    }

func restore(payload: Dictionary) -> void:
    boss_id = str(payload.get("boss_id", ""))
    current_phase = clampi(int(payload.get("phase", 1)), 1, 3)
    pending_phase = clampi(int(payload.get("pending_phase", 0)), 0, 3)
    transition_round = int(payload.get("transition_round", -1))
    last_event = (payload.get("last_event", {}) as Dictionary).duplicate(true)

func _desired_phase(hp_ratio: float) -> int:
    if hp_ratio <= PHASE_3_HP:
        return 3
    if hp_ratio <= PHASE_2_HP:
        return 2
    return 1

func _apply_phase(runtime: Variant, phase: int) -> Dictionary:
    var row: Dictionary = runtime.combatants[boss_id]
    var event := {"ok":true, "boss":boss_id, "phase":phase, "state":"applied", "telegraph":_phase_name(boss_id, phase)}
    match boss_id:
        "ENT_BOSS_GARDIEN_SEUIL":
            row["guard_bonus"] = maxi(int(row.get("guard_bonus", 0)), 8 + phase * 4)
            var cells: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 4)] if phase == 2 else [Vector2i(2, 0), Vector2i(2, 4), Vector2i(3, 1), Vector2i(3, 3)]
            var applied := 0
            for cell: Vector2i in cells:
                if runtime.grid.inside(cell) and not runtime.grid.occupied(cell):
                    runtime.register_terrain_effect(cell, "BOSS_GARDIEN_PHASE_%d" % phase, boss_id, 2)
                    applied += 1
            event["locked_cells_added"] = applied
        "ENT_BOSS_CHOEUR_FENDU":
            for watcher_id: String in runtime.alive_ids("watcher"):
                var watcher: Dictionary = runtime.combatants[watcher_id]
                watcher["evasive_bonus"] = maxi(0, int(watcher.get("evasive_bonus", 0)) - phase)
                watcher["sensory_uncertainty"] = maxi(int(watcher.get("sensory_uncertainty", 0)), phase)
                runtime.combatants[watcher_id] = watcher
            event["uncertainty"] = phase
        "ENT_BOSS_MERE_MUES":
            row["weapon_power"] = int(row.get("weapon_power", 42)) + (4 if phase == 2 else 8)
            row["evasive_bonus"] = maxi(int(row.get("evasive_bonus", 0)), 3 * phase)
            event["mutation_pressure"] = phase
        "ENT_BOSS_JUGE_SANS_VISAGE":
            row["accuracy_bonus"] = maxi(int(row.get("accuracy_bonus", 0)), 3 * phase)
            for watcher_id: String in runtime.alive_ids("watcher"):
                var watcher: Dictionary = runtime.combatants[watcher_id]
                watcher["resolve_current"] = maxi(0, int(watcher.get("resolve_current", 60)) - (2 + phase * 2))
                runtime.combatants[watcher_id] = watcher
            event["judgment_pressure"] = 2 + phase * 2
        "ENT_BOSS_ARCHIVISTE_AVEUGLE":
            row["accuracy_bonus"] = maxi(int(row.get("accuracy_bonus", 0)), 4 * phase)
            row["guard_bonus"] = maxi(int(row.get("guard_bonus", 0)), 4 * phase)
            event["adaptation_strength"] = 4 * phase
    runtime.combatants[boss_id] = row
    return event

func _telegraph_for(value: String, phase: int) -> String:
    match value:
        "ENT_BOSS_GARDIEN_SEUIL": return "Le Seuil se resserre : de nouvelles cases vont se fermer." if phase == 2 else "Le Gardien prépare la fermeture complète de la ligne."
        "ENT_BOSS_CHOEUR_FENDU": return "Les voix commencent à se superposer." if phase == 2 else "Le Chœur abandonne toute voix distincte."
        "ENT_BOSS_MERE_MUES": return "La chair se détache : une nouvelle forme arrive." if phase == 2 else "La Mère sacrifie ce qui reste de sa forme initiale."
        "ENT_BOSS_JUGE_SANS_VISAGE": return "Le Juge ouvre le registre des choix consignés." if phase == 2 else "La sentence est prête à être prononcée."
        "ENT_BOSS_ARCHIVISTE_AVEUGLE": return "L'Archiviste a isolé vos habitudes les plus répétées." if phase == 2 else "L'Archive commence à agir sur ce qu'elle a appris."
        _: return "Le combat change de phase."

func _phase_name(value: String, phase: int) -> String:
    var names := {
        "ENT_BOSS_GARDIEN_SEUIL":["seuil_mobile","quadrillage","fermeture"],
        "ENT_BOSS_CHOEUR_FENDU":["voix_distinctes","polyphonie","saturation"],
        "ENT_BOSS_MERE_MUES":["forme_initiale","mue_reactive","forme_predatrice"],
        "ENT_BOSS_JUGE_SANS_VISAGE":["lecture","accusation","sentence"],
        "ENT_BOSS_ARCHIVISTE_AVEUGLE":["observation","contre_adaptation","remanence_active"]
    }
    var values: Array = names.get(value, ["phase_1","phase_2","phase_3"])
    return str(values[clampi(phase - 1, 0, 2)])
