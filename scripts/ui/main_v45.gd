extends "res://scripts/ui/main_v44.gd"

# v45 — rend les interactions de cadavres visibles et tactiles dans GE09.
# Le joueur voit la cause et la conséquence avant validation : corps, rang,
# couverture/blocage et projection dans la ligne ennemie.

const CORPSE_SKILL_SCRIPT := preload("res://scripts/core/veilleurs_corpse_skill_runtime.gd")
var _corpse_skills: RefCounted = CORPSE_SKILL_SCRIPT.new()
var corpse_action_menu: String = ""
var corpse_selected_id: String = ""

func show_combat() -> void:
    super.show_combat()
    if _ge01_combat_active() and _ge01_room_id() == "ge_09":
        _render_corpse_tactical_entry()
        if corpse_action_menu != "":
            _render_corpse_action_menu()

func _render_corpse_tactical_entry() -> void:
    var corpse_ids: Array = _ge01_corpse_ids()
    if corpse_ids.is_empty():
        return
    var button := make_button("☠ CADAVRES · %d" % corpse_ids.size(), func(): corpse_action_menu = "choose"; show_screen("combat"), Vector2(190, 48))
    button.name = "CorpseTacticsEntryV45"
    button.position = Vector2(1038, 350)
    button.tooltip_text = "Utiliser les corps du champ de bataille : déplacer, barricader ou projeter. L'effet sera affiché avant validation."
    content.add_child(button)

func _render_corpse_action_menu() -> void:
    var panel := PanelContainer.new()
    panel.name = "CorpseTacticsMenuV45"
    panel.position = Vector2(420, 365)
    panel.size = Vector2(820, 150)
    panel.z_index = 55
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.98)))
    content.add_child(panel)
    var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 5); panel.add_child(box)
    box.add_child(make_label("CADAVRES · choisissez une conséquence tactique visible", 12, GOLD))
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 5); box.add_child(row)
    row.add_child(make_button("DÉPLACER", func(): corpse_action_menu = "push"; show_screen("combat"), Vector2(150, 46)))
    row.add_child(make_button("BARRICADE", func(): corpse_action_menu = "barricade"; show_screen("combat"), Vector2(150, 46)))
    row.add_child(make_button("PROJETER", func(): corpse_action_menu = "project"; show_screen("combat"), Vector2(150, 46)))
    row.add_child(make_button("FERMER", func(): _clear_corpse_action(); show_screen("combat"), Vector2(130, 46)))
    if corpse_action_menu in ["push", "barricade", "project"]:
        _render_corpse_choices(box)

func _render_corpse_choices(box: VBoxContainer) -> void:
    var corpse_ids: Array = _ge01_corpse_ids()
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 5); box.add_child(row)
    for index in range(corpse_ids.size()):
        var scar_id := str(corpse_ids[index])
        var scar: Dictionary = RemanenceRuntime.world_scars.get(scar_id, {})
        var payload: Dictionary = scar.get("payload", {})
        var slot := int(payload.get("combat_slot", index)) + 1
        var label := "CORPS %d · R%d" % [index + 1, slot]
        row.add_child(make_button(label, func(id = scar_id): corpse_selected_id = str(id); corpse_action_menu += "_rank"; show_screen("combat"), Vector2(150, 42)))
    if corpse_action_menu.ends_with("_rank") and corpse_selected_id != "":
        _render_corpse_rank_choices(box)

func _render_corpse_rank_choices(box: VBoxContainer) -> void:
    var action: String = corpse_action_menu.trim_suffix("_rank")
    var explanation: String = str({
        "push": "DÉPLACER · le corps change de rang sans bloquer la ligne.",
        "barricade": "BARRICADE · le rang sera BLOQUÉ et donnera 40 % de couverture.",
        "project": "PROJETER · le corps bloque une ligne ennemie et peut repousser son occupant."
    }.get(action, ""))
    box.add_child(make_label(explanation, 11, CANON_TEXT))
    var ranks := HBoxContainer.new(); ranks.add_theme_constant_override("separation", 4); box.add_child(ranks)
    for rank in range(4):
        var side: String = "enemy" if action == "project" else "hero"
        var prefix: String = "E" if side == "enemy" else "R"
        var consequence: String = "bloque + couverture" if action == "barricade" else ("bloque + déplacement ennemi" if action == "project" else "déplace le corps")
        var button := make_button("%s%d\n%s" % [prefix, rank + 1, consequence], func(target = rank, a = action): _execute_corpse_action(str(a), int(target)), Vector2(170, 48))
        button.tooltip_text = "%s%d : %s" % [prefix, rank + 1, consequence]
        ranks.add_child(button)

func _execute_corpse_action(action: String, rank: int) -> void:
    if corpse_selected_id == "" or battle_locked:
        return
    var result: Dictionary = {}
    if action == "push":
        result = _corpse_skills.call("push", corpse_selected_id, rank, "hero")
    elif action == "barricade":
        result = _corpse_skills.call("barricade", corpse_selected_id, rank, "hero", 40)
    elif action == "project":
        var target := _selected_living_enemy()
        if target.is_empty():
            GameState.add_log("Projection impossible : aucune cible ennemie vivante.")
            return
        result = _corpse_skills.call("project", corpse_selected_id, target, GameState.battle_enemies, rank)
    if not bool(result.get("ok", false)):
        GameState.add_log("Interaction avec le cadavre impossible : %s." % str(result.get("reason", "terrain incompatible")))
        return
    if action == "push": GameState.add_log("Le corps est déplacé vers R%d. La ligne reste praticable." % (rank + 1))
    elif action == "barricade": GameState.add_log("Le corps barricade R%d : ligne bloquée · couverture 40 %% ." % (rank + 1))
    else: GameState.add_log("Le corps est projeté vers E%d : ligne ennemie bloquée%s." % [rank + 1, " · cible repoussée" if bool(result.get("displaced", false)) else ""])
    _clear_corpse_action()
    battle_locked = true
    _complete_active_hero_turn()

func _clear_corpse_action() -> void:
    corpse_action_menu = ""
    corpse_selected_id = ""

func _ge01_room_id() -> String:
    var runtime := get_node_or_null("/root/GE01Runtime")
    return str(runtime.call("current_room")) if runtime != null and runtime.has_method("current_room") else ""
