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
        {"description": str(preview.get("description", ""))},
        _authored_salience()
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

func _authored_salience() -> String:
    if anchor_id.is_empty():
        return EnvironmentInteractionContract.SALIENCE_INSPECT

    var state_value: Dictionary = VeilleursVS001WorldRuntime.snapshot()
    match anchor_id:
        "extraction_gate":
            return EnvironmentInteractionContract.SALIENCE_IMMEDIATE
        "s1_fresco":
            return EnvironmentInteractionContract.SALIENCE_INSPECT
        "s2_tripwire":
            var tripwire_state := str(state_value.get("s2_tripwire", "armed"))
            return EnvironmentInteractionContract.SALIENCE_IMMEDIATE if tripwire_state in ["armed", "detected"] else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s2_salvage":
            var salvage_state := str(state_value.get("s2_tripwire", "armed"))
            return EnvironmentInteractionContract.SALIENCE_CONTEXTUAL if salvage_state == "disarmed" and not VeilleursVS001WorldRuntime.is_loot_claimed("s2_salvage") else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s3_combat":
            return EnvironmentInteractionContract.SALIENCE_IMMEDIATE if not VeilleursVS001WorldRuntime.is_encounter_cleared("vs001_s3_ghouls") else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s3_corpses":
            return EnvironmentInteractionContract.SALIENCE_CONTEXTUAL if VeilleursVS001WorldRuntime.is_encounter_cleared("vs001_s3_ghouls") and not VeilleursVS001WorldRuntime.is_loot_claimed("s3") else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s4_supplies":
            return EnvironmentInteractionContract.SALIENCE_CONTEXTUAL if not VeilleursVS001WorldRuntime.is_loot_claimed("s4") else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s4_black_basin":
            return EnvironmentInteractionContract.SALIENCE_INSPECT
        "s5_scout_corpse":
            return EnvironmentInteractionContract.SALIENCE_CONTEXTUAL if not VeilleursVS001WorldRuntime.is_loot_claimed("s5") else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s5_wall_voice":
            return EnvironmentInteractionContract.SALIENCE_INSPECT
        "s6_survivor":
            return EnvironmentInteractionContract.SALIENCE_CONTEXTUAL if str(state_value.get("s6_outcome", "unresolved")) == "unresolved" else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s7_combat":
            return EnvironmentInteractionContract.SALIENCE_IMMEDIATE if not VeilleursVS001WorldRuntime.is_encounter_cleared("vs001_s7_ghouls") else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s7_acoustic_device":
            var device_ready := VeilleursVS001WorldRuntime.is_encounter_cleared("vs001_s7_ghouls") and str(state_value.get("s7_device", "intact")) == "intact"
            return EnvironmentInteractionContract.SALIENCE_IMMEDIATE if device_ready else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s7_secret_stair":
            var newly_revealed := bool(state_value.get("s8_unlocked", false)) and not bool(state_value.get("s8_discovered", false))
            return EnvironmentInteractionContract.SALIENCE_IMMEDIATE if newly_revealed else EnvironmentInteractionContract.SALIENCE_INSPECT
        "s8_archive":
            return EnvironmentInteractionContract.SALIENCE_INSPECT
        "s8_fragment":
            return EnvironmentInteractionContract.SALIENCE_CONTEXTUAL if not VeilleursVS001WorldRuntime.is_loot_claimed("s8") else EnvironmentInteractionContract.SALIENCE_INSPECT
        _:
            return EnvironmentInteractionContract.SALIENCE_INSPECT
