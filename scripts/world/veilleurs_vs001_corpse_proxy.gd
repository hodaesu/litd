extends Area3D
class_name VeilleursVS001CorpseProxy

var scar_id: String = ""
var owner_name: String = "Corps"

func configure(scar: Dictionary) -> void:
    scar_id = str(scar.get("id", ""))
    var payload: Dictionary = scar.get("payload", {})
    owner_name = str(payload.get("owner_name", scar.get("summary", "Corps")))
    name = "Corpse_%s" % scar_id.replace(":", "_")
    collision_layer = 1
    collision_mask = 0
    monitoring = false
    monitorable = true
    set_meta("scar_id", scar_id)
    set_meta("interaction_prompt", "AGIR SUR LE CORPS")
    set_meta("interaction_id", "corpse:%s" % scar_id)
    set_meta("interaction_label", owner_name)
    add_to_group("veilleurs_vs001_persistent_corpse")

func interaction_descriptor(_actor: Object = null) -> Dictionary:
    return EnvironmentInteractionContract.descriptor(
        "corpse:%s" % (scar_id if scar_id != "" else "missing"),
        EnvironmentInteractionContract.KIND_CORPSE,
        owner_name,
        "AGIR SUR LE CORPS",
        not scar_id.is_empty(),
        "missing_scar_id" if scar_id.is_empty() else "",
        false,
        {"owner_name": owner_name}
    )

func perform_interaction(actor: Object = null) -> Dictionary:
    var current := interaction_descriptor(actor)
    if not bool(current.get("available", false)):
        return EnvironmentInteractionContract.result(current, false, "blocked", str(current.get("blocked_reason", "missing_scar_id")))
    var preview := interact()
    var success := bool(preview.get("ok", preview.get("success", true)))
    return EnvironmentInteractionContract.result(
        current,
        success,
        "preview" if success else "blocked",
        str(preview.get("reason", "interaction_failed" if not success else "")),
        {"preview": preview}
    )

func interact() -> Dictionary:
    if scar_id.is_empty():
        return {"ok": false, "reason": "missing_scar_id"}
    return VeilleursCorpseInteractionRuntime.preview(scar_id)
