extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const DARK := Color(0.015, 0.017, 0.023, 0.97)
const PANEL := Color(0.035, 0.038, 0.050, 0.98)
const RED := Color("#7f1e24")

var launcher: Button
var overlay: Control
var body: Control
var selected_npc_id := "nara_vey"

func _ready() -> void:
    layer = 30
    GameState.screen_requested.connect(_on_screen_requested)
    GameState.state_changed.connect(_on_runtime_changed)
    PoliticalState.politics_changed.connect(_on_politics_changed)
    CreatureManager.creatures_changed.connect(_on_runtime_changed)
    _build_launcher()
    _build_overlay()
    _on_screen_requested(GameState.current_screen)

func _panel_style(color := PANEL) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.45, 0.34, 0.20, 0.82)
    style.set_border_width_all(1)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    return style

func _button(text: String, callback: Callable, size := Vector2(220, 48)) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = size
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_stylebox_override("normal", _panel_style())
    button.add_theme_stylebox_override("hover", _panel_style(Color(0.11, 0.085, 0.06, 0.99)))
    button.pressed.connect(callback)
    return button

func _label(text: String, size := 17, color := TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _build_launcher() -> void:
    launcher = _button("CONCORDE\nDécisions et habitants", func(): GameState.request_screen("politics"), Vector2(230, 70))
    launcher.position = Vector2(790, 535)
    launcher.visible = false
    add_child(launcher)

func _build_overlay() -> void:
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    add_child(overlay)

    var background := ColorRect.new()
    background.color = DARK
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(background)

    var header := HBoxContainer.new()
    header.position = Vector2(24, 18)
    header.size = Vector2(1232, 52)
    header.add_theme_constant_override("separation", 14)
    overlay.add_child(header)

    var title := _label("LA CONCORDE — SANCTUAIRE DU PREMIER VOILE", 25, GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(_button("SAUVEGARDER", func(): SaveManager.save_game(), Vector2(150, 42)))
    header.add_child(_button("RETOUR", func(): GameState.request_screen("sanctuary"), Vector2(130, 42)))

    body = Control.new()
    body.position = Vector2(24, 82)
    body.size = Vector2(1232, 610)
    overlay.add_child(body)

func _on_screen_requested(screen_name: String) -> void:
    if screen_name == "politics":
        launcher.visible = false
        overlay.visible = true
        PoliticalState.refresh_unlocks()
        _render()
    else:
        overlay.visible = false
        launcher.visible = screen_name == "sanctuary"

func _on_runtime_changed() -> void:
    PoliticalState.refresh_unlocks()
    if overlay.visible:
        call_deferred("_render")

func _on_politics_changed() -> void:
    if overlay.visible:
        call_deferred("_render")

func _clear_body() -> void:
    for child in body.get_children():
        child.queue_free()

func _status_text() -> String:
    var awakenings: Dictionary = PoliticalState.three_awakenings
    return "CONFIANCE %d   ·   TENSION %d   ·   RÉPUTATION %+d\nCORPS %d   ·   ESPRIT %d   ·   CITÉ %d   ·   PRIX × %.2f" % [
        PoliticalState.trust,
        PoliticalState.tension,
        PoliticalState.reputation,
        int(awakenings.get("body", 50)),
        int(awakenings.get("spirit", 50)),
        int(awakenings.get("city", 50)),
        PoliticalState.price_modifier()
    ]

func _render() -> void:
    if not is_instance_valid(body) or not overlay.visible:
        return
    _clear_body()

    var status_panel := PanelContainer.new()
    status_panel.position = Vector2(0, 0)
    status_panel.size = Vector2(1232, 72)
    status_panel.add_theme_stylebox_override("panel", _panel_style())
    var status := _label(_status_text(), 16, GOLD)
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_panel.add_child(status)
    body.add_child(status_panel)

    var npc_panel := PanelContainer.new()
    npc_panel.position = Vector2(0, 88)
    npc_panel.size = Vector2(390, 510)
    npc_panel.add_theme_stylebox_override("panel", _panel_style())
    body.add_child(npc_panel)
    var npc_scroll := ScrollContainer.new()
    npc_panel.add_child(npc_scroll)
    var npc_list := VBoxContainer.new()
    npc_list.custom_minimum_size = Vector2(350, 0)
    npc_list.add_theme_constant_override("separation", 7)
    npc_scroll.add_child(npc_list)
    npc_list.add_child(_label("HABITANTS ET VOIX DE LA CONCORDE", 17, GOLD))
    for npc_value in PoliticalState.data.get("npcs", []):
        var npc: Dictionary = npc_value
        var npc_id: String = String(npc.get("id", ""))
        var button_text := "%s\n%s" % [String(npc.get("name", "Habitant")), String(npc.get("role", ""))]
        var npc_button := _button(button_text, func(id_value = npc_id):
            selected_npc_id = String(id_value)
            _render(), Vector2(345, 54))
        npc_button.disabled = npc_id == selected_npc_id
        npc_list.add_child(npc_button)

    var npc_detail := PanelContainer.new()
    npc_detail.position = Vector2(406, 88)
    npc_detail.size = Vector2(390, 235)
    npc_detail.add_theme_stylebox_override("panel", _panel_style())
    body.add_child(npc_detail)
    var npc_box := VBoxContainer.new()
    npc_box.add_theme_constant_override("separation", 7)
    npc_detail.add_child(npc_box)
    var selected: Dictionary = PoliticalState.get_npc(selected_npc_id)
    if selected.is_empty() and not PoliticalState.data.get("npcs", []).is_empty():
        selected = PoliticalState.data.get("npcs", [])[0]
        selected_npc_id = String(selected.get("id", ""))
    npc_box.add_child(_label(String(selected.get("name", "")), 22, GOLD))
    npc_box.add_child(_label(String(selected.get("role", "")), 14, MUTED))
    npc_box.add_child(_label("« %s »" % PoliticalState.get_npc_dialogue(selected_npc_id), 16, TEXT))
    npc_box.add_child(_label(String(selected.get("stance", "")), 13, MUTED))

    var services := PanelContainer.new()
    services.position = Vector2(406, 339)
    services.size = Vector2(390, 259)
    services.add_theme_stylebox_override("panel", _panel_style())
    body.add_child(services)
    var services_box := VBoxContainer.new()
    services_box.add_theme_constant_override("separation", 7)
    services.add_child(services_box)
    services_box.add_child(_label("ÉTAT DU SANCTUAIRE", 17, GOLD))
    var service_names := {
        "mediation": "Médiation civique",
        "creature_habitat": "Habitat des créatures",
        "volunteer_watch": "Veille volontaire",
        "shared_archive": "Archives partagées"
    }
    for service_id in service_names.keys():
        var unlocked: bool = PoliticalState.service_unlocked(String(service_id))
        services_box.add_child(_label("%s  %s" % ["✓" if unlocked else "—", String(service_names[service_id])], 14, TEXT if unlocked else MUTED))
    services_box.add_child(_label("Les services dépendent directement de la confiance et des Trois Éveils.", 13, MUTED))

    var quest_panel := PanelContainer.new()
    quest_panel.position = Vector2(812, 88)
    quest_panel.size = Vector2(420, 510)
    quest_panel.add_theme_stylebox_override("panel", _panel_style())
    body.add_child(quest_panel)
    var quest_scroll := ScrollContainer.new()
    quest_panel.add_child(quest_scroll)
    var quest_list := VBoxContainer.new()
    quest_list.custom_minimum_size = Vector2(385, 0)
    quest_list.add_theme_constant_override("separation", 9)
    quest_scroll.add_child(quest_list)
    quest_list.add_child(_label("DÉCISIONS", 18, GOLD))

    var available := PoliticalState.available_quests()
    if available.is_empty():
        quest_list.add_child(_label("Aucune décision urgente. Explorez, ramenez des survivants et observez les conséquences de vos actes.", 14, MUTED))
    for quest_value in available:
        _add_quest_card(quest_list, quest_value)

    var completed := PoliticalState.completed_quests()
    if not completed.is_empty():
        quest_list.add_child(_label("DÉCISIONS PRISES", 16, GOLD))
        for quest_value in completed:
            var quest: Dictionary = quest_value
            var quest_id := String(quest.get("id", ""))
            quest_list.add_child(_label("%s\n%s" % [String(quest.get("name", "")), PoliticalState.completed_consequence(quest_id)], 13, MUTED))

func _add_quest_card(parent: VBoxContainer, quest: Dictionary) -> void:
    var quest_id := String(quest.get("id", ""))
    parent.add_child(_label(String(quest.get("name", "Décision")), 18, GOLD))
    parent.add_child(_label(String(quest.get("theme", "")), 13, MUTED))
    var choices: Dictionary = quest.get("choices", {})
    for choice_id_value in choices.keys():
        var choice_id := String(choice_id_value)
        var choice: Dictionary = choices[choice_id]
        var effects: Dictionary = choice.get("effects", {})
        var awakening_effects: Dictionary = effects.get("three_awakenings", {})
        var effect_text := "Conf %+d · Tension %+d · Rép %+d · C/E/C %+d/%+d/%+d" % [
            int(effects.get("trust", 0)),
            int(effects.get("tension", 0)),
            int(effects.get("reputation", 0)),
            int(awakening_effects.get("body", 0)),
            int(awakening_effects.get("spirit", 0)),
            int(awakening_effects.get("city", 0))
        ]
        var label := "%s\n%s" % [String(choice.get("label", choice_id)), effect_text]
        parent.add_child(_button(label, func(qid = quest_id, cid = choice_id): _take_decision(String(qid), String(cid)), Vector2(380, 62)))

func _take_decision(quest_id: String, choice_id: String) -> void:
    if PoliticalState.complete_quest(quest_id, choice_id):
        SaveManager.save_game()
    _render()
