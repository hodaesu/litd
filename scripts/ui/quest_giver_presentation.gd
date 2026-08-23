extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const PANEL := Color(0.022, 0.025, 0.034, 0.985)

var overlay: Control
var dialogue_body: VBoxContainer
var active_giver_id := ""

func _ready() -> void:
    layer = 74
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_overlay()
    GameState.screen_requested.connect(func(_screen: String): close_dialogue())

func bind_card(card: Control, giver: Dictionary, state: String = "offered") -> void:
    if giver.is_empty():
        return
    card.tooltip_text = _tooltip(giver)
    card.mouse_entered.connect(func(): _emphasize(card, giver, true))
    card.mouse_exited.connect(func(): _emphasize(card, giver, false))
    card.focus_entered.connect(func(): _emphasize(card, giver, true))
    card.focus_exited.connect(func(): _emphasize(card, giver, false))
    call_deferred("_apply_profile", card, giver, state)

func open_dialogue(giver: Dictionary, quest: Dictionary, state: String = "offered") -> void:
    if giver.is_empty():
        return
    active_giver_id = String(giver.get("id", ""))
    _clear(dialogue_body)
    dialogue_body.add_child(_label(String(giver.get("name", "Inconnu")), 27, GOLD))
    dialogue_body.add_child(_label("%s · %s" % [String(giver.get("role", "")), String(giver.get("location", ""))], 15, MUTED))
    var body: Dictionary = giver.get("body_profile", {})
    dialogue_body.add_child(_label("MISE EN SCÈNE", 17, GOLD))
    dialogue_body.add_child(_label("%s. %s." % [String(body.get("posture", "Posture neutre")).capitalize(), String(body.get("gesture", ""))], 14, TEXT))
    var staging: Dictionary = giver.get("staging", {})
    dialogue_body.add_child(_label(String(staging.get(state, staging.get("idle", ""))), 13, MUTED))
    if not quest.is_empty():
        dialogue_body.add_child(_label(String(quest.get("name", "Quête")), 21, GOLD))
        var lines := NarrativeLibrary.quest_dialogue_lines(quest, state)
        if lines.is_empty():
            dialogue_body.add_child(_label(NarrativeLibrary.quest_state_text(quest, state), 15, TEXT))
        else:
            for line: String in lines:
                dialogue_body.add_child(_label(line, 15, TEXT))
        if state in ["offered", "refused"]:
            var narrative := NarrativeLibrary.quest_narrative(quest)
            var quest_id := String(quest.get("id", ""))
            var accept := Button.new()
            accept.text = "ACCEPTER — " + String(narrative.get("player_accept", "Accepter"))
            accept.custom_minimum_size = Vector2(740, 46)
            accept.pressed.connect(func():
                if SideQuestRuntime.accept(quest_id):
                    open_dialogue(giver, quest, "active")
            )
            dialogue_body.add_child(accept)
            var refuse := Button.new()
            refuse.text = "REFUSER — " + String(narrative.get("player_decline", "Refuser"))
            refuse.custom_minimum_size = Vector2(740, 42)
            refuse.pressed.connect(func():
                SideQuestRuntime.refuse(quest_id)
                close_dialogue()
            )
            dialogue_body.add_child(refuse)
        elif state == "active":
            var track := Button.new()
            track.text = "SUIVRE CETTE QUÊTE PAR LES CENDRES"
            track.custom_minimum_size = Vector2(740, 44)
            track.pressed.connect(func(): SideQuestRuntime.track(String(quest.get("id", ""))))
            dialogue_body.add_child(track)
    overlay.visible = true
    _stage_dialogue_entrance(giver)

func close_dialogue() -> void:
    overlay.visible = false
    active_giver_id = ""

func _unhandled_input(event: InputEvent) -> void:
    if overlay.visible and (event.is_action_pressed("back") or event.is_action_pressed("confirm")):
        close_dialogue()
        get_viewport().set_input_as_handled()

func _apply_profile(card: Control, giver: Dictionary, state: String) -> void:
    if not is_instance_valid(card):
        return
    var body: Dictionary = giver.get("body_profile", {})
    var stance := clampf(float(body.get("stance_height", 1.0)), 0.88, 1.05)
    var lean := clampf(float(body.get("lean", 0.0)), -0.06, 0.06)
    var stillness := clampf(float(body.get("stillness", 0.7)), 0.0, 1.0)
    var tempo := clampf(float(body.get("tempo", 1.0)), 0.6, 1.3)
    card.pivot_offset = card.size * 0.5
    card.scale = Vector2(1.0, stance)
    card.rotation = lean
    var original_modulate := card.modulate
    card.modulate.a = 0.0
    var entrance := card.create_tween()
    entrance.tween_property(card, "modulate", original_modulate, 0.20 / tempo)
    if state == "completed":
        entrance.parallel().tween_property(card, "scale", Vector2(1.015, stance * 1.01), 0.20)
    var motion := card.create_tween().set_loops()
    motion.set_trans(Tween.TRANS_SINE)
    var amplitude := 0.002 + (1.0 - stillness) * 0.009
    motion.tween_property(card, "rotation", lean + amplitude, 1.2 / tempo)
    motion.tween_property(card, "rotation", lean - amplitude * 0.7, 1.2 / tempo)

func _emphasize(card: Control, giver: Dictionary, active: bool) -> void:
    if not is_instance_valid(card):
        return
    var body: Dictionary = giver.get("body_profile", {})
    var stance := clampf(float(body.get("stance_height", 1.0)), 0.88, 1.05)
    var target := Vector2(1.025, stance * 1.015) if active else Vector2(1.0, stance)
    card.create_tween().tween_property(card, "scale", target, 0.10)

func _stage_dialogue_entrance(giver: Dictionary) -> void:
    var body: Dictionary = giver.get("body_profile", {})
    var orientation := String(body.get("orientation", "directe"))
    var direction := -1.0 if orientation in ["directe", "oblique"] else 1.0
    dialogue_body.position.x = direction * 22.0
    dialogue_body.modulate.a = 0.0
    var tween := dialogue_body.create_tween()
    tween.tween_property(dialogue_body, "position:x", 0.0, 0.20)
    tween.parallel().tween_property(dialogue_body, "modulate:a", 1.0, 0.20)

func _tooltip(giver: Dictionary) -> String:
    var body: Dictionary = giver.get("body_profile", {})
    return "%s — %s\nPosture : %s\nGestuelle : %s" % [
        String(giver.get("name", "")), String(giver.get("role", "")),
        String(body.get("posture", "")), String(body.get("gesture", ""))
    ]

func _build_overlay() -> void:
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    var dim := ColorRect.new()
    dim.color = Color(0.006, 0.007, 0.012, 0.90)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(dim)
    var frame := PanelContainer.new()
    frame.position = Vector2(220, 68)
    frame.size = Vector2(840, 584)
    frame.add_theme_stylebox_override("panel", _style())
    overlay.add_child(frame)
    var root := VBoxContainer.new()
    frame.add_child(root)
    var header := HBoxContainer.new()
    root.add_child(header)
    var title := _label("RENCONTRE", 17, MUTED)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close := Button.new()
    close.text = "FERMER"
    close.custom_minimum_size = Vector2(140, 42)
    close.pressed.connect(close_dialogue)
    header.add_child(close)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    dialogue_body = VBoxContainer.new()
    dialogue_body.custom_minimum_size = Vector2(770, 500)
    dialogue_body.add_theme_constant_override("separation", 9)
    scroll.add_child(dialogue_body)
    overlay.visible = false

func _clear(container: Container) -> void:
    for child in container.get_children():
        child.queue_free()

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.55, 0.42, 0.22, 0.95)
    style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    return style

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label
