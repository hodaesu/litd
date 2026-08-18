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
    Chapter09Runtime.chapter_nine_changed.connect(_on_changed)
    Chapter09Runtime.final_choice_required.connect(_on_final_choice_required)
    _on_screen_requested(GameState.current_screen)

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.45,0.34,0.20,0.82)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 10; style.content_margin_bottom = 10
    return style

func _label(text_value: String, size := 14, color := TEXT) -> Label:
    var label := Label.new(); label.text = text_value; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return label

func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new(); button.text = text_value; button.custom_minimum_size = Vector2(540,46); button.add_theme_font_size_override("font_size",14); button.add_theme_color_override("font_color",TEXT); button.add_theme_stylebox_override("normal",_style()); button.pressed.connect(callback); return button

func _build() -> void:
    root_panel = PanelContainer.new(); root_panel.position = Vector2(22,78); root_panel.size = Vector2(610,600); root_panel.add_theme_stylebox_override("panel",_style()); root_panel.visible = false; add_child(root_panel)
    var scroll := ScrollContainer.new(); root_panel.add_child(scroll)
    body = VBoxContainer.new(); body.custom_minimum_size = Vector2(570,0); body.add_theme_constant_override("separation",8); scroll.add_child(body)

func _on_screen_requested(screen_name: String) -> void:
    root_panel.visible = screen_name == "quest_journal" and CampaignState.current_chapter_id == "chapter_09_veil_nature"
    if root_panel.visible:
        Chapter09Runtime.refresh_progress()
        _render()

func _on_changed() -> void:
    if root_panel.visible: call_deferred("_render")

func _on_final_choice_required() -> void:
    GameState.request_screen("quest_journal")

func _clear() -> void:
    for child in body.get_children(): child.queue_free()

func _render() -> void:
    if not root_panel.visible: return
    _clear()
    body.add_child(_label("CHAPITRE IX — CE QU'EST RÉELLEMENT LE VOILE",19,GOLD))
    body.add_child(_label("PROGRESSION — %s" % Chapter09Runtime.progress_text(),15,GOLD))
    var stage: Dictionary = Chapter09Runtime.active_stage()
    if not stage.is_empty():
        body.add_child(_label("Objectif : %s" % String(stage.get("name","")),16,TEXT))
        body.add_child(_label(String(stage.get("objective","")),13,MUTED))
    if not AshlandsRuntime.is_zone_discovered("c09_tree_node"):
        body.add_child(_button("DESCENDRE SOUS L'ARBRE",func(): AshlandsSceneRouter.start_chapter_09()))
    body.add_child(_label("SYNTHÈSE — %d observations · %d familles · %d/5 modèles · %d Vérités Profondes" % [Chapter09Runtime.observation_count(),Chapter09Runtime.source_family_count(),Chapter09Runtime.confirmed_model_count(),Chapter09Runtime.deep_truth_count()],14,GOLD))
    body.add_child(_label("FAITS ET MODÈLES",14,GOLD))
    for value in Chapter09Runtime.chapter.get("models", []):
        var model: Dictionary = value
        var id_value := String(model.get("id",""))
        var status := "CONFIRMÉ AVEC RÉSERVE" if bool(Chapter09Runtime.confirmed_models.get(id_value,false)) else "HYPOTHÈSE"
        body.add_child(_label("%s — %d%% — %s" % [String(model.get("name",id_value)),Chapter09Runtime.confidence_for(id_value),status],13,TEXT))
        body.add_child(_label(String(model.get("statement","")),12,MUTED))
    body.add_child(_label("INCONNUES MAINTENUES OUVERTES",14,GOLD))
    body.add_child(_label("Origine ultime du Voile : inconnue. Volonté propre : non établie. Nature ontologique des Absents : non résolue.",12,MUTED))
    body.add_child(_label("ANCRAGES",14,GOLD))
    body.add_child(_label("Saan : %d/3 · Perspectives du Consensus : %d/3" % [Chapter09Runtime.node_count("stabilizer"),Chapter09Runtime.node_count("perspective")],13,MUTED))
    if AshlandsRuntime.is_encounter_cleared("c09_boss_consensus") and Chapter09Runtime.final_choice == "":
        body.add_child(_label("DÉCISION — CONSENSUS BRISÉ",15,GOLD))
        for value in Chapter09Runtime.available_final_choices():
            var choice: Dictionary = value
            var id_value := String(choice.get("id",""))
            body.add_child(_button(String(choice.get("label",id_value)),func(choice_value = id_value): Chapter09Runtime.choose_final_outcome(String(choice_value)); SaveManager.save_game(); _render()))
