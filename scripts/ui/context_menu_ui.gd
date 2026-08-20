extends CanvasLayer

# Menu contextuel persistant : disponible pendant le jeu sans remplacer les écrans
# existants. Les onglets lisent et modifient directement les managers du runtime.

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const RED := Color("#b95b5b")
const DARK := Color(0.008, 0.010, 0.016, 0.96)
const PANEL := Color(0.030, 0.033, 0.044, 0.98)
const SETTINGS_PATH := "user://litd_settings.cfg"
const TABS: Array[String] = ["inventory", "equipment", "skills", "journal", "options"]

var launcher: Button
var overlay: Control
var body: Control
var tab_title: Label
var current_tab := "inventory"
var selected_hero_id := ""
var current_screen := "title"

func _ready() -> void:
    layer = 90
    _load_options()
    _build_launcher()
    _build_overlay()
    GameState.screen_requested.connect(_on_screen_requested)
    GameState.state_changed.connect(_refresh_if_open)
    CampaignState.campaign_changed.connect(_refresh_if_open)
    EquipmentManager.inventory_changed.connect(func(_items: Array): _refresh_if_open())
    ExpeditionManager.inventory_changed.connect(func(_inventory: Dictionary): _refresh_if_open())
    current_screen = GameState.current_screen
    _sync_launcher()

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("context_menu"):
        toggle_menu()
        get_viewport().set_input_as_handled()
    elif overlay != null and overlay.visible and event.is_action_pressed("back"):
        close_menu()
        get_viewport().set_input_as_handled()

func toggle_menu() -> void:
    if current_screen == "title":
        return
    if overlay.visible:
        close_menu()
    else:
        open_menu()

func open_menu(tab: String = "") -> void:
    if current_screen == "title":
        return
    if tab in TABS:
        current_tab = tab
    if selected_hero_id == "" and not GameState.party.is_empty():
        selected_hero_id = str((GameState.party[0] as Dictionary).get("id", ""))
    overlay.visible = true
    launcher.visible = false
    _render_current_tab()

func close_menu() -> void:
    overlay.visible = false
    _sync_launcher()

func _on_screen_requested(screen_name: String) -> void:
    current_screen = screen_name
    if screen_name == "title":
        overlay.visible = false
    _sync_launcher()

func _sync_launcher() -> void:
    if launcher == null:
        return
    launcher.visible = current_screen != "title" and (overlay == null or not overlay.visible)

func _style(color: Color = PANEL) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.45, 0.34, 0.20, 0.82)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    return style

func _label(text: String, size: int = 15, color: Color = TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(text: String, callback: Callable, min_size: Vector2 = Vector2(180, 44)) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = min_size
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_stylebox_override("normal", _style())
    button.add_theme_stylebox_override("hover", _style(Color(0.11, 0.085, 0.06, 0.99)))
    button.pressed.connect(callback)
    return button

func _build_launcher() -> void:
    launcher = _button("MENU", func(): open_menu(), Vector2(130, 42))
    launcher.position = Vector2(1110, 76)
    add_child(launcher)

func _build_overlay() -> void:
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var dim := ColorRect.new()
    dim.color = DARK
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(dim)

    var frame := PanelContainer.new()
    frame.position = Vector2(28, 24)
    frame.size = Vector2(1224, 672)
    frame.add_theme_stylebox_override("panel", _style(Color(0.018, 0.020, 0.028, 0.995)))
    overlay.add_child(frame)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    frame.add_child(root)

    var header := HBoxContainer.new()
    header.custom_minimum_size = Vector2(0, 54)
    root.add_child(header)
    var title := _label("LIGHT IN THE DARK · MENU", 23, GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(_button("FERMER  [TAB]", func(): close_menu(), Vector2(170, 42)))

    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 14)
    root.add_child(main)

    var nav_panel := PanelContainer.new()
    nav_panel.custom_minimum_size = Vector2(230, 0)
    nav_panel.add_theme_stylebox_override("panel", _style())
    main.add_child(nav_panel)
    var nav := VBoxContainer.new()
    nav.add_theme_constant_override("separation", 8)
    nav_panel.add_child(nav)
    nav.add_child(_label("MENU CONTEXTUEL", 16, GOLD))
    nav.add_child(_button("INVENTAIRE", func(): _select_tab("inventory"), Vector2(200, 46)))
    nav.add_child(_button("ÉQUIPEMENT", func(): _select_tab("equipment"), Vector2(200, 46)))
    nav.add_child(_button("COMPÉTENCES", func(): _select_tab("skills"), Vector2(200, 46)))
    nav.add_child(_button("JOURNAL DE QUÊTES", func(): _select_tab("journal"), Vector2(200, 46)))
    nav.add_child(_button("OPTIONS DE JEU", func(): _select_tab("options"), Vector2(200, 46)))
    nav.add_spacer(false)
    nav.add_child(_button("SAUVEGARDER", func(): SaveManager.save_game(), Vector2(200, 42)))

    var content_panel := PanelContainer.new()
    content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_panel.add_theme_stylebox_override("panel", _style())
    main.add_child(content_panel)
    var content_root := VBoxContainer.new()
    content_root.add_theme_constant_override("separation", 8)
    content_panel.add_child(content_root)
    tab_title = _label("", 22, GOLD)
    content_root.add_child(tab_title)
    var separator := HSeparator.new()
    content_root.add_child(separator)
    body = Control.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_root.add_child(body)

func _select_tab(tab: String) -> void:
    if tab not in TABS:
        return
    current_tab = tab
    _render_current_tab()

func _refresh_if_open() -> void:
    if overlay != null and overlay.visible:
        call_deferred("_render_current_tab")

func _clear_body() -> void:
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()

func _render_current_tab() -> void:
    if body == null or not overlay.visible:
        return
    _clear_body()
    match current_tab:
        "inventory":
            tab_title.text = "INVENTAIRE"
            _render_inventory()
        "equipment":
            tab_title.text = "ÉQUIPEMENT"
            _render_equipment()
        "skills":
            tab_title.text = "COMPÉTENCES"
            _render_skills()
        "journal":
            tab_title.text = "JOURNAL DE QUÊTES"
            _render_journal()
        "options":
            tab_title.text = "OPTIONS DE JEU"
            _render_options()

func _scroll_column() -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    body.add_child(scroll)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(900, 0)
    column.add_theme_constant_override("separation", 9)
    scroll.add_child(column)
    return column

func _render_inventory() -> void:
    var column := _scroll_column()
    column.add_child(_label("OBJETS TRANSPORTÉS · %d" % EquipmentManager.items.size(), 17, GOLD))
    if EquipmentManager.items.is_empty():
        column.add_child(_label("Aucun équipement n'est actuellement transporté.", 14, MUTED))
    for item_value in EquipmentManager.items:
        var item: Dictionary = item_value
        var hero_level := EquipmentManager.level_for_class(str(item.get("class_id", "")))
        column.add_child(_label("• %s" % EquipmentManager.describe_item(item, hero_level), 13, TEXT))

    column.add_child(HSeparator.new())
    column.add_child(_label("COFFRE DE GUILDE · %d OBJET(S)" % EquipmentManager.guild_stash.size(), 16, GOLD))
    column.add_child(_label("Le coffre reste au Sanctuaire. Utilise l'écran de Guilde pour déposer ou retirer des objets.", 13, MUTED))

    if ExpeditionManager.expedition_active:
        column.add_child(HSeparator.new())
        column.add_child(_label("SAC D'EXPÉDITION · %d/%d EMPLACEMENTS" % [ExpeditionManager.inventory_slots_used(), ExpeditionManager.inventory_capacity()], 16, GOLD))
        var inv: Dictionary = ExpeditionManager.inventory
        column.add_child(_label("Nourriture %d · Eau %d · Bandages %d · Lumière %d · Outils %d · Médecine %d" % [
            int(inv.get("food", 0)), int(inv.get("water", 0)), int(inv.get("bandages", 0)),
            int(inv.get("light", 0)), int(inv.get("camp_tools", 0)), int(inv.get("medicine", 0))
        ], 13, TEXT))
        var runtime: Node = ExpeditionManager.roguelike_runtime
        var cargo: Array = runtime.active_run.get("cargo", []) if runtime != null else []
        column.add_child(_label("BUTIN NON SÉCURISÉ · %d" % cargo.size(), 15, GOLD))
        for cargo_value in cargo:
            var cargo_item: Dictionary = cargo_value
            column.add_child(_label("• %s · %s%s" % [
                str(cargo_item.get("rarity", "common")).to_upper(),
                "NON IDENTIFIÉ · " if not bool(cargo_item.get("identified", true)) else "",
                "MAUDIT" if bool(cargo_item.get("cursed", false)) else str(cargo_item.get("source", "relique"))
            ], 12, MUTED))

func _hero_by_id(hero_id: String) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _hero_selector(parent: VBoxContainer, rerender: Callable) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        var prefix := "◆ " if hero_id == selected_hero_id else ""
        row.add_child(_button("%s%s · Niv.%d" % [prefix, str(hero.get("name", "Héros")), int(hero.get("level", 1))], func(id_value = hero_id):
            selected_hero_id = str(id_value)
            rerender.call(), Vector2(190, 42)))

func _render_equipment() -> void:
    var column := _scroll_column()
    _hero_selector(column, func(): _render_current_tab())
    var hero := _hero_by_id(selected_hero_id)
    if hero.is_empty():
        column.add_child(_label("Aucun héros sélectionné.", 14, MUTED))
        return
    var slots: Dictionary = EquipmentManager.equipped_by_hero.get(selected_hero_id, {})
    column.add_child(_label("ÉQUIPÉ SUR %s" % str(hero.get("name", "Héros")).to_upper(), 17, GOLD))
    for slot_name in ["weapon", "armor", "ring_1", "ring_2", "necklace"]:
        var instance_id := str(slots.get(slot_name, ""))
        var item := EquipmentManager.get_instance(instance_id)
        var description := "Vide" if item.is_empty() else EquipmentManager.describe_item(item, int(hero.get("level", 1)))
        column.add_child(_label("%s : %s" % [_slot_label(slot_name), description], 13, TEXT if not item.is_empty() else MUTED))

    column.add_child(HSeparator.new())
    column.add_child(_label("OBJETS COMPATIBLES À ÉQUIPER", 16, GOLD))
    var compatible := 0
    for item_value in EquipmentManager.items:
        var item: Dictionary = item_value
        var item_class := str(item.get("class_id", ""))
        if item_class != "" and item_class != str(hero.get("class_id", "")):
            continue
        compatible += 1
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        column.add_child(row)
        var desc := _label(EquipmentManager.describe_item(item, int(hero.get("level", 1))), 12, TEXT)
        desc.custom_minimum_size = Vector2(640, 44)
        desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(desc)
        var instance_id := str(item.get("instance_id", ""))
        row.add_child(_button("ÉQUIPER", func(item_id = instance_id):
            if EquipmentManager.equip(selected_hero_id, str(item_id)):
                SaveManager.save_game()
            _render_current_tab(), Vector2(130, 40)))
    if compatible == 0:
        column.add_child(_label("Aucun objet compatible dans l'inventaire transporté.", 13, MUTED))

func _slot_label(slot_name: String) -> String:
    return str({"weapon":"Arme", "armor":"Armure", "ring_1":"Anneau I", "ring_2":"Anneau II", "necklace":"Collier"}.get(slot_name, slot_name))

func _render_skills() -> void:
    var column := _scroll_column()
    _hero_selector(column, func(): _render_current_tab())
    var hero := _hero_by_id(selected_hero_id)
    if hero.is_empty():
        column.add_child(_label("Aucun héros sélectionné.", 14, MUTED))
        return
    column.add_child(_label("%s · Niveau %d · %d point(s) · Spécialisation : %s" % [
        str(hero.get("name", "Héros")), int(hero.get("level", 1)), int(hero.get("skill_points", 0)),
        str(hero.get("specialization", "aucune")) if str(hero.get("specialization", "")) != "" else "aucune"
    ], 15, GOLD))
    for branch in HeroSkillManager.BRANCHES:
        var specialization := str(hero.get("specialization", ""))
        var branch_state := "CHOISIE" if specialization == branch else ("VERROUILLÉE" if specialization != "" and not HeroSkillManager.multi_tree_enabled() else "DISPONIBLE")
        column.add_child(_label("%s · %s" % [_branch_label(branch), branch_state], 16, GOLD))
        for node_value in HeroSkillManager.skill_nodes(hero, branch):
            var node: Dictionary = node_value
            var unlocked := (hero.get("unlocked_skills", []) as Array).has(str(node.get("id", "")))
            var can_unlock := HeroSkillManager.can_unlock(hero, str(node.get("id", "")))
            var row := HBoxContainer.new()
            row.add_theme_constant_override("separation", 8)
            column.add_child(row)
            var status := "ACQUISE" if unlocked else ("DÉBLOCABLE" if can_unlock else "VERROUILLÉE")
            var desc := _label("%s · niv.%d · coût %d — %s [%s]" % [
                str(node.get("name", "Compétence")), int(node.get("required_level", 1)), int(node.get("cost", 1)),
                str(node.get("description", "")), status
            ], 12, TEXT if unlocked or can_unlock else MUTED)
            desc.custom_minimum_size = Vector2(690, 40)
            desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(desc)
            var skill_id := str(node.get("id", ""))
            var unlock_button := _button("ACQUÉRIR", func(id_value = skill_id):
                if HeroSkillManager.unlock(hero, str(id_value)):
                    SaveManager.save_game()
                _render_current_tab(), Vector2(130, 38))
            unlock_button.disabled = not can_unlock
            row.add_child(unlock_button)

func _branch_label(branch: String) -> String:
    return str({"offense":"ASSAUT", "defense":"ÉGIDE", "special":"ESSENCE"}.get(branch, branch.to_upper()))

func _render_journal() -> void:
    var column := _scroll_column()
    var chapter := CampaignState.current_chapter()
    column.add_child(_label("[CAMPAGNE] · CHAPITRE %d — %s" % [CampaignState.current_chapter_number(), str(chapter.get("title", ""))], 18, GOLD))
    column.add_child(_label(str(chapter.get("premise", "")), 13, MUTED))
    var active_campaign: Array = CampaignState.active_main_quests()
    if active_campaign.is_empty():
        column.add_child(_label("Toutes les quêtes principales de ce chapitre sont terminées.", 13, MUTED))
    for quest_value in active_campaign:
        var quest: Dictionary = quest_value
        column.add_child(_quest_card("CAMPAGNE", str(quest.get("name", "Quête")), str(quest.get("goal", "")), "EN COURS", GOLD))

    for quest_value in PoliticalState.available_quests():
        var quest: Dictionary = quest_value
        column.add_child(_quest_card("CAMPAGNE", str(quest.get("name", "Décision locale")), str(quest.get("theme", "")), "DISPONIBLE", GOLD))

    column.add_child(HSeparator.new())
    column.add_child(_label("[DONJON] · QUÊTES DE DONJON", 18, GOLD))
    var dungeon_gate: Dictionary = level_scaling_context()
    column.add_child(_label("%s · niveau requis %d" % [str(dungeon_gate.get("title", "Donjon")), int(dungeon_gate.get("required_level", 1))], 13, MUTED))
    for quest_value in DataLoader.quests:
        var quest: Dictionary = quest_value
        var quest_type := str(quest.get("quest_type", "dungeon")).to_lower()
        if quest_type != "dungeon":
            continue
        var status := _dungeon_quest_status(quest)
        column.add_child(_quest_card("DONJON", str(quest.get("name", "Quête de donjon")), str(quest.get("description", "")), status, TEXT))

    if ExpeditionManager.expedition_active:
        var runtime: Node = ExpeditionManager.roguelike_runtime
        var active_run: Dictionary = runtime.active_run if runtime != null else {}
        column.add_child(_quest_card("DONJON", "Descendre sous le Premier Voile", "Explorer le donjon, sécuriser le butin ou vaincre son boss.", "PROFONDEUR %d" % int(active_run.get("deepest_depth", 0)), TEXT))

func level_scaling_context() -> Dictionary:
    var rules: Dictionary = ExpeditionManager.roguelike_runtime.rules if ExpeditionManager.roguelike_runtime != null else {}
    var dungeon_id := str(rules.get("default_dungeon_id", "first_veil_crypts"))
    var profile: Dictionary = rules.get("dungeons", {}).get(dungeon_id, {})
    return {"title": str(profile.get("title", "Cryptes du Premier Voile")), "required_level": int(profile.get("required_level", 1))}

func _quest_card(kind: String, name: String, description: String, status: String, color: Color) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(Color(0.024, 0.027, 0.036, 0.98)))
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    panel.add_child(column)
    column.add_child(_label("[%s] · %s" % [kind, status], 12, color))
    column.add_child(_label(name, 15, TEXT))
    column.add_child(_label(description, 12, MUTED))
    return panel

func _dungeon_quest_status(quest: Dictionary) -> String:
    if not ExpeditionManager.expedition_active:
        return "DISPONIBLE"
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        return "DISPONIBLE"
    var active_run: Dictionary = runtime.active_run
    var condition: Dictionary = quest.get("condition", {})
    var condition_type := str(condition.get("type", ""))
    if condition_type == "boss_defeated":
        return "TERMINÉE" if bool(active_run.get("boss_defeated", false)) else "EN COURS"
    if condition_type == "visit_room_type":
        var target_type := str(condition.get("room_type", ""))
        var visited: Array = active_run.get("visited", [])
        for room_value in active_run.get("dungeon", []):
            var room: Dictionary = room_value
            if visited.has(str(room.get("id", ""))) and str(room.get("type", "")) == target_type:
                return "TERMINÉE"
        return "EN COURS"
    return "EN COURS"

func _render_options() -> void:
    var column := _scroll_column()
    column.add_child(_label("AUDIO", 17, GOLD))
    _add_volume_row(column, "Master", "Volume général")
    _add_volume_row(column, "Music", "Musique")
    _add_volume_row(column, "SFX", "Effets sonores")

    column.add_child(HSeparator.new())
    column.add_child(_label("AFFICHAGE", 17, GOLD))
    var fullscreen := CheckButton.new()
    fullscreen.text = "Plein écran"
    fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    fullscreen.toggled.connect(func(enabled: bool):
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
        _save_options())
    column.add_child(fullscreen)

    var vsync := CheckButton.new()
    vsync.text = "Synchronisation verticale (V-Sync)"
    vsync.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
    vsync.toggled.connect(func(enabled: bool):
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
        _save_options())
    column.add_child(vsync)
    column.add_child(_label("Les réglages sont enregistrés automatiquement sur cet appareil.", 12, MUTED))

func _add_volume_row(parent: VBoxContainer, bus_name: String, title: String) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index < 0:
        return
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    var name_label := _label(title, 14, TEXT)
    name_label.custom_minimum_size = Vector2(220, 36)
    row.add_child(name_label)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.step = 1.0
    slider.custom_minimum_size = Vector2(440, 36)
    var current_db := AudioServer.get_bus_volume_db(bus_index)
    slider.value = clampf(pow(10.0, current_db / 20.0) * 100.0, 0.0, 100.0)
    row.add_child(slider)
    var value_label := _label("%d %%" % int(round(slider.value)), 13, MUTED)
    value_label.custom_minimum_size = Vector2(70, 36)
    row.add_child(value_label)
    slider.value_changed.connect(func(value: float):
        _set_bus_volume(bus_name, value)
        value_label.text = "%d %%" % int(round(value)))

func _set_bus_volume(bus_name: String, percent: float) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index < 0:
        return
    var linear := maxf(0.0001, percent / 100.0)
    AudioServer.set_bus_volume_db(bus_index, 20.0 * log(linear) / log(10.0))
    AudioServer.set_bus_mute(bus_index, percent <= 0.0)
    _save_options()

func _save_options() -> void:
    var config := ConfigFile.new()
    for bus_name in ["Master", "Music", "SFX"]:
        var bus_index := AudioServer.get_bus_index(bus_name)
        if bus_index >= 0:
            var current_db := AudioServer.get_bus_volume_db(bus_index)
            var percent := clampf(pow(10.0, current_db / 20.0) * 100.0, 0.0, 100.0)
            if AudioServer.is_bus_mute(bus_index):
                percent = 0.0
            config.set_value("audio", bus_name.to_lower(), percent)
    config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
    config.set_value("display", "vsync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
    config.save(SETTINGS_PATH)

func _load_options() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return
    for bus_name in ["Master", "Music", "SFX"]:
        var bus_index := AudioServer.get_bus_index(bus_name)
        if bus_index < 0:
            continue
        var percent := clampf(float(config.get_value("audio", bus_name.to_lower(), 100.0)), 0.0, 100.0)
        var linear := maxf(0.0001, percent / 100.0)
        AudioServer.set_bus_volume_db(bus_index, 20.0 * log(linear) / log(10.0))
        AudioServer.set_bus_mute(bus_index, percent <= 0.0)
    var fullscreen := bool(config.get_value("display", "fullscreen", false))
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
    var vsync := bool(config.get_value("display", "vsync", true))
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
