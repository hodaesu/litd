extends "res://scripts/ui/context_menu_ui.gd"

# v2 UI clarity pass: one primary decision per screen, progressive disclosure,
# compact navigation and details shown only after a deliberate selection.

const TAB_LABELS := {
    "inventory": "INVENTAIRE",
    "equipment": "ÉQUIPEMENT",
    "skills": "COMPÉTENCES",
    "journal": "JOURNAL",
    "options": "OPTIONS"
}
const FILTER_LABELS := {
    "all": "TOUT",
    "equipment": "ÉQUIPEMENT",
    "consumable": "CONSOMMABLES",
    "quest": "QUÊTE"
}

var tab_buttons: Dictionary = {}
var inventory_filter := "all"
var selected_item_id := ""
var selected_equipment_slot := ""
var selected_skill_branch := "offense"
var selected_skill_id := ""
var journal_filter := "all"
var selected_quest_key := ""
var options_category := "audio"
var show_item_details := false
var menu_text_scale := 1.0
var high_contrast := false

func _style(color: Color = Color(0.030, 0.033, 0.044, 0.98)) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color("#e8c981") if high_contrast else Color(0.45, 0.34, 0.20, 0.82)
    style.set_border_width_all(2 if high_contrast else 1)
    style.set_corner_radius_all(7)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _label(text: String, size: int = 15, color: Color = Color("#e5dccb")) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", maxi(11, int(round(float(size) * menu_text_scale))))
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(text: String, callback: Callable, min_size: Vector2 = Vector2(180, 44)) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = min_size
    button.add_theme_font_size_override("font_size", maxi(12, int(round(15.0 * menu_text_scale))))
    button.add_theme_color_override("font_color", Color("#e5dccb"))
    button.add_theme_stylebox_override("normal", _style())
    button.add_theme_stylebox_override("hover", _style(Color(0.11, 0.085, 0.06, 0.99)))
    button.pressed.connect(callback)
    return button

func _build_overlay() -> void:
    tab_buttons.clear()
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.006, 0.008, 0.013, 0.965)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(dim)

    var frame := PanelContainer.new()
    frame.position = Vector2(34, 26)
    frame.size = Vector2(1212, 666)
    frame.add_theme_stylebox_override("panel", _style(Color(0.016, 0.018, 0.025, 0.995)))
    overlay.add_child(frame)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    frame.add_child(root)

    var header := HBoxContainer.new()
    header.custom_minimum_size = Vector2(0, 48)
    root.add_child(header)
    var title := _label("LIGHT IN THE DARK", 22, Color("#d5b26c"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(_label("TAB / M", 12, Color("#a49884")))
    header.add_child(_button("FERMER", func(): close_menu(), Vector2(120, 40)))

    var tab_bar := HBoxContainer.new()
    tab_bar.custom_minimum_size = Vector2(0, 46)
    tab_bar.add_theme_constant_override("separation", 7)
    root.add_child(tab_bar)
    for tab_name in TABS:
        var tab_id := str(tab_name)
        var button := _button(str(TAB_LABELS.get(tab_id, tab_id.to_upper())), func(value = tab_id): _select_tab(str(value)), Vector2(185, 42))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab_bar.add_child(button)
        tab_buttons[tab_id] = button

    var content_panel := PanelContainer.new()
    content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_panel.add_theme_stylebox_override("panel", _style(Color(0.024, 0.027, 0.036, 0.985)))
    root.add_child(content_panel)
    var content_root := VBoxContainer.new()
    content_root.add_theme_constant_override("separation", 7)
    content_panel.add_child(content_root)
    tab_title = _label("", 20, Color("#d5b26c"))
    content_root.add_child(tab_title)
    body = Control.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_root.add_child(body)
    _update_tab_highlight()

func _render_current_tab() -> void:
    _update_tab_highlight()
    super._render_current_tab()

func _select_tab(tab: String) -> void:
    if tab not in TABS:
        return
    current_tab = tab
    show_item_details = false
    _render_current_tab()

func _update_tab_highlight() -> void:
    for key_value in tab_buttons.keys():
        var key := str(key_value)
        var button: Button = tab_buttons.get(key)
        if button == null:
            continue
        var selected := key == current_tab
        button.add_theme_color_override("font_color", Color("#f2d99b") if selected else Color("#c8bda9"))
        button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.075, 0.045, 0.99) if selected else Color(0.030, 0.033, 0.044, 0.98)))

func _two_panes(left_width: float = 520.0) -> Array:
    var row := HBoxContainer.new()
    row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    row.add_theme_constant_override("separation", 12)
    body.add_child(row)
    var left := _pane(row, left_width)
    var right := _pane(row, 0.0)
    return [left, right]

func _pane(parent: HBoxContainer, min_width: float) -> VBoxContainer:
    var panel := PanelContainer.new()
    if min_width > 0.0:
        panel.custom_minimum_size = Vector2(min_width, 0)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", _style(Color(0.019, 0.022, 0.030, 0.98)))
    parent.add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(maxf(420.0, min_width - 28.0), 0)
    column.add_theme_constant_override("separation", 8)
    scroll.add_child(column)
    return column

func _compact_hero_selector(parent: VBoxContainer) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        var selected := hero_id == selected_hero_id
        var button := _button("%s%s · %d" % ["◆ " if selected else "", str(hero.get("name", "Héros")), int(hero.get("level", 1))], func(value = hero_id):
            selected_hero_id = str(value)
            selected_item_id = ""
            selected_skill_id = ""
            _render_current_tab(), Vector2(175, 40))
        row.add_child(button)

func _render_inventory() -> void:
    var panes := _two_panes(570.0)
    var left: VBoxContainer = panes[0]
    var right: VBoxContainer = panes[1]

    var filter_row := HBoxContainer.new()
    filter_row.add_theme_constant_override("separation", 5)
    left.add_child(filter_row)
    for filter_id in ["all", "equipment", "consumable", "quest"]:
        var id := str(filter_id)
        var button := _button("%s%s" % ["◆ " if inventory_filter == id else "", str(FILTER_LABELS.get(id, id.to_upper()))], func(value = id):
            inventory_filter = str(value)
            selected_item_id = ""
            show_item_details = false
            _render_current_tab(), Vector2(128, 38))
        filter_row.add_child(button)

    if ExpeditionManager.expedition_active:
        var inv: Dictionary = ExpeditionManager.inventory
        var runtime: Node = ExpeditionManager.roguelike_runtime
        var cargo: Array = runtime.active_run.get("cargo", []) if runtime != null else []
        left.add_child(_label("Sac %d/%d · Lumière %d · Butin non sécurisé %d" % [
            ExpeditionManager.inventory_slots_used(), ExpeditionManager.inventory_capacity(), int(inv.get("light", 0)), cargo.size()
        ], 12, Color("#a49884")))

    var items := _filtered_items()
    if items.is_empty():
        left.add_child(_label("Aucun objet dans cette catégorie.", 14, Color("#a49884")))
    else:
        var grid := GridContainer.new()
        grid.columns = 2
        grid.add_theme_constant_override("h_separation", 7)
        grid.add_theme_constant_override("v_separation", 7)
        left.add_child(grid)
        for item_value in items:
            var item: Dictionary = item_value
            var instance_id := str(item.get("instance_id", ""))
            var selected := instance_id == selected_item_id
            var rarity := str(item.get("rarity", "common")).to_upper()
            var button := _button("%s%s\n%s" % ["◆ " if selected else "", str(item.get("name", "Objet")), rarity], func(value = instance_id):
                selected_item_id = str(value)
                show_item_details = false
                _render_current_tab(), Vector2(255, 60))
            grid.add_child(button)

    _render_item_detail(right, selected_item_id, false)

func _filtered_items() -> Array:
    var result: Array = []
    for item_value in EquipmentManager.items:
        var item: Dictionary = item_value
        if inventory_filter == "all" or _inventory_category(item) == inventory_filter:
            result.append(item)
    return result

func _inventory_category(item: Dictionary) -> String:
    var explicit := str(item.get("category", item.get("type", ""))).to_lower()
    if explicit in ["quest", "quest_item", "key_item"]:
        return "quest"
    if explicit in ["consumable", "supply", "potion", "food"]:
        return "consumable"
    if str(item.get("slot", "")) in ["weapon", "armor", "ring", "necklace"]:
        return "equipment"
    return "other"

func _render_item_detail(parent: VBoxContainer, instance_id: String, allow_equip: bool) -> void:
    if instance_id == "":
        parent.add_child(_label("SÉLECTION", 15, Color("#d5b26c")))
        parent.add_child(_label("Choisissez un objet pour afficher ses informations utiles.", 14, Color("#a49884")))
        return
    var item := EquipmentManager.get_instance(instance_id)
    if item.is_empty():
        parent.add_child(_label("Cet objet n'est plus disponible.", 14, Color("#a49884")))
        return
    var hero_level := EquipmentManager.level_for_class(str(item.get("class_id", "")))
    parent.add_child(_label(str(item.get("name", "Objet")), 19, Color("#e5dccb")))
    parent.add_child(_label("%s · %s" % [str(item.get("rarity", "common")).to_upper(), _slot_label(str(item.get("slot", "")))], 12, Color("#d5b26c")))

    var bonuses: Dictionary = EquipmentManager.effective_bonuses_for_level(item, hero_level)
    var keys := bonuses.keys()
    var visible_count := keys.size() if show_item_details else mini(3, keys.size())
    for index in range(visible_count):
        var key := str(keys[index])
        parent.add_child(_label("%s %+d" % [_short_stat_label(key), int(bonuses.get(key, 0))], 13, Color("#e5dccb")))
    if keys.size() > 3:
        parent.add_child(_button("MOINS DE DÉTAILS" if show_item_details else "DÉTAILS", func():
            show_item_details = not show_item_details
            _render_current_tab(), Vector2(170, 38)))
    if show_item_details:
        parent.add_child(HSeparator.new())
        parent.add_child(_label(EquipmentManager.describe_item(item, hero_level), 12, Color("#a49884")))
    if str(item.get("slot", "")) in ["weapon", "armor", "ring", "necklace"]:
        if allow_equip:
            parent.add_child(_button("ÉQUIPER", func():
                if EquipmentManager.equip(selected_hero_id, instance_id):
                    SaveManager.save_game()
                    selected_item_id = ""
                _render_current_tab(), Vector2(150, 42)))
        else:
            parent.add_child(_button("VOIR DANS ÉQUIPEMENT", func():
                selected_equipment_slot = _normalized_slot(str(item.get("slot", "")))
                current_tab = "equipment"
                _render_current_tab(), Vector2(230, 42)))

func _short_stat_label(stat: String) -> String:
    return str({
        "damage_bonus":"Dégâts", "damage_percent":"Dégâts %", "critical_chance":"Critique", "physical_resistance":"Défense",
        "fear_resistance":"Rés. peur", "madness_resistance":"Rés. folie", "guard_power":"Garde", "max_hp":"PV",
        "max_hope":"Espoir", "precision":"Précision", "healing_power":"Soins", "riposte_chance":"Riposte"
    }.get(stat, stat.replace("_", " ").capitalize()))

func _render_equipment() -> void:
    var panes := _two_panes(620.0)
    var left: VBoxContainer = panes[0]
    var right: VBoxContainer = panes[1]
    _compact_hero_selector(left)
    var hero := _hero_by_id(selected_hero_id)
    if hero.is_empty():
        left.add_child(_label("Aucun héros sélectionné.", 14, Color("#a49884")))
        return

    var slots: Dictionary = EquipmentManager.equipped_by_hero.get(selected_hero_id, {})
    var layout := GridContainer.new()
    layout.columns = 3
    layout.add_theme_constant_override("h_separation", 8)
    layout.add_theme_constant_override("v_separation", 8)
    left.add_child(layout)
    _add_slot_button(layout, "weapon", slots)
    _add_hero_silhouette(layout, hero)
    _add_slot_button(layout, "armor", slots)
    _add_slot_button(layout, "ring_1", slots)
    layout.add_child(_label("", 12, Color("#a49884")))
    _add_slot_button(layout, "ring_2", slots)
    layout.add_child(_label("", 12, Color("#a49884")))
    _add_key_stats(layout, hero)
    _add_slot_button(layout, "necklace", slots)

    if selected_equipment_slot == "":
        right.add_child(_label("ÉQUIPEMENT", 15, Color("#d5b26c")))
        right.add_child(_label("Choisissez un emplacement autour du héros.", 14, Color("#a49884")))
        return
    right.add_child(_label(_slot_label(selected_equipment_slot).to_upper(), 17, Color("#d5b26c")))
    var compatible := _compatible_items_for_slot(hero, selected_equipment_slot)
    if compatible.is_empty():
        right.add_child(_label("Aucun objet compatible dans l'inventaire.", 13, Color("#a49884")))
        return
    for item_value in compatible:
        var item: Dictionary = item_value
        var item_id := str(item.get("instance_id", ""))
        right.add_child(_button("%s%s · %s" % ["◆ " if selected_item_id == item_id else "", str(item.get("name", "Objet")), str(item.get("rarity", "common")).to_upper()], func(value = item_id):
            selected_item_id = str(value)
            show_item_details = false
            _render_current_tab(), Vector2(430, 44)))
    if selected_item_id != "":
        right.add_child(HSeparator.new())
        _render_item_detail(right, selected_item_id, true)

func _add_slot_button(parent: GridContainer, slot_name: String, slots: Dictionary) -> void:
    var item := EquipmentManager.get_instance(str(slots.get(slot_name, "")))
    var item_name := "Vide" if item.is_empty() else str(item.get("name", "Objet"))
    var selected := selected_equipment_slot == slot_name
    parent.add_child(_button("%s%s\n%s" % ["◆ " if selected else "", _slot_label(slot_name), item_name], func(value = slot_name):
        selected_equipment_slot = str(value)
        selected_item_id = ""
        show_item_details = false
        _render_current_tab(), Vector2(175, 82)))

func _add_hero_silhouette(parent: GridContainer, hero: Dictionary) -> void:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(220, 170)
    panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.032, 0.030, 0.98)))
    parent.add_child(panel)
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(column)
    var name := _label(str(hero.get("name", "Héros")).to_upper(), 19, Color("#d5b26c"))
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(name)
    var level := _label("NIVEAU %d" % int(hero.get("level", 1)), 13, Color("#a49884"))
    level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(level)
    var silhouette := _label("◇\nPERSONNAGE\n◇", 16, Color("#8f8068"))
    silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(silhouette)

func _add_key_stats(parent: GridContainer, hero: Dictionary) -> void:
    var bonuses: Dictionary = EquipmentManager.bonuses_for_hero(selected_hero_id)
    var text := "PV %d/%d\nDégâts %+d · Crit %+d%%\nGarde %+d · Rés. folie %+d" % [
        int(hero.get("hp", 0)), int(hero.get("max_hp", 0)), int(bonuses.get("damage_bonus", 0)),
        int(bonuses.get("critical_chance", 0)), int(bonuses.get("guard_power", 0)), int(bonuses.get("madness_resistance", 0))
    ]
    var label := _label(text, 12, Color("#c8bda9"))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)

func _compatible_items_for_slot(hero: Dictionary, slot_name: String) -> Array:
    var result: Array = []
    var normalized := _normalized_slot(slot_name)
    for item_value in EquipmentManager.items:
        var item: Dictionary = item_value
        if _normalized_slot(str(item.get("slot", ""))) != normalized:
            continue
        var class_id := str(item.get("class_id", ""))
        if class_id != "" and class_id != str(hero.get("class_id", "")):
            continue
        result.append(item)
    return result

func _normalized_slot(slot_name: String) -> String:
    return "ring" if slot_name in ["ring", "ring_1", "ring_2"] else slot_name

func _slot_label(slot_name: String) -> String:
    return str({"weapon":"Arme", "armor":"Armure", "ring":"Anneau", "ring_1":"Anneau I", "ring_2":"Anneau II", "necklace":"Collier"}.get(slot_name, slot_name.capitalize()))

func _render_skills() -> void:
    var panes := _two_panes(610.0)
    var left: VBoxContainer = panes[0]
    var right: VBoxContainer = panes[1]
    _compact_hero_selector(left)
    var hero := _hero_by_id(selected_hero_id)
    if hero.is_empty():
        left.add_child(_label("Aucun héros sélectionné.", 14, Color("#a49884")))
        return

    left.add_child(_label("Niveau %d · %d point(s) disponible(s)" % [int(hero.get("level", 1)), int(hero.get("skill_points", 0))], 13, Color("#a49884")))
    var branch_row := HBoxContainer.new()
    branch_row.add_theme_constant_override("separation", 5)
    left.add_child(branch_row)
    for branch_value in HeroSkillManager.BRANCHES:
        var branch := str(branch_value)
        branch_row.add_child(_button("%s%s" % ["◆ " if selected_skill_branch == branch else "", _branch_label(branch)], func(value = branch):
            selected_skill_branch = str(value)
            selected_skill_id = ""
            _render_current_tab(), Vector2(180, 40)))

    var specialization := str(hero.get("specialization", ""))
    if specialization != "" and specialization != selected_skill_branch and not HeroSkillManager.multi_tree_enabled():
        left.add_child(_label("VOIE VERROUILLÉE · La spécialisation choisie est %s." % _branch_label(specialization), 12, Color("#b95b5b")))
    elif specialization == selected_skill_branch:
        left.add_child(_label("VOIE CHOISIE", 12, Color("#d5b26c")))

    var nodes: Array = HeroSkillManager.skill_nodes(hero, selected_skill_branch)
    for index in range(nodes.size()):
        var node: Dictionary = nodes[index]
        var skill_id := str(node.get("id", ""))
        var unlocked := (hero.get("unlocked_skills", []) as Array).has(skill_id)
        var can_unlock := HeroSkillManager.can_unlock(hero, skill_id)
        var status := "ACQUISE" if unlocked else ("DISPONIBLE" if can_unlock else "VERROUILLÉE")
        left.add_child(_button("%02d · %s · niv.%d\n%s" % [index + 1, str(node.get("name", "Compétence")), int(node.get("required_level", 1)), status], func(value = skill_id):
            selected_skill_id = str(value)
            _render_current_tab(), Vector2(555, 50)))

    if selected_skill_id == "":
        right.add_child(_label("COMPÉTENCE", 15, Color("#d5b26c")))
        right.add_child(_label("Sélectionnez un nœud de l'arbre pour voir son effet et ses prérequis.", 14, Color("#a49884")))
        return
    var selected_node := _skill_node_by_id(hero, selected_skill_branch, selected_skill_id)
    if selected_node.is_empty():
        return
    _render_skill_detail(right, hero, selected_node)

func _skill_node_by_id(hero: Dictionary, branch: String, skill_id: String) -> Dictionary:
    for node_value in HeroSkillManager.skill_nodes(hero, branch):
        var node: Dictionary = node_value
        if str(node.get("id", "")) == skill_id:
            return node
    return {}

func _render_skill_detail(parent: VBoxContainer, hero: Dictionary, node: Dictionary) -> void:
    var skill_id := str(node.get("id", ""))
    var unlocked := (hero.get("unlocked_skills", []) as Array).has(skill_id)
    var can_unlock := HeroSkillManager.can_unlock(hero, skill_id)
    parent.add_child(_label(str(node.get("name", "Compétence")), 19, Color("#e5dccb")))
    parent.add_child(_label(_branch_label(selected_skill_branch), 12, Color("#d5b26c")))
    parent.add_child(_label(str(node.get("description", "")), 14, Color("#e5dccb")))
    parent.add_child(HSeparator.new())
    parent.add_child(_label("Niveau requis : %d" % int(node.get("required_level", 1)), 13, Color("#a49884")))
    parent.add_child(_label("Coût : %d point(s)" % int(node.get("cost", 1)), 13, Color("#a49884")))
    var requires := str(node.get("requires", ""))
    if requires != "":
        parent.add_child(_label("Prérequis : compétence précédente", 13, Color("#a49884")))
    parent.add_child(_label("Statut : %s" % ("ACQUISE" if unlocked else ("DÉBLOCABLE" if can_unlock else "VERROUILLÉE")), 13, Color("#d5b26c") if unlocked or can_unlock else Color("#b95b5b")))
    var unlock_button := _button("DÉBLOQUER", func():
        if HeroSkillManager.unlock(hero, skill_id):
            SaveManager.save_game()
        _render_current_tab(), Vector2(180, 42))
    unlock_button.disabled = not can_unlock
    parent.add_child(unlock_button)

func _render_journal() -> void:
    var panes := _two_panes(560.0)
    var left: VBoxContainer = panes[0]
    var right: VBoxContainer = panes[1]
    var filters := HBoxContainer.new()
    filters.add_theme_constant_override("separation", 5)
    left.add_child(filters)
    var filter_defs := {"all":"TOUTES", "campaign":"CAMPAGNE", "dungeon":"DONJON", "completed":"TERMINÉES"}
    for filter_value in ["all", "campaign", "dungeon", "completed"]:
        var filter_id := str(filter_value)
        filters.add_child(_button("%s%s" % ["◆ " if journal_filter == filter_id else "", str(filter_defs[filter_id])], func(value = filter_id):
            journal_filter = str(value)
            selected_quest_key = ""
            _render_current_tab(), Vector2(125, 38)))

    var entries := _journal_entries()
    var shown := 0
    for entry_value in entries:
        var entry: Dictionary = entry_value
        if not _journal_entry_matches(entry):
            continue
        shown += 1
        var key := str(entry.get("key", ""))
        left.add_child(_button("%s[%s] %s\n%s" % [
            "◆ " if selected_quest_key == key else "", str(entry.get("type", "")).to_upper(), str(entry.get("name", "Quête")), str(entry.get("status", ""))
        ], func(value = key):
            selected_quest_key = str(value)
            _render_current_tab(), Vector2(510, 58)))
    if shown == 0:
        left.add_child(_label("Aucune quête dans ce filtre.", 14, Color("#a49884")))

    var selected := _journal_entry_by_key(entries, selected_quest_key)
    if selected.is_empty():
        right.add_child(_label("QUÊTE", 15, Color("#d5b26c")))
        right.add_child(_label("Sélectionnez une quête pour afficher uniquement son objectif et son contexte.", 14, Color("#a49884")))
        return
    _render_quest_detail(right, selected)

func _journal_entries() -> Array:
    var result: Array = []
    var chapter := CampaignState.current_chapter()
    var chapter_title := "Chapitre %d — %s" % [CampaignState.current_chapter_number(), str(chapter.get("title", ""))]
    var index := 0
    for quest_value in CampaignState.active_main_quests():
        var quest: Dictionary = quest_value
        result.append({"key":"campaign_main_%d" % index, "type":"campaign", "name":str(quest.get("name", "Quête principale")), "status":"EN COURS", "objective":str(quest.get("goal", "")), "location":chapter_title})
        index += 1
    index = 0
    for quest_value in PoliticalState.available_quests():
        var quest: Dictionary = quest_value
        result.append({"key":"campaign_local_%d" % index, "type":"campaign", "name":str(quest.get("name", "Décision locale")), "status":"DISPONIBLE", "objective":str(quest.get("theme", "")), "location":"Sanctuaire / campagne"})
        index += 1
    var dungeon_context := level_scaling_context()
    for quest_value in DataLoader.quests:
        var quest: Dictionary = quest_value
        if str(quest.get("quest_type", "dungeon")).to_lower() != "dungeon":
            continue
        result.append({
            "key":"dungeon_%s" % str(quest.get("id", "quest")), "type":"dungeon", "name":str(quest.get("name", "Quête de donjon")),
            "status":_dungeon_quest_status(quest), "objective":str(quest.get("description", "")),
            "location":"%s · niveau requis %d" % [str(dungeon_context.get("title", "Donjon")), int(dungeon_context.get("required_level", 1))]
        })
    return result

func _journal_entry_matches(entry: Dictionary) -> bool:
    if journal_filter == "all":
        return true
    if journal_filter == "completed":
        return str(entry.get("status", "")) == "TERMINÉE"
    return str(entry.get("type", "")) == journal_filter

func _journal_entry_by_key(entries: Array, key: String) -> Dictionary:
    for entry_value in entries:
        var entry: Dictionary = entry_value
        if str(entry.get("key", "")) == key:
            return entry
    return {}

func _render_quest_detail(parent: VBoxContainer, entry: Dictionary) -> void:
    var kind := str(entry.get("type", "campaign")).to_upper()
    parent.add_child(_label("[%s]" % kind, 12, Color("#d5b26c")))
    parent.add_child(_label(str(entry.get("name", "Quête")), 19, Color("#e5dccb")))
    parent.add_child(_label(str(entry.get("status", "")), 13, Color("#d5b26c")))
    parent.add_child(HSeparator.new())
    parent.add_child(_label("OBJECTIF", 12, Color("#a49884")))
    parent.add_child(_label(str(entry.get("objective", "")), 14, Color("#e5dccb")))
    parent.add_child(_label("LIEU / CONTEXTE", 12, Color("#a49884")))
    parent.add_child(_label(str(entry.get("location", "")), 13, Color("#c8bda9")))

func _render_options() -> void:
    var column := _scroll_column()
    var categories := HBoxContainer.new()
    categories.add_theme_constant_override("separation", 6)
    column.add_child(categories)
    var labels := {"audio":"AUDIO", "display":"AFFICHAGE", "controls":"CONTRÔLES", "accessibility":"ACCESSIBILITÉ"}
    for category_value in ["audio", "display", "controls", "accessibility"]:
        var category := str(category_value)
        categories.add_child(_button("%s%s" % ["◆ " if options_category == category else "", str(labels[category])], func(value = category):
            options_category = str(value)
            _render_current_tab(), Vector2(190, 40)))
    column.add_child(HSeparator.new())
    match options_category:
        "audio": _render_audio_options(column)
        "display": _render_display_options(column)
        "controls": _render_controls_options(column)
        "accessibility": _render_accessibility_options(column)

func _render_audio_options(parent: VBoxContainer) -> void:
    parent.add_child(_label("AUDIO", 17, Color("#d5b26c")))
    _add_volume_row(parent, "Master", "Volume général")
    _add_volume_row(parent, "Music", "Musique")
    _add_volume_row(parent, "SFX", "Effets sonores")

func _render_display_options(parent: VBoxContainer) -> void:
    parent.add_child(_label("AFFICHAGE", 17, Color("#d5b26c")))
    var fullscreen := CheckButton.new()
    fullscreen.text = "Plein écran"
    fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    fullscreen.toggled.connect(func(enabled: bool):
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
        _save_options())
    parent.add_child(fullscreen)
    var vsync := CheckButton.new()
    vsync.text = "Synchronisation verticale"
    vsync.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
    vsync.toggled.connect(func(enabled: bool):
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
        _save_options())
    parent.add_child(vsync)

func _render_controls_options(parent: VBoxContainer) -> void:
    parent.add_child(_label("CONTRÔLES ESSENTIELS", 17, Color("#d5b26c")))
    parent.add_child(_label("Menu contextuel  ·  TAB ou M", 14, Color("#e5dccb")))
    parent.add_child(_label("Fermer / retour     ·  Échap", 14, Color("#e5dccb")))
    parent.add_child(_label("Interagir           ·  E ou Espace", 14, Color("#e5dccb")))
    parent.add_child(_label("Déplacement         ·  ZQSD / WASD / flèches", 14, Color("#e5dccb")))
    parent.add_child(_label("Seules les commandes utiles sont affichées ici. Les détails avancés restent hors de cet écran.", 12, Color("#a49884")))

func _render_accessibility_options(parent: VBoxContainer) -> void:
    parent.add_child(_label("ACCESSIBILITÉ DU MENU", 17, Color("#d5b26c")))
    parent.add_child(_label("Taille du texte", 13, Color("#a49884")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    for scale_value in [1.0, 1.15, 1.30]:
        var scale := float(scale_value)
        row.add_child(_button("%s%d %%" % ["◆ " if is_equal_approx(menu_text_scale, scale) else "", int(round(scale * 100.0))], func(value = scale):
            menu_text_scale = float(value)
            _save_options()
            _rebuild_overlay_keep_state(), Vector2(130, 40)))
    var contrast := CheckButton.new()
    contrast.text = "Contraste renforcé"
    contrast.button_pressed = high_contrast
    contrast.toggled.connect(func(enabled: bool):
        high_contrast = enabled
        _save_options()
        _rebuild_overlay_keep_state())
    parent.add_child(contrast)
    parent.add_child(_label("Le menu conserve toujours texte + libellé : aucune information importante ne dépend uniquement d'une couleur.", 12, Color("#a49884")))

func _rebuild_overlay_keep_state() -> void:
    var was_visible := overlay != null and overlay.visible
    if overlay != null:
        remove_child(overlay)
        overlay.free()
        overlay = null
    _build_overlay()
    overlay.visible = was_visible
    launcher.visible = not was_visible and current_screen != "title"
    if was_visible:
        _render_current_tab()

func _save_options() -> void:
    super._save_options()
    var config := ConfigFile.new()
    config.load(SETTINGS_PATH)
    config.set_value("accessibility", "menu_text_scale", menu_text_scale)
    config.set_value("accessibility", "high_contrast", high_contrast)
    config.save(SETTINGS_PATH)

func _load_options() -> void:
    super._load_options()
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return
    menu_text_scale = clampf(float(config.get_value("accessibility", "menu_text_scale", 1.0)), 1.0, 1.30)
    high_contrast = bool(config.get_value("accessibility", "high_contrast", false))