extends PanelContainer
class_name LITDCharacterCard

signal character_pressed(character_id: String)

var character_id := ""
var name_label: Label
var health_bar: LITDGauge
var status_row: HBoxContainer
var selected := false

func _ready() -> void:
    custom_minimum_size = Vector2(150, 96)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build()
    _apply_frame()

func bind_character(data: Dictionary, is_selected := false) -> void:
    character_id = str(data.get("id", data.get("entity_id", "")))
    selected = is_selected
    if name_label == null:
        _build()
    name_label.text = str(data.get("name", data.get("display_name", character_id)))
    health_bar.set_values(float(data.get("hp", 0)), float(data.get("max_hp", 1)))
    _bind_statuses(data.get("statuses", []))
    _apply_frame()

func _build() -> void:
    if name_label != null:
        return
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", UITokens.SPACE_XS)
    add_child(root)

    name_label = Label.new()
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    name_label.add_theme_font_size_override("font_size", UITokens.TEXT_BODY)
    root.add_child(name_label)

    health_bar = LITDGauge.new()
    health_bar.gauge_kind = "health"
    health_bar.compact = true
    root.add_child(health_bar)

    status_row = HBoxContainer.new()
    status_row.alignment = BoxContainer.ALIGNMENT_CENTER
    status_row.add_theme_constant_override("separation", UITokens.SPACE_XS)
    root.add_child(status_row)

func _bind_statuses(statuses: Variant) -> void:
    for child in status_row.get_children():
        child.queue_free()
    if not (statuses is Array):
        return
    var values: Array = statuses
    var visible_count := mini(values.size(), 3)
    for index in range(visible_count):
        var chip := LITDStatusIcon.new()
        var row: Dictionary = values[index] if values[index] is Dictionary else {"name":str(values[index]), "glyph":"!"}
        chip.bind_status(row)
        chip.custom_minimum_size = Vector2(36, 36)
        status_row.add_child(chip)
    if values.size() > 3:
        var overflow := Label.new()
        overflow.text = "+%d" % (values.size() - 3)
        overflow.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)
        status_row.add_child(overflow)

func _apply_frame() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = UITokens.COLOR_SURFACE_RAISED if selected else UITokens.COLOR_SURFACE
    style.border_color = UITokens.COLOR_OCHRE if selected else UITokens.COLOR_BORDER_METAL
    style.set_border_width_all(2 if selected else 1)
    style.corner_radius_top_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_top_right = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_right = UITokens.CORNER_RADIUS_M
    style.content_margin_left = UITokens.SPACE_S
    style.content_margin_right = UITokens.SPACE_S
    style.content_margin_top = UITokens.SPACE_S
    style.content_margin_bottom = UITokens.SPACE_S
    add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        character_pressed.emit(character_id)
        accept_event()
    elif event is InputEventScreenTouch and event.pressed:
        character_pressed.emit(character_id)
        accept_event()
