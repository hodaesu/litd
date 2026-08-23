extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const BACK := Color(0.01, 0.012, 0.018, 0.97)
const PANEL := Color(0.035, 0.038, 0.050, 0.98)

var overlay: Control
var launcher: Button
var content: VBoxContainer
var active_tab := "inventory"
var selected_hero_id := ""
var selected_skill_slot := 0
var character_panel := "stats"

func _ready() -> void:
    layer = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    GameState.new_game_reset.connect(_on_new_game)
    GameState.screen_requested.connect(_on_screen_requested)
    EquipmentManager.inventory_changed.connect(func(_items: Array): _refresh_if(active_tab))
    CombatLoadoutManager.loadout_changed.connect(func(_hero_id: String): _refresh_if("characters"))
    SideQuestRuntime.quests_changed.connect(func(): _refresh_if("journal"))
    GameState.state_changed.connect(func(): _refresh_if(active_tab))
    GameSettings.settings_changed.connect(func(): _refresh_if("options"))

func _on_screen_requested(screen_name: String) -> void:
    launcher.visible = screen_name != "title" and not overlay.visible

func _on_new_game() -> void:
    selected_hero_id = String(GameState.party[0].get("id", "")) if not GameState.party.is_empty() else ""
    close_menu()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("game_menu"):
        if overlay.visible:
            close_menu()
        elif GameState.current_screen != "title":
            open_menu()
        get_viewport().set_input_as_handled()

func open_menu(tab := "") -> void:
    if tab != "":
        active_tab = tab
    if selected_hero_id == "" and not GameState.party.is_empty():
        selected_hero_id = String(GameState.party[0].get("id", ""))
    overlay.visible = true
    launcher.visible = false
    get_tree().paused = true
    _render()

func close_menu() -> void:
    overlay.visible = false
    launcher.visible = GameState.current_screen != "title"
    get_tree().paused = false

func _build() -> void:
    launcher = _button("MENU", open_menu, Vector2(120, 42))
    launcher.position = Vector2(1136, 82)
    launcher.visible = false
    add_child(launcher)
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    add_child(overlay)
    var bg := ColorRect.new()
    bg.color = BACK
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(bg)
    var shell := VBoxContainer.new()
    shell.position = Vector2(24, 18)
    shell.size = Vector2(1232, 684)
    shell.add_theme_constant_override("separation", 12)
    overlay.add_child(shell)
    var header := HBoxContainer.new()
    shell.add_child(header)
    var title := _label("LIGHT IN THE DARK", 27, GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(_button("FERMER", close_menu, Vector2(140, 44)))
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    shell.add_child(tabs)
    for entry: Array in [["inventory","INVENTAIRE"],["map","CARTE"],["journal","JOURNAL"],["characters","PERSONNAGES"],["options","OPTIONS"]]:
        tabs.add_child(_button(String(entry[1]), func(id = String(entry[0])): active_tab = id; _render(), Vector2(220, 46)))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    shell.add_child(scroll)
    content = VBoxContainer.new()
    content.custom_minimum_size = Vector2(1190, 560)
    content.add_theme_constant_override("separation", 10)
    scroll.add_child(content)

func _render() -> void:
    for child in content.get_children():
        child.queue_free()
    content.add_child(_label(_tab_title(), 22, GOLD))
    match active_tab:
        "inventory": _render_inventory()
        "map": _render_map()
        "journal": _render_journal()
        "characters": _render_characters()
        "options": _render_options()

func _tab_title() -> String:
    return {"inventory":"INVENTAIRE","map":"CARTE","journal":"JOURNAL DE QUÊTES","characters":"PERSONNAGES ET COMPÉTENCES","options":"OPTIONS ET RÉGLAGES"}.get(active_tab, "MENU")

func _render_inventory() -> void:
    content.add_child(_hero_selector())
    content.add_child(_label("Objets transportés : %d · Coffre de Guilde : %d" % [EquipmentManager.items.size(), EquipmentManager.guild_stash.size()], 15, MUTED))
    content.add_child(_label("CONSOMMABLES — 10 maximum par pile", 18, GOLD))
    for stack: Dictionary in CombatLoadoutManager.inventory_stacks:
        var consumable := CombatLoadoutManager.definition(String(stack.get("item_id", "")))
        content.add_child(_label("• %s ×%d/10" % [String(consumable.get("name", "Objet")), int(stack.get("quantity", 0))], 14, TEXT))
    if EquipmentManager.items.is_empty():
        content.add_child(_label("L’inventaire transporté est vide.", 16, TEXT))
    for value: Variant in EquipmentManager.items:
        var item: Dictionary = value
        var row := HBoxContainer.new()
        var level := _selected_hero_level()
        var description := _label(EquipmentManager.describe_item(item, level), 14, TEXT)
        description.custom_minimum_size = Vector2(900, 48)
        row.add_child(description)
        row.add_child(_button("ÉQUIPER", func(instance_id = String(item.get("instance_id", ""))): _equip_item(instance_id), Vector2(180, 42)))
        content.add_child(row)
    if not EquipmentManager.guild_stash.is_empty():
        content.add_child(_label("COFFRE COMMUN", 18, GOLD))
        for value: Variant in EquipmentManager.guild_stash:
            var item: Dictionary = value
            content.add_child(_label("• " + EquipmentManager.describe_item(item, _selected_hero_level()), 13, MUTED))

func _equip_item(instance_id: String) -> void:
    if selected_hero_id != "" and EquipmentManager.equip(selected_hero_id, instance_id):
        GameState.add_log("Équipement modifié depuis le menu.")
    else:
        GameState.add_log("Cet objet n’est pas compatible avec ce personnage.")
    _render()

func _render_map() -> void:
    var current := AshlandsRuntime.current_zone_id
    content.add_child(_label("Position actuelle : %s" % (_zone_name(current) if current != "" else "Sanctuaire ou position inconnue"), 17, TEXT))
    content.add_child(_label("Zones découvertes : %d · Raccourcis : %d" % [AshlandsRuntime.discovered_zones.size(), AshlandsRuntime.unlocked_shortcuts.size()], 14, MUTED))
    if AshlandsRuntime.discovered_zones.is_empty():
        content.add_child(_label("La carte se dévoilera pendant l’exploration.", 16, MUTED))
        return
    for zone_value: Variant in AshlandsRuntime.discovered_zones.keys():
        var zone_id := String(zone_value)
        var marker := "◆" if zone_id == current else "◇"
        var details: Array[String] = []
        if zone_id == AshlandsRuntime.previous_zone_id:
            details.append("zone précédente")
        content.add_child(_label("%s %s%s" % [marker, _zone_name(zone_id), " — " + ", ".join(details) if not details.is_empty() else ""], 16, GOLD if zone_id == current else TEXT))
    if not AshlandsRuntime.unlocked_shortcuts.is_empty():
        content.add_child(_label("RACCOURCIS OUVERTS", 18, GOLD))
        for shortcut: Variant in AshlandsRuntime.unlocked_shortcuts.keys():
            content.add_child(_label("• %s" % String(shortcut).replace("_", " ").capitalize(), 14, MUTED))

func _zone_name(zone_id: String) -> String:
    return zone_id.replace("c01_", "").replace("_", " ").capitalize()

func _render_journal() -> void:
    var chapter := CampaignState.current_chapter()
    content.add_child(_label("Chapitre %d — %s" % [CampaignState.current_chapter_number(), String(chapter.get("title", ""))], 19, TEXT))
    content.add_child(_label(String(chapter.get("premise", "")), 14, MUTED))
    content.add_child(_label("QUÊTES PRINCIPALES", 18, GOLD))
    for value: Variant in CampaignState.active_main_quests():
        var quest: Dictionary = value
        content.add_child(_label("◆ %s" % String(quest.get("name", "Quête principale")), 16, TEXT))
        content.add_child(_label(String(quest.get("goal", "")), 13, MUTED))
    content.add_child(_label("QUÊTES DE DONJON", 18, GOLD))
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
    if parsed is Array:
        for value: Variant in parsed:
            var quest: Dictionary = value
            var giver := NarrativeLibrary.quest_giver_for(quest)
            var quest_id := String(quest.get("id", ""))
            var quest_status := SideQuestRuntime.status(quest_id)
            content.add_child(_label("%s %s — %s" % ["◆" if quest_status == "active" else ("✓" if quest_status == "completed" else "◇"), String(quest.get("name", "Quête")), quest_status.capitalize()], 15, TEXT))
            var giver_button := _button("RENCONTRER %s — %s" % [String(giver.get("name", "Donneur inconnu")).to_upper(), String(giver.get("role", ""))], func(g = giver, q = quest, s = quest_status): QuestGiverPresentation.open_dialogue(g, q, s), Vector2(520, 40))
            QuestGiverPresentation.bind_card(giver_button, giver, quest_status)
            content.add_child(giver_button)
            content.add_child(_label(NarrativeLibrary.quest_state_text(quest, quest_status), 13, MUTED))
    content.add_child(_label("CONTRATS DE CHASSE", 18, GOLD))
    for value: Variant in BountyContractDirector.active_contracts:
        var contract: Dictionary = value
        content.add_child(_label("• %s — %d/%d" % [String(contract.get("name", "Contrat")), int(contract.get("progress", 0)), int(contract.get("required", 1))], 14, TEXT))

func _render_characters() -> void:
    content.add_child(_label("Sélectionne un héros pour déployer sa fiche de préparation.", 14, MUTED))
    content.add_child(_hero_selector())
    var hero := _selected_hero()
    if hero.is_empty():
        content.add_child(_label("Aucun personnage sélectionné.", 16, MUTED))
        return
    var class_definition := DataLoader.find_by_id(DataLoader.classes, String(hero.get("class_id", "")))
    content.add_child(_label("▼ %s · %s · niveau %d" % [String(hero.get("name", "Héros")), String(class_definition.get("name", "")), int(hero.get("level", 1))], 19, TEXT))
    var navigation := HBoxContainer.new()
    navigation.add_child(_button(("▶ " if character_panel == "stats" else "") + "STATS ET ÉTATS", func(): character_panel = "stats"; _render(), Vector2(280, 42)))
    navigation.add_child(_button(("▶ " if character_panel == "equipment" else "") + "ÉQUIPEMENT", func(): character_panel = "equipment"; _render(), Vector2(250, 42)))
    navigation.add_child(_button(("▶ " if character_panel == "items" else "") + "SOINS ET GRENADES", func(): character_panel = "items"; _render(), Vector2(300, 42)))
    navigation.add_child(_button(("▶ " if character_panel == "skills" else "") + "COMPÉTENCES", func(): character_panel = "skills"; _render(), Vector2(260, 42)))
    content.add_child(navigation)
    match character_panel:
        "equipment": _render_hero_equipment(hero)
        "items": _render_hero_combat_items(hero)
        "skills": _render_hero_skills(hero)
        _: _render_hero_stats(hero)

func _render_hero_stats(hero: Dictionary) -> void:
    var hero_id := String(hero.get("id", ""))
    var equipment_bonuses := EquipmentManager.bonuses_for_hero(hero_id)
    content.add_child(_label("STATISTIQUES", 18, GOLD))
    content.add_child(_label("PV %d/%d · Peur %d · Folie %d · Espoir %d" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 0)), int(hero.get("fear", 0)), int(hero.get("madness", 0)), int(hero.get("hope", 0))], 15, TEXT))
    var stat_parts: Array[String] = []
    for entry: Array in [["damage","DGT"],["precision","PRÉ"],["critical_chance","CRIT"],["dodge","ESQUIVE"],["physical_resistance","PROT"],["speed","VIT"]]:
        var key := String(entry[0])
        stat_parts.append("%s %d" % [String(entry[1]), int(hero.get(key, 0)) + int(equipment_bonuses.get(key, equipment_bonuses.get(key + "_bonus", 0)))])
    content.add_child(_label(" · ".join(stat_parts), 14, MUTED))
    var trait_names := CharacterTraitDirector.trait_names(hero)
    var buffs: Array[String] = []
    for value: Variant in trait_names.get("positive", []):
        buffs.append(String(value))
    for value: Variant in hero.get("buffs", []):
        buffs.append(_effect_name(value))
    var debuffs: Array[String] = []
    for value: Variant in trait_names.get("negative", []):
        debuffs.append(String(value))
    for value: Variant in hero.get("debuffs", []):
        debuffs.append(_effect_name(value))
    content.add_child(_label("BUFFS", 17, GOLD))
    content.add_child(_label("• " + "\n• ".join(buffs) if not buffs.is_empty() else "Aucun bonus actif.", 14, TEXT if not buffs.is_empty() else MUTED))
    content.add_child(_label("DEBUFFS ET BLESSURES", 17, GOLD))
    content.add_child(_label("• " + "\n• ".join(debuffs) if not debuffs.is_empty() else "Aucun malus temporaire.", 14, TEXT if not debuffs.is_empty() else MUTED))
    var injuries: Array = hero.get("persistent_injuries", [])
    for injury_value: Variant in injuries:
        var injury: Dictionary = injury_value
        var definition := PersistentInjuryRuntime.definition(String(injury.get("id", "")))
        content.add_child(_label("• %s — %s" % [String(definition.get("name", injury.get("id", ""))), String(injury.get("severity", ""))], 14, TEXT))

func _render_hero_equipment(hero: Dictionary) -> void:
    var hero_id := String(hero.get("id", ""))
    var equipped: Dictionary = EquipmentManager.equipped_by_hero.get(hero_id, {})
    content.add_child(_label("ÉQUIPEMENT PORTÉ", 18, GOLD))
    for entry: Array in [["weapon","ARME"],["armor","ARMURE"],["ring_1","ANNEAU 1"],["ring_2","ANNEAU 2"],["necklace","COLLIER"]]:
        var slot_id := String(entry[0])
        var item := EquipmentManager.get_instance(String(equipped.get(slot_id, "")))
        content.add_child(_label("%s · %s" % [String(entry[1]), EquipmentManager.describe_item(item, int(hero.get("level", 1))) if not item.is_empty() else "Vide"], 14, TEXT))
    content.add_child(_label("ÉQUIPEMENT COMPATIBLE DISPONIBLE", 17, GOLD))
    var found := false
    for value: Variant in EquipmentManager.items:
        var item: Dictionary = value
        var item_class := String(item.get("class_id", ""))
        if item_class != "" and item_class != String(hero.get("class_id", "")):
            continue
        found = true
        var row := HBoxContainer.new()
        var description := _label(EquipmentManager.describe_item(item, int(hero.get("level", 1))), 13, MUTED)
        description.custom_minimum_size = Vector2(880, 42)
        row.add_child(description)
        row.add_child(_button("ÉQUIPER", func(instance_id = String(item.get("instance_id", ""))): _equip_item(instance_id), Vector2(190, 40)))
        content.add_child(row)
    if not found:
        content.add_child(_label("Aucun équipement compatible dans l’inventaire.", 14, MUTED))

func _render_hero_combat_items(hero: Dictionary) -> void:
    var hero_id := String(hero.get("id", ""))
    content.add_child(_label("EMPLACEMENTS RAPIDES", 18, GOLD))
    for category in [CombatLoadoutManager.HEAL_SLOT, CombatLoadoutManager.GRENADE_SLOT]:
        var equipped := CombatLoadoutManager.equipped(hero_id, category)
        var equipped_stack := CombatLoadoutManager.equipped_stack(hero_id, category)
        var title := "SOIN" if category == CombatLoadoutManager.HEAL_SLOT else "GRENADE"
        var equipped_name := String(equipped.get("name", "Vide"))
        var equipped_quantity := int(equipped_stack.get("quantity", 0))
        content.add_child(_label("%s · %s ×%d/5" % [title, equipped_name, equipped_quantity], 15, TEXT))
        for item: Dictionary in CombatLoadoutManager.definitions_for(category):
            var item_id := String(item.get("id", ""))
            var count := CombatLoadoutManager.inventory_count(item_id)
            var row := HBoxContainer.new()
            var description := _label("%s · réserve ×%d — %s" % [String(item.get("name", "Objet")), count, String(item.get("description", ""))], 14, MUTED)
            description.custom_minimum_size = Vector2(760, 44)
            row.add_child(description)
            var one_button := _button("×1", func(id = item_id): _equip_combat_item(id, 1), Vector2(100, 40))
            one_button.disabled = count <= 0
            row.add_child(one_button)
            var max_button := _button("MAX ×5", func(id = item_id): _equip_combat_item(id, 5), Vector2(150, 40))
            max_button.disabled = count <= 0
            row.add_child(max_button)
            content.add_child(row)

func _equip_combat_item(item_id: String, quantity: int) -> void:
    var hero := _selected_hero()
    if CombatLoadoutManager.equip(String(hero.get("id", "")), item_id, quantity):
        GameState.add_log("%s prépare une pile de consommables." % String(hero.get("name", "Le héros")))
    _render()

func _render_hero_skills(hero: Dictionary) -> void:
    content.add_child(_label("COMPÉTENCES ÉQUIPÉES — sélectionne un emplacement", 18, GOLD))
    var slots := HBoxContainer.new()
    var loadout := HeroSkillManager.combat_loadout(hero)
    for index in range(HeroSkillManager.COMBAT_LOADOUT_SIZE):
        var skill := HeroSkillManager.combat_skill(hero, loadout[index])
        var prefix := "▶ " if selected_skill_slot == index else ""
        slots.add_child(_button(prefix + "%d · %s" % [index + 1, String(skill.get("name", loadout[index]))], func(slot = index): selected_skill_slot = slot; _render(), Vector2(280, 44)))
    content.add_child(slots)
    content.add_child(_label("COMPÉTENCES DISPONIBLES", 17, GOLD))
    for skill_value: Variant in HeroSkillManager.known_combat_skills(hero):
        var skill: Dictionary = skill_value
        var row := HBoxContainer.new()
        var description := _label("%s — %s" % [String(skill.get("name", "Technique")), String(skill.get("description", ""))], 14, TEXT)
        description.custom_minimum_size = Vector2(850, 44)
        row.add_child(description)
        row.add_child(_button("PLACER EN %d" % (selected_skill_slot + 1), func(skill_id = String(skill.get("id", ""))): _equip_skill(skill_id), Vector2(230, 40)))
        content.add_child(row)

func _effect_name(value: Variant) -> String:
    if value is Dictionary:
        return String(value.get("name", value.get("id", "Effet")))
    return String(value)

func _equip_skill(skill_id: String) -> void:
    var hero := _selected_hero()
    if HeroSkillManager.equip_combat_skill(hero, selected_skill_slot, skill_id):
        GameState.add_log("%s équipe une nouvelle compétence." % String(hero.get("name", "Le héros")))
    _render()

func _render_options() -> void:
    content.add_child(_slider_row("Volume général", GameSettings.master_volume, GameSettings.set_master_volume))
    content.add_child(_slider_row("Musique", GameSettings.music_volume, GameSettings.set_music_volume))
    content.add_child(_slider_row("Effets sonores", GameSettings.sfx_volume, GameSettings.set_sfx_volume))
    content.add_child(_toggle_row("Plein écran", GameSettings.fullscreen, GameSettings.set_fullscreen))
    content.add_child(_toggle_row("Sous-titres", GameSettings.subtitles, GameSettings.set_subtitles))
    content.add_child(_toggle_row("Secousses de caméra", GameSettings.screen_shake, GameSettings.set_screen_shake))
    content.add_child(_label("Les réglages sont appliqués et sauvegardés automatiquement.", 14, MUTED))
    content.add_child(_button("SAUVEGARDER LA PARTIE", func(): SaveManager.save_game(), Vector2(300, 46)))
    content.add_child(_button("RETOUR AU SANCTUAIRE", func(): close_menu(); GameState.request_screen("sanctuary"), Vector2(300, 46)))

func _slider_row(title: String, value: float, callback: Callable) -> HBoxContainer:
    var row := HBoxContainer.new()
    var label := _label(title, 16, TEXT)
    label.custom_minimum_size = Vector2(330, 44)
    row.add_child(label)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.05
    slider.value = value
    slider.custom_minimum_size = Vector2(500, 44)
    slider.value_changed.connect(callback)
    row.add_child(slider)
    return row

func _toggle_row(title: String, value: bool, callback: Callable) -> HBoxContainer:
    var row := HBoxContainer.new()
    var label := _label(title, 16, TEXT)
    label.custom_minimum_size = Vector2(330, 44)
    row.add_child(label)
    var toggle := CheckButton.new()
    toggle.button_pressed = value
    toggle.toggled.connect(callback)
    row.add_child(toggle)
    return row

func _hero_selector() -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    for value: Variant in GameState.party:
        var hero: Dictionary = value
        var hero_id := String(hero.get("id", ""))
        var prefix := "▶ " if hero_id == selected_hero_id else ""
        row.add_child(_button(prefix + String(hero.get("name", "Héros")), func(id = hero_id): selected_hero_id = id; _render(), Vector2(240, 42)))
    return row

func _selected_hero() -> Dictionary:
    for value: Variant in GameState.party:
        var hero: Dictionary = value
        if String(hero.get("id", "")) == selected_hero_id:
            return hero
    return {}

func _selected_hero_level() -> int:
    return int(_selected_hero().get("level", 1))

func _refresh_if(tab: String) -> void:
    if overlay.visible and active_tab == tab:
        call_deferred("_render")

func _style(color := PANEL) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.45, 0.34, 0.20, 0.82)
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _button(text: String, callback: Callable, size := Vector2(180, 44)) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = size
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_stylebox_override("normal", _style())
    button.add_theme_stylebox_override("hover", _style(Color(0.11, 0.085, 0.06, 0.99)))
    button.pressed.connect(callback)
    return button

func _label(text: String, size := 15, color := TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label
