extends Area3D
class_name VeilleursVS001InteractionProxy

@export var anchor_id: String = ""
@export var interaction_prompt: String = "EXAMINER"

func configure(anchor_id_value: String) -> void:
    anchor_id = anchor_id_value
    name = "Interact_%s" % anchor_id
    interaction_prompt = VeilleursVS001WorldRuntime.interaction_prompt(anchor_id)
    set_meta("interaction_prompt", interaction_prompt)
    set_meta("anchor_id", anchor_id)
    add_to_group("veilleurs_vs001_interactable")

func interact() -> Dictionary:
    if anchor_id.is_empty():
        return {"success": false, "reason": "missing_anchor_id"}
    var preview: Dictionary = VeilleursVS001WorldRuntime.preview_anchor(anchor_id)
    var title := str(preview.get("title", "Interaction"))
    var description := str(preview.get("description", ""))
    GameState.add_log("%s — %s" % [title, description])
    return preview
