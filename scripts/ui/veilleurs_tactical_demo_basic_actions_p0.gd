extends "res://scripts/ui/veilleurs_tactical_demo_p0.gd"
class_name VeilleursTacticalDemoBasicActionsP0

const SESSION_P0_SCRIPT := preload("res://scripts/core/veilleurs_tactical_session_p0.gd")

var basic_action_rows: Array[Dictionary] = []

func _ready() -> void:
    _build_shell()
    flow_bridge = FLOW_SCRIPT.new() as VeilleursKharSenFlowBridge
    flow_payload = flow_bridge.pending()
    flow_active = not flow_payload.is_empty()
    session = SESSION_P0_SCRIPT.new() as VeilleursTacticalSessionV2
    add_child(session)
    var setup: Dictionary
    if flow_active:
        var encounter: Dictionary = flow_payload.get("encounter", {})
        var node_id := str(flow_payload.get("node_id", "KHAR"))
        setup = (session as VeilleursTacticalSessionP0).start_authored_encounter(encounter, "khar_sen:%s" % node_id, "khar_sen")
        back_button.text = "Retraite"
    else:
        setup = (session as VeilleursTacticalSessionP0).start_first_combat()
    if not bool(setup.get("ok", false)):
        message_label.text = "Échec d'initialisation : %s" % str(setup.get("reason", "inconnu"))
        return
    _repair_selection()
    _refresh()

func _refresh() -> void:
    super._refresh()
    if session == null or not session.is_active():
        return
    basic_action_rows = (session as VeilleursTacticalSessionP0).basic_actions_for(selected_watcher)
    var names: Array[String] = []
    for action: Dictionary in basic_action_rows:
        names.append(str(action.get("name", action.get("id", "Action"))))
    tactical_ui.set_skill_labels(names)
    _refresh_decision_state()

func _on_skill(slot: int) -> void:
    if session == null or not session.is_active() or slot < 0 or slot >= basic_action_rows.size():
        return
    if pending_skill_slot != slot:
        pending_skill_slot = slot
        _refresh()
        return
    var action: Dictionary = basic_action_rows[slot]
    pending_skill_slot = -1
    tactical_ui.set_armed_skill(-1)
    tactical_ui.set_targeting_mode(false)
    var target_id := _basic_target_id(action)
    var result := (session as VeilleursTacticalSessionP0).resolve_basic_action(selected_watcher, target_id, str(action.get("id", "")), selected_zone, -1)
    if not bool(result.get("ok", false)):
        message_label.text = "Action refusée : %s" % str(result.get("reason", "inconnue"))
        _refresh()
        return
    message_label.text = _basic_result_text(action, result)
    _check_end_or_enemy_phase()
    _refresh()

func _refresh_decision_state() -> void:
    if tactical_ui == null or session == null or not session.is_active():
        return
    basic_action_rows = (session as VeilleursTacticalSessionP0).basic_actions_for(selected_watcher)
    if pending_skill_slot < 0 or pending_skill_slot >= basic_action_rows.size():
        tactical_ui.set_armed_skill(-1)
        tactical_ui.set_targeting_mode(false)
        if tactical_ui.has_method("set_body_zone_choices_visible"):
            tactical_ui.call("set_body_zone_choices_visible", false)
        if decision_label != null:
            decision_label.text = ""
        return
    var action: Dictionary = basic_action_rows[pending_skill_slot]
    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    var row: Dictionary = runtime.combatants.get(selected_watcher, {})
    var rank := int(row.get("combat_rank", 1))
    var allowed := (action.get("positions", []) as Array).has(rank)
    var target_id := _basic_target_id(action)
    tactical_ui.set_armed_skill(pending_skill_slot)
    tactical_ui.set_targeting_mode(true, [target_id] if target_id != "" else [], [], allowed)
    var kind := str(action.get("kind", ""))
    var zone_relevant := kind.find("damage") >= 0 or kind.find("attack") >= 0 or kind.find("bleed") >= 0 or kind.find("precision") >= 0
    if tactical_ui.has_method("set_body_zone_choices_visible"):
        tactical_ui.call("set_body_zone_choices_visible", zone_relevant)
    var rank_labels: Array[String] = []
    for value: Variant in action.get("positions", []):
        rank_labels.append("R%d" % int(value))
    var ranks := ",".join(rank_labels)
    if allowed:
        decision_label.text = "%s · %s · rang actuel R%d · utilisable %s · cible %s · confirmer : même action" % [
            str(action.get("name", "Action")),
            str(action.get("effect", kind)),
            rank,
            ranks,
            _display(target_id) if target_id != "" else "—"
        ]
    else:
        decision_label.text = "%s · INDISPONIBLE EN R%d · positions : %s" % [str(action.get("name", "Action")), rank, ranks]

func _basic_target_id(action: Dictionary) -> String:
    var target_type := str(action.get("target", "enemy"))
    if target_type == "self":
        return selected_watcher
    if target_type == "ally":
        return selected_watcher
    return selected_target

func _basic_result_text(action: Dictionary, result: Dictionary) -> String:
    var name := str(action.get("name", "Action"))
    if result.has("healed"):
        return "%s : +%d PV (%s)." % [name, int(result.get("healed", 0)), str(result.get("healing_provenance", "origine inconnue"))]
    if result.has("damage"):
        return "%s : %d dégâts." % [name, int(result.get("damage", 0))]
    if result.has("rank_after"):
        return "%s : R%d → R%d." % [name, int(result.get("rank_before", 0)), int(result.get("rank_after", 0))]
    if result.has("status_applied"):
        return "%s : %s." % [name, str(result.get("status_applied", "effet"))]
    if result.has("guard_delta"):
        return "%s : garde +%d." % [name, int(result.get("guard_delta", 0))]
    return "%s exécutée." % name
