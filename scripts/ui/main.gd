extends Control

var root: Control
var content: Control
var selected_enemy := 0
var battle_locked := false

const GOLD := Color("#d5b26c")
const PANEL := Color(0.025, 0.027, 0.035, 0.94)
const DARK := Color("#07080b")
const RED := Color("#7f1e24")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")

func _ready() -> void:
    GameState.screen_requested.connect(show_screen)
    GameState.state_changed.connect(refresh_header)
    build_shell()
    show_screen("title")

func build_shell() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var bg := ColorRect.new()
    bg.color = DARK
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)

    var header := HBoxContainer.new()
    header.name = "Header"
    header.set_anchors_preset(Control.PRESET_TOP_WIDE)
    header.offset_bottom = 64
    header.add_theme_constant_override("separation", 18)
    root.add_child(header)

    var title := Label.new()
    title.text = "LIGHT IN THE DARK"
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    for name in ["Gold", "Essence", "Lumière", "Vivres"]:
        var l := Label.new()
        l.name = name
        l.add_theme_color_override("font_color", TEXT)
        l.add_theme_font_size_override("font_size", 17)
        header.add_child(l)

    content = Control.new()
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.offset_top = 64
    root.add_child(content)
    refresh_header()

func refresh_header() -> void:
    if not is_instance_valid(root):
        return
    var header = root.get_node_or_null("Header")
    if header:
        header.get_node("Gold").text = "◉ %d" % GameState.gold
        header.get_node("Essence").text = "◆ %d" % GameState.essence
        header.get_node("Lumière").text = "✦ %d" % GameState.light
        header.get_node("Vivres").text = "▣ %d" % GameState.supplies

func clear_content() -> void:
    for child in content.get_children():
        child.queue_free()

func panel_style(color := PANEL) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.border_color = Color(0.45, 0.34, 0.20, 0.8)
    s.set_border_width_all(1)
    s.corner_radius_top_left = 4
    s.corner_radius_top_right = 4
    s.corner_radius_bottom_left = 4
    s.corner_radius_bottom_right = 4
    s.content_margin_left = 14
    s.content_margin_right = 14
    s.content_margin_top = 10
    s.content_margin_bottom = 10
    return s

func make_button(text: String, callback: Callable, min_size := Vector2(190, 52)) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_stylebox_override("normal", panel_style())
    b.add_theme_stylebox_override("hover", panel_style(Color(0.12, 0.09, 0.06, 0.98)))
    b.pressed.connect(callback)
    return b

func make_label(text: String, size := 18, color := TEXT) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func full_texture(path: String) -> TextureRect:
    var t := TextureRect.new()
    t.texture = load(path)
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    return t

func show_screen(name: String) -> void:
    GameState.current_screen = name
    clear_content()
    match name:
        "title": show_title()
        "sanctuary": show_sanctuary()
        "company": show_company()
        "creatures": show_creatures()
        "market": show_market()
        "expedition": show_expedition()
        "combat": show_combat()
        "rewards": show_rewards()
        _: show_title()

func show_title() -> void:
    var bg := full_texture("res://assets/backgrounds/sanctuary.png")
    bg.modulate = Color(0.55,0.55,0.60,1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0,0,0,0.52)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)
    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.position = Vector2(-220,-180)
    box.size = Vector2(440,360)
    box.add_theme_constant_override("separation", 15)
    content.add_child(box)
    var title := make_label("LIGHT IN THE DARK", 42, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var sub := make_label("Le Sanctuaire du Premier Voile", 20, MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(sub)
    box.add_child(make_button("NOUVELLE PARTIE", func():
        GameState.reset_new_game()
        GameState.request_screen("sanctuary"), Vector2(440,58)))
    box.add_child(make_button("CONTINUER", func():
        if SaveManager.load_game():
            GameState.request_screen("sanctuary"), Vector2(440,58)))
    box.add_child(make_button("QUITTER", func(): get_tree().quit(), Vector2(440,58)))

func show_sanctuary() -> void:
    var bg := full_texture("res://assets/backgrounds/sanctuary.png")
    content.add_child(bg)
    var top := make_label("SANCTUAIRE DU PREMIER VOILE", 25, GOLD)
    top.position = Vector2(24,18)
    content.add_child(top)
    var buttons := [
        ["GUILDE\nCompagnie et talents", "company", Vector2(240,110)],
        ["CHAPELLE\nPeur, folie et espoir", "chapel", Vector2(520,105)],
        ["INFIRMERIE\nSoins et blessures", "infirmary", Vector2(790,135)],
        ["TAVERNE\nRecruter et rumeurs", "tavern", Vector2(980,180)],
        ["MARCHÉ NOIR\nÉquipement", "market", Vector2(185,360)],
        ["LA PORTE\nPartir en expédition", "expedition", Vector2(555,350)],
        ["BESTIAIRE\nCréatures liées", "creatures", Vector2(910,360)],
        ["MÉMORIAL\nHéros tombés", "memorial", Vector2(250,535)],
    ]
    for item in buttons:
        var action = item[1]
        var b := make_button(item[0], func(a=action):
            if a == "company":
                GameState.request_screen("company")
            elif a == "expedition":
                GameState.request_screen("expedition")
            elif a == "market":
                GameState.request_screen("market")
            elif a == "creatures":
                GameState.request_screen("creatures")
            else:
                GameState.add_log("%s : cette fonction est préparée pour la phase suivante." % a)
        , Vector2(230,70))
        b.position = item[2]
        b.modulate = Color(1,1,1,0.92)
        content.add_child(b)
    var save := make_button("SAUVEGARDER", func(): SaveManager.save_game(), Vector2(170,46))
    save.position = Vector2(1080,20)
    content.add_child(save)

func hero_art(hero: Dictionary) -> String:
    var c := DataLoader.find_by_id(DataLoader.classes, hero.get("class_id"))
    return "res://assets/heroes/%s" % c.get("art","inquisitor.webp")

func show_company() -> void:
    var bg := full_texture("res://assets/backgrounds/forgotten_city.webp")
    bg.modulate = Color(0.45,0.45,0.48,1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0,0,0,0.42)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)
    var row := HBoxContainer.new()
    row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    row.offset_left = 24
    row.offset_right = -24
    row.offset_top = 16
    row.offset_bottom = -70
    row.add_theme_constant_override("separation", 10)
    content.add_child(row)
    for hero in GameState.party:
        var card := VBoxContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var art := TextureRect.new()
        art.texture = load(hero_art(hero))
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.custom_minimum_size = Vector2(0,430)
        card.add_child(art)
        card.add_child(make_label("%s · Niveau %d" % [hero.name, hero.level], 18, GOLD))
        var cls = DataLoader.find_by_id(DataLoader.classes, hero.class_id)
        card.add_child(make_label("%s — %s" % [cls.name, cls.role], 13, MUTED))
        card.add_child(make_label("PV %d/%d   Peur %d   Folie %d" % [hero.hp,hero.max_hp,hero.fear,hero.madness], 13))
        row.add_child(card)
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(280,48))
    back.position = Vector2(24,630)
    content.add_child(back)

func show_creatures() -> void:
    var bg := full_texture("res://assets/backgrounds/forgotten_city.webp")
    bg.modulate = Color(0.35, 0.35, 0.40, 1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)
    var title := make_label("BESTIAIRE — CRÉATURES LIÉES", 28, GOLD)
    title.position = Vector2(32, 18)
    content.add_child(title)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(32, 64)
    scroll.size = Vector2(1216, 548)
    content.add_child(scroll)
    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(1180, 0)
    list.add_theme_constant_override("separation", 14)
    scroll.add_child(list)
    if CreatureManager.captured_creatures.is_empty():
        list.add_child(make_label(
            "Aucune créature liée. Affaiblissez une Goule affamée, un Oni ou une Jorōgumo, puis utilisez CAPTURER. Les boss ne peuvent jamais être capturés.",
            18, MUTED
        ))
    for creature_value in CreatureManager.captured_creatures:
        var creature: Dictionary = creature_value
        var instance_id: String = str(creature.get("instance_id", ""))
        var active: bool = instance_id == CreatureManager.active_instance_id
        var specialization: String = str(creature.get("specialization", ""))
        var header := HBoxContainer.new()
        var status: String = " — ACTIVE" if active else ""
        var info := make_label(
            "%s%s · niveau %d · XP %d/%d · %d point(s)" % [
                str(creature.get("evolution_name", creature.get("name", "Créature"))),
                status,
                int(creature.get("level", 1)),
                int(creature.get("xp", 0)),
                CreatureManager.xp_to_next_level(int(creature.get("level", 1))),
                int(creature.get("skill_points", 0))
            ],
            18, GOLD if active else TEXT
        )
        info.custom_minimum_size = Vector2(890, 44)
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        header.add_child(info)
        var active_button := make_button(
            "ACTIVE" if active else "ACTIVER",
            func(id_value = instance_id):
                CreatureManager.set_active(str(id_value))
                show_creatures(),
            Vector2(170, 42)
        )
        active_button.disabled = active
        header.add_child(active_button)
        list.add_child(header)
        for branch_value in ["offense", "defense", "special"]:
            var branch: String = str(branch_value)
            var branch_row := VBoxContainer.new()
            branch_row.add_theme_constant_override("separation", 6)
            var branch_name: String = str({
                "offense": "OFFENSIF", "defense": "DÉFENSIF", "special": "SPÉCIAL"
            }.get(branch, branch.to_upper()))
            if specialization == branch:
                branch_name += " — CHOISI"
            elif specialization != "":
                branch_name += " — VERROUILLÉ"
            var branch_label := make_label(branch_name, 14, MUTED)
            branch_label.custom_minimum_size = Vector2(105, 28)
            branch_row.add_child(branch_label)
            var skill_grid := GridContainer.new()
            skill_grid.columns = 3
            skill_grid.add_theme_constant_override("h_separation", 8)
            skill_grid.add_theme_constant_override("v_separation", 8)
            branch_row.add_child(skill_grid)
            for node_value in CreatureManager.skill_nodes(creature, branch):
                var node: Dictionary = node_value
                var node_id: String = str(node.get("id", ""))
                var unlocked: bool = creature.get("unlocked_skills", []).has(node_id)
                var node_text: String = "%s\n%s" % [
                    str(node.get("name", "Talent")),
                    "ACQUIS" if unlocked else str(node.get("description", ""))
                ]
                var node_button := make_button(
                    node_text,
                    func(creature_id = instance_id, skill_id = node_id):
                        _unlock_creature_skill(str(creature_id), str(skill_id)),
                    Vector2(350, 58)
                )
                node_button.disabled = unlocked or not CreatureManager.can_unlock(instance_id, node_id)
                skill_grid.add_child(node_button)
            list.add_child(branch_row)
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(280, 48))
    back.position = Vector2(32, 625)
    content.add_child(back)

func _unlock_creature_skill(instance_id: String, skill_id: String) -> void:
    if CreatureManager.unlock_skill(instance_id, skill_id):
        GameState.add_log("Un nouveau talent de créature est débloqué.")
    show_creatures()

func show_market() -> void:
    var bg := full_texture("res://assets/backgrounds/forgotten_city.webp")
    bg.modulate = Color(0.38, 0.38, 0.42, 1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.68)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)
    var title := make_label("MARCHÉ NOIR — INVENTAIRE D’ÉQUIPEMENT", 28, GOLD)
    title.position = Vector2(32, 18)
    content.add_child(title)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(32, 66)
    scroll.size = Vector2(1216, 548)
    content.add_child(scroll)
    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(1180, 0)
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)
    if EquipmentManager.items.is_empty():
        list.add_child(make_label("Aucun équipement trouvé. Les quatre salles du niveau test accordent chacune le lot d’un héros.", 18, MUTED))
    for item in EquipmentManager.items:
        var row := HBoxContainer.new()
        var hero_level: int = EquipmentManager.level_for_class(str(item.get("class_id", "")))
        var description := make_label(EquipmentManager.describe_item(item, hero_level), 15)
        description.custom_minimum_size = Vector2(930, 48)
        description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(description)
        var instance_id: String = str(item.get("instance_id", ""))
        row.add_child(make_button("ÉQUIPER", func(id_value = instance_id): _equip_matching_hero(str(id_value)), Vector2(180, 44)))
        list.add_child(row)
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(280, 48))
    back.position = Vector2(32, 625)
    content.add_child(back)

func _equip_matching_hero(instance_id: String) -> void:
    var item: Dictionary = EquipmentManager.get_instance(instance_id)
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("class_id", "")) == str(item.get("class_id", "")):
            if EquipmentManager.equip(str(hero.get("id", "")), instance_id):
                GameState.add_log("%s équipe %s." % [str(hero.get("name", "Héros")), str(item.get("name", "objet"))])
            break
    show_market()

func show_expedition() -> void:
    var bg := full_texture("res://assets/backgrounds/crypts.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0,0,0,0.5)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)
    var box := VBoxContainer.new()
    box.position = Vector2(90,70)
    box.size = Vector2(520,540)
    box.add_theme_constant_override("separation", 12)
    content.add_child(box)
    box.add_child(make_label("LES CRYPTES DU PREMIER VOILE", 30, GOLD))
    box.add_child(make_label("Expédition courte — 4 salles", 19, MUTED))
    box.add_child(make_label("Compagnie : %d héros\nVivres : %d\nLumière : %d\nDanger : ◆◆◆◇◇" % [GameState.party.size(),GameState.supplies,GameState.light], 18))
    box.add_child(make_label("Objectif : traverser les salles, survivre au combat et rapporter une relique.", 16))
    box.add_child(make_button("LANCER L'EXPÉDITION", func():
        GameState.expedition_room = 1
        start_random_battle()
    , Vector2(480,60)))
    box.add_child(make_button("RETOUR", func(): GameState.request_screen("sanctuary"), Vector2(480,52)))

func start_random_battle() -> void:
    GameState.battle_enemies = []
    var ids := [1,8,10]
    if GameState.expedition_room >= GameState.expedition_rooms:
        ids = [38]
    for enemy_id in ids:
        var e := DataLoader.find_by_id(DataLoader.enemies, enemy_id).duplicate(true)
        e["max_hp"] = e.hp
        e["guarding"] = false
        GameState.battle_enemies.append(e)
    battle_locked = false
    selected_enemy = 0
    GameState.add_log("Le combat commence.")
    GameState.request_screen("combat")

func show_combat() -> void:
    var bg := full_texture("res://assets/backgrounds/crypts.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0,0,0,0.18)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var heroes_row := HBoxContainer.new()
    heroes_row.position = Vector2(50,160)
    heroes_row.size = Vector2(550,400)
    heroes_row.add_theme_constant_override("separation", -12)
    content.add_child(heroes_row)
    for i in range(GameState.party.size()):
        var h = GameState.party[i]
        var card := VBoxContainer.new()
        card.custom_minimum_size = Vector2(135,390)
        var art := TextureRect.new()
        art.texture = load(hero_art(h))
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.custom_minimum_size = Vector2(135,320)
        art.modulate = Color(1,1,1, 1.0 if h.hp > 0 else 0.35)
        card.add_child(art)
        card.add_child(make_label("%s\nPV %d/%d" % [h.name,h.hp,h.max_hp], 13, GOLD))
        heroes_row.add_child(card)

    var enemies_row := HBoxContainer.new()
    enemies_row.position = Vector2(675,170)
    enemies_row.size = Vector2(500,390)
    enemies_row.add_theme_constant_override("separation", -5)
    content.add_child(enemies_row)
    for i in range(GameState.battle_enemies.size()):
        var e = GameState.battle_enemies[i]
        var b := Button.new()
        b.flat = true
        b.custom_minimum_size = Vector2(155,380)
        var v := VBoxContainer.new()
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var art := TextureRect.new()
        art.texture = load("res://assets/enemies/%s" % e.art)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.custom_minimum_size = Vector2(150,310)
        art.modulate = Color(1,1,1,1.0 if e.hp > 0 else 0.25)
        v.add_child(art)
        v.add_child(make_label("%s\nPV %d/%d" % [e.name,e.hp,e.max_hp], 12, GOLD if i == selected_enemy else TEXT))
        b.add_child(v)
        b.pressed.connect(func(index=i):
            selected_enemy = index
            show_screen("combat")
        )
        enemies_row.add_child(b)

    var action_panel := HBoxContainer.new()
    action_panel.position = Vector2(310,575)
    action_panel.size = Vector2(700,70)
    action_panel.add_theme_constant_override("separation", 10)
    content.add_child(action_panel)
    action_panel.add_child(make_button("FRAPPE", func(): hero_action("strike"), Vector2(150,55)))
    action_panel.add_child(make_button("COUP LOURD", func(): hero_action("heavy"), Vector2(170,55)))
    action_panel.add_child(make_button("SOIN", func(): hero_action("heal"), Vector2(140,55)))
    action_panel.add_child(make_button("GARDE", func(): hero_action("guard"), Vector2(140,55)))
    action_panel.add_child(make_button("CAPTURER", func(): hero_action("capture"), Vector2(150,55)))

    var log := VBoxContainer.new()
    log.position = Vector2(20,15)
    log.size = Vector2(500,130)
    content.add_child(log)
    log.add_child(make_label("TOUR DE COMBAT", 22, GOLD))
    var companion: Dictionary = CreatureManager.active_creature()
    if not companion.is_empty():
        log.add_child(make_label(
            "Compagnon : %s · niv. %d" % [
                str(companion.get("evolution_name", companion.get("name", "Créature"))),
                int(companion.get("level", 1))
            ],
            13, GOLD
        ))
    for line in GameState.log_lines.slice(0,4):
        log.add_child(make_label("• "+line, 13, MUTED))

func hero_action(action: String) -> void:
    if battle_locked:
        return
    battle_locked = true
    var hero: Dictionary = GameState.alive_heroes()[0] if not GameState.alive_heroes().is_empty() else {}
    if hero.is_empty():
        finish_defeat()
        return
    if action == "capture":
        var living_targets: Array = GameState.alive_enemies()
        if living_targets.is_empty():
            finish_victory()
            return
        selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
        var capture_target: Dictionary = GameState.battle_enemies[selected_enemy]
        if int(capture_target.get("hp", 0)) <= 0:
            capture_target = living_targets[0]
        var capture_result: Dictionary = CreatureManager.attempt_capture(capture_target)
        GameState.add_log(str(capture_result.get("message", "Le sceau échoue.")))
        if bool(capture_result.get("success", false)) and GameState.alive_enemies().is_empty():
            finish_victory()
            return
        if bool(capture_result.get("consumed", false)):
            enemy_turn()
        else:
            battle_locked = false
            show_screen("combat")
        return
    elif action == "heal":
        var target: Dictionary = GameState.party[mini(2, GameState.party.size() - 1)]
        var bonuses: Dictionary = EquipmentManager.bonuses_for_hero(str(hero.get("id", "")))
        var amount: int = int(round(18.0 * (1.0 + float(bonuses.get("healing_power", 0)) / 100.0)))
        target.hp = min(target.max_hp, target.hp + amount)
        var target_bonuses: Dictionary = EquipmentManager.bonuses_for_hero(str(target.get("id", "")))
        target.hope = mini(100 + int(target_bonuses.get("max_hope", 0)), int(target.get("hope", 0)) + 2)
        GameState.add_log("%s restaure %d PV à %s." % [hero.name,amount,target.name])
    elif action == "guard":
        hero["guarding"] = true
        hero["guard_power"] = int(EquipmentManager.bonuses_for_hero(str(hero.get("id", ""))).get("guard_power", 0))
        GameState.add_log("%s se met en garde." % hero.name)
    else:
        var living: Array = GameState.alive_enemies()
        if living.is_empty():
            finish_victory()
            return
        selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
        var target: Dictionary = GameState.battle_enemies[selected_enemy]
        if target.hp <= 0:
            target = living[0]
        var power := 1.0 if action == "strike" else 1.35
        var cls: Dictionary = DataLoader.find_by_id(DataLoader.classes, hero.class_id)
        var bonuses: Dictionary = EquipmentManager.bonuses_for_hero(str(hero.get("id", "")))
        var base_damage: int = randi_range(int(cls.damage[0]), int(cls.damage[1])) + int(bonuses.get("damage_bonus", 0))
        var damage: int = int(base_damage * power)
        damage += int(round(damage * float(bonuses.get("precision", 0)) / 100.0))
        var critical_chance: int = int(bonuses.get("critical_chance", 0))
        var critical: bool = critical_chance > 0 and randi_range(1, 100) <= critical_chance
        if critical:
            damage = int(round(damage * 1.5))
        if EquipmentManager.has_effect(str(hero.get("id", "")), "bone_fury") and int(hero.get("hp", 0)) * 2 <= int(hero.get("max_hp", 1)):
            damage = int(round(damage * 1.25))
        if int(target.get("broken", 0)) > 0:
            damage = int(round(damage * 1.15))
            target["broken"] = int(target.get("broken", 0)) - 1
        if EquipmentManager.has_effect(str(hero.get("id", "")), "void_echo"):
            damage += int(round(damage * 0.20))
        target.hp = max(0, target.hp - damage)
        if int(bonuses.get("stun_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("stun_chance", 0)):
            target["stunned"] = true
        if int(bonuses.get("bleed_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("bleed_chance", 0)):
            target["bleeding"] = maxi(2, int(bonuses.get("bleed_chance", 0)) / 2)
        if int(bonuses.get("break_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("break_chance", 0)):
            target["broken"] = 2
        if EquipmentManager.has_effect(str(hero.get("id", "")), "radiant_mercy"):
            var wounded: Array = GameState.alive_heroes()
            wounded.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("hp", 0)) < int(right.get("hp", 0)))
            if not wounded.is_empty():
                var healed: Dictionary = wounded[0]
                healed["hp"] = mini(int(healed.get("max_hp", 1)), int(healed.get("hp", 0)) + 4)
        GameState.add_log("%s inflige %d dégâts%s à %s." % [hero.name, damage, " critiques" if critical else "", target.name])
    var companion_targets: Array = GameState.alive_enemies()
    if not companion_targets.is_empty():
        var companion_result: Dictionary = CreatureManager.companion_turn(companion_targets[0])
        if not companion_result.is_empty():
            GameState.add_log("%s inflige %d dégâts." % [
                str(companion_result.get("name", "Le compagnon")),
                int(companion_result.get("damage", 0))
            ])
    if GameState.alive_enemies().is_empty():
        finish_victory()
        return
    enemy_turn()

func enemy_turn() -> void:
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        if int(enemy.get("bleeding", 0)) > 0:
            enemy.hp = max(0, int(enemy.hp) - int(enemy.get("bleeding", 0)))
        if bool(enemy.get("stunned", false)):
            enemy["stunned"] = false
            GameState.add_log("%s est étourdi et perd son tour." % enemy.name)
            continue
        var targets: Array = GameState.alive_heroes()
        if targets.is_empty():
            finish_defeat()
            return
        var target: Dictionary = targets[randi() % targets.size()]
        var target_bonuses: Dictionary = EquipmentManager.bonuses_for_hero(str(target.get("id", "")))
        var creature_bonuses: Dictionary = CreatureManager.party_bonuses()
        for bonus_key_value in creature_bonuses.keys():
            var bonus_key: String = str(bonus_key_value)
            target_bonuses[bonus_key] = int(target_bonuses.get(bonus_key, 0)) + int(creature_bonuses.get(bonus_key, 0))
        var damage: int = randi_range(int(enemy.damage[0]), int(enemy.damage[1]))
        damage = maxi(1, int(round(damage * (1.0 - float(target_bonuses.get("physical_resistance", 0)) / 100.0))))
        if target.get("guarding",false):
            var guard_reduction: float = clampf(0.5 + float(target.get("guard_power", 0)) / 100.0, 0.5, 0.85)
            damage = maxi(1, int(round(damage * (1.0 - guard_reduction))))
            target["guarding"] = false
        target.hp = max(0, target.hp - damage)
        var fear_gain: int = maxi(0, int(enemy.fear) - int(target_bonuses.get("fear_resistance", 0)))
        target.fear = min(100, target.fear + fear_gain)
        var riposte_chance: int = int(target_bonuses.get("riposte_chance", 0))
        if EquipmentManager.has_effect(str(target.get("id", "")), "steadfast_counter"):
            riposte_chance += 10
        if riposte_chance > 0 and randi_range(1, 100) <= riposte_chance:
            enemy.hp = max(0, int(enemy.hp) - 4)
            GameState.add_log("%s riposte contre %s." % [target.name, enemy.name])
        GameState.add_log("%s frappe %s pour %d dégâts." % [enemy.name,target.name,damage])
    battle_locked = false
    show_screen("combat")

func finish_victory() -> void:
    GameState.gold += 28
    GameState.essence += 4
    GameState.expedition_room += 1
    CreatureManager.grant_active_xp(30)
    if not AshlandsCombatBridge.active:
        var hero_index: int = clampi(GameState.expedition_room - 2, 0, DataLoader.heroes.size() - 1)
        EquipmentManager.grant_test_level_bundle(hero_index, "common")
    GameState.add_log("Victoire. La compagnie récupère ses récompenses.")
    GameState.request_screen("rewards")

func finish_defeat() -> void:
    GameState.add_log("La compagnie est anéantie.")
    GameState.request_screen("sanctuary")

func show_rewards() -> void:
    var bg := full_texture("res://assets/backgrounds/ossuary.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0,0,0,0.58)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)
    var box := VBoxContainer.new()
    box.position = Vector2(365,125)
    box.size = Vector2(550,470)
    box.add_theme_constant_override("separation", 15)
    content.add_child(box)
    box.add_child(make_label("VICTOIRE", 42, GOLD))
    var reward_lines: Array[String] = ["+28 or", "+4 essence"]
    for reward_value in EquipmentManager.last_rewards:
        var reward: Dictionary = reward_value
        var hero_level: int = EquipmentManager.level_for_class(str(reward.get("class_id", "")))
        reward_lines.append(EquipmentManager.describe_item(reward, hero_level))
    box.add_child(make_label("\n".join(reward_lines), 18))
    if GameState.expedition_room > GameState.expedition_rooms:
        box.add_child(make_label("Les Cryptes du Premier Voile sont terminées.", 18, MUTED))
        box.add_child(make_button("RETOUR AU SANCTUAIRE", func():
            SaveManager.save_game()
            GameState.request_screen("sanctuary"), Vector2(500,58)))
    else:
        box.add_child(make_label("Salle %d / %d" % [GameState.expedition_room,GameState.expedition_rooms], 18, MUTED))
        box.add_child(make_button("POURSUIVRE L'EXPÉDITION", func(): start_random_battle(), Vector2(500,58)))
        box.add_child(make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(500,52)))

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("back") and GameState.current_screen != "title":
        GameState.request_screen("sanctuary")
