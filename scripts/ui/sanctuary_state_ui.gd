extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const DARK_PANEL := Color(0.02, 0.022, 0.03, 0.92)

var panel: PanelContainer
var summary_label: Label
var details_label: Label

func _ready() -> void:
    layer = 22
    _build()
    GameState.screen_requested.connect(_on_screen_requested)
    SanctuaryState.sanctuary_state_changed.connect(_on_state_changed)
    _on_screen_requested(GameState.current_screen)

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = DARK_PANEL
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

func _label(text: String, size := 14, color := TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _build() -> void:
    panel = PanelContainer.new()
    panel.position = Vector2(24, 76)
    panel.size = Vector2(1180, 92)
    panel.add_theme_stylebox_override("panel", _style())
    panel.visible = false
    add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 3)
    panel.add_child(box)
    summary_label = _label("", 16, GOLD)
    details_label = _label("", 12, MUTED)
    box.add_child(summary_label)
    box.add_child(details_label)

func _on_screen_requested(screen_name: String) -> void:
    panel.visible = screen_name == "sanctuary"
    if panel.visible:
        SanctuaryState.refresh()
        _render()

func _on_state_changed(_layers: Array) -> void:
    if panel.visible:
        _render()

func _render() -> void:
    summary_label.text = "ÉTAT DU SANCTUAIRE — %s" % SanctuaryState.summary().to_upper()
    var visuals := SanctuaryState.current_visual_cues()
    var audio := SanctuaryState.current_audio_cues()
    var population := SanctuaryState.current_population_cues()
    var parts: Array[String] = []
    if not visuals.is_empty():
        parts.append("Visible : %s" % ", ".join(visuals.slice(0, 3)))
    if not population.is_empty():
        parts.append("Présences : %s" % ", ".join(population.slice(0, 3)))
    if not audio.is_empty():
        parts.append("Ambiance : %s" % ", ".join(audio.slice(0, 2)))
    details_label.text = "   ·   ".join(parts)
