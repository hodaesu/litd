extends "res://scripts/ui/main_v49.gd"

# v50 — ressenti de combat mobile.
# Réduit les taps sans masquer les décisions :
# - action self : exécution immédiate au choix de l'action ;
# - action enemy sans zone : action + cible = exécution ;
# - action enemy_zone : action + cible + zone = exécution ;
# - action ally : action + allié = exécution.
# Les conséquences et changements de tour sont montrés par des bandeaux temporaires,
# pas par un nouveau HUD permanent.

var _sandbox_feedback_text := ""
var _sandbox_turn_banner_text := ""

func _show_combat_sandbox() -> void:
    super._show_combat_sandbox()
    if not _sandbox_started:
        return
    _render_sandbox_flow_hint_v50()
    _render_sandbox_feedback_v50()
    _render_sandbox_turn_banner_v50()

func _sandbox_select_action(action_id: String) -> void:
    _sandbox_selected_action = action_id
    _sandbox_feedback_text = ""
    var action := _sandbox_selected_action_data()
    if action.is_empty():
        show_screen("combat_sandbox")
        return
    var target_type := str(action.get("target", "enemy"))
    if target_type == "self":
        _sandbox_execute_v50()
        return
    show_screen("combat_sandbox")

func _sandbox_select_target(index: int) -> void:
    _sandbox_selected_target = index
    var action := _sandbox_selected_action_data()
    if action.is_empty():
        show_screen("combat_sandbox")
        return
    var target_type := str(action.get("target", "enemy"))
    if target_type == "enemy":
        _sandbox_execute_v50()
        return
    # enemy_zone garde la décision anatomique : le prochain tap sur une zone exécute.
    show_screen("combat_sandbox")

func _sandbox_select_zone(zone: String) -> void:
    _sandbox_selected_zone = zone
    var action := _sandbox_selected_action_data()
    if not action.is_empty() and str(action.get("target", "enemy")) == "enemy_zone" and _sandbox_selected_target >= 0:
        _sandbox_execute_v50()
        return
    show_screen("combat_sandbox")

func _sandbox_select_ally_or_inspect(index: int) -> void:
    var action := _sandbox_selected_action_data()
    if not action.is_empty() and str(action.get("target", "")) == "ally":
        _sandbox_selected_ally = index
        _sandbox_execute_v50()
        return
    super._sandbox_select_ally_or_inspect(index)

func _sandbox_execute() -> void:
    _sandbox_execute_v50()

func _sandbox_execute_v50() -> void:
    if not _sandbox_action_ready():
        return
    var before: Dictionary = _sandbox.call("active_hero").duplicate(true)
    var before_id := str(before.get("id", ""))
    var before_name := str(before.get("name", "Veilleur"))
    super._sandbox_execute()

    _sandbox_feedback_text = _feedback_from_result_v50(_sandbox_last_result)
    var after: Dictionary = _sandbox.call("active_hero")
    var after_id := str(after.get("id", ""))
    if after_id != before_id:
        _sandbox_turn_banner_text = "%s termine · %s agit" % [before_name, str(after.get("name", "Veilleur"))]
    else:
        _sandbox_turn_banner_text = ""
    show_screen("combat_sandbox")

func _render_sandbox_flow_hint_v50() -> void:
    var action := _sandbox_selected_action_data()
    var text := "Choisissez une compétence"
    if not action.is_empty():
        var target_type := str(action.get("target", "enemy"))
        if target_type == "enemy_zone":
            text = "Touchez un ennemi" if _sandbox_selected_target < 0 else "Touchez directement la zone anatomique"
        elif target_type == "enemy":
            text = "Touchez un ennemi pour exécuter"
        elif target_type == "ally":
            text = "Touchez un allié pour exécuter"
        elif target_type == "self":
            text = "Action personnelle"
    var label := make_label(text, 11, CANON_GOLD)
    label.name = "SandboxFlowHintV50"
    label.position = Vector2(470, 258)
    label.size = Vector2(430, 26)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(label)

func _render_sandbox_feedback_v50() -> void:
    if _sandbox_feedback_text.is_empty():
        return
    var panel := PanelContainer.new()
    panel.name = "SandboxImpactFeedbackV50"
    panel.position = Vector2(300, 438)
    panel.size = Vector2(680, 48)
    panel.z_index = 80
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.02, 0.02, 0.026, 0.97)))
    content.add_child(panel)
    var label := make_label(_sandbox_feedback_text, 13, CANON_TEXT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    panel.add_child(label)

func _render_sandbox_turn_banner_v50() -> void:
    if _sandbox_turn_banner_text.is_empty():
        return
    var banner := make_label(_sandbox_turn_banner_text, 14, CANON_GOLD)
    banner.name = "SandboxTurnBannerV50"
    banner.position = Vector2(390, 82)
    banner.size = Vector2(500, 28)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(banner)

func _feedback_from_result_v50(result: Dictionary) -> String:
    if not bool(result.get("ok", false)):
        return "Impossible · %s" % str(result.get("reason", "action refusée"))
    if result.has("hit"):
        if not bool(result.get("hit", false)):
            return "Raté · %s" % _zone_label_context(str(result.get("zone", "torso")))
        var parts: Array[String] = []
        parts.append("%s touché" % _zone_label_context(str(result.get("zone", "torso"))))
        var severity := int(result.get("severity", 0))
        if severity >= 3:
            parts.append("lésion sévère")
        elif severity >= 2:
            parts.append("lésion importante")
        else:
            parts.append("lésion légère")
        var function := str(result.get("functional_loss", "functional"))
        if function == "impaired":
            parts.append("fonction diminuée")
        return " · ".join(parts)
    match str(result.get("kind", "")):
        "stabilize": return "Saignement et douleur réévalués"
        "anatomical_care": return "Fonction stabilisée · blessure conservée"
        "control": return "Contrôle appliqué"
        "persistent_control": return "Contrôle appliqué · %d tour(s)" % int(result.get("rounds", 0))
        "synergy": return "Synergie déclenchée"
        "ultimate": return "Signature déclenchée · %d charge(s) restante(s)" % int(result.get("charges_remaining", 0))
        "formation": return "Formation ajustée"
        "reaction_ready": return "Réaction préparée"
        "posture": return "Posture active"
    return "Action résolue"
