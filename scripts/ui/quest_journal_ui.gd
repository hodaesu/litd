extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const DARK := Color(0.015, 0.017, 0.023, 0.98)
const PANEL := Color(0.035, 0.038, 0.050, 0.98)

var launcher: Button
var overlay: Control
var body: Control

func _ready() -> void:
    layer = 28
    _build_launcher()
    _build_overlay()
    GameState.screen_requested.connect(_on_screen_requested)
    PoliticalState.politics_changed.connect(_on_state_changed)
    SanctuaryState.sanctuary_state_changed.connect(_on_sanctuary_changed)
    _on_screen_requested(GameState.current_screen)

func _style(color := PANEL) -> StyleBoxFlat:
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

func _label(text: String, size := 15, color := TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

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

func _build_launcher() -> void:
    launcher = _button("JOURNAL", func(): GameState.request_screen("quest_journal"), Vector2(150, 44))
    launcher.position = Vector2(1080, 80)
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
    overlay.add_child(header)
    var title := _label("JOURNAL", 26, GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(_button("RETOUR", func(): GameState.request_screen("sanctuary"), Vector2(130, 42)))

    body = Control.new()
    body.position = Vector2(24, 82)
    body.size = Vector2(1232, 610)
    overlay.add_child(body)

func _on_screen_requested(screen_name: String) -> void:
    overlay.visible = screen_name == "quest_journal"
    launcher.visible = screen_name == "sanctuary"
    if overlay.visible:
        SanctuaryState.refresh()
        PoliticalState.refresh_unlocks()
        _render()

func _on_state_changed() -> void:
    if overlay.visible:
        call_deferred("_render")

func _on_sanctuary_changed(_layers: Array) -> void:
    if overlay.visible:
        call_deferred("_render")

func _clear() -> void:
    for child in body.get_children():
        child.queue_free()

func _render() -> void:
    if not overlay.visible:
        return
    _clear()

    var columns := HBoxContainer.new()
    columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    columns.add_theme_constant_override("separation", 16)
    body.add_child(columns)

    var quests_panel := PanelContainer.new()
    quests_panel.custom_minimum_size = Vector2(590, 590)
    quests_panel.add_theme_stylebox_override("panel", _style())
    columns.add_child(quests_panel)
    var quest_scroll := ScrollContainer.new()
    quests_panel.add_child(quest_scroll)
    var quest_box := VBoxContainer.new()
    quest_box.custom_minimum_size = Vector2(550, 0)
    quest_box.add_theme_constant_override("separation", 9)
    quest_scroll.add_child(quest_box)
    quest_box.add_child(_label("QUÊTES ET DÉCISIONS", 19, GOLD))

    var available := PoliticalState.available_quests()
    if available.is_empty():
        quest_box.add_child(_label("Aucune décision politique urgente pour le moment.", 14, MUTED))
    for quest_value in available:
        var quest: Dictionary = quest_value
        quest_box.add_child(_label("• %s" % String(quest.get("name", "Quête")), 17, TEXT))
        quest_box.add_child(_label(String(quest.get("theme", "")), 13, MUTED))

    var completed := PoliticalState.completed_quests()
    if not completed.is_empty():
        quest_box.add_child(_label("TERMINÉES", 17, GOLD))
        for quest_value in completed:
            var quest: Dictionary = quest_value
            var quest_id := String(quest.get("id", ""))
            quest_box.add_child(_label("✓ %s" % String(quest.get("name", "")), 15, TEXT))
            quest_box.add_child(_label(PoliticalState.completed_consequence(quest_id), 13, MUTED))

    var sanctuary_panel := PanelContainer.new()
    sanctuary_panel.custom_minimum_size = Vector2(590, 590)
    sanctuary_panel.add_theme_stylebox_override("panel", _style())
    columns.add_child(sanctuary_panel)
    var sanctuary_scroll := ScrollContainer.new()
    sanctuary_panel.add_child(sanctuary_scroll)
    var sanctuary_box := VBoxContainer.new()
    sanctuary_box.custom_minimum_size = Vector2(550, 0)
    sanctuary_box.add_theme_constant_override("separation", 9)
    sanctuary_scroll.add_child(sanctuary_box)

    sanctuary_box.add_child(_label("SANCTUAIRE DU PREMIER VOILE", 19, GOLD))
    sanctuary_box.add_child(_label("État actuel : %s" % SanctuaryState.summary(), 16, TEXT))
    sanctuary_box.add_child(_label("Confiance %d · Tension %d · Réputation %+d" % [PoliticalState.trust, PoliticalState.tension, PoliticalState.reputation], 14, MUTED))
    var awakenings: Dictionary = PoliticalState.three_awakenings
    sanctuary_box.add_child(_label("Corps %d · Esprit %d · Cité %d" % [int(awakenings.get("body", 50)), int(awakenings.get("spirit", 50)), int(awakenings.get("city", 50))], 14, MUTED))

    _add_section(sanctuary_box, "CHANGEMENTS VISIBLES", SanctuaryState.current_visual_cues())
    _add_section(sanctuary_box, "POPULATION ET PRÉSENCES", SanctuaryState.current_population_cues())
    _add_section(sanctuary_box, "AMBIANCE", SanctuaryState.current_audio_cues())

    var social := PoliticalState.social_snapshot()
    _add_section(sanctuary_box, "RUMEURS", social.get("rumors", []))
    _add_section(sanctuary_box, "INSCRIPTIONS", social.get("inscriptions", []))

func _add_section(parent: VBoxContainer, title: String, entries: Array) -> void:
    if entries.is_empty():
        return
    parent.add_child(_label(title, 15, GOLD))
    for entry in entries:
        parent.add_child(_label("• %s" % String(entry), 13, MUTED))
