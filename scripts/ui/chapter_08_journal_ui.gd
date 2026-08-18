extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const PANEL := Color(0.035,0.038,0.050,0.995)

var root_panel: PanelContainer
var body: VBoxContainer

func _ready() -> void:
    layer = 29
    _build()
    GameState.screen_requested.connect(_on_screen_requested)
    Chapter08Runtime.chapter_eight_changed.connect(_on_changed)
    Chapter08Runtime.boss_choice_required.connect(_on_boss_choice_required)
    _on_screen_requested(GameState.current_screen)

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.45,0.34,0.20,0.82)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _label(text_value: String, size := 14, color := TEXT) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(520,46)
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_stylebox_override("normal", _style())
    button.pressed.connect(callback)
    return button

func _build() -> void:
    root_panel = PanelContainer.new()
    root_panel.position = Vector2(24,82)
    root_panel.size = Vector2(590,590)
    root_panel.add_theme_stylebox_override("panel", _style())
    root_panel.visible = false
    add_child(root_panel)
    var scroll := ScrollContainer.new()
    root_panel.add_child(scroll)
    body = VBoxContainer.new()
    body.custom_minimum_size = Vector2(550,0)
    body.add_theme_constant_override("separation", 8)
    scroll.add_child(body)

func _on_screen_requested(screen_name: String) -> void:
    root_panel.visible = screen_name == "quest_journal" and CampaignState.current_chapter_id == "chapter_08_outer_world"
    if root_panel.visible:
        Chapter08Runtime.refresh_progress()
        _render()

func _on_changed() -> void:
    if root_panel.visible: call_deferred("_render")

func _on_boss_choice_required(_boss_id: String) -> void:
    GameState.request_screen("quest_journal")

func _clear() -> void:
    for child in body.get_children(): child.queue_free()

func _render() -> void:
    if not root_panel.visible: return
    _clear()
    body.add_child(_label("CHAPITRE VIII — LE MONDE EXTÉRIEUR",19,GOLD))
    body.add_child(_label("PROGRESSION — %s" % Chapter08Runtime.progress_text(),15,GOLD))
    var stage: Dictionary = Chapter08Runtime.active_stage()
    if not stage.is_empty():
        body.add_child(_label("Objectif : %s" % String(stage.get("name", "")),16,TEXT))
        body.add_child(_label(String(stage.get("objective", "")),13,MUTED))
    if not AshlandsRuntime.is_zone_discovered("c08_varkhane_border"):
        body.add_child(_button("TRAVERSER VERS VARKHANE", func(): AshlandsSceneRouter.start_chapter_08()))
    body.add_child(_label("DOSSIER TRANSFRONTALIER — %d/16 sources · %d familles indépendantes · %d maillons de commandement" % [Chapter08Runtime.record_count(),Chapter08Runtime.independent_source_family_count(),Chapter08Runtime.foreign_command_count()],14,GOLD))
    for power_id in ["varkhane","namar","azravel","kor_em"]:
        var display := {"varkhane":"Varkhane","namar":"Namar","azravel":"Azravel","kor_em":"Kor-Em"}[power_id]
        var understood := "compris" if Chapter08Runtime.power_understood(power_id) else "incomplet"
        body.add_child(_label("%s — %d sources · %d civiles/dissidentes · %s" % [display,Chapter08Runtime.record_count_for(power_id),Chapter08Runtime.civilian_or_dissident_count_for(power_id),understood],13,TEXT))
    body.add_child(_label("CONTRE-AUTORITÉS",14,GOLD))
    body.add_child(_label("Varkhane : %d/3 · Azravel : %d/3" % [Chapter08Runtime.authority_node_count("varkhane"),Chapter08Runtime.authority_node_count("azravel")],13,MUTED))
    _add_boss_choices("c08_boss_varkhane","MARÉCHAL DU TRÔNE VIDE")
    _add_boss_choices("c08_boss_azravel","SAINT DE LA FAILLE")
    if not Chapter08Runtime.collected_records.is_empty():
        body.add_child(_label("SOURCES RETROUVÉES",14,GOLD))
        for value in Chapter08Runtime.collected_records.values():
            var entry: Dictionary = value
            body.add_child(_label("• %s — %s" % [String(entry.get("title", "")),String(entry.get("power", ""))],12,MUTED))

func _add_boss_choices(boss_id: String, title: String) -> void:
    if Chapter08Runtime.boss_choices.has(boss_id) or not AshlandsRuntime.is_encounter_cleared(boss_id): return
    body.add_child(_label("DÉCISION — %s" % title,15,GOLD))
    for value in Chapter08Runtime.available_boss_choices(boss_id):
        var choice: Dictionary = value
        var choice_id := String(choice.get("id", ""))
        body.add_child(_button(String(choice.get("label", choice_id)), func(id_value = choice_id, boss_value = boss_id): Chapter08Runtime.choose_boss_outcome(String(boss_value),String(id_value)); SaveManager.save_game(); _render()))
