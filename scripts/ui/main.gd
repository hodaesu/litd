extends Control

var root: Control
var content: Control
var selected_enemy := 0
var battle_locked := false
var selected_hero_id: String = "aurelien"
var starter_positive_traits: Array = []
var starter_negative_traits: Array = []
var trait_setup_message := ""

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
    l.add_theme_font_size_override("font_size", int(round(float(size) * GameSettings.text_scale)))
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
        "trait_setup": show_trait_setup()
        "trait_evolution": show_trait_evolution_choice()
        "sanctuary": show_sanctuary()
        "company": show_company()
        "guild_chest": show_guild_chest()
        "hero_skills": show_hero_skills()
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
        selected_hero_id = "aurelien"
        starter_positive_traits = []
        starter_negative_traits = []
        trait_setup_message = ""
        GameState.request_screen("sanctuary"), Vector2(440,58)))
    box.add_child(make_button("CONTINUER", func():
        if SaveManager.load_game():
            GameState.request_screen("sanctuary"), Vector2(440,58)))
    box.add_child(make_button("QUITTER", func(): get_tree().quit(), Vector2(440,58)))

func show_trait_setup() -> void:
    var title := make_label("CARACTÉRISTIQUES DU HÉROS DE DÉPART", 27, GOLD)
    title.position = Vector2(28, 12)
    content.add_child(title)
    var hero_row := HBoxContainer.new()
    hero_row.position = Vector2(28, 52)
    hero_row.size = Vector2(1220, 48)
    content.add_child(hero_row)
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        hero_row.add_child(make_button(str(hero.get("name", "Héros")), func(hero_id = str(hero.get("id", ""))):
            selected_hero_id = hero_id
            starter_positive_traits = []
            starter_negative_traits = []
            trait_setup_message = ""
            show_screen("trait_setup"), Vector2(210, 42)))
    var columns := HBoxContainer.new()
    columns.position = Vector2(28, 112)
    columns.size = Vector2(1220, 455)
    columns.add_theme_constant_override("separation", 18)
    content.add_child(columns)
    columns.add_child(_trait_choice_column("POSITIVES · MAXIMUM 2", CharacterTraitDirector.data.get("positives", []), true))
    columns.add_child(_trait_choice_column("NÉGATIVES · MAXIMUM 2", CharacterTraitDirector.data.get("negatives", []), false))
    var chosen := make_label("Choix : %s / %s" % [
        ", ".join(CharacterTraitDirector.trait_names({"positive_traits": starter_positive_traits, "negative_traits": []}).get("positive", [])),
        ", ".join(CharacterTraitDirector.trait_names({"positive_traits": [], "negative_traits": starter_negative_traits}).get("negative", []))
    ], 14, TEXT)
    chosen.position = Vector2(28, 580)
    chosen.size = Vector2(930, 45)
    content.add_child(chosen)
    if trait_setup_message != "":
        var warning := make_label(trait_setup_message, 14, Color("#d4773d"))
        warning.position = Vector2(28, 618)
        content.add_child(warning)
    var confirm := make_button("VALIDER ET COMMENCER", func(): _confirm_starter_traits(), Vector2(280, 52))
    confirm.position = Vector2(960, 590)
    content.add_child(confirm)

func _trait_choice_column(title_text: String, traits: Array, positive: bool) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(590, 455)
    column.add_child(make_label(title_text, 18, GOLD))
    var grid := GridContainer.new()
    grid.columns = 2
    column.add_child(grid)
    var selected: Array = starter_positive_traits if positive else starter_negative_traits
    for value: Variant in traits:
        var trait_definition: Dictionary = value
        var trait_id := str(trait_definition.get("id", ""))
        var prefix := "✓ " if selected.has(trait_id) else ""
        grid.add_child(make_button(prefix + str(trait_definition.get("name", trait_id)), func(id_value = trait_id, is_positive = positive):
            _toggle_starter_trait(id_value, is_positive), Vector2(285, 36)))
    return column

func _toggle_starter_trait(trait_id: String, positive: bool) -> void:
    var selected: Array = starter_positive_traits if positive else starter_negative_traits
    if selected.has(trait_id):
        selected.erase(trait_id)
    elif selected.size() < 2:
        selected.append(trait_id)
    else:
        trait_setup_message = "Maximum deux caractéristiques par catégorie."
    show_screen("trait_setup")

func _confirm_starter_traits() -> void:
    var starter: Dictionary = {}
    for hero_value: Variant in GameState.party:
        if str((hero_value as Dictionary).get("id", "")) == selected_hero_id:
            starter = hero_value
            break
    var result := CharacterTraitDirector.set_starter_traits(starter, starter_positive_traits, starter_negative_traits)
    if not bool(result.get("ok", false)):
        trait_setup_message = "Deux caractéristiques positives imposent au moins une caractéristique négative."
        show_screen("trait_setup")
        return
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) != selected_hero_id and (hero.get("positive_traits", []) as Array).is_empty():
            CharacterTraitDirector.randomize_traits(hero)
    GameState.request_screen("sanctuary")

func show_trait_evolution_choice() -> void:
    var character := _first_pending_trait_character()
    if character.is_empty():
        GameState.request_screen("rewards")
        return
    var pending := CharacterTraitDirector.pending_evolution(character)
    var from_name := str(CharacterTraitDirector.by_id.get(str(pending.get("from", "")), {}).get("name", pending.get("from", "")))
    var to_name := str(CharacterTraitDirector.by_id.get(str(pending.get("to", "")), {}).get("name", pending.get("to", "")))
    var box := VBoxContainer.new()
    box.position = Vector2(290, 105)
    box.size = Vector2(700, 500)
    box.add_theme_constant_override("separation", 16)
    content.add_child(box)
    box.add_child(make_label("UNE PEUR DEVIENT UNE FORCE", 30, GOLD))
    box.add_child(make_label("%s a surmonté : %s" % [str(character.get("name", "Le personnage")), from_name], 18, TEXT))
    box.add_child(make_label("Nouveau trait : %s" % to_name, 20, Color("#d5b26c")))
    box.add_child(make_label("Les deux emplacements positifs sont occupés. Choisis toi-même le trait à supprimer :", 16, MUTED))
    for positive_id: Variant in character.get("positive_traits", []):
        var positive_name := str(CharacterTraitDirector.by_id.get(str(positive_id), {}).get("name", positive_id))
        box.add_child(make_button("REMPLACER : %s" % positive_name, func(character_ref = character, trait_id = str(positive_id)):
            _resolve_trait_evolution(character_ref, trait_id), Vector2(650, 58)))

func _first_pending_trait_character() -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if CharacterTraitDirector.has_pending_evolution(hero):
            return hero
    for creature_value: Variant in CreatureManager.captured_creatures:
        var creature: Dictionary = creature_value
        if CharacterTraitDirector.has_pending_evolution(creature):
            return creature
    return {}

func _resolve_trait_evolution(character: Dictionary, replace_positive_id: String) -> void:
    var result := CharacterTraitDirector.resolve_pending_evolution(character, replace_positive_id)
    if bool(result.get("ok", false)):
        GameState.add_log("%s remplace un ancien trait par %s." % [str(character.get("name", "Le personnage")), str(result.get("added", ""))])
    if _first_pending_trait_character().is_empty():
        GameState.request_screen("rewards")
    else:
        show_screen("trait_evolution")

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
        ["MÉMORIAL\nHéros tombés", "memorial", Vector2(250,535)],
    ]
    if ContentScopeDirector.is_unlocked("capture"):
        buttons.append(["BESTIAIRE\nCréatures liées", "creatures", Vector2(910,360)])
    for item in buttons:
        var action = item[1]
        var b := make_button(item[0], func(a=action):
            if a == "company":
                GameState.request_screen("company")
            elif a == "expedition":
                GameState.request_screen("expedition")
            elif a == "infirmary":
                var infirmary_result := PersistentInjuryRuntime.treat_all_at_infirmary(GameState.party)
                GameState.add_log("Infirmerie : %d blessure(s) soignée(s), %d mutilation(s) stabilisée(s)." % [int(infirmary_result.get("treated", 0)), int(infirmary_result.get("stabilized", 0))])
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
    var starter_traits := make_button("CARACTÉRISTIQUES DU HÉROS", func():
        starter_positive_traits = []
        starter_negative_traits = []
        trait_setup_message = ""
        GameState.request_screen("trait_setup"), Vector2(290,46))
    starter_traits.position = Vector2(780,20)
    content.add_child(starter_traits)
    var save := make_button("SAUVEGARDER", func(): SaveManager.save_game(), Vector2(170,46))
    save.position = Vector2(1080,20)
    content.add_child(save)

func hero_art(hero: Dictionary) -> String:
    var c := DataLoader.find_by_id(DataLoader.classes, hero.get("class_id"))
    return "res://assets/heroes/%s" % c.get("art","inquisitor.webp")

func _party_healer_treatment() -> void:
    var result := PersistentInjuryRuntime.treat_all_party_injuries(GameState.party)
    if bool(result.get("ok", false)):
        GameState.add_log("Le soigneur traite %d blessure(s) et stabilise %d mutilation(s)." % [int(result.get("treated", 0)), int(result.get("stabilized", 0))])
    else:
        GameState.add_log("Aucun personnage apte ne possède de capacité de soin.")

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
        var trait_labels := CharacterTraitDirector.trait_names(hero)
        card.add_child(make_label("+ %s\n− %s" % [", ".join(trait_labels.get("positive", [])), ", ".join(trait_labels.get("negative", []))], 11, MUTED))
        card.add_child(make_button("ARBRES DE COMPÉTENCES", func(hero_id = str(hero.id)):
            selected_hero_id = hero_id
            GameState.request_screen("hero_skills"), Vector2(220, 42)))
        row.add_child(card)
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(280,48))
    back.position = Vector2(24,630)
    content.add_child(back)
    var heal := make_button("SOINS DE L’ÉQUIPE", func(): _party_healer_treatment(); show_company(), Vector2(260,48))
    heal.position = Vector2(600,630)
    content.add_child(heal)
    var chest := make_button("COFFRE COMMUN", func(): GameState.request_screen("guild_chest"), Vector2(240,48))
    chest.position = Vector2(330,630)
    content.add_child(chest)

func show_guild_chest() -> void:
    var title := make_label("GUILDE — COFFRE COMMUN",28,GOLD); title.position=Vector2(24,16); content.add_child(title)
    var columns := HBoxContainer.new(); columns.position=Vector2(24,60); columns.size=Vector2(1230,550); columns.add_theme_constant_override("separation",20); content.add_child(columns)
    var carried := VBoxContainer.new(); carried.custom_minimum_size=Vector2(590,0); columns.add_child(carried)
    carried.add_child(make_label("INVENTAIRE TRANSPORTÉ",18,GOLD))
    if EquipmentManager.items.is_empty(): carried.add_child(make_label("Inventaire vide",14,MUTED))
    for item in EquipmentManager.items:
        var row:=HBoxContainer.new(); var id:String=str(item.instance_id)
        var label:=make_label(EquipmentManager.describe_item(item,EquipmentManager.level_for_class(str(item.class_id))),13); label.custom_minimum_size=Vector2(410,45); row.add_child(label)
        row.add_child(make_button("DÉPOSER",func(item_id=id): EquipmentManager.store_in_guild_stash(item_id); show_guild_chest(),Vector2(140,40))); carried.add_child(row)
    var stored := VBoxContainer.new(); stored.custom_minimum_size=Vector2(590,0); columns.add_child(stored)
    stored.add_child(make_label("BUTIN STOCKÉ · %d OBJET(S)"%EquipmentManager.guild_stash.size(),18,GOLD))
    if EquipmentManager.guild_stash.is_empty(): stored.add_child(make_label("Coffre vide",14,MUTED))
    for item in EquipmentManager.guild_stash:
        var row:=HBoxContainer.new(); var id:String=str(item.instance_id)
        var label:=make_label(EquipmentManager.describe_item(item,EquipmentManager.level_for_class(str(item.class_id))),13); label.custom_minimum_size=Vector2(410,45); row.add_child(label)
        row.add_child(make_button("RETIRER",func(item_id=id): EquipmentManager.withdraw_from_guild_stash(item_id); show_guild_chest(),Vector2(140,40))); stored.add_child(row)
    var back:=make_button("RETOUR À LA GUILDE",func():GameState.request_screen("company"),Vector2(250,45)); back.position=Vector2(24,640); content.add_child(back)

func show_hero_skills() -> void:
    var hero: Dictionary = {}
    for hero_value in GameState.party:
        if str(hero_value.id) == selected_hero_id: hero = hero_value
    if hero.is_empty(): GameState.request_screen("company"); return
    var title := make_label("%s — 30 EN PRODUCTION · 45 AU CATALOGUE · %d POINT(S)" % [hero.name, int(hero.skill_points)], 24, GOLD)
    title.position = Vector2(24, 15); content.add_child(title)
    var scroll := ScrollContainer.new(); scroll.position = Vector2(24,55); scroll.size = Vector2(1230,570); content.add_child(scroll)
    var list := VBoxContainer.new(); list.custom_minimum_size = Vector2(1190,0); scroll.add_child(list)
    var specialization: String = str(hero.specialization)
    for branch in HeroSkillManager.BRANCHES:
        var label := make_label("%s%s" % [branch.to_upper(), " — CHOISI" if specialization==branch else (" — VERROUILLÉ" if specialization!="" else "")],16,GOLD)
        list.add_child(label)
        var grid := GridContainer.new(); grid.columns=3; list.add_child(grid)
        for node_value in HeroSkillManager.production_skill_nodes(hero,branch):
            var node: Dictionary=node_value; var unlocked: bool=hero.unlocked_skills.has(str(node.id))
            var button := make_button("%s\n%s"%[node.name,"ACQUIS" if unlocked else node.description],func(skill_id=str(node.id)):
                HeroSkillManager.unlock(hero,skill_id); show_hero_skills(),Vector2(380,55))
            button.disabled=unlocked or not HeroSkillManager.can_unlock(hero,str(node.id)); grid.add_child(button)
    var back := make_button("RETOUR",func():GameState.request_screen("company"),Vector2(180,45)); back.position=Vector2(24,640); content.add_child(back)

func hero_bonuses(hero: Dictionary) -> Dictionary:
    var result: Dictionary = EquipmentManager.bonuses_for_hero(str(hero.get("id","")))
    for trait_key: Variant in CharacterTraitDirector.modifiers(hero).keys():
        result[str(trait_key)] = int(result.get(str(trait_key), 0)) + int(round(float(CharacterTraitDirector.modifiers(hero).get(trait_key, 0.0))))
    var injury_context := {"weapon_hands": int(hero.get("equipped_weapon_hands", 1))}
    var injury_debuffs := PersistentInjuryRuntime.active_debuffs(hero, injury_context)
    for injury_key: Variant in injury_debuffs.keys():
        result[String(injury_key)] = int(result.get(String(injury_key), 0)) + int(round(float(injury_debuffs[injury_key])))
    for key_value in HeroSkillManager.stats_for(hero).keys():
        var key: String=str(key_value); result[key]=int(result.get(key,0))+int(HeroSkillManager.stats_for(hero).get(key,0))
    var fear_modifiers := PsychologyRuntime.combat_modifiers(hero)
    var hope_modifiers := PsychologyRuntime.hope_combat_modifiers(hero)
    for psychology_key_value: Variant in ["precision", "healing_power", "fear_resistance", "guard_power"]:
        var psychology_key := str(psychology_key_value)
        result[psychology_key] = int(result.get(psychology_key, 0)) \
            + int(fear_modifiers.get(psychology_key, 0)) \
            + int(hope_modifiers.get(psychology_key, 0))
    result["damage_bonus"] = int(result.get("damage_bonus", 0)) \
        + int(fear_modifiers.get("damage_percent", 0)) \
        + int(hope_modifiers.get("damage_percent", 0))
    return result

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
    if ExpeditionReportDirector.current.is_empty():
        ExpeditionReportDirector.begin_expedition("first_veil_crypts")
    GameState.battle_enemies = []
    var ids := [1,8,10]
    if GameState.expedition_room >= GameState.expedition_rooms:
        ids = [38]
    for enemy_id in ids:
        var e := DataLoader.find_by_id(DataLoader.enemies, enemy_id).duplicate(true)
        e["max_hp"] = e.hp
        e["guarding"] = false
        CharacterTraitDirector.prepare_character(e, "%s:%d:%d" % [str(e.get("id", "")), GameState.expedition_room, GameState.battle_enemies.size()])
        EnemyFearDirector.initialize_enemy(e, GameState.party)
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
        var hero_button := Button.new()
        hero_button.flat = true
        hero_button.custom_minimum_size = Vector2(135,390)
        hero_button.tooltip_text = "Survol : aperçu · Clic/toucher/validation : inspection"
        var card := VBoxContainer.new()
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.custom_minimum_size = Vector2(135,390)
        var art := TextureRect.new()
        art.texture = load(hero_art(h))
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.custom_minimum_size = Vector2(135,320)
        art.modulate = Color(1,1,1, 1.0 if h.hp > 0 else 0.35)
        card.add_child(art)
        CombatBodyPresentation.bind_visual(art, h, false, i)
        card.add_child(make_label("%s\nPV %d/%d" % [h.name,h.hp,h.max_hp], 13, GOLD))
        card.add_child(make_label(CombatBodyPresentation.state_label(h, false), 9, MUTED))
        hero_button.add_child(card)
        CombatantInspectionUI.bind_combatant(hero_button, h, false)
        heroes_row.add_child(hero_button)

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
        CombatBodyPresentation.bind_visual(art, e, true, i)
        v.add_child(make_label("%s\nPV %d/%d" % [e.name,e.hp,e.max_hp], 12, GOLD if i == selected_enemy else TEXT))
        v.add_child(make_label(CombatBodyPresentation.state_label(e, true), 9, MUTED))
        var enemy_traits := CharacterTraitDirector.trait_names(e)
        v.add_child(make_label("+%s · −%s" % [", ".join(enemy_traits.get("positive", [])), ", ".join(enemy_traits.get("negative", []))], 9, MUTED))
        var fear_gauge := EnemyFearGauge.new()
        v.add_child(fear_gauge)
        fear_gauge.bind_enemy(e)
        b.add_child(v)
        b.tooltip_text = "Survol : aperçu · Clic/toucher/validation : inspection"
        b.pressed.connect(func(index=i):
            selected_enemy = index
        )
        CombatantInspectionUI.bind_combatant(b, e, true)
        enemies_row.add_child(b)

    var action_panel := VBoxContainer.new()
    action_panel.position = Vector2(245,555)
    action_panel.size = Vector2(850,120)
    action_panel.add_theme_constant_override("separation", 6)
    content.add_child(action_panel)
    var acting_hero: Dictionary = GameState.alive_heroes()[0] if not GameState.alive_heroes().is_empty() else {}
    var skill_row := HBoxContainer.new()
    skill_row.add_theme_constant_override("separation", 6)
    action_panel.add_child(skill_row)
    if not acting_hero.is_empty():
        var equipped_skills: Array[String] = HeroSkillManager.combat_loadout(acting_hero)
        for slot in range(4):
            var skill_id: String = equipped_skills[slot] if slot < equipped_skills.size() else ""
            var skill: Dictionary = HeroSkillManager.combat_skill(acting_hero, skill_id)
            var label: String = str(skill.get("name", "EMPLACEMENT VIDE")).to_upper()
            var skill_button := make_button(label, func(slot_index = slot): _use_skill_slot(slot_index), Vector2(200, 48))
            skill_button.disabled = skill.is_empty()
            if not skill.is_empty() and not GameState.alive_enemies().is_empty():
                var preview_target: Dictionary = GameState.battle_enemies[clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)]
                skill_button.tooltip_text = CombatPreviewDirector.describe(CombatPreviewDirector.preview(acting_hero, skill, preview_target))
            skill_row.add_child(skill_button)
    var item_row := HBoxContainer.new()
    item_row.add_theme_constant_override("separation", 6)
    action_panel.add_child(item_row)
    if not acting_hero.is_empty():
        var hero_id: String = str(acting_hero.get("id", ""))
        var heal_stack: Dictionary = CombatLoadoutManager.equipped_stack(hero_id, CombatLoadoutManager.HEAL_SLOT)
        var grenade_stack: Dictionary = CombatLoadoutManager.equipped_stack(hero_id, CombatLoadoutManager.GRENADE_SLOT)
        item_row.add_child(make_button("SOIN ×%d" % int(heal_stack.get("quantity", 0)), func(): _use_combat_item(CombatLoadoutManager.HEAL_SLOT), Vector2(190, 42)))
        item_row.add_child(make_button("GRENADE ×%d" % int(grenade_stack.get("quantity", 0)), func(): _use_combat_item(CombatLoadoutManager.GRENADE_SLOT), Vector2(210, 42)))
    if ContentScopeDirector.is_unlocked("capture"):
        action_panel.add_child(make_button("CAPTURER", func(): hero_action("capture"), Vector2(180, 42)))

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

    var timeline := VBoxContainer.new()
    timeline.position = Vector2(510, 8)
    timeline.size = Vector2(740, 145)
    content.add_child(timeline)
    timeline.add_child(make_label("ORDRE ET INTENTIONS PARTIELLES", 15, GOLD))
    var timeline_lines: Array[String] = ActionTimelineDirector.preview_lines(GameState.alive_heroes(), GameState.alive_enemies())
    for timeline_line: String in timeline_lines.slice(0, 6):
        timeline.add_child(make_label("• " + timeline_line, 11, MUTED))

func _use_skill_slot(slot: int) -> void:
    if battle_locked:
        return
    var living_heroes: Array = GameState.alive_heroes()
    if living_heroes.is_empty():
        finish_defeat()
        return
    var hero: Dictionary = living_heroes[0]
    var equipped_skills: Array[String] = HeroSkillManager.combat_loadout(hero)
    if slot < 0 or slot >= equipped_skills.size():
        return
    var skill: Dictionary = HeroSkillManager.combat_skill(hero, equipped_skills[slot])
    if skill.is_empty():
        return
    var effect: String = str(skill.get("effect", "attack"))
    match effect:
        "heal", "support":
            _hero_action_with_skill("heal", skill)
        "guard":
            _hero_action_with_skill("guard", skill)
        _:
            _hero_action_with_skill("heavy" if float(skill.get("power", 1.0)) > 1.2 else "strike", skill)

func _use_combat_item(category: String) -> void:
    if battle_locked:
        return
    var living_heroes: Array = GameState.alive_heroes()
    if living_heroes.is_empty():
        finish_defeat()
        return
    var hero: Dictionary = living_heroes[0]
    var item: Dictionary = CombatLoadoutManager.consume(str(hero.get("id", "")), category)
    if item.is_empty():
        GameState.add_log("Aucun consommable préparé dans cet emplacement.")
        show_screen("combat")
        return
    battle_locked = true
    ExpeditionReportDirector.record_consumable(hero, item)
    CombatBodyPresentation.stage_action(hero, false, "use_item")
    await get_tree().create_timer(0.18).timeout
    if category == CombatLoadoutManager.HEAL_SLOT:
        var wounded: Array = GameState.alive_heroes()
        wounded.sort_custom(func(left: Dictionary, right: Dictionary): return float(left.get("hp", 0)) / maxf(1.0, float(left.get("max_hp", 1))) < float(right.get("hp", 0)) / maxf(1.0, float(right.get("max_hp", 1))))
        var target: Dictionary = wounded[0]
        var amount: int = int(item.get("heal", 0))
        target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + amount)
        GameState.add_log("%s utilise %s sur %s : +%d PV." % [hero.get("name", "Le héros"), item.get("name", "un soin"), target.get("name", "un allié"), amount])
    else:
        var damage: int = int(item.get("damage", 0))
        var status: String = str(item.get("status", ""))
        for enemy_value: Variant in GameState.alive_enemies():
            var enemy: Dictionary = enemy_value
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
            if status == "burn":
                enemy["burning"] = 2
            elif status == "accuracy_down":
                enemy["accuracy_down"] = 2
            CombatBodyPresentation.stage_hit(enemy, true, "torso", "heavy")
            if int(enemy.get("hp", 0)) <= 0:
                CombatBodyPresentation.stage_death(enemy, true)
        GameState.add_log("%s lance %s : %d dégâts à tous les ennemis." % [hero.get("name", "Le héros"), item.get("name", "une grenade"), damage])
    if GameState.alive_enemies().is_empty():
        finish_victory()
        return
    enemy_turn()

func hero_action(action: String) -> void:
    _hero_action_with_skill(action, {})

func _hero_action_with_skill(action: String, skill: Dictionary) -> void:
    if battle_locked:
        return
    battle_locked = true
    var hero: Dictionary = GameState.alive_heroes()[0] if not GameState.alive_heroes().is_empty() else {}
    if hero.is_empty():
        finish_defeat()
        return
    CombatBodyPresentation.stage_action(hero, false, action)
    await get_tree().create_timer(0.18).timeout
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
        var bonuses: Dictionary = hero_bonuses(hero)
        var amount: int = int(round(float(skill.get("heal", 18)) * (1.0 + float(bonuses.get("healing_power", 0)) / 100.0)))
        target.hp = min(target.max_hp, target.hp + amount)
        var target_bonuses: Dictionary = hero_bonuses(target)
        target.hope = mini(100 + int(target_bonuses.get("max_hope", 0)), int(target.get("hope", 0)) + 2)
        GameState.add_log("%s restaure %d PV à %s." % [hero.name,amount,target.name])
    elif action == "guard":
        hero["guarding"] = true
        hero["guard_power"] = int(hero_bonuses(hero).get("guard_power", 0)) + int(skill.get("guard_bonus", 0))
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
        var hp_before := int(target.get("hp", 0))
        var power: float = float(skill.get("power", 1.0 if action == "strike" else 1.35))
        var cls: Dictionary = DataLoader.find_by_id(DataLoader.classes, hero.class_id)
        var bonuses: Dictionary = hero_bonuses(hero)
        for contextual_key: Variant in CharacterTraitDirector.contextual_modifiers(hero, CharacterTraitDirector.context_for_enemy(target)).keys():
            bonuses[str(contextual_key)] = int(bonuses.get(str(contextual_key), 0)) + int(round(float(CharacterTraitDirector.contextual_modifiers(hero, CharacterTraitDirector.context_for_enemy(target)).get(contextual_key, 0.0))))
        var base_damage: int = randi_range(int(cls.damage[0]), int(cls.damage[1])) + int(bonuses.get("damage_bonus", 0))
        var damage: int = int(base_damage * power)
        damage += int(round(damage * float(bonuses.get("precision", 0)) / 100.0))
        var critical_chance: int = int(bonuses.get("critical_chance", 0)) + int(skill.get("critical_chance", 0))
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
        CombatBodyPresentation.stage_hit(target, true, "torso", "heavy" if action == "heavy" else "light")
        if int(target.get("hp", 0)) <= 0:
            CombatBodyPresentation.stage_death(target, true)
        if int(bonuses.get("stun_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("stun_chance", 0)):
            target["stunned"] = true
        if int(bonuses.get("bleed_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("bleed_chance", 0)):
            target["bleeding"] = maxi(2, int(bonuses.get("bleed_chance", 0)) / 2)
        if int(bonuses.get("break_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("break_chance", 0)):
            target["broken"] = 2
        var skill_status: String = str(skill.get("status", ""))
        var skill_status_chance: int = int(skill.get("status_chance", 0))
        if skill_status != "" and randi_range(1, 100) <= skill_status_chance:
            target[skill_status] = true if skill_status in ["stunned", "weakened"] else 2
        if EquipmentManager.has_effect(str(hero.get("id", "")), "radiant_mercy"):
            var wounded: Array = GameState.alive_heroes()
            wounded.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("hp", 0)) < int(right.get("hp", 0)))
            if not wounded.is_empty():
                var healed: Dictionary = wounded[0]
                healed["hp"] = mini(int(healed.get("max_hp", 1)), int(healed.get("hp", 0)) + 4)
        GameState.add_log("%s inflige %d dégâts%s à %s." % [hero.name, damage, " critiques" if critical else "", target.name])
        EnemyFearDirector.apply_event(target, "hero_damage", {"damage": damage})
        if critical:
            EnemyFearDirector.record_deed(hero, "critical_hit")
            EnemyFearDirector.apply_witness_event(GameState.alive_enemies(), "critical_hit", {"hero_id": str(hero.get("id", ""))})
        if hp_before > 0 and int(target.get("hp", 0)) <= 0:
            EnemyFearDirector.record_deed(hero, "enemy_defeated", 1, str(target.get("id", "")))
            EnemyFearDirector.apply_witness_event(GameState.alive_enemies(), "ally_killed", {"hero_id": str(hero.get("id", "")), "enemy_id": int(target.get("id", 0))})
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
        if EnemyFearDirector.should_panic(enemy, GameState.expedition_room):
            GameState.add_log("%s panique et perd son action." % enemy.name)
            continue
        var targets: Array = GameState.alive_heroes()
        if targets.is_empty():
            finish_defeat()
            return
        var enemy_action: Dictionary = EnemyCombatDirector.choose_action(enemy, targets)
        var target_index: int = clampi(int(enemy_action.get("target_index", 0)), 0, targets.size() - 1)
        var target: Dictionary = targets[target_index]
        var target_bonuses: Dictionary = hero_bonuses(target)
        for contextual_key: Variant in CharacterTraitDirector.contextual_modifiers(target, CharacterTraitDirector.context_for_enemy(enemy)).keys():
            target_bonuses[str(contextual_key)] = int(target_bonuses.get(str(contextual_key), 0)) + int(round(float(CharacterTraitDirector.contextual_modifiers(target, CharacterTraitDirector.context_for_enemy(enemy)).get(contextual_key, 0.0))))
        var creature_bonuses: Dictionary = CreatureManager.party_bonuses()
        for bonus_key_value in creature_bonuses.keys():
            var bonus_key: String = str(bonus_key_value)
            target_bonuses[bonus_key] = int(target_bonuses.get(bonus_key, 0)) + int(creature_bonuses.get(bonus_key, 0))
        var damage: int = int(round(float(randi_range(int(enemy.damage[0]), int(enemy.damage[1]))) * float(enemy_action.get("power", 1.0))))
        damage = maxi(1, damage)
        var enemy_fear_modifiers := EnemyFearDirector.combat_modifiers(enemy)
        if randf() > float(enemy_fear_modifiers.get("accuracy_multiplier", 1.0)):
            GameState.add_log("%s hésite sous l’effet de la Peur et manque sa cible." % enemy.name)
            continue
        damage = maxi(1, int(round(float(damage) * float(enemy_fear_modifiers.get("damage_multiplier", 1.0)))))
        var enemy_trait_modifiers: Dictionary = CharacterTraitDirector.modifiers(enemy, CharacterTraitDirector.context_for_enemy(target))
        damage = maxi(1, int(round(float(damage) * (1.0 + float(enemy_trait_modifiers.get("damage_bonus", 0.0)) / 100.0))))
        damage = maxi(1, int(round(damage * (1.0 - float(target_bonuses.get("physical_resistance", 0)) / 100.0))))
        if target.get("guarding",false):
            var guard_reduction: float = clampf(0.5 + float(target.get("guard_power", 0)) / 100.0, 0.5, 0.85)
            damage = maxi(1, int(round(damage * (1.0 - guard_reduction))))
            target["guarding"] = false
        CombatBodyPresentation.stage_action(enemy, true, String(enemy_action.get("id", "strike")))
        await get_tree().create_timer(0.16).timeout
        target.hp = max(0, target.hp - damage)
        CombatBodyPresentation.stage_hit(target, false, "torso", "heavy" if damage >= int(enemy.damage[1]) else "light")
        if int(target.get("hp", 0)) <= 0:
            CombatBodyPresentation.stage_death(target, false)
        await get_tree().create_timer(0.12).timeout
        var fear_gain: int = maxi(0, int(enemy.fear) - int(target_bonuses.get("fear_resistance", 0)))
        target.fear = min(100, target.fear + fear_gain)
        var riposte_chance: int = int(target_bonuses.get("riposte_chance", 0))
        if EquipmentManager.has_effect(str(target.get("id", "")), "steadfast_counter"):
            riposte_chance += 10
        if riposte_chance > 0 and randi_range(1, 100) <= riposte_chance:
            enemy.hp = max(0, int(enemy.hp) - 4)
            GameState.add_log("%s riposte contre %s." % [target.name, enemy.name])
        GameState.add_log("%s utilise %s sur %s pour %d dégâts." % [enemy.name, String(enemy_action.get("name", "une attaque")), target.name, damage])
        for secondary_message: String in EnemyCombatDirector.apply_secondary(enemy_action, enemy, target, targets):
            GameState.add_log(secondary_message)
        if damage >= int(enemy.damage[1]):
            EnemyFearDirector.apply_event(enemy, "enemy_lands_heavy_hit")
    battle_locked = false
    show_screen("combat")

func finish_victory() -> void:
    var trait_evolutions: Array = CharacterTraitDirector.record_enemy_encounter(GameState.alive_heroes(), GameState.battle_enemies)
    for evolution_value: Variant in trait_evolutions:
        var evolution: Dictionary = evolution_value
        if bool(evolution.get("pending_choice", false)):
            GameState.add_log("Une peur est prête à devenir une force : un trait doit être remplacé.")
        else:
            GameState.add_log("Une peur est maîtrisée : %s." % str(evolution.get("to", "")))
    var defeated_boss := false
    for enemy_value: Variant in GameState.battle_enemies:
        var defeated_enemy: Dictionary = enemy_value
        CampaignMemoryDirector.learn_enemy(defeated_enemy)
        if int(defeated_enemy.get("hp", 0)) <= 0:
            var family_id := String(defeated_enemy.get("family", defeated_enemy.get("family_id", "any")))
            BountyContractDirector.record_event("enemy_defeated", family_id)
            if bool(defeated_enemy.get("elite", false)):
                BountyContractDirector.record_event("elite_defeated", String(defeated_enemy.get("id", family_id)))
            if int(defeated_enemy.get("fear", 0)) >= 50:
                BountyContractDirector.record_event("enemy_defeated_under_fear", family_id)
        if bool(defeated_enemy.get("boss", false)) and int(defeated_enemy.get("hp", 0)) <= 0:
            defeated_boss = true
    for hero_value: Variant in GameState.alive_heroes():
        var surviving_hero: Dictionary = hero_value
        if defeated_boss:
            EnemyFearDirector.record_deed(surviving_hero, "boss_defeated")
    GameState.gold += 28
    GameState.essence += 4
    GameState.expedition_room += 1
    if GameState.expedition_room > GameState.expedition_rooms:
        for hero_value: Variant in GameState.alive_heroes():
            EnemyFearDirector.record_deed(hero_value, "dungeon_survived")
        BountyContractDirector.record_event("dungeon_completed_no_hero_death", "first_veil_crypts")
        BountyContractDirector.record_event("dungeon_completed", "first_veil_crypts")
        BountyContractDirector.close_dungeon_run(true)
        var worsened_injuries := PersistentInjuryRuntime.close_expedition(GameState.party)
        for worsening_value: Variant in worsened_injuries:
            var worsening: Dictionary = worsening_value
            GameState.add_log("Une blessure non soignée s’aggrave : %s." % String(worsening.get("injury_id", "blessure")))
        var expedition_report := ExpeditionReportDirector.finish_expedition(true)
        CampaignMemoryDirector.record_expedition(expedition_report)
        SaveManager.autosave("fin d’expédition")
    CreatureManager.grant_active_xp(30)
    for hero_value in GameState.party:
        HeroSkillManager.grant_xp(hero_value, 30)
    if not AshlandsCombatBridge.active:
        var hero_index: int = clampi(GameState.expedition_room - 2, 0, DataLoader.heroes.size() - 1)
        EquipmentManager.grant_test_level_bundle(hero_index, "common")
    GameState.add_log("Victoire. La compagnie récupère ses récompenses.")
    if _first_pending_trait_character().is_empty():
        GameState.request_screen("rewards")
    else:
        GameState.request_screen("trait_evolution")

func finish_defeat() -> void:
    for hero_value: Variant in GameState.party:
        var fallen_hero: Dictionary = hero_value
        if int(fallen_hero.get("hp", 0)) <= 0:
            CampaignMemoryDirector.record_death(fallen_hero, "Tombé en expédition", AshlandsRuntime.current_zone_id)
    var expedition_report := ExpeditionReportDirector.finish_expedition(false)
    CampaignMemoryDirector.record_expedition(expedition_report)
    SaveManager.autosave("défaite")
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
