extends "res://scripts/ui/main_v46.gd"

const GE01_TACTICAL_SKILLS_SCRIPT := preload("res://scripts/core/veilleurs_ge01_tactical_skill_runtime.gd")
var _ge01_tactical_skills: RefCounted = GE01_TACTICAL_SKILLS_SCRIPT.new()
var ge01_pending_skill_id: String = ""
var ge01_pending_skill_slot: int = -1
var ge01_pending_reposition: Dictionary = {}

func show_combat() -> void:
    super.show_combat()
    if not _ge01_combat_active():
        return
    _decorate_rank_skill_previews()
    _render_reaction_risk_hint()
    if ge01_pending_skill_id == "AÏ-ANA-05":
        _render_expose_zone_menu()
    elif ge01_pending_skill_id == "TA-ENT-05" and not ge01_pending_reposition.is_empty():
        _render_pas_sanglant_reposition()

func _use_combat_skill(slot: int) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if slot < 0 or slot >= loadout.size():
        return
    var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
    var skill_id := str(skill.get("id", ""))
    if _ge01_combat_active() and skill_id == "AÏ-ANA-05":
        ge01_pending_skill_id = skill_id
        ge01_pending_skill_slot = slot
        show_screen("combat")
        return
    if _ge01_combat_active() and skill_id == "TA-ENT-05":
        _execute_pas_sanglant(hero, skill)
        return
    await super._use_combat_skill(slot)

func _render_expose_zone_menu() -> void:
    var panel := PanelContainer.new()
    panel.name = "ExposeArticulationMenuV47"
    panel.position = Vector2(420, 330)
    panel.size = Vector2(820, 170)
    panel.z_index = 65
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.98)))
    content.add_child(panel)
    var box := VBoxContainer.new(); panel.add_child(box)
    box.add_child(make_label("EXPOSER L’ARTICULATION · choisir la zone anatomique", 13, GOLD))
    box.add_child(make_label("Conséquence : zone exposée 2 rounds · +12 précision et +10 % dégâts pour les attaques qui visent cette zone.", 11, CANON_TEXT))
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 4); box.add_child(row)
    for entry in [["BRAS G.", "left_arm"], ["BRAS D.", "right_arm"], ["JAMBE G.", "left_leg"], ["JAMBE D.", "right_leg"]]:
        row.add_child(make_button(str(entry[0]), func(zone = str(entry[1])): _execute_expose_articulation(zone), Vector2(145, 48)))
    row.add_child(make_button("ANNULER", func(): _clear_ge01_pending_skill(); show_screen("combat"), Vector2(130, 48)))

func _execute_expose_articulation(zone: String) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    var target := _selected_living_enemy()
    if hero.is_empty() or target.is_empty():
        _clear_ge01_pending_skill()
        return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if ge01_pending_skill_slot < 0 or ge01_pending_skill_slot >= loadout.size():
        _clear_ge01_pending_skill()
        return
    var skill := HeroSkillManager.combat_skill(hero, str(loadout[ge01_pending_skill_slot]))
    battle_locked = true
    _resolve_skill_attack(hero, skill)
    if int(target.get("hp", 0)) > 0:
        var result: Dictionary = _ge01_tactical_skills.call("expose_articulation", target, zone)
        GameState.add_log("Aïsha expose %s sur %s : 2 rounds d'ouverture anatomique." % [str(result.get("zone", zone)).replace("_", " "), str(target.get("name", "la cible"))])
    _clear_ge01_pending_skill()
    _complete_active_hero_turn()

func _execute_pas_sanglant(hero: Dictionary, skill: Dictionary) -> void:
    var target := _selected_living_enemy()
    if target.is_empty():
        return
    var was_wounded := int(target.get("hp", 0)) < int(target.get("max_hp", target.get("hp", 0))) or not (target.get("persistent_injuries", []) as Array).is_empty() or not (target.get("anatomy_injuries", []) as Array).is_empty()
    battle_locked = true
    _resolve_skill_attack(hero, skill)
    if int(target.get("hp", 0)) <= 0 or not was_wounded:
        if not was_wounded:
            GameState.add_log("Pas sanglant : pas de repositionnement, la cible n'était pas déjà blessée.")
        _complete_active_hero_turn()
        return
    var options: Dictionary = _ge01_tactical_skills.call("pas_sanglant_options", hero, target, GameState.alive_heroes())
    var destinations: Array = options.get("destinations", [])
    if destinations.is_empty():
        GameState.add_log("Pas sanglant : %s" % str(options.get("summary", "aucun rang libre")))
        _complete_active_hero_turn()
        return
    ge01_pending_skill_id = "TA-ENT-05"
    ge01_pending_reposition = {"hero_id": str(hero.get("id", "")), "destinations": destinations.duplicate()}
    battle_locked = false
    show_screen("combat")

func _render_pas_sanglant_reposition() -> void:
    var panel := PanelContainer.new()
    panel.name = "PasSanglantRepositionV47"
    panel.position = Vector2(510, 385)
    panel.size = Vector2(700, 120)
    panel.z_index = 65
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.98)))
    content.add_child(panel)
    var box := VBoxContainer.new(); panel.add_child(box)
    box.add_child(make_label("PAS SANGLANT · la cible était déjà blessée : choisissez le repositionnement", 12, GOLD))
    var row := HBoxContainer.new(); box.add_child(row)
    for destination_value: Variant in ge01_pending_reposition.get("destinations", []):
        var destination := int(destination_value)
        row.add_child(make_button("R%d\nREPOSITIONNER" % (destination + 1), func(slot = destination): _finish_pas_sanglant(int(slot)), Vector2(170, 48)))
    row.add_child(make_button("RESTER", func(): _finish_pas_sanglant(-1), Vector2(140, 48)))

func _finish_pas_sanglant(destination: int) -> void:
    var hero := _active_combat_hero()
    if hero.is_empty():
        _clear_ge01_pending_skill(); return
    if destination >= 0:
        var result: Dictionary = _ge01_tactical_skills.call("pas_sanglant_move", hero, destination, GameState.alive_heroes())
        if bool(result.get("ok", false)):
            GameState.add_log("Pas sanglant : %s se repositionne R%d → R%d après l'entaille." % [str(hero.get("name", "Tarek")), int(result.get("from", 0)) + 1, int(result.get("to", 0)) + 1])
    _clear_ge01_pending_skill()
    battle_locked = true
    _complete_active_hero_turn()

func _decorate_rank_skill_previews() -> void:
    var hero := _active_combat_hero()
    if hero.is_empty(): return
    var loadout := HeroSkillManager.combat_loadout(hero)
    var buttons := content.find_children("*", "Button", true, false)
    for slot in range(mini(HeroSkillManager.COMBAT_LOADOUT_SIZE, loadout.size())):
        var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
        var id := str(skill.get("id", ""))
        if id not in ["AÏ-ANA-05", "TA-ENT-05"]: continue
        var prefix := "%d · " % (slot + 1)
        for node_value: Variant in buttons:
            var button := node_value as Button
            if button == null or not button.text.begins_with(prefix): continue
            if id == "AÏ-ANA-05": button.tooltip_text += "\nTACTIQUE · Choisir une articulation avant l'attaque. La zone reste exposée 2 rounds."
            else: button.tooltip_text += "\nTACTIQUE · Si la cible était déjà blessée, choisir un rang adjacent après l'attaque."
            break

func _render_reaction_risk_hint() -> void:
    var hero_reactions: Array[String] = []
    for hero_value: Variant in GameState.party:
        if not hero_value is Dictionary: continue
        var hero: Dictionary = hero_value
        var unlocked: Array = hero.get("unlocked_skills", [])
        if unlocked.has("TA-ENT-13"): hero_reactions.append("Tarek · Fauchage réflexe")
        if unlocked.has("AÏ-ANA-13"): hero_reactions.append("Aïsha · Réflexe musculaire")
    if hero_reactions.is_empty(): return
    var hint := make_label("RÉACTIONS AU MOUVEMENT : %s · un changement de rang ennemi peut les déclencher." % " / ".join(hero_reactions), 11, CANON_GOLD)
    hint.position = Vector2(610, 125)
    hint.size = Vector2(630, 28)
    content.add_child(hint)

func _clear_ge01_pending_skill() -> void:
    ge01_pending_skill_id = ""
    ge01_pending_skill_slot = -1
    ge01_pending_reposition.clear()
