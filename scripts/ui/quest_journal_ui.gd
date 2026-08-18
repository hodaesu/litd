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
    CampaignState.campaign_changed.connect(_on_state_changed)
    Chapter01Runtime.chapter_one_changed.connect(_on_state_changed)
    Chapter01Runtime.boss_choice_required.connect(_on_boss_choice_required)
    Chapter02Runtime.chapter_two_changed.connect(_on_state_changed)
    Chapter02Runtime.final_choice_required.connect(_on_chapter_two_choice_required)
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
    launcher.visible = false
    if overlay.visible:
        SanctuaryState.refresh()
        PoliticalState.refresh_unlocks()
        Chapter01Runtime.refresh_progress()
        Chapter02Runtime.refresh_progress()
        _render()

func _on_boss_choice_required() -> void:
    GameState.request_screen("quest_journal")

func _on_chapter_two_choice_required() -> void:
    GameState.request_screen("quest_journal")

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

    var chapter := CampaignState.current_chapter()
    quest_box.add_child(_label("QUÊTE PRINCIPALE", 19, GOLD))
    quest_box.add_child(_label("CHAPITRE %d — %s" % [CampaignState.current_chapter_number(), String(chapter.get("title", ""))], 18, TEXT))
    quest_box.add_child(_label(String(chapter.get("premise", "")), 13, MUTED))

    if CampaignState.current_chapter_id == "chapter_01_ashlands":
        _render_chapter_one(quest_box)
    elif CampaignState.current_chapter_id == "chapter_02_before_fall":
        _render_chapter_two(quest_box)

    var main_active := CampaignState.active_main_quests()
    if main_active.is_empty():
        quest_box.add_child(_label("Toutes les quêtes principales de ce chapitre sont terminées.", 14, MUTED))
    else:
        for quest_value in main_active:
            var main_quest: Dictionary = quest_value
            quest_box.add_child(_label("◆ %s" % String(main_quest.get("name", "Quête principale")), 16, TEXT))
            quest_box.add_child(_label(String(main_quest.get("goal", "")), 13, MUTED))

    if not CampaignState.discovered_revelations.is_empty():
        quest_box.add_child(_label("RÉVÉLATIONS CONFIRMÉES", 16, GOLD))
        for revelation in CampaignState.discovered_revelations.values():
            quest_box.add_child(_label("• %s" % String(revelation), 13, MUTED))

    quest_box.add_child(_label("DÉCISIONS LOCALES", 18, GOLD))
    var available := PoliticalState.available_quests()
    if available.is_empty():
        quest_box.add_child(_label("Aucune décision politique urgente pour le moment.", 14, MUTED))
    for quest_value in available:
        var quest: Dictionary = quest_value
        quest_box.add_child(_label("• %s" % String(quest.get("name", "Quête")), 17, TEXT))
        quest_box.add_child(_label(String(quest.get("theme", "")), 13, MUTED))

    var completed := PoliticalState.completed_quests()
    if not completed.is_empty():
        quest_box.add_child(_label("DÉCISIONS TERMINÉES", 17, GOLD))
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

func _render_chapter_one(parent: VBoxContainer) -> void:
    parent.add_child(_label("PROGRESSION DU CHAPITRE I — %s" % Chapter01Runtime.progress_text(), 15, GOLD))
    var active_stage := Chapter01Runtime.active_stage()
    if not active_stage.is_empty():
        parent.add_child(_label("Objectif actuel : %s" % String(active_stage.get("name", "")), 16, TEXT))
        parent.add_child(_label(String(active_stage.get("objective", "")), 13, MUTED))
    _add_boss_choice_if_needed(parent)

func _render_chapter_two(parent: VBoxContainer) -> void:
    parent.add_child(_label("PROGRESSION DU CHAPITRE II — %s" % Chapter02Runtime.progress_text(), 15, GOLD))
    var active_stage := Chapter02Runtime.active_stage()
    if not active_stage.is_empty():
        parent.add_child(_label("Objectif actuel : %s" % String(active_stage.get("name", "")), 16, TEXT))
        parent.add_child(_label(String(active_stage.get("objective", "")), 13, MUTED))
    if GameState.current_screen == "quest_journal" and not AshlandsRuntime.is_zone_discovered("c02_old_road"):
        parent.add_child(_button("PARTIR SUR LA ROUTE DES BORNES", func(): AshlandsSceneRouter.start_chapter_02(), Vector2(520, 48)))
    parent.add_child(_label("ENQUÊTE — %d indices · %d sources indépendantes" % [Chapter02Runtime.clue_count(), Chapter02Runtime.independent_source_count()], 15, GOLD))
    for clue_value in Chapter02Runtime.discovered_clues.values():
        var clue: Dictionary = clue_value
        var status := "douteux" if String(clue.get("authenticity", "")) in ["false", "partial"] else "établi"
        parent.add_child(_label("• %s [%s]" % [String(clue.get("title", "Indice")), status], 13, MUTED))
    if not Chapter02Runtime.confirmed_hypotheses.is_empty():
        parent.add_child(_label("HYPOTHÈSES CONFIRMÉES", 15, GOLD))
        for hypothesis_value in Chapter02Runtime.hypotheses():
            var hypothesis: Dictionary = hypothesis_value
            var id_value := String(hypothesis.get("id", ""))
            if bool(Chapter02Runtime.confirmed_hypotheses.get(id_value, false)):
                parent.add_child(_label("✓ %s" % String(hypothesis.get("title", id_value)), 13, TEXT))
    _add_chapter_two_choice_if_needed(parent)

func _add_boss_choice_if_needed(parent: VBoxContainer) -> void:
    if Chapter01Runtime.boss_choice != "" or not AshlandsRuntime.is_encounter_cleared("c01_boss_ash_witness"):
        return
    var boss_stage := Chapter01Runtime.stage("c01_stage_07_witness")
    parent.add_child(_label("DÉCISION — LE TÉMOIN DES CENDRES", 16, GOLD))
    parent.add_child(_label("Le combat est terminé, mais ce qu'il reste du Témoin peut encore être traité de plusieurs manières.", 13, MUTED))
    for choice_value in boss_stage.get("boss_choices", []):
        var choice: Dictionary = choice_value
        var choice_id := String(choice.get("id", ""))
        parent.add_child(_button(String(choice.get("label", choice_id)), func(id_value = choice_id):
            Chapter01Runtime.choose_boss_outcome(String(id_value))
            SaveManager.save_game()
            _render(), Vector2(520, 48)))

func _add_chapter_two_choice_if_needed(parent: VBoxContainer) -> void:
    if Chapter02Runtime.final_choice != "" or not AshlandsRuntime.is_encounter_cleared("c02_marker_warden"):
        return
    parent.add_child(_label("DÉCISION — LES PREUVES DE SAHRA VEL", 16, GOLD))
    parent.add_child(_label("La question n'est plus seulement ce qui est vrai, mais quand et comment cette vérité doit être rendue publique.", 13, MUTED))
    for choice_value in Chapter02Runtime.slice.get("final_choice", []):
        var choice: Dictionary = choice_value
        var choice_id := String(choice.get("id", ""))
        parent.add_child(_button(String(choice.get("label", choice_id)), func(id_value = choice_id):
            Chapter02Runtime.choose_final_outcome(String(id_value))
            SaveManager.save_game()
            _render(), Vector2(520, 48)))

func _add_section(parent: VBoxContainer, title: String, entries: Array) -> void:
    if entries.is_empty():
        return
    parent.add_child(_label(title, 15, GOLD))
    for entry in entries:
        parent.add_child(_label("• %s" % String(entry), 13, MUTED))
