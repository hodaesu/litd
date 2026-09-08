extends Node
class_name VeilleursCombatTurnFeedbackV09

const FEEDBACK_MS := 3200
const STATUS_LABELS := {
    "STAGGER":"déséquilibré",
    "PINNED":"entravé",
    "EXPOSED":"exposé",
    "FEAR":"apeuré",
    "DISORIENTED":"désorienté",
    "DOUBT":"doute",
    "GUARDED":"protégé",
    "STABILIZED":"stabilisé",
    "OBSERVED":"observé",
    "ADAPTED":"adapté"
}

var qa: VeilleursVerticalSliceQAV09
var feedback_layer: CanvasLayer
var feedback_panel: PanelContainer
var feedback_label: Label
var tracked_runtime: Variant = null
var seen_log_size := 0
var feedback_until_ms := 0
var installed := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _process(_delta: float) -> void:
    if not installed or qa == null:
        return

    var runtime: Variant = null
    if qa.slice != null and qa.slice.combat != null:
        runtime = qa.slice.combat

    if runtime != null:
        if tracked_runtime != runtime:
            tracked_runtime = runtime
            seen_log_size = runtime.action_log.size()
        _update_turn_header(runtime)
        _consume_new_actions(runtime)
    elif tracked_runtime != null:
        _consume_new_actions(tracked_runtime)
        tracked_runtime = null
        seen_log_size = 0

    if feedback_panel != null and feedback_panel.visible and Time.get_ticks_msec() > feedback_until_ms:
        feedback_panel.visible = false

func _install() -> void:
    qa = _root_qa()
    if qa == null:
        call_deferred("_install")
        return
    _build_feedback()
    installed = true

func _root_qa() -> VeilleursVerticalSliceQAV09:
    var node: Node = get_parent()
    while node != null:
        if node is VeilleursVerticalSliceQAV09:
            return node as VeilleursVerticalSliceQAV09
        node = node.get_parent()
    return null

func _build_feedback() -> void:
    feedback_layer = CanvasLayer.new()
    feedback_layer.layer = 119
    feedback_layer.name = "CombatTurnFeedbackLayer"
    add_child(feedback_layer)

    var shell := Control.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_layer.add_child(shell)

    feedback_panel = PanelContainer.new()
    feedback_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    feedback_panel.offset_left = -300
    feedback_panel.offset_top = 72
    feedback_panel.offset_right = 300
    feedback_panel.offset_bottom = 158
    feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(feedback_panel)

    feedback_label = Label.new()
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    feedback_label.add_theme_font_size_override("font_size", 15)
    feedback_panel.add_child(feedback_label)
    feedback_panel.visible = false

func _update_turn_header(runtime: Variant) -> void:
    if qa.status_label == null:
        return
    var attacker := _display(runtime, qa.selected_watcher)
    var target := _display(runtime, qa.selected_target) if qa.selected_target != "" else "aucune"
    var zone := _zone_label(qa.selected_zone)
    var phase_text := _boss_phase_text(runtime)

    if qa.tactical_ui != null and qa.tactical_ui.target_selection_mode:
        if qa.tactical_ui.target_choice_confirmed and qa.selected_target != "":
            qa.status_label.text = "CONFIRMATION — ▶ %s → ◎ %s | zone : %s | retouchez la compétence%s" % [attacker, target, zone, phase_text]
        else:
            qa.status_label.text = "CIBLAGE — ▶ %s | choisissez un ennemi ○ | zone : %s%s" % [attacker, zone, phase_text]
        return

    qa.status_label.text = "À VOUS — round %d | ▶ %s | cible actuelle : %s | zone : %s | choisissez une compétence%s" % [
        int(runtime.round_index), attacker, target, zone, phase_text
    ]

func _boss_phase_text(runtime: Variant) -> String:
    if not runtime.has_method("boss_phase_snapshot"):
        return ""
    var phase: Dictionary = runtime.call("boss_phase_snapshot")
    if str(phase.get("boss_id", "")) == "":
        return ""
    var text := " | Boss : phase %d" % int(phase.get("phase", 1))
    var pending := int(phase.get("pending_phase", 0))
    if pending > 0:
        text += " → phase %d annoncée" % pending
    return text

func _consume_new_actions(runtime: Variant) -> void:
    var log: Array = runtime.action_log
    if log.size() < seen_log_size:
        seen_log_size = 0
    if log.size() <= seen_log_size:
        return

    var fresh: Array = log.slice(seen_log_size, log.size())
    seen_log_size = log.size()
    var player_index := -1
    var player_event: Dictionary = {}

    for index in range(fresh.size()):
        if not (fresh[index] is Dictionary):
            continue
        var event: Dictionary = fresh[index]
        var attacker_id := str(event.get("attacker", ""))
        if attacker_id.begins_with("ENT_WATCHER_") and bool(event.get("ok", false)):
            player_event = event
            player_index = index

    if player_event.is_empty():
        return

    var text := _format_player_event(runtime, player_event)
    var enemy_summary := _enemy_response_summary(fresh, player_index + 1)
    if enemy_summary != "":
        text += "\n" + enemy_summary
    _show_feedback(text)

func _format_player_event(runtime: Variant, event: Dictionary) -> String:
    var attacker_id := str(event.get("attacker", ""))
    var target_id := str(event.get("target", ""))
    var attacker := _display(runtime, attacker_id)
    var target := _display(runtime, target_id)
    var skill_name := _skill_name(runtime, str(event.get("skill_id", "")))
    var zone := _zone_label(str(event.get("zone", qa.selected_zone)))

    if event.has("hit") and not bool(event.get("hit", false)):
        return "RATÉ — %s · %s → %s · %s | réussite %d%%" % [skill_name, attacker, target, zone, int(event.get("hit_chance", 0))]

    if event.has("damage"):
        var text := "TOUCHÉ — %s · %s → %s · %s | -%d PV · reste %d" % [
            skill_name, attacker, target, zone, int(event.get("damage", 0)), int(event.get("target_hp", 0))
        ]
        var body: Dictionary = event.get("body", {})
        if not body.is_empty() and bool(body.get("ok", false)):
            text += " · trauma %d · %s" % [int(body.get("trauma", 0)), _body_state_label(str(body.get("state", "")))]
            if bool(body.get("severed", false)):
                text += " · MEMBRE TRANCHÉ"
            elif bool(body.get("dead", false)):
                text += " · LÉSION VITALE"
        if str(event.get("status_applied", "")) != "":
            text += " · %s" % _status_label(str(event.get("status_applied", "")))
        var redirected: Dictionary = event.get("protection_redirect", {})
        if bool(redirected.get("redirected", false)):
            text += " · %d absorbés par %s" % [int(redirected.get("amount", 0)), _display(runtime, str(redirected.get("protector", "")))]
        return text

    if event.has("healed"):
        return "SOIN — %s · %s récupère +%d PV" % [skill_name, target, int(event.get("healed", 0))]
    if event.has("guard_delta") and event.has("resolve_restored"):
        return "SOUTIEN — %s · %s : +%d garde · +%d résolution" % [skill_name, target, int(event.get("guard_delta", 0)), int(event.get("resolve_restored", 0))]
    if event.has("guard_delta"):
        return "GARDE — %s · %s : +%d garde" % [skill_name, attacker, int(event.get("guard_delta", 0))]
    if int(event.get("resolve_delta", 0)) < 0:
        var pressure := absi(int(event.get("resolve_delta", 0)))
        var status := _status_label(str(event.get("status_applied", "")))
        return "PRESSION — %s · %s perd %d résolution%s" % [skill_name, target, pressure, (" · " + status) if status != "" else ""]
    if str(event.get("status_applied", "")) != "":
        return "EFFET — %s · %s : %s" % [skill_name, target, _status_label(str(event.get("status_applied", "")))]
    if event.has("knowledge_reveal"):
        return "OBSERVATION — %s · %s analysé · niveau %d" % [skill_name, target, int(event.get("knowledge_reveal", 0))]
    if event.has("moved"):
        return "DÉPLACEMENT — %s · %s se repositionne" % [skill_name, attacker]
    if event.has("passive_effect"):
        return "POSTURE — %s activée par %s" % [skill_name, attacker]
    return "%s utilise %s sur %s." % [attacker, skill_name, target]

func _enemy_response_summary(fresh: Array, start_index: int) -> String:
    var actions := 0
    var hits := 0
    var damage := 0
    var resolve_loss := 0
    for index in range(maxi(0, start_index), fresh.size()):
        if not (fresh[index] is Dictionary):
            continue
        var event: Dictionary = fresh[index]
        var enemy_id := str(event.get("attacker", event.get("enemy", "")))
        if not (enemy_id.begins_with("ENT_ENEMY_") or enemy_id.begins_with("ENT_BOSS_")):
            continue
        actions += 1
        var target_id := str(event.get("target", ""))
        if target_id.begins_with("ENT_WATCHER_") and bool(event.get("hit", false)):
            hits += 1
            damage += int(event.get("damage", 0))
            resolve_loss += maxi(0, -int(event.get("resolve_delta", 0)))
    if actions <= 0:
        return ""
    var text := "Riposte ennemie : %d action(s) · %d touche(s)" % [actions, hits]
    if damage > 0:
        text += " · %d dégâts" % damage
    if resolve_loss > 0:
        text += " · %d résolution perdue" % resolve_loss
    return text

func _show_feedback(text: String) -> void:
    if feedback_panel == null or feedback_label == null:
        return
    feedback_label.text = text
    feedback_panel.visible = true
    feedback_until_ms = Time.get_ticks_msec() + FEEDBACK_MS

func _display(runtime: Variant, entity_id: String) -> String:
    if entity_id == "" or runtime == null:
        return ""
    var row: Dictionary = runtime.combatants.get(entity_id, {})
    return str(row.get("name", entity_id))

func _skill_name(runtime: Variant, skill_id: String) -> String:
    if skill_id == "" or runtime == null or runtime.content_db == null:
        return skill_id if skill_id != "" else "Action"
    var skill: Dictionary = runtime.content_db.skill(skill_id)
    return str(skill.get("name_fr", skill_id))

func _zone_label(zone: String) -> String:
    return {
        "head":"Tête",
        "torso":"Torse",
        "left_arm":"Bras gauche",
        "right_arm":"Bras droit",
        "left_leg":"Jambe gauche",
        "right_leg":"Jambe droite"
    }.get(zone, zone)

func _status_label(status: String) -> String:
    if status == "":
        return ""
    return str(STATUS_LABELS.get(status, status.replace("_", " ").capitalize()))

func _body_state_label(state: String) -> String:
    return {
        "L0":"intact",
        "L1":"atteint",
        "L2":"blessé",
        "L3":"critique",
        "L4":"hors d'usage",
        "L5":"détruit"
    }.get(state, state)
