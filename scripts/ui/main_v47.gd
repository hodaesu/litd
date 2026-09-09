extends "res://scripts/ui/main_v46.gd"

# v47 — Combat Sandbox 0.1 interactif.
# Rend la boucle runtime manipulable depuis l'interface sans promouvoir les
# actions prototypes au rang de compétences canoniques.

const SANDBOX_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_combat_sandbox_runtime.gd")

var _sandbox: RefCounted = SANDBOX_RUNTIME_SCRIPT.new()
var _sandbox_started := false
var _sandbox_selected_action := ""
var _sandbox_selected_target := -1
var _sandbox_selected_zone := "torso"
var _sandbox_last_result: Dictionary = {}
var _sandbox_inspect_side := ""
var _sandbox_inspect_index := -1

func show_screen(name: String) -> void:
    if name == "combat_sandbox":
        GameState.current_screen = name
        clear_content()
        _show_combat_sandbox()
        _install_header_controls()
        call_deferred("_postprocess_mobile_screen")
        return
    super.show_screen(name)

func _show_navigation() -> void:
    super._show_navigation()
    var launch := make_button("COMBAT SANDBOX 0.1\nTester la boucle anatomie + IA", func(): GameState.request_screen("combat_sandbox"), Vector2(360, 54))
    launch.name = "CombatSandboxLaunchV47"
    launch.position = Vector2(860, 574)
    launch.tooltip_text = "Prototype jouable isolé — aucune action temporaire n'est canonisée."
    content.add_child(launch)

func _ensure_sandbox_started() -> void:
    if _sandbox_started:
        return
    var result: Dictionary = _sandbox.call("setup")
    _sandbox_started = bool(result.get("ok", false))
    _sandbox_selected_action = ""
    _sandbox_selected_target = -1
    _sandbox_selected_zone = "torso"
    _sandbox_last_result = result

func _show_combat_sandbox() -> void:
    _ensure_sandbox_started()
    _canonical_backdrop("COMBAT SANDBOX 0.1", "Prototype interactif · 2 PA · R1→R4 de droite à gauche · actions temporaires jusqu'à export des fiches canoniques.")
    if not _sandbox_started:
        var fail := make_label("Impossible d'initialiser le sandbox.", 18, CANON_TEXT)
        fail.position = Vector2(60, 130)
        content.add_child(fail)
        return

    _render_sandbox_status()
    _render_sandbox_actions()
    _render_sandbox_targets()
    _render_sandbox_zones()
    _render_sandbox_controls()
    _render_sandbox_result()
    if _sandbox_inspect_side != "" and _sandbox_inspect_index >= 0:
        _render_sandbox_inspection()

func _render_sandbox_status() -> void:
    var active: Dictionary = _sandbox.call("active_hero")
    var heroes: Array = _sandbox.get("heroes")
    var enemies: Array = _sandbox.get("enemies")
    var round_number := int(_sandbox.get("round"))

    var top := HBoxContainer.new()
    top.position = Vector2(52, 112)
    top.size = Vector2(1170, 70)
    top.add_theme_constant_override("separation", 10)
    content.add_child(top)
    for hero_value: Variant in heroes:
        if not hero_value is Dictionary:
            continue
        var hero: Dictionary = hero_value
        var current := str(hero.get("id", "")) == str(active.get("id", ""))
        var label := "%s%s\nPV %d/%d · %d PA" % ["◆ " if current else "", str(hero.get("name", "Veilleur")), int(hero.get("hp", 0)), int(hero.get("max_hp", 0)), int(hero.get("ap", 0))]
        var index := heroes.find(hero_value)
        var button := make_button(label, func(i = index): _sandbox_open_inspection("hero", int(i)), Vector2(270, 62))
        button.tooltip_text = "Examiner · 0 PA"
        top.add_child(button)

    var enemy_row := HBoxContainer.new()
    enemy_row.position = Vector2(52, 194)
    enemy_row.size = Vector2(1170, 72)
    enemy_row.add_theme_constant_override("separation", 12)
    content.add_child(enemy_row)
    for enemy_index in range(enemies.size()):
        var enemy: Dictionary = enemies[enemy_index]
        var selected := enemy_index == _sandbox_selected_target
        var label := "%s%s\n%s" % ["◆ " if selected else "", str(enemy.get("name", "Ennemi")), _sandbox_vital_label(enemy)]
        var button := make_button(label, func(i = enemy_index): _sandbox_select_target(int(i)), Vector2(300, 62))
        button.disabled = int(enemy.get("hp", 0)) <= 0
        button.tooltip_text = "Sélectionner comme cible · appui long non requis"
        enemy_row.add_child(button)
        var inspect := make_button("EXAMINER", func(i = enemy_index): _sandbox_open_inspection("enemy", int(i)), Vector2(120, 62))
        inspect.disabled = int(enemy.get("hp", 0)) <= 0
        inspect.tooltip_text = "Connaissances disponibles uniquement · 0 PA"
        enemy_row.add_child(inspect)

    var round_label := make_label("ROUND %d · %s actif" % [round_number, str(active.get("name", "Veilleur"))], 13, CANON_GOLD)
    round_label.position = Vector2(960, 82)
    round_label.size = Vector2(260, 28)
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(round_label)

func _render_sandbox_actions() -> void:
    var active: Dictionary = _sandbox.call("active_hero")
    var actions: Array = _sandbox.call("available_actions")
    var box := VBoxContainer.new()
    box.position = Vector2(52, 286)
    box.size = Vector2(390, 210)
    box.add_theme_constant_override("separation", 6)
    content.add_child(box)
    box.add_child(make_label("ACTIONS · %s" % str(active.get("name", "Veilleur")), 14, CANON_GOLD))
    box.add_child(make_label("PROTOTYPE — ces noms ne sont pas canoniques", 10, CANON_MUTED))
    for action_value: Variant in actions:
        if not action_value is Dictionary:
            continue
        var action: Dictionary = action_value
        var action_id := str(action.get("id", ""))
        var selected := action_id == _sandbox_selected_action
        var label := "%s%s · %d PA" % ["◆ " if selected else "", str(action.get("name", action_id)), int(action.get("ap", 1))]
        var button := make_button(label, func(id = action_id): _sandbox_select_action(str(id)), Vector2(370, 44))
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.tooltip_text = str(action.get("description", "Action prototype"))
        box.add_child(button)

func _render_sandbox_targets() -> void:
    var label := make_label("CIBLE · touchez un ennemi ci-dessus", 12, CANON_TEXT)
    label.position = Vector2(470, 286)
    label.size = Vector2(350, 30)
    content.add_child(label)

func _render_sandbox_zones() -> void:
    var box := VBoxContainer.new()
    box.position = Vector2(470, 322)
    box.size = Vector2(420, 180)
    box.add_theme_constant_override("separation", 5)
    content.add_child(box)
    box.add_child(make_label("ZONE ANATOMIQUE", 13, CANON_GOLD))
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 5)
    grid.add_theme_constant_override("v_separation", 5)
    box.add_child(grid)
    for zone in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
        var selected := str(zone) == _sandbox_selected_zone
        var button := make_button(("◆ " if selected else "") + _zone_label_context(str(zone)), func(z = zone): _sandbox_select_zone(str(z)), Vector2(190, 42))
        grid.add_child(button)

func _render_sandbox_controls() -> void:
    var box := VBoxContainer.new()
    box.position = Vector2(920, 286)
    box.size = Vector2(300, 220)
    box.add_theme_constant_override("separation", 8)
    content.add_child(box)
    box.add_child(make_label("DÉCISION", 13, CANON_GOLD))
    var execute := make_button("EXÉCUTER", func(): _sandbox_execute(), Vector2(280, 52))
    execute.disabled = _sandbox_selected_action == "" or _sandbox_selected_target < 0
    box.add_child(execute)
    box.add_child(make_button("FIN DU TOUR", func(): _sandbox_end_turn(), Vector2(280, 48)))
    box.add_child(make_button("RÉINITIALISER", func(): _sandbox_reset(), Vector2(280, 44)))
    box.add_child(make_button("RETOUR", func(): GameState.request_screen("navigation"), Vector2(280, 44)))

func _render_sandbox_result() -> void:
    var panel := PanelContainer.new()
    panel.position = Vector2(52, 522)
    panel.size = Vector2(1168, 108)
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.92)))
    content.add_child(panel)
    var text := "Choisissez une action, une cible et une zone."
    if not _sandbox_last_result.is_empty():
        text = _sandbox_result_text(_sandbox_last_result)
    var label := make_label(text, 12, CANON_TEXT)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(label)

func _sandbox_select_action(action_id: String) -> void:
    _sandbox_selected_action = action_id
    show_screen("combat_sandbox")

func _sandbox_select_target(index: int) -> void:
    _sandbox_selected_target = index
    show_screen("combat_sandbox")

func _sandbox_select_zone(zone: String) -> void:
    _sandbox_selected_zone = zone
    show_screen("combat_sandbox")

func _sandbox_execute() -> void:
    if _sandbox_selected_action == "" or _sandbox_selected_target < 0:
        return
    _sandbox_last_result = _sandbox.call("perform_action", _sandbox_selected_action, _sandbox_selected_target, _sandbox_selected_zone)
    if int(_sandbox_last_result.get("remaining_ap", 1)) <= 0:
        _sandbox.call("end_active_turn")
        _sandbox_selected_action = ""
        _sandbox_selected_target = -1
    show_screen("combat_sandbox")

func _sandbox_end_turn() -> void:
    _sandbox_last_result = _sandbox.call("end_active_turn")
    _sandbox_selected_action = ""
    _sandbox_selected_target = -1
    show_screen("combat_sandbox")

func _sandbox_reset() -> void:
    _sandbox_started = false
    _sandbox_inspect_side = ""
    _sandbox_inspect_index = -1
    _ensure_sandbox_started()
    show_screen("combat_sandbox")

func _sandbox_open_inspection(side: String, index: int) -> void:
    _sandbox_inspect_side = side
    _sandbox_inspect_index = index
    show_screen("combat_sandbox")

func _sandbox_close_inspection() -> void:
    _sandbox_inspect_side = ""
    _sandbox_inspect_index = -1
    show_screen("combat_sandbox")

func _render_sandbox_inspection() -> void:
    var details: Dictionary = _sandbox.call("inspect_actor", _sandbox_inspect_side, _sandbox_inspect_index)
    if not bool(details.get("ok", false)):
        return
    var panel := PanelContainer.new()
    panel.position = Vector2(300, 125)
    panel.size = Vector2(680, 390)
    panel.z_index = 120
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.01, 0.011, 0.016, 0.99)))
    content.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    panel.add_child(box)
    box.add_child(make_label("%s · EXAMEN · 0 PA" % str(details.get("name", "Combattant")), 20, CANON_GOLD))
    box.add_child(make_label("État %s · douleur %s · saignement %s · psyché %s" % [_fr_state(str(details.get("vital_state", "unknown"))), _fr_state(str(details.get("pain_state", "unknown"))), _fr_state(str(details.get("bleeding_state", "unknown"))), _fr_state(str(details.get("psych_state", "unknown")))], 12, CANON_TEXT))
    box.add_child(make_label("CORPS", 12, CANON_GOLD))
    var lines: Array[String] = []
    for zone_value: Variant in details.get("anatomy", []):
        if not zone_value is Dictionary:
            continue
        var zone: Dictionary = zone_value
        lines.append("%s · %s · armure %s · fonction %s" % [_zone_label_context(str(zone.get("id", ""))), _fr_state(str(zone.get("state", "unknown"))), _fr_state(str(zone.get("armor", "unknown"))), _fr_state(str(zone.get("function", "unknown")))])
    var anatomy := make_label("\n".join(lines), 11, CANON_MUTED)
    anatomy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(anatomy)
    box.add_child(make_button("FERMER", func(): _sandbox_close_inspection(), Vector2(150, 48)))

func _sandbox_result_text(result: Dictionary) -> String:
    if not bool(result.get("ok", false)):
        return "Action impossible · %s" % str(result.get("reason", "raison inconnue"))
    if result.has("hit") and not bool(result.get("hit", false)):
        return "ÉCHEC · zone %s · jet %d / précision %d." % [_zone_label_context(str(result.get("zone", "torso"))), int(result.get("roll", 0)), int(result.get("accuracy", 0))]
    if bool(result.get("hit", false)):
        var reaction: Dictionary = result.get("ai_reaction", {})
        return "IMPACT · %s · %d dégâts · lésion %d · fonction %s. IA : %s → %s (%s)." % [_zone_label_context(str(result.get("zone", "torso"))), int(result.get("damage", 0)), int(result.get("severity", 0)), _fr_state(str(result.get("functional_loss", "functional"))), str(reaction.get("hypothesis", "aucune hypothèse")), str(reaction.get("decision", "aucune décision")), str(reaction.get("confidence", "faible"))]
    if str(result.get("kind", "")) == "observe":
        return "OBSERVATION · de nouvelles informations sont maintenant consultables sur la cible."
    if str(result.get("kind", "")) == "stabilize":
        return "STABILISATION · douleur/saignement de la cible réévalués."
    return "Action résolue · %s" % str(result.get("kind", "ok"))

func _sandbox_vital_label(actor: Dictionary) -> String:
    var hp := int(actor.get("hp", 0))
    var max_hp := maxi(1, int(actor.get("max_hp", 1)))
    if hp <= 0:
        return "HORS COMBAT"
    var ratio := float(hp) / float(max_hp)
    if ratio <= 0.25:
        return "Critique"
    if ratio <= 0.6:
        return "Blessé"
    return "Stable"
