extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const WARNING := Color("#c98776")
const PANEL := Color(0.025,0.028,0.038,0.985)

var access_button: Button
var panel: PanelContainer
var body: VBoxContainer
var opened := false

func _ready() -> void:
    layer = 36
    _build()
    GameState.screen_requested.connect(_on_screen_requested)
    CampaignState.campaign_changed.connect(_refresh_visibility)
    EndgameState.endgame_changed.connect(_on_endgame_changed)
    _refresh_visibility()

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.45,0.34,0.20,0.9)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func _label(text_value: String, size := 14, color := TEXT) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(text_value: String, callback: Callable, width := 310) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(width, 44)
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_stylebox_override("normal", _style())
    button.pressed.connect(callback)
    return button

func _build() -> void:
    access_button = _button("MONDE D'APRÈS", _open, 190)
    access_button.position = Vector2(850, 18)
    access_button.visible = false
    add_child(access_button)

    panel = PanelContainer.new()
    panel.position = Vector2(150, 42)
    panel.size = Vector2(980, 640)
    panel.add_theme_stylebox_override("panel", _style())
    panel.visible = false
    add_child(panel)

    var scroll := ScrollContainer.new()
    panel.add_child(scroll)
    body = VBoxContainer.new()
    body.custom_minimum_size = Vector2(925, 0)
    body.add_theme_constant_override("separation", 9)
    scroll.add_child(body)

func _on_screen_requested(_screen_name: String) -> void:
    if GameState.current_screen != "sanctuary": _close()
    _refresh_visibility()

func _refresh_visibility() -> void:
    if not is_instance_valid(access_button): return
    access_button.visible = GameState.current_screen == "sanctuary" and EndgameState.is_postgame_unlocked() and not opened

func _on_endgame_changed() -> void:
    _refresh_visibility()
    if opened: call_deferred("_render")

func _open() -> void:
    if not EndgameState.is_postgame_unlocked(): return
    EndgameState.record_current_ending()
    opened = true
    access_button.visible = false
    panel.visible = true
    _render()

func _close() -> void:
    opened = false
    if is_instance_valid(panel): panel.visible = false
    _refresh_visibility()

func _clear() -> void:
    for child in body.get_children(): child.queue_free()

func _render() -> void:
    if not opened: return
    _clear()
    var ending := EndgameState.current_epilogue()
    body.add_child(_label("LE MONDE D'APRÈS", 22, GOLD))
    body.add_child(_label("%s · %s" % [String(ending.get("title", "Épilogue")), EndgameState.cycle_label()], 17, TEXT))
    for key in ["opening", "middle", "political", "closing"]:
        var text := String(ending.get(key, ""))
        if text != "": body.add_child(_label(text, 13, TEXT))

    var vignettes := EndgameState.visible_vignettes()
    if not vignettes.is_empty():
        body.add_child(_label("DESTINS ET TRACES", 16, GOLD))
        for value in vignettes:
            var vignette: Dictionary = value
            body.add_child(_label(String(vignette.get("title", "")), 14, TEXT))
            body.add_child(_label(String(vignette.get("text", "")), 12, MUTED))

    body.add_child(_label("RECONSTRUCTION — %d opération(s) accomplie(s) · %d point(s) d'héritage" % [EndgameState.operation_count(), EndgameState.legacy_points], 16, GOLD))
    for value in EndgameState.operations():
        var operation: Dictionary = value
        var operation_id := String(operation.get("id", ""))
        var done := bool(EndgameState.completed_operations.get(operation_id, false))
        var title := "✓ %s" % String(operation.get("name", operation_id)) if done else String(operation.get("name", operation_id))
        body.add_child(_label(title, 14, TEXT if not done else MUTED))
        body.add_child(_label(String(operation.get("description", "")), 11, MUTED))
        if not done:
            var button := _button("ACCOMPLIR", func(id_value=operation_id):
                if EndgameState.complete_operation(String(id_value)):
                    SaveManager.save_game()
                    _render())
            button.disabled = not EndgameState.operation_available(operation_id)
            body.add_child(button)

    body.add_child(_label("NOUVEAU CYCLE+", 17, GOLD))
    if not EndgameState.ng_plus_unlocked():
        var required := int(EndgameState.postgame_data.get("operations_required_for_ng_plus", 3))
        body.add_child(_label("Accomplir au moins %d opérations du monde d'après pour transmettre un héritage au cycle suivant." % required, 12, WARNING))
    else:
        body.add_child(_label("Le nouveau cycle remet à zéro campagne, niveaux, inventaire, créatures et politique. Il conserve l'historique des fins et un seul héritage choisi. Les ennemis deviennent plus résistants et plus dangereux à chaque cycle.", 12, MUTED))
        for value in EndgameState.perks():
            var perk: Dictionary = value
            var perk_id := String(perk.get("id", ""))
            body.add_child(_label("%s — coût %d" % [String(perk.get("name", perk_id)), int(perk.get("cost", 0))], 14, TEXT))
            body.add_child(_label(String(perk.get("description", "")), 11, MUTED))
            var button := _button("COMMENCER AVEC CET HÉRITAGE", func(id_value=perk_id):
                if EndgameState.begin_new_game_plus(String(id_value)):
                    SaveManager.save_game()
                    _close()
                    GameState.request_screen("sanctuary"))
            button.disabled = not EndgameState.perk_available(perk_id)
            body.add_child(button)

    if not EndgameState.ending_history.is_empty():
        body.add_child(_label("CHRONIQUE DES CYCLES", 16, GOLD))
        for value in EndgameState.ending_history:
            var record: Dictionary = value
            body.add_child(_label("• Cycle %d — %s" % [int(record.get("cycle", 0)), String(record.get("name", record.get("ending_id", "")))], 12, MUTED))

    body.add_child(_button("REFERMER LA CHRONIQUE", _close, 330))
