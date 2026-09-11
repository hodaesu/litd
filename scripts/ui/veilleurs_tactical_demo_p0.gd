extends "res://scripts/ui/veilleurs_tactical_demo_v2.gd"
class_name VeilleursTacticalDemoP0

var pending_skill_slot := -1
var decision_label: Label

func _build_shell() -> void:
    super._build_shell()
    # Player-facing P0: keep QA save/load support in code, but remove it from the
    # permanent combat chrome. The same functions remain available to dedicated QA scenes.
    for node: Node in find_children("*", "Button", true, false):
        if node is Button and (node as Button).text in ["Sauvegarder", "Reprendre"]:
            (node as Button).visible = false
    if tactical_ui != null:
        tactical_ui.offset_bottom = -112
        tactical_ui.status_label.visible = false
        if tactical_ui.has_method("set_body_zone_choices_visible"):
            tactical_ui.call("set_body_zone_choices_visible", false)

    decision_label = Label.new()
    decision_label.name = "DecisionPreview"
    decision_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    decision_label.offset_left = 18
    decision_label.offset_right = -18
    decision_label.offset_top = -108
    decision_label.offset_bottom = -72
    decision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    decision_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    decision_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    decision_label.add_theme_font_size_override("font_size", 15)
    add_child(decision_label)

func _refresh() -> void:
    super._refresh()
    if tactical_ui == null or session == null or not session.is_active():
        return
    tactical_ui.set_external_selection(selected_watcher, selected_target, selected_zone)
    _refresh_decision_state()

func _on_skill(slot: int) -> void:
    if session == null or not session.is_active() or slot < 0 or slot >= skill_ids.size():
        return
    if pending_skill_slot != slot:
        pending_skill_slot = slot
        _refresh()
        return

    # A second press confirms the action after the player has seen its consequences.
    pending_skill_slot = -1
    tactical_ui.set_armed_skill(-1)
    tactical_ui.set_targeting_mode(false)
    super._on_skill(slot)
    _refresh()

func _on_cell(cell: Vector2i) -> void:
    if pending_skill_slot >= 0 and session != null and session.is_active():
        var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
        var occupant := runtime.grid.occupant(cell)
        if occupant == "":
            message_label.text = "Une compétence est préparée. Choisissez une cible ou retouchez la compétence pour confirmer."
            return
    super._on_cell(cell)

func _on_zone(zone: String) -> void:
    super._on_zone(zone)
    if pending_skill_slot >= 0:
        _refresh_decision_state()

func _refresh_decision_state() -> void:
    if pending_skill_slot < 0 or pending_skill_slot >= skill_ids.size():
        tactical_ui.set_armed_skill(-1)
        tactical_ui.set_targeting_mode(false)
        if tactical_ui.has_method("set_body_zone_choices_visible"):
            tactical_ui.call("set_body_zone_choices_visible", false)
        if decision_label != null:
            decision_label.text = ""
        return

    var runtime: VeilleursTacticalCombatRuntimeV2 = session.runtime
    var skill_id := skill_ids[pending_skill_slot]
    var skill: Dictionary = runtime.content_db.skill(skill_id)
    var action := runtime.skill_behavior.effective_action(skill)
    var candidates: Array[String] = []
    var blocked: Array[String] = []
    var target_id := selected_target

    if action in ["guard", "heal", "passive_modifier", "move", "support"]:
        target_id = selected_watcher
        candidates.append(selected_watcher)
    else:
        var required_range := runtime.skill_behavior.range_for(skill)
        for enemy_id: String in runtime.alive_ids("enemy"):
            var distance := runtime.grid.distance(selected_watcher, enemy_id)
            if action == "attack_move" or (distance >= 0 and distance <= required_range):
                candidates.append(enemy_id)
            else:
                blocked.append(enemy_id)
        if not candidates.has(target_id) and not candidates.is_empty():
            target_id = candidates[0]
            selected_target = target_id

    tactical_ui.set_armed_skill(pending_skill_slot)
    tactical_ui.set_targeting_mode(true, candidates, blocked, target_id != "" and candidates.has(target_id))
    var zone_relevant := action in ["attack", "attack_move"]
    if tactical_ui.has_method("set_body_zone_choices_visible"):
        tactical_ui.call("set_body_zone_choices_visible", zone_relevant)
    decision_label.text = _decision_preview(runtime, selected_watcher, target_id, skill, selected_zone)

func _decision_preview(runtime: VeilleursTacticalCombatRuntimeV2, attacker_id: String, target_id: String, skill: Dictionary, zone: String) -> String:
    var skill_name := str(skill.get("name_fr", skill.get("skill_id", "Compétence")))
    var action := runtime.skill_behavior.effective_action(skill)
    var effect: Dictionary = skill.get("effect_spec", {})

    if action in ["guard", "heal", "support", "observe", "psychological", "control", "move", "passive_modifier", "transform"]:
        var effects: Array[String] = []
        var guard_delta := int(effect.get("guard_delta", 0))
        var resolve_delta := int(effect.get("resolve_delta", 0))
        var knowledge := int(effect.get("knowledge_reveal", 0))
        if guard_delta != 0:
            effects.append("garde %+d" % guard_delta)
        if resolve_delta != 0:
            effects.append("résolution %+d" % resolve_delta)
        if knowledge > 0:
            effects.append("connaissance +%d" % knowledge)
        if action == "move":
            effects.append("repositionnement")
        if effects.is_empty():
            effects.append(str(skill.get("canonical_function", "effet tactique")))
        return "%s · %s · cible : %s · %s · confirmer : même compétence" % [
            skill_name,
            action.capitalize(),
            _display(target_id),
            " · ".join(effects),
        ]

    if target_id == "" or not runtime.combatants.has(attacker_id) or not runtime.combatants.has(target_id):
        return "%s · aucune cible valide" % skill_name

    var attacker: Dictionary = runtime.combatants[attacker_id]
    var target: Dictionary = runtime.combatants[target_id]
    var required_range := runtime.skill_behavior.range_for(skill)
    var distance := runtime.grid.distance(attacker_id, target_id)
    if action != "attack_move" and (distance < 0 or distance > required_range):
        return "%s · %s HORS PORTÉE · distance %d / portée %d" % [skill_name, _display(target_id), distance, required_range]

    var chance := int(runtime.call("_hit_chance", attacker, target, skill, zone))
    chance += int(attacker.get("accuracy_bonus", 0))
    chance -= int(target.get("evasive_bonus", 0))
    if (target.get("statuses", {}) as Dictionary).has("EXPOSED"):
        chance += 8
    var clamps: Dictionary = runtime.content_db.combat_constants.get("hit_clamp", {})
    chance = clampi(chance, int(clamps.get("min_percent", 10)), int(clamps.get("max_percent", 97)))
    var damage := int(runtime.call("_skill_damage", attacker, target, skill))
    var forced_move := int(effect.get("forced_move", 0))
    var consequence := str(skill.get("canonical_impacts", "")).strip_edges()
    var details: Array[String] = [
        "%d %% toucher" % chance,
        "~%d dégâts" % damage,
        "portée %d · distance %d" % [required_range, distance],
    ]
    if forced_move > 0:
        details.append("repousse jusqu'à %d" % forced_move)
    if consequence != "":
        details.append(consequence)
    return "%s → %s · %s · %s · confirmer : même compétence" % [
        skill_name,
        _display(target_id),
        _zone_name(zone),
        " · ".join(details),
    ]
