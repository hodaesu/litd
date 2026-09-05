extends CanvasLayer
class_name VeilleursSkillTreeOverlay

var open_button: Button
var overlay: ColorRect
var watcher_row: HBoxContainer
var branch_row: HBoxContainer
var skill_list: VBoxContainer
var detail: VBoxContainer
var selected_watcher_id := "nayra_orun"
var selected_branch := ""
var selected_skill_id := ""

func _ready() -> void:
    layer = 41
    _build()
    get_viewport().size_changed.connect(_apply_layout)
    _select_existing_watcher()
    _refresh()
    _apply_layout()

func _build() -> void:
    open_button = Button.new()
    open_button.text = "ARBRES"
    open_button.custom_minimum_size = Vector2(118, 54)
    open_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    open_button.offset_left = -396
    open_button.offset_right = -274
    open_button.offset_top = -72
    open_button.offset_bottom = -16
    open_button.pressed.connect(_toggle)
    add_child(open_button)

    overlay = ColorRect.new()
    overlay.color = Color(0.012, 0.014, 0.02, 0.97)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    add_child(overlay)

    var frame := PanelContainer.new()
    frame.name = "SkillTreeFrame"
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frame.offset_left = 18
    frame.offset_top = 18
    frame.offset_right = -18
    frame.offset_bottom = -18
    overlay.add_child(frame)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    frame.add_child(root)

    var header := HBoxContainer.new()
    header.custom_minimum_size = Vector2(0, 56)
    root.add_child(header)
    var title := Label.new()
    title.text = "LES VEILLEURS · ARBRES CANONIQUES"
    title.add_theme_font_size_override("font_size", 22)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close := Button.new()
    close.text = "FERMER"
    close.custom_minimum_size = Vector2(120, 54)
    close.pressed.connect(_toggle)
    header.add_child(close)

    watcher_row = HBoxContainer.new()
    watcher_row.add_theme_constant_override("separation", 6)
    root.add_child(watcher_row)
    branch_row = HBoxContainer.new()
    branch_row.add_theme_constant_override("separation", 6)
    root.add_child(branch_row)

    var body := HBoxContainer.new()
    body.name = "SkillTreeBody"
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 10)
    root.add_child(body)

    var left_panel := PanelContainer.new()
    left_panel.custom_minimum_size = Vector2(610, 0)
    left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(left_panel)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left_panel.add_child(scroll)
    skill_list = VBoxContainer.new()
    skill_list.custom_minimum_size = Vector2(575, 0)
    skill_list.add_theme_constant_override("separation", 6)
    scroll.add_child(skill_list)

    var right_panel := PanelContainer.new()
    right_panel.name = "SkillDetailPanel"
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(right_panel)
    detail = VBoxContainer.new()
    detail.add_theme_constant_override("separation", 8)
    right_panel.add_child(detail)

func _select_existing_watcher() -> void:
    for hero_value: Variant in GameState.party:
        if hero_value is Dictionary and VeilleursSkillCatalog.is_watcher(hero_value):
            selected_watcher_id = str((hero_value as Dictionary).get("id", selected_watcher_id))
            break

func _toggle() -> void:
    overlay.visible = not overlay.visible
    if overlay.visible:
        _refresh()

func _refresh() -> void:
    var hero := _selected_hero()
    if hero.is_empty():
        overlay.visible = false
        open_button.visible = false
        return
    open_button.visible = true
    _refresh_watchers()
    var branches := HeroSkillManager.branches_for(hero)
    if selected_branch == "" or not branches.has(selected_branch):
        selected_branch = str(branches[0]) if not branches.is_empty() else ""
    _refresh_branches(hero)
    _refresh_skills(hero)
    _refresh_detail(hero)

func _refresh_watchers() -> void:
    _clear(watcher_row)
    for hero_value: Variant in GameState.party:
        if not (hero_value is Dictionary):
            continue
        var hero: Dictionary = hero_value
        if not VeilleursSkillCatalog.is_watcher(hero):
            continue
        var id := str(hero.get("id", ""))
        var button := Button.new()
        button.text = ("◆ " if id == selected_watcher_id else "") + str(hero.get("name", id))
        button.custom_minimum_size = Vector2(190, 50)
        button.pressed.connect(_select_watcher.bind(id))
        watcher_row.add_child(button)

func _refresh_branches(hero: Dictionary) -> void:
    _clear(branch_row)
    var specialization := str(hero.get("specialization", ""))
    for branch in HeroSkillManager.branches_for(hero):
        var branch_id := str(branch)
        var suffix := ""
        if specialization == branch_id:
            suffix = " · CHOISI"
        elif specialization != "":
            suffix = " · VERROUILLÉ"
        var button := Button.new()
        button.text = ("◆ " if branch_id == selected_branch else "") + HeroSkillManager.branch_label(hero, branch_id).to_upper() + suffix
        button.custom_minimum_size = Vector2(230, 50)
        button.pressed.connect(_select_branch.bind(branch_id))
        branch_row.add_child(button)

func _refresh_skills(hero: Dictionary) -> void:
    _clear(skill_list)
    var nodes := HeroSkillManager.skill_nodes(hero, selected_branch)
    for value: Variant in nodes:
        var node: Dictionary = value
        var id := str(node.get("id", ""))
        var unlocked := (hero.get("unlocked_skills", []) as Array).has(id)
        var resolver := str(node.get("resolver_status", "required"))
        var runtime_label := "CONTEXTE PRÊT" if resolver == "implemented" else "RUNTIME REQUIS"
        var button := Button.new()
        button.text = "%sN%d · %s\n%s · %s" % ["◆ " if id == selected_skill_id else "", int(node.get("required_level", 1)), str(node.get("name", id)), "ACQUIS" if unlocked else str(node.get("canonical_type", "")), runtime_label]
        button.custom_minimum_size = Vector2(560, 62)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.pressed.connect(_select_skill.bind(id))
        skill_list.add_child(button)

func _refresh_detail(hero: Dictionary) -> void:
    _clear(detail)
    var node := _node_by_id(hero, selected_skill_id)
    if node.is_empty():
        detail.add_child(_label("Sélectionnez une compétence.", 17))
        _append_ultimate(hero)
        return
    detail.add_child(_label(str(node.get("name", "Technique")), 22))
    detail.add_child(_label("%s · Niveau %d · coût %d" % [str(node.get("canonical_type", "")), int(node.get("required_level", 1)), int(node.get("cost", 0))], 14))
    detail.add_child(_label(str(node.get("description", "")), 15))
    detail.add_child(_label("Cible : %s\nImpacts : %s\nPrécision : %d%% · puissance %.1f/5" % [str(node.get("canonical_target", "")), str(node.get("canonical_impacts", "")), int(node.get("base_accuracy_pct", 100)), float(node.get("power_0_5", 0.0))], 13))
    detail.add_child(_label("Resolver : %s · %s" % [str(node.get("resolver_id", "")), str(node.get("resolver_status", "required"))], 13))
    var unlocked := (hero.get("unlocked_skills", []) as Array).has(str(node.get("id", "")))
    if not unlocked:
        var unlock := Button.new()
        unlock.text = "DÉBLOQUER"
        unlock.custom_minimum_size = Vector2(240, 56)
        unlock.disabled = not HeroSkillManager.can_unlock(hero, str(node.get("id", "")))
        unlock.pressed.connect(_unlock_selected)
        detail.add_child(unlock)
    elif bool(node.get("manual_combat_usable", false)):
        detail.add_child(_label("Cette technique possède un resolver manuel utilisable.", 13))
    else:
        detail.add_child(_label("Compétence canonique acquise. Son resolver spécialisé doit être prêt avant équipement manuel.", 13))
    _append_ultimate(hero)

func _append_ultimate(hero: Dictionary) -> void:
    if selected_branch == "":
        return
    var ultimate := HeroSkillManager.ultimate_for(hero, selected_branch)
    if ultimate.is_empty():
        return
    var sep := HSeparator.new()
    detail.add_child(sep)
    detail.add_child(_label("ULTIME · %s" % str(ultimate.get("name", "")), 18))
    detail.add_child(_label("Charges disponibles : %d · maximum 1 activation du même ultime par rencontre\n%s" % [int(ultimate.get("available_charges", 0)), str(ultimate.get("mechanic", ""))], 13))
    detail.add_child(_label("Resolver : ultimate_sequence · requis", 12))

func _select_watcher(id: String) -> void:
    selected_watcher_id = id
    selected_branch = ""
    selected_skill_id = ""
    _refresh()

func _select_branch(branch: String) -> void:
    selected_branch = branch
    selected_skill_id = ""
    _refresh()

func _select_skill(skill_id: String) -> void:
    selected_skill_id = skill_id
    _refresh()

func _unlock_selected() -> void:
    var hero := _selected_hero()
    if hero.is_empty() or selected_skill_id == "":
        return
    HeroSkillManager.unlock(hero, selected_skill_id)
    _refresh()
    SaveManager.autosave("VS001 · compétence %s" % selected_skill_id)

func _selected_hero() -> Dictionary:
    for value: Variant in GameState.party:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == selected_watcher_id:
            return value
    return {}

func _node_by_id(hero: Dictionary, skill_id: String) -> Dictionary:
    if skill_id == "":
        return {}
    for branch in HeroSkillManager.branches_for(hero):
        for value: Variant in HeroSkillManager.skill_nodes(hero, str(branch)):
            if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
                return value
    return {}

func _label(text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _clear(parent: Node) -> void:
    for child: Node in parent.get_children():
        child.queue_free()

func _apply_layout() -> void:
    if overlay == null:
        return
    var phone := get_viewport().get_visible_rect().size.x < 950
    var body := overlay.get_node_or_null("SkillTreeFrame/VBoxContainer/SkillTreeBody")
    if body is HBoxContainer:
        (body as HBoxContainer).vertical = false if "vertical" in body else false
    # On phone, the overlay remains full-screen and scrollable; all actions stay >= 50 px.
    open_button.custom_minimum_size = Vector2(118, 54 if phone else 54)
