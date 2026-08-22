extends "res://scripts/ui/main_v29.gd"

# v30 : chaque héros agit une fois par round avec 4 compétences équipées.
# Les compétences sont interchangeables uniquement hors combat. Objets, changement
# de position, capture et passage de tour sont des actions séparées du loadout.

var combat_active_hero_id := ""
var combat_acted_hero_ids: Array[String] = []
var combat_round_number := 1
var combat_item_menu := false
var combat_position_menu := false
var selected_loadout_slot := 0

func show_hero_skills() -> void:
    var hero := _selected_skill_hero()
    if hero.is_empty():
        GameState.request_screen("company")
        return
    HeroSkillManager.prepare_hero(hero)
    var title := make_label("%s — COMPÉTENCES · %d POINT(S)" % [hero.name, int(hero.skill_points)], 24, GOLD)
    title.position = Vector2(24, 12)
    content.add_child(title)

    var loadout_label := make_label("4 COMPÉTENCES ÉQUIPÉES — choisissez un emplacement puis une technique", 15, GOLD)
    loadout_label.position = Vector2(24, 48)
    loadout_label.size = Vector2(1000, 28)
    content.add_child(loadout_label)

    var loadout_row := HBoxContainer.new()
    loadout_row.position = Vector2(24, 78)
    loadout_row.size = Vector2(1220, 64)
    loadout_row.add_theme_constant_override("separation", 8)
    content.add_child(loadout_row)
    var loadout := HeroSkillManager.combat_loadout(hero)
    for slot in range(HeroSkillManager.COMBAT_LOADOUT_SIZE):
        var skill := HeroSkillManager.combat_skill(hero, loadout[slot])
        var slot_button := make_button(
            "%d · %s%s" % [slot + 1, str(skill.get("name", "Technique")), "\nÀ REMPLACER" if slot == selected_loadout_slot else ""],
            func(slot_index = slot):
                selected_loadout_slot = int(slot_index)
                show_hero_skills(),
            Vector2(292, 58)
        )
        loadout_row.add_child(slot_button)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(24, 154)
    scroll.size = Vector2(1230, 470)
    content.add_child(scroll)
    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(1190, 0)
    list.add_theme_constant_override("separation", 10)
    scroll.add_child(list)

    list.add_child(make_label("TECHNIQUES DE BASE — toujours connues", 15, MUTED))
    var base_grid := GridContainer.new()
    base_grid.columns = 4
    list.add_child(base_grid)
    for skill_value in HeroSkillManager.BASE_COMBAT_SKILLS:
        var base_skill: Dictionary = skill_value
        base_grid.add_child(make_button(
            "%s\n%s" % [str(base_skill.get("name", "Technique")), str(base_skill.get("description", ""))],
            func(skill_id = str(base_skill.get("id", ""))): _equip_selected_combat_skill(hero, skill_id),
            Vector2(282, 66)
        ))

    var specialization := str(hero.get("specialization", ""))
    for branch in HeroSkillManager.BRANCHES:
        var branch_title := "%s%s" % [branch.to_upper(), " — CHOISI" if specialization == branch else (" — VERROUILLÉ" if specialization != "" and not HeroSkillManager.multi_tree_enabled() else "")]
        list.add_child(make_label(branch_title, 15, GOLD))
        var grid := GridContainer.new()
        grid.columns = 3
        list.add_child(grid)
        for node_value in HeroSkillManager.skill_nodes(hero, branch):
            var node: Dictionary = node_value
            var node_id := str(node.get("id", ""))
            var unlocked := hero.get("unlocked_skills", []).has(node_id)
            var text := "%s\n%s" % [str(node.get("name", "Compétence")), "ACQUISE · ÉQUIPER" if unlocked else str(node.get("description", ""))]
            var button := make_button(
                text,
                func(skill_id = node_id, is_unlocked = unlocked):
                    if bool(is_unlocked):
                        _equip_selected_combat_skill(hero, str(skill_id))
                    else:
                        HeroSkillManager.unlock(hero, str(skill_id))
                        show_hero_skills(),
                Vector2(380, 58)
            )
            if not unlocked:
                button.disabled = not HeroSkillManager.can_unlock(hero, node_id)
            grid.add_child(button)

    var back := make_button("RETOUR", func(): GameState.request_screen("company"), Vector2(180,45))
    back.position = Vector2(24, 640)
    content.add_child(back)

func _selected_skill_hero() -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == selected_hero_id:
            return hero
    return {}

func _equip_selected_combat_skill(hero: Dictionary, skill_id: String) -> void:
    if HeroSkillManager.equip_combat_skill(hero, selected_loadout_slot, skill_id):
        GameState.add_log("%s équipe %s en emplacement %d." % [str(hero.get("name", "Héros")), str(HeroSkillManager.combat_skill(hero, skill_id).get("name", "Technique")), selected_loadout_slot + 1])
    show_hero_skills()

func _render_roguelike_departure() -> void:
    super._render_roguelike_departure()
    var grenades := make_label("Grenades %d" % int(ExpeditionManager.inventory.get("grenades", 0)), 14, GOLD)
    grenades.position = Vector2(735, 224)
    grenades.size = Vector2(240, 24)
    content.add_child(grenades)

func _render_roguelike_side_panel(active_run: Dictionary, risk: Dictionary) -> void:
    super._render_roguelike_side_panel(active_run, risk)
    var grenades := make_label("Grenades : %d" % int(ExpeditionManager.inventory.get("grenades", 0)), 12, GOLD)
    grenades.position = Vector2(1060, 600)
    grenades.size = Vector2(170, 24)
    content.add_child(grenades)

func show_combat() -> void:
    _ensure_combat_state()
    var hero := _active_combat_hero()
    if hero.is_empty():
        finish_defeat()
        return

    var bg := full_texture("res://assets/backgrounds/crypts.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.24)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var status := make_label("ROUND %d · TOUR DE %s · POSITION %d" % [combat_round_number, str(hero.get("name", "Héros")), int(hero.get("combat_position", 0)) + 1], 20, GOLD)
    status.position = Vector2(24, 12)
    status.size = Vector2(610, 32)
    content.add_child(status)

    var log := VBoxContainer.new()
    log.position = Vector2(24, 48)
    log.size = Vector2(560, 108)
    content.add_child(log)
    for line in GameState.log_lines.slice(0, 4):
        log.add_child(make_label("• " + line, 12, MUTED))

    var heroes_row := HBoxContainer.new()
    heroes_row.position = Vector2(35, 160)
    heroes_row.size = Vector2(560, 330)
    heroes_row.add_theme_constant_override("separation", -8)
    content.add_child(heroes_row)
    var ordered_heroes := _heroes_by_position()
    for hero_value in ordered_heroes:
        var displayed: Dictionary = hero_value
        var active := str(displayed.get("id", "")) == combat_active_hero_id
        var card := VBoxContainer.new()
        card.custom_minimum_size = Vector2(140, 320)
        var art := TextureRect.new()
        art.texture = load(hero_art(displayed))
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.custom_minimum_size = Vector2(138, 250)
        art.modulate = Color(1.0, 1.0, 1.0, 1.0 if int(displayed.get("hp", 0)) > 0 else 0.30)
        card.add_child(art)
        card.add_child(make_label("%s%s\nPV %d/%d · P%d" % ["▶ " if active else "", str(displayed.get("name", "Héros")), int(displayed.get("hp", 0)), int(displayed.get("max_hp", 1)), int(displayed.get("combat_position", 0)) + 1], 12, GOLD if active else TEXT))
        heroes_row.add_child(card)

    var enemies_row := HBoxContainer.new()
    enemies_row.position = Vector2(650, 155)
    enemies_row.size = Vector2(600, 340)
    enemies_row.add_theme_constant_override("separation", -5)
    content.add_child(enemies_row)
    for i in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[i]
        var button := Button.new()
        button.flat = true
        button.custom_minimum_size = Vector2(145, 330)
        var column := VBoxContainer.new()
        column.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var enemy_art := TextureRect.new()
        enemy_art.texture = load("res://assets/enemies/%s" % str(enemy.get("art", "enemy_01.webp")))
        enemy_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        enemy_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        enemy_art.custom_minimum_size = Vector2(140, 260)
        enemy_art.modulate = Color(1,1,1,1.0 if int(enemy.get("hp",0)) > 0 else 0.25)
        column.add_child(enemy_art)
        column.add_child(make_label("%s\nPV %d/%d" % [str(enemy.get("name", "Ennemi")), int(enemy.get("hp",0)), int(enemy.get("max_hp",1))], 11, GOLD if i == selected_enemy else TEXT))
        button.add_child(column)
        button.pressed.connect(func(index = i): selected_enemy = int(index); show_screen("combat"))
        enemies_row.add_child(button)

    var loadout_row := HBoxContainer.new()
    loadout_row.position = Vector2(24, 510)
    loadout_row.size = Vector2(1220, 60)
    loadout_row.add_theme_constant_override("separation", 7)
    content.add_child(loadout_row)
    var loadout := HeroSkillManager.combat_loadout(hero)
    for slot in range(HeroSkillManager.COMBAT_LOADOUT_SIZE):
        var skill := HeroSkillManager.combat_skill(hero, loadout[slot])
        var skill_button := make_button("%d · %s" % [slot + 1, str(skill.get("name", "Technique"))], func(slot_index = slot): _use_combat_skill(int(slot_index)), Vector2(292, 54))
        skill_button.tooltip_text = str(skill.get("description", ""))
        loadout_row.add_child(skill_button)

    var extra_row := HBoxContainer.new()
    extra_row.position = Vector2(24, 580)
    extra_row.size = Vector2(1220, 58)
    extra_row.add_theme_constant_override("separation", 8)
    content.add_child(extra_row)
    extra_row.add_child(make_button("OBJETS", func(): combat_item_menu = not combat_item_menu; combat_position_menu = false; show_screen("combat"), Vector2(160,48)))
    extra_row.add_child(make_button("POSITION", func(): combat_position_menu = not combat_position_menu; combat_item_menu = false; show_screen("combat"), Vector2(160,48)))
    extra_row.add_child(make_button("CAPTURER", func(): _combat_capture(), Vector2(160,48)))
    extra_row.add_child(make_button("PASSER", func(): _pass_combat_turn(), Vector2(160,48)))

    if combat_item_menu:
        _render_combat_item_menu()
    elif combat_position_menu:
        _render_combat_position_menu(hero)

func _render_combat_item_menu() -> void:
    var panel := HBoxContainer.new()
    panel.position = Vector2(690, 640)
    panel.size = Vector2(555, 46)
    panel.add_theme_constant_override("separation", 6)
    content.add_child(panel)
    var inv := ExpeditionManager.inventory
    panel.add_child(make_button("BANDAGE ×%d" % int(inv.get("bandages",0)), func(): _use_combat_item("bandages"), Vector2(170,42)))
    panel.add_child(make_button("MÉDECINE ×%d" % int(inv.get("medicine",0)), func(): _use_combat_item("medicine"), Vector2(180,42)))
    panel.add_child(make_button("GRENADE ×%d" % int(inv.get("grenades",0)), func(): _use_combat_item("grenades"), Vector2(180,42)))

func _render_combat_position_menu(hero: Dictionary) -> void:
    var panel := HBoxContainer.new()
    panel.position = Vector2(830, 640)
    panel.size = Vector2(415, 46)
    panel.add_theme_constant_override("separation", 8)
    content.add_child(panel)
    var forward := make_button("AVANCER", func(): _change_combat_position(-1), Vector2(190,42))
    forward.disabled = int(hero.get("combat_position",0)) <= 0
    panel.add_child(forward)
    var backward := make_button("RECULER", func(): _change_combat_position(1), Vector2(190,42))
    backward.disabled = int(hero.get("combat_position",0)) >= 3
    panel.add_child(backward)

func _ensure_combat_state() -> void:
    _ensure_combat_positions()
    if combat_active_hero_id == "" or _active_combat_hero().is_empty():
        combat_acted_hero_ids.clear()
        combat_round_number = maxi(1, round_number)
        _select_next_combat_hero()

func _ensure_combat_positions() -> void:
    var used: Array[int] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var desired := clampi(int(hero.get("combat_position", -1)), 0, 3)
        if desired < 0 or used.has(desired):
            desired = 0
            while used.has(desired) and desired < 3:
                desired += 1
        hero["combat_position"] = desired
        used.append(desired)

func _heroes_by_position() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for hero_value in GameState.party:
        result.append(hero_value)
    result.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("combat_position",0)) < int(right.get("combat_position",0)))
    return result

func _active_combat_hero() -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == combat_active_hero_id and int(hero.get("hp",0)) > 0:
            return hero
    return {}

func _select_next_combat_hero() -> void:
    combat_active_hero_id = ""
    for hero in _heroes_by_position():
        var hero_id := str(hero.get("id", ""))
        if int(hero.get("hp",0)) > 0 and not combat_acted_hero_ids.has(hero_id):
            combat_active_hero_id = hero_id
            break

func _use_combat_skill(slot: int) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty():
        finish_defeat(); return
    var loadout := HeroSkillManager.combat_loadout(hero)
    if slot < 0 or slot >= loadout.size():
        return
    var skill := HeroSkillManager.combat_skill(hero, loadout[slot])
    if skill.is_empty():
        return
    battle_locked = true
    var effect := str(skill.get("effect", "attack"))
    if effect == "attack":
        _resolve_skill_attack(hero, skill)
    elif effect == "guard":
        hero["guarding"] = true
        hero["guard_power"] = int(hero_bonuses(hero).get("guard_power",0)) + int(skill.get("guard_bonus",0))
        hero["hope"] = mini(100 + int(hero_bonuses(hero).get("max_hope",0)), int(hero.get("hope",0)) + int(skill.get("hope_gain",0)))
        GameState.add_log("%s utilise %s et se met en garde." % [hero.name, str(skill.get("name","Garde"))])
    elif effect in ["heal", "support"]:
        _resolve_skill_support(hero, skill)
    _complete_active_hero_turn()

func _resolve_skill_attack(hero: Dictionary, skill: Dictionary) -> void:
    var living := GameState.alive_enemies()
    if living.is_empty():
        finish_victory(); return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp",0)) <= 0:
        target = living[0]
    var cls := DataLoader.find_by_id(DataLoader.classes, hero.get("class_id"))
    var damage_range: Array = cls.get("damage", [6,10])
    var base_damage := randi_range(int(damage_range[0]), int(damage_range[1]))
    var bonuses := hero_bonuses(hero)
    var damage := int(round(float(base_damage + int(bonuses.get("damage_bonus",0))) * float(skill.get("power",1.0)) * (1.0 + float(bonuses.get("damage_percent",0)) / 100.0)))
    if int(target.get("broken",0)) > 0:
        damage = int(round(float(damage) * 1.20))
    var crit_chance := int(bonuses.get("critical_chance",0)) + int(skill.get("critical_bonus",0))
    var critical := crit_chance > 0 and randi_range(1,100) <= crit_chance
    if critical:
        damage = int(round(float(damage) * 1.50))
    target["hp"] = maxi(0, int(target.get("hp",0)) - maxi(1, damage))
    var status := str(skill.get("status", ""))
    var status_chance := int(skill.get("status_chance",0))
    if status != "" and randi_range(1,100) <= status_chance:
        if status == "stun": target["stunned"] = true
        elif status == "break": target["broken"] = 2
        elif status == "bleed": target["bleeding"] = maxi(2, int(skill.get("value",2)) / 2)
    GameState.add_log("%s utilise %s : %d dégâts%s à %s." % [hero.name, str(skill.get("name","Technique")), damage, " critiques" if critical else "", target.name])

func _resolve_skill_support(hero: Dictionary, skill: Dictionary) -> void:
    var target := _most_wounded_hero()
    if target.is_empty():
        target = hero
    var heal := int(skill.get("heal",0))
    if heal > 0:
        heal = int(round(float(heal) * (1.0 + float(hero_bonuses(hero).get("healing_power",0)) / 100.0)))
        target["hp"] = mini(int(target.get("max_hp",1)), int(target.get("hp",0)) + heal)
    target["hope"] = mini(100 + int(hero_bonuses(target).get("max_hope",0)), int(target.get("hope",0)) + int(skill.get("hope_gain",0)))
    target["fear"] = maxi(0, int(target.get("fear",0)) - int(skill.get("fear_reduction",0)))
    GameState.add_log("%s utilise %s sur %s." % [hero.name, str(skill.get("name","Soutien")), target.name])

func _use_combat_item(resource_id: String) -> void:
    if battle_locked or int(ExpeditionManager.inventory.get(resource_id,0)) <= 0:
        return
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var item: Dictionary = item_rules.get(resource_id, {})
    if item.is_empty():
        return
    battle_locked = true
    ExpeditionManager.consume_bundle({resource_id: 1})
    var hero := _active_combat_hero()
    var effect := str(item.get("effect", ""))
    if effect == "heal":
        var target := _most_wounded_hero()
        if target.is_empty(): target = hero
        var amount := int(item.get("heal",0))
        target["hp"] = mini(int(target.get("max_hp",1)), int(target.get("hp",0)) + amount)
        target["fear"] = maxi(0, int(target.get("fear",0)) - int(item.get("fear_reduction",0)))
        GameState.add_log("%s utilise %s sur %s : +%d PV." % [hero.name, str(item.get("label","Objet")), target.name, amount])
    elif effect == "damage_all":
        var damage_range: Array = item.get("damage", [12,18])
        var total := 0
        for enemy_value in GameState.alive_enemies():
            var enemy: Dictionary = enemy_value
            var damage := randi_range(int(damage_range[0]), int(damage_range[1]))
            enemy["hp"] = maxi(0, int(enemy.get("hp",0)) - damage)
            total += damage
        GameState.add_log("%s lance une grenade : %d dégâts cumulés." % [hero.name, total])
    combat_item_menu = false
    _complete_active_hero_turn()

func _change_combat_position(delta: int) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty(): return
    var current := int(hero.get("combat_position",0))
    var target_position := clampi(current + delta, 0, 3)
    if target_position == current: return
    for hero_value in GameState.party:
        var other: Dictionary = hero_value
        if str(other.get("id","")) != str(hero.get("id","")) and int(other.get("combat_position",-1)) == target_position:
            other["combat_position"] = current
            break
    hero["combat_position"] = target_position
    GameState.add_log("%s change de position : rang %d." % [hero.name, target_position + 1])
    combat_position_menu = false
    battle_locked = true
    _complete_active_hero_turn()

func _pass_combat_turn() -> void:
    if battle_locked: return
    var hero := _active_combat_hero()
    if hero.is_empty(): return
    GameState.add_log("%s passe son tour." % hero.name)
    battle_locked = true
    _complete_active_hero_turn()

func _combat_capture() -> void:
    if battle_locked: return
    var living := GameState.alive_enemies()
    if living.is_empty(): finish_victory(); return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp",0)) <= 0: target = living[0]
    if ExpeditionManager.expedition_active:
        var gate := ExpeditionManager.capture_check(target, _current_roguelike_room_id())
        if not bool(gate.get("allowed", false)):
            GameState.add_log(_capture_denial_message(str(gate.get("reason","capture_denied"))))
            show_screen("combat")
            return
    battle_locked = true
    var result := CreatureManager.attempt_capture(target)
    GameState.add_log(str(result.get("message","Le sceau échoue.")))
    if bool(result.get("success",false)) and ExpeditionManager.expedition_active:
        ExpeditionManager.register_roguelike_capture(target, _current_roguelike_room_id())
        CaptureWoundRuntime.apply_to_latest_capture(target)
    if bool(result.get("consumed",false)):
        _complete_active_hero_turn()
    else:
        battle_locked = false
        show_screen("combat")

func _complete_active_hero_turn() -> void:
    if GameState.alive_enemies().is_empty():
        finish_victory(); return
    var hero := _active_combat_hero()
    if not hero.is_empty():
        var hero_id := str(hero.get("id",""))
        if not combat_acted_hero_ids.has(hero_id):
            combat_acted_hero_ids.append(hero_id)
    _select_next_combat_hero()
    if combat_active_hero_id != "":
        battle_locked = false
        show_screen("combat")
        return
    var companion_targets := GameState.alive_enemies()
    if not companion_targets.is_empty():
        var companion_result := CreatureManager.companion_turn(companion_targets[0])
        if not companion_result.is_empty():
            GameState.add_log("%s inflige %d dégâts." % [str(companion_result.get("name","Le compagnon")), int(companion_result.get("damage",0))])
    if GameState.alive_enemies().is_empty():
        finish_victory(); return
    combat_acted_hero_ids.clear()
    combat_round_number += 1
    round_number = combat_round_number
    _select_next_combat_hero()
    combat_item_menu = false
    combat_position_menu = false
    super.enemy_turn()

func _most_wounded_hero() -> Dictionary:
    var candidates := GameState.alive_heroes()
    if candidates.is_empty(): return {}
    var result: Dictionary = candidates[0]
    var best_ratio := float(result.get("hp",0)) / maxf(1.0, float(result.get("max_hp",1)))
    for hero_value in candidates:
        var hero: Dictionary = hero_value
        var ratio := float(hero.get("hp",0)) / maxf(1.0, float(hero.get("max_hp",1)))
        if ratio < best_ratio:
            result = hero; best_ratio = ratio
    return result

func finish_victory() -> void:
    _reset_combat_turn_state()
    super.finish_victory()

func finish_defeat() -> void:
    _reset_combat_turn_state()
    super.finish_defeat()

func _reset_combat_turn_state() -> void:
    combat_active_hero_id = ""
    combat_acted_hero_ids.clear()
    combat_round_number = 1
    round_number = 1
    combat_item_menu = false
    combat_position_menu = false
    battle_locked = false
