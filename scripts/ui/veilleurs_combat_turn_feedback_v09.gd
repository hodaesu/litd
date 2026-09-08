extends Node
class_name VeilleursCombatTurnFeedbackV09

const FEEDBACK_MS := 4400
const BASE_FEEDBACK_SIZE := Vector2(640, 168)
const SAFE_GUTTER := 12.0
const META_BASE_FONT := "litd_combat_feedback_base_font"
const STATUS_LABELS := {
    "STAGGER":"déséquilibré",
    "PINNED":"entravé",
    "IMMOBILIZED":"immobilisé",
    "EXPOSED":"exposé",
    "FEAR":"apeuré",
    "DISORIENTED":"désorienté",
    "DOUBT":"doute",
    "GUARDED":"protégé",
    "STABILIZED":"stabilisé",
    "OBSERVED":"observé",
    "ADAPTED":"adapté",
    "BLEEDING":"saignement",
    "BURNING":"brûlure",
    "BROKEN":"rupture",
    "STUNNED":"étourdi"
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
    if not GameSettings.settings_changed.is_connected(_on_settings_changed):
        GameSettings.settings_changed.connect(_on_settings_changed)
    if not get_viewport().size_changed.is_connected(_apply_layout):
        get_viewport().size_changed.connect(_apply_layout)
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
    _apply_layout()
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
    feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(feedback_panel)

    feedback_label = Label.new()
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    feedback_label.set_meta(META_BASE_FONT, 15)
    feedback_panel.add_child(feedback_label)
    feedback_panel.visible = false

func _on_settings_changed() -> void:
    call_deferred("_apply_layout")

func _apply_layout() -> void:
    if feedback_panel == null or feedback_label == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var insets := _logical_safe_insets(viewport_size)
    var safe_origin := Vector2(insets.x + SAFE_GUTTER, insets.y + SAFE_GUTTER)
    var safe_size := Vector2(
        maxf(1.0, viewport_size.x - insets.x - insets.z - SAFE_GUTTER * 2.0),
        maxf(1.0, viewport_size.y - insets.y - insets.w - SAFE_GUTTER * 2.0)
    )
    var ui_scale := clampf(GameSettings.ui_scale, 0.8, 1.4)
    var desired := BASE_FEEDBACK_SIZE * ui_scale
    var panel_size := Vector2(
        minf(desired.x, safe_size.x),
        minf(desired.y, safe_size.y * 0.38)
    )
    feedback_panel.custom_minimum_size = panel_size
    feedback_panel.size = panel_size
    feedback_panel.position = safe_origin + Vector2(
        maxf(0.0, (safe_size.x - panel_size.x) * 0.5),
        minf(maxf(44.0, 58.0 * ui_scale), maxf(0.0, safe_size.y - panel_size.y))
    )
    var base_font := int(feedback_label.get_meta(META_BASE_FONT, 15))
    feedback_label.add_theme_font_size_override("font_size", maxi(11, int(round(float(base_font) * GameSettings.text_scale))))
    set_meta("litd_safe_area_insets", insets)
    set_meta("litd_ui_scale", ui_scale)
    set_meta("litd_text_scale", GameSettings.text_scale)

func _logical_safe_insets(reference_size: Vector2) -> Vector4:
    if not OS.has_feature("mobile"):
        return Vector4.ZERO
    var screen_size_i := DisplayServer.screen_get_size()
    var screen_position_i := DisplayServer.screen_get_position()
    var safe_i := DisplayServer.get_display_safe_area()
    if screen_size_i.x <= 0 or screen_size_i.y <= 0 or safe_i.size.x <= 0 or safe_i.size.y <= 0:
        return Vector4.ZERO

    var screen_size := Vector2(screen_size_i)
    var safe_position := Vector2(safe_i.position - screen_position_i)
    var safe_size := Vector2(safe_i.size)
    var content_scale := minf(screen_size.x / reference_size.x, screen_size.y / reference_size.y)
    if content_scale <= 0.0:
        return Vector4.ZERO
    var content_size := reference_size * content_scale
    var content_origin := (screen_size - content_size) * 0.5
    var content_end := content_origin + content_size
    var safe_end := safe_position + safe_size
    var clipped_left := maxf(content_origin.x, safe_position.x)
    var clipped_top := maxf(content_origin.y, safe_position.y)
    var clipped_right := minf(content_end.x, safe_end.x)
    var clipped_bottom := minf(content_end.y, safe_end.y)
    if clipped_right <= clipped_left or clipped_bottom <= clipped_top:
        return Vector4.ZERO
    return Vector4(
        maxf(0.0, (clipped_left - content_origin.x) / content_scale),
        maxf(0.0, (clipped_top - content_origin.y) / content_scale),
        maxf(0.0, (content_end.x - clipped_right) / content_scale),
        maxf(0.0, (content_end.y - clipped_bottom) / content_scale)
    )

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
    var enemy_summary := _enemy_response_summary(runtime, fresh, player_index + 1)
    if enemy_summary != "":
        text += "\n" + enemy_summary
    _show_feedback(text)

func _format_player_event(runtime: Variant, event: Dictionary) -> String:
    var attacker_id := str(event.get("attacker", ""))
    var target_id := str(event.get("target", ""))
    var attacker := _display(runtime, attacker_id)
    var target := _display(runtime, target_id)
    var skill_name := _skill_name(runtime, str(event.get("skill_id", "")))
    var fallback_zone := qa.selected_zone if qa != null else "torso"
    var zone := _zone_label(str(event.get("zone", fallback_zone)))

    if event.has("hit") and not bool(event.get("hit", false)):
        return "RATÉ — %s · %s → %s · %s | chance %d%%" % [skill_name, attacker, target, zone, int(event.get("hit_chance", 0))]

    if event.has("damage"):
        var text := "TOUCHÉ — %s · %s → %s · %s | -%d PV · reste %d" % [
            skill_name, attacker, target, zone, int(event.get("damage", 0)), int(event.get("target_hp", 0))
        ]
        var body: Dictionary = event.get("body", {})
        if not body.is_empty() and bool(body.get("ok", false)):
            text += " · traumatisme %d · %s" % [int(body.get("trauma", 0)), _body_state_label(str(body.get("state", "")))]
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

    if bool(event.get("attack_deferred", false)):
        return "APPROCHE — %s · %s se rapproche de %s ; l'attaque reste à porter." % [skill_name, attacker, target]
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

func _enemy_response_summary(runtime: Variant, fresh: Array, start_index: int) -> String:
    var lines: Array[String] = []
    for index in range(maxi(0, start_index), fresh.size()):
        if not (fresh[index] is Dictionary):
            continue
        var event: Dictionary = fresh[index]
        var enemy_id := str(event.get("attacker", event.get("enemy", event.get("boss", ""))))
        if not (enemy_id.begins_with("ENT_ENEMY_") or enemy_id.begins_with("ENT_BOSS_")):
            continue
        var line := _format_enemy_event(runtime, event, enemy_id)
        if line != "":
            lines.append(line)
    if lines.is_empty():
        return ""
    var visible_count := mini(lines.size(), 4)
    var text := "RIPOSTE ENNEMIE"
    for index in range(visible_count):
        text += "\n" + lines[index]
    if lines.size() > visible_count:
        text += "\n+%d autre%s action%s" % [
            lines.size() - visible_count,
            "" if lines.size() - visible_count == 1 else "s",
            "" if lines.size() - visible_count == 1 else "s"
        ]
    return text

func _format_enemy_event(runtime: Variant, event: Dictionary, enemy_id: String) -> String:
    var enemy := _display(runtime, enemy_id)
    var target_id := str(event.get("target", ""))
    var target := _display(runtime, target_id)
    var action := str(event.get("action", ""))

    if bool(event.get("generated_ultimate", false)) and bool(event.get("prepared", false)):
        return "↳ %s prépare son ultime." % enemy
    if action in ["move", "flee"]:
        return "↳ %s se repositionne." % enemy
    if action == "hold":
        return "↳ %s temporise." % enemy
    if action in ["boss_phase", "boss_mechanic", "boss_rule"]:
        return "↳ %s modifie le champ de bataille." % enemy

    var arrow := "%s → %s" % [enemy, target] if target != "" else enemy
    if event.has("hit") and not bool(event.get("hit", false)):
        return "↳ %s : RATÉ" % arrow

    var details: Array[String] = []
    var zone := str(event.get("zone", ""))
    if zone != "":
        details.append(_zone_label(zone))
    if int(event.get("damage", 0)) > 0:
        details.append("-%d PV" % int(event.get("damage", 0)))
    if int(event.get("resolve_delta", 0)) < 0:
        details.append("-%d résolution" % absi(int(event.get("resolve_delta", 0))))
    var status := str(event.get("status_applied", ""))
    if status != "":
        details.append(_status_label(status))
    var body: Dictionary = event.get("body", {})
    if not body.is_empty() and bool(body.get("ok", false)):
        var state := str(body.get("state", ""))
        if state in ["L3", "L4", "L5"]:
            details.append(_body_state_label(state))
        if bool(body.get("severed", false)):
            details.append("MEMBRE TRANCHÉ")
        elif bool(body.get("dead", false)):
            details.append("LÉSION VITALE")
    if details.is_empty():
        var skill_name := _skill_name(runtime, str(event.get("skill_id", "")))
        return "↳ %s : %s" % [arrow, skill_name]
    return "↳ %s · %s" % [arrow, " · ".join(details)]

func _show_feedback(text: String) -> void:
    if feedback_panel == null or feedback_label == null:
        return
    feedback_label.text = text
    feedback_panel.visible = true
    feedback_until_ms = Time.get_ticks_msec() + FEEDBACK_MS
    call_deferred("_apply_layout")

func _display(runtime: Variant, entity_id: String) -> String:
    if entity_id == "":
        return ""
    if runtime == null:
        return entity_id.replace("ENT_WATCHER_", "").replace("ENT_ENEMY_", "").replace("ENT_BOSS_", "").replace("_", " ").capitalize()
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
    var key := status.to_upper()
    return str(STATUS_LABELS.get(key, status.replace("_", " ").capitalize()))

func _body_state_label(state: String) -> String:
    return {
        "L0":"intact",
        "L1":"atteint",
        "L2":"blessé",
        "L3":"critique",
        "L4":"hors d'usage",
        "L5":"détruit"
    }.get(state, state)
