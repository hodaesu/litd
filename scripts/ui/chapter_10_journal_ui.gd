extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const WARNING := Color("#c98776")
const PANEL := Color(0.035,0.038,0.050,0.995)

var root_panel: PanelContainer
var body: VBoxContainer

func _ready() -> void:
    layer = 31
    _build()
    GameState.screen_requested.connect(_on_screen_requested)
    Chapter10Runtime.chapter_ten_changed.connect(_on_changed)
    Chapter10Runtime.final_choice_required.connect(_on_final_choice_required)
    _on_screen_requested(GameState.current_screen)

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = PANEL; style.border_color = Color(0.45,0.34,0.20,0.82); style.set_border_width_all(1); style.set_corner_radius_all(5); style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 10; style.content_margin_bottom = 10; return style

func _label(text_value: String, size := 14, color := TEXT) -> Label:
    var label := Label.new(); label.text = text_value; label.add_theme_font_size_override("font_size",size); label.add_theme_color_override("font_color",color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return label

func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new(); button.text = text_value; button.custom_minimum_size = Vector2(560,48); button.add_theme_font_size_override("font_size",14); button.add_theme_color_override("font_color",TEXT); button.add_theme_stylebox_override("normal",_style()); button.pressed.connect(callback); return button

func _build() -> void:
    root_panel = PanelContainer.new(); root_panel.position = Vector2(20,68); root_panel.size = Vector2(625,620); root_panel.add_theme_stylebox_override("panel",_style()); root_panel.visible = false; add_child(root_panel)
    var scroll := ScrollContainer.new(); root_panel.add_child(scroll)
    body = VBoxContainer.new(); body.custom_minimum_size = Vector2(585,0); body.add_theme_constant_override("separation",8); scroll.add_child(body)

func _on_screen_requested(screen_name: String) -> void:
    root_panel.visible = screen_name == "quest_journal" and CampaignState.current_chapter_id == "chapter_10_final_choice"
    if root_panel.visible:
        Chapter10Runtime.refresh_progress(); _render()

func _on_changed() -> void:
    if root_panel.visible: call_deferred("_render")

func _on_final_choice_required() -> void:
    GameState.request_screen("quest_journal")

func _clear() -> void:
    for child in body.get_children(): child.queue_free()

func _render() -> void:
    if not root_panel.visible: return
    _clear()
    body.add_child(_label("CHAPITRE X — LA LUMIÈRE MÉRITE D'ÊTRE DÉFENDUE",19,GOLD))
    body.add_child(_label("PROGRESSION — %s" % Chapter10Runtime.progress_text(),15,GOLD))
    var stage: Dictionary = Chapter10Runtime.active_stage()
    if not stage.is_empty():
        body.add_child(_label(String(stage.get("name","")),16,TEXT)); body.add_child(_label(String(stage.get("objective","")),13,MUTED))
    if not AshlandsRuntime.is_zone_discovered("c10_world_council"):
        body.add_child(_button("OUVRIR LE CONSEIL DU MONDE",func(): AshlandsSceneRouter.start_chapter_10()))
    body.add_child(_label("CONSEIL — %d voix actives" % Chapter10Runtime.council_count(),14,GOLD))
    for value in Chapter10Runtime.chapter.get("council_groups", []):
        var group: Dictionary = value; var group_id := String(group.get("id","")); var available := Chapter10Runtime.council_group_available(group_id); var active := false
        for node_id in Chapter10Runtime.active_nodes.keys():
            var node_data: Dictionary = Chapter10Runtime._node_data(String(node_id))
            if String(node_data.get("group","")) == group_id: active = true
        var status := "présente" if active else ("disponible" if available else "non constituée")
        body.add_child(_label("• %s — %s" % [String(group.get("name",group_id)),status],12,TEXT if active else MUTED))
    body.add_child(_label("COÛTS DOCUMENTÉS — %d/13 · %d familles" % [Chapter10Runtime.stake_count(),Chapter10Runtime.stake_family_count()],14,GOLD))
    body.add_child(_label("Routes %d/3 · coûts nommés %d/3 · ancrages préparés %d/3 · ancrages de Rupture %d/3" % [Chapter10Runtime.route_count(),Chapter10Runtime.cost_count(),Chapter10Runtime.world_anchor_count(),Chapter10Runtime.node_count("rupture_anchor")],12,MUTED))
    if Chapter10Runtime.final_orientation != "":
        body.add_child(_label("MONDE D'APRÈS",16,GOLD)); body.add_child(_label(String(Chapter10Runtime.final_record.get("name",Chapter10Runtime.final_orientation)),17,TEXT)); body.add_child(_label(String(Chapter10Runtime.final_record.get("principle",Chapter10Runtime.final_record.get("outcome",""))),13,MUTED)); return
    if AshlandsRuntime.is_encounter_cleared("c10_boss_final") and GameState.current_screen == "quest_journal": _render_final_choices()

func _render_final_choices() -> void:
    body.add_child(_label("ORIENTATIONS RÉELLEMENT DISPONIBLES",16,GOLD))
    for value in Chapter10Runtime.final_choices():
        var ending: Dictionary = value; var ending_id := String(ending.get("id",""))
        body.add_child(_label(String(ending.get("name",ending_id)),15,TEXT))
        body.add_child(_label(String(ending.get("principle",ending.get("outcome",""))),12,MUTED))
        var costs: Array = ending.get("costs",[])
        if not costs.is_empty(): body.add_child(_label("Coûts : %s" % "; ".join(costs),11,WARNING))
        body.add_child(_button("CHOISIR — %s" % String(ending.get("name",ending_id)),func(id_value=ending_id): Chapter10Runtime.choose_final_orientation(String(id_value)); SaveManager.save_game(); _render()))
    var unavailable := Chapter10Runtime.unavailable_orientations()
    if not unavailable.is_empty():
        body.add_child(_label("ORIENTATIONS NON RÉALISABLES PAR CETTE PARTIE",14,WARNING))
        for value in unavailable:
            var ending: Dictionary = value
            body.add_child(_label("• %s — manque : %s" % [String(ending.get("name","")),", ".join(ending.get("missing",[]))],11,MUTED))
