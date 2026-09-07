extends RefCounted
class_name VeilleursEncounterDirector

const HYBRID_SCRIPT := preload("res://scripts/core/veilleurs_hybrid_generation_bridge.gd")
const RECENT_CAP := 6

var hybrid: VeilleursHybridGenerationBridge
var recent_templates: Array[String] = []
var resolved_templates: Dictionary = {}

func _init() -> void:
    hybrid = HYBRID_SCRIPT.new() as VeilleursHybridGenerationBridge

func next_encounter(family: String, band: String, variant: int, seed_value: int) -> Dictionary:
    var selected: Dictionary = {}
    for offset in range(12):
        var candidate := hybrid.generate_encounter(family, band, variant, seed_value + offset * 7919)
        if candidate.is_empty():
            continue
        var template_id := str(candidate.get("template_id", ""))
        if not recent_templates.has(template_id) or offset >= 8:
            selected = candidate
            break
    if selected.is_empty():
        selected = hybrid.generate_encounter(family, band, variant, seed_value)
    if not selected.is_empty():
        _remember(str(selected.get("template_id", "")))
    return selected

func resolve_encounter(encounter: Dictionary, outcome: String, anchor_id: String, context: Dictionary = {}) -> Dictionary:
    var template_id := str(encounter.get("template_id", ""))
    if template_id == "":
        return {"ok":false, "reason":"missing_template"}
    resolved_templates[template_id] = int(resolved_templates.get(template_id, 0)) + 1
    var result := {"ok":true, "template_id":template_id, "outcome":outcome, "times_resolved":int(resolved_templates[template_id])}
    if outcome in ["retreat", "defeat", "victory_with_mutilation"]:
        var scar_context := context.duplicate(true)
        scar_context["summary"] = str(context.get("summary", "Rencontre %s : %s" % [template_id, outcome]))
        scar_context["protected"] = bool(context.get("protected", false))
        var severity := "major" if outcome in ["defeat", "victory_with_mutilation"] else "trace"
        result["scar_id"] = RemanenceRuntime.create_world_scar(anchor_id, "encounter_%s" % outcome, severity, scar_context)
    return result

func serialize() -> Dictionary:
    return {"recent_templates":recent_templates.duplicate(), "resolved_templates":resolved_templates.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    recent_templates.clear()
    for value: Variant in payload.get("recent_templates", []):
        recent_templates.append(str(value))
    while recent_templates.size() > RECENT_CAP:
        recent_templates.remove_at(0)
    resolved_templates = (payload.get("resolved_templates", {}) as Dictionary).duplicate(true)

func _remember(template_id: String) -> void:
    if template_id == "":
        return
    recent_templates.erase(template_id)
    recent_templates.append(template_id)
    while recent_templates.size() > RECENT_CAP:
        recent_templates.remove_at(0)
