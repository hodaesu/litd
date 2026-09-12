extends Area3D
class_name VeilleursVS001InteractionProxy

@export var anchor_id: String = ""
@export var interaction_prompt: String = "EXAMINER"

func configure(anchor_id_value: String) -> void:
    anchor_id = anchor_id_value
    name = "Interact_%s" % anchor_id
    interaction_prompt = VeilleursVS001WorldRuntime.interaction_prompt(anchor_id)
    set_meta("interaction_prompt", interaction_prompt)
    set_meta("interaction_id", "anchor:%s" % anchor_id)
    set_meta("anchor_id", anchor_id)
    add_to_group("veilleurs_vs001_interactable")

func interaction_descriptor(_actor: Object = null) -> Dictionary:
    var preview: Dictionary = VeilleursVS001WorldRuntime.preview_anchor(anchor_id) if not anchor_id.is_empty() else {}
    return EnvironmentInteractionContract.descriptor(
        "anchor:%s" % (anchor_id if anchor_id != "" else "missing"),
        EnvironmentInteractionContract.KIND_GENERIC,
        str(preview.get("title", "Interaction")),
        interaction_prompt,
        not anchor_id.is_empty(),
        "missing_anchor_id" if anchor_id.is_empty() else "",
        false,
        {"description": str(preview.get("description", ""))}
    )

func perform_interaction(actor: Object = null) -> Dictionary:
    var current := interaction_descriptor(actor)
    if not bool(current.get("available", false)):
        return EnvironmentInteractionContract.result(current, false, "blocked", str(current.get("blocked_reason", "missing_anchor_id")))
    var preview := interact()
    var success := bool(preview.get("success", preview.get("ok", true)))
    return EnvironmentInteractionContract.result(
        current,
        success,
        "examined" if success else "blocked",
        str(preview.get("reason", "interaction_failed" if not success else "")),
        {"preview": preview}
    )

func interact() -> Dictionary:
    if anchor_id.is_empty():
        return {"success": false, "reason": "missing_anchor_id"}
    var preview: Dictionary = VeilleursVS001WorldRuntime.preview_anchor(anchor_id)
    var title := str(preview.get("title", "Interaction"))
    var description := str(preview.get("description", ""))
    GameState.add_log("%s — %s" % [title, description])
    return preview
