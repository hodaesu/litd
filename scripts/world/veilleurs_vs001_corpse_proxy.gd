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
    set_meta("owner_name", owner_name)
    add_to_group("veilleurs_vs001_persistent_corpse")

func interact() -> Dictionary:
    if scar_id.is_empty():
        return {"ok": false, "reason": "missing_scar_id"}
    return VeilleursCorpseInteractionRuntime.preview(scar_id)
