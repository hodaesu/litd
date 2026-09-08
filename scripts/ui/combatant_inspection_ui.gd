extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const PANEL := Color(0.025, 0.028, 0.038, 0.98)
const BASE_PREVIEW_SIZE := Vector2(440, 126)
const BASE_DETAIL_SIZE := Vector2(860, 580)
const SAFE_GUTTER := 12.0
const META_BASE_FONT := "litd_inspection_base_font_size"

var preview_panel: PanelContainer
var preview_content: VBoxContainer
var detail_overlay: Control
var detail_frame: PanelContainer
var detail_content: VBoxContainer
var detail_close_button: Button
var detail_open := false

func _ready() -> void:
    layer = 75
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_preview()
    _build_detail()
    GameState.screen_requested.connect(func(_screen: String): close_detail(); hide_preview())
    if not GameSettings.settings_changed.is_connected(_on_settings_changed):
        GameSettings.settings_changed.connect(_on_settings_changed)
    if not get_viewport().size_changed.is_connected(_apply_layout):
        get_viewport().size_changed.connect(_apply_layout)
    call_deferred("_apply_layout")

func bind_combatant(control: Control, combatant: Dictionary, enemy: bool) -> void:
    control.mouse_entered.connect(func(): show_preview(combatant, enemy))
    control.mouse_exited.connect(hide_preview)
    control.focus_entered.connect(func(): show_preview(combatant, enemy))
    control.focus_exited.connect(hide_preview)
    if control is BaseButton:
        (control as BaseButton).pressed.connect(func(): open_detail(combatant, enemy))

func show_preview(combatant: Dictionary, enemy: bool) -> void:
    if detail_open or combatant.is_empty():
        return
    _clear(preview_content)
    preview_content.add_child(_label(_title(combatant, enemy), 17, GOLD))
    preview_content.add_child(_label(_stat_line(combatant, enemy), 13, TEXT))
    var capture_summary := _capture_summary(combatant) if enemy else ""
    if capture_summary != "":
        preview_content.add_child(_label(capture_summary, 12, _capture_color(combatant)))
    preview_content.add_child(_label("Afflictions : " + _affliction_summary(combatant, enemy, 3), 12, MUTED))
    preview_content.add_child(_label("Compétences : " + _skill_summary(combatant, enemy, 3), 12, MUTED))
    preview_panel.visible = true
    call_deferred("_apply_layout")

func hide_preview() -> void:
    if not detail_open and is_instance_valid(preview_panel):
        preview_panel.visible = false

func open_detail(combatant: Dictionary, enemy: bool) -> void:
    if combatant.is_empty():
        return
    detail_open = true
    preview_panel.visible = false
    detail_overlay.visible = true
    HUDDirector.set_disclosure_level(HUDDirector.LEVEL_INSPECTION)
    _clear(detail_content)
    detail_content.add_child(_label(_title(combatant, enemy), 25, GOLD))
    detail_content.add_child(_label("STATISTIQUES", 18, GOLD))
    detail_content.add_child(_label(_stat_line(combatant, enemy), 15, TEXT))
    var capture_summary := _capture_summary(combatant) if enemy else ""
    if capture_summary != "":
        detail_content.add_child(_label("CAPTURE", 18, GOLD))
        detail_content.add_child(_label(capture_summary, 15, _capture_color(combatant)))
    detail_content.add_child(_label("AFFLICTIONS, BUFFS ET DEBUFFS", 18, GOLD))
    for line in _affliction_lines(combatant, enemy):
        detail_content.add_child(_label("• " + line, 14, TEXT))
    detail_content.add_child(_label("COMPÉTENCES", 18, GOLD))
    for line in _skill_lines(combatant, enemy):
        detail_content.add_child(_label("• " + line, 14, TEXT))
    call_deferred("_apply_layout")

func close_detail() -> void:
    if not detail_open:
        return
    detail_open = false
    detail_overlay.visible = false
    HUDDirector.set_screen_context(GameState.current_screen)

func _unhandled_input(event: InputEvent) -> void:
    if detail_open and (event.is_action_pressed("back") or event.is_action_pressed("confirm")):
        close_detail()
        get_viewport().set_input_as_handled()

func _build_preview() -> void:
    preview_panel = PanelContainer.new()
    preview_panel.custom_minimum_size = BASE_PREVIEW_SIZE
    preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    preview_panel.add_theme_stylebox_override("panel", _style())
    add_child(preview_panel)
    preview_content = VBoxContainer.new()
    preview_content.add_theme_constant_override("separation", 4)
    preview_panel.add_child(preview_content)
    preview_panel.visible = false

func _build_detail() -> void:
    detail_overlay = Control.new()
    detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(detail_overlay)
    var dim := ColorRect.new()
    dim.color = Color(0.005, 0.006, 0.010, 0.91)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    detail_overlay.add_child(dim)

    detail_frame = PanelContainer.new()
    detail_frame.size = BASE_DETAIL_SIZE
    detail_frame.add_theme_stylebox_override("panel", _style())
    detail_overlay.add_child(detail_frame)

    var root := VBoxContainer.new()
    detail_frame.add_child(root)
    var header := HBoxContainer.new()
    root.add_child(header)
    var heading := _label("INSPECTION DU COMBATTANT", 17, MUTED)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(heading)

    detail_close_button = Button.new()
    detail_close_button.text = "FERMER"
    detail_close_button.set_meta(META_BASE_FONT, 14)
    detail_close_button.custom_minimum_size = Vector2(140, 42)
    detail_close_button.pressed.connect(close_detail)
    header.add_child(detail_close_button)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    detail_content = VBoxContainer.new()
    detail_content.custom_minimum_size = Vector2(790, 500)
    detail_content.add_theme_constant_override("separation", 8)
    scroll.add_child(detail_content)
    detail_overlay.visible = false

func _on_settings_changed() -> void:
    call_deferred("_apply_layout")

func _apply_layout() -> void:
    if preview_panel == null or detail_frame == null or detail_content == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var insets := _logical_safe_insets(viewport_size)
    var safe_origin := Vector2(insets.x + SAFE_GUTTER, insets.y + SAFE_GUTTER)
    var safe_size := Vector2(
        maxf(1.0, viewport_size.x - insets.x - insets.z - SAFE_GUTTER * 2.0),
        maxf(1.0, viewport_size.y - insets.y - insets.w - SAFE_GUTTER * 2.0)
    )
    var ui_scale := clampf(GameSettings.ui_scale, 0.8, 1.4)

    var preview_size := BASE_PREVIEW_SIZE * ui_scale
    preview_size.x = minf(preview_size.x, safe_size.x)
    preview_size.y = minf(preview_size.y, safe_size.y * 0.42)
    preview_panel.custom_minimum_size = preview_size
    preview_panel.size = preview_size
    preview_panel.position = safe_origin + Vector2(maxf(0.0, (safe_size.x - preview_size.x) * 0.5), 0.0)

    var desired_detail := BASE_DETAIL_SIZE * ui_scale
    var detail_size := Vector2(
        minf(desired_detail.x, safe_size.x),
        minf(desired_detail.y, safe_size.y)
    )
    detail_frame.size = detail_size
    detail_frame.position = safe_origin + Vector2(
        maxf(0.0, (safe_size.x - detail_size.x) * 0.5),
        maxf(0.0, (safe_size.y - detail_size.y) * 0.5)
    )
    detail_content.custom_minimum_size = Vector2(
        maxf(220.0, detail_size.x - 70.0),
        maxf(180.0, detail_size.y - 92.0)
    )
    if detail_close_button != null:
        detail_close_button.custom_minimum_size = Vector2(
            minf(196.0, maxf(120.0, 140.0 * ui_scale)),
            maxf(44.0, 42.0 * ui_scale)
        )

    _apply_text_scale_existing()
    set_meta("litd_safe_area_insets", insets)
    set_meta("litd_ui_scale", ui_scale)
    set_meta("litd_text_scale", GameSettings.text_scale)

func _apply_text_scale_existing() -> void:
    for node_value: Node in find_children("*", "Control", true, false):
        if not (node_value is Label or node_value is Button):
            continue
        var control := node_value as Control
        var base_size := int(control.get_meta(META_BASE_FONT, -1))
        if base_size <= 0:
            base_size = control.get_theme_font_size("font_size")
            if base_size <= 0:
                base_size = 16
            control.set_meta(META_BASE_FONT, base_size)
        control.add_theme_font_size_override(
            "font_size",
            maxi(10, int(round(float(base_size) * GameSettings.text_scale)))
        )

func _logical_safe_insets(reference_size: Vector2) -> Vector4:
    if not OS.has_feature("mobile"):
        return Vector4.ZERO
    var screen_size_i := DisplayServer.screen_get_size()
    var screen_position_i := DisplayServer.screen_get_position()
    var safe_i := DisplayServer.get_display_safe_area()
    if screen_size_i.x <= 0 or screen_size_i.y <= 0 or safe_i.size.x <= 0 or safe_i.size.y <= 0:
        return Vector4.ZERO

    var screen_size := Vector2(screen_size_i)
    var safe_position := Vector2(safe_i.position - screen_position_i)
    var safe_size := Vector2(safe_i.size)
    var content_scale := minf(screen_size.x / reference_size.x, screen_size.y / reference_size.y)
    if content_scale <= 0.0:
        return Vector4.ZERO
    var content_size := reference_size * content_scale
    var content_origin := (screen_size - content_size) * 0.5
    var content_end := content_origin + content_size
    var safe_end := safe_position + safe_size
    var clipped_left := maxf(content_origin.x, safe_position.x)
    var clipped_top := maxf(content_origin.y, safe_position.y)
    var clipped_right := minf(content_end.x, safe_end.x)
    var clipped_bottom := minf(content_end.y, safe_end.y)
    if clipped_right <= clipped_left or clipped_bottom <= clipped_top:
        return Vector4.ZERO
    return Vector4(
        maxf(0.0, (clipped_left - content_origin.x) / content_scale),
        maxf(0.0, (clipped_top - content_origin.y) / content_scale),
        maxf(0.0, (content_end.x - clipped_right) / content_scale),
        maxf(0.0, (content_end.y - clipped_bottom) / content_scale)
    )

func _title(combatant: Dictionary, enemy: bool) -> String:
    var side := "ENNEMI" if enemy else "HÉROS"
    return "%s — %s · niveau %d" % [side, String(combatant.get("name", "Inconnu")), int(combatant.get("level", 1))]

func _stat_line(combatant: Dictionary, enemy: bool) -> String:
    var parts: Array[String] = [
        "PV %d/%d" % [int(combatant.get("hp", 0)), int(combatant.get("max_hp", combatant.get("hp", 0)))],
        "DGT %s" % _damage_text(combatant.get("damage", combatant.get("damage_bonus", 0))),
        "PRÉ %d" % int(combatant.get("precision", 0)),
        "PROT %d" % int(combatant.get("physical_resistance", combatant.get("protection", 0))),
        "VIT %d" % int(combatant.get("speed", 0))
    ]
    if enemy:
        parts.append("PEUR %d" % int(combatant.get("enemy_fear", combatant.get("fear", 0))))
    else:
        parts.append("PEUR %d" % int(combatant.get("fear", 0)))
        parts.append("FOLIE %d" % int(combatant.get("madness", 0)))
        parts.append("ESPOIR %d" % int(combatant.get("hope", 0)))
    return " · ".join(parts)

func _capture_summary(combatant: Dictionary) -> String:
    var readiness: Dictionary = CreatureManager.capture_readiness(combatant)
    var state := str(readiness.get("state", ""))
    if state not in ["ready", "no_essence"]:
        return ""
    var chance := CreatureManager.capture_chance(combatant)
    var cost := int(readiness.get("essence_cost", 0))
    if state == "no_essence":
        return "◇ CAPTURABLE · %d %% de chance · coût %d Essence · Essence insuffisante" % [chance, cost]
    return "◇ CAPTURABLE · %d %% de chance · coût %d Essence" % [chance, cost]

func _capture_color(combatant: Dictionary) -> Color:
    var readiness: Dictionary = CreatureManager.capture_readiness(combatant)
    if str(readiness.get("state", "")) == "no_essence":
        return Color(0.82, 0.68, 0.38)
    return Color(0.64, 0.94, 0.82)

func _damage_text(value: Variant) -> String:
    if value is Array and value.size() >= 2:
        return "%d–%d" % [int(value[0]), int(value[1])]
    return str(int(value))

func _affliction_lines(combatant: Dictionary, enemy: bool) -> Array[String]:
    var result: Array[String] = []
    var traits := CharacterTraitDirector.trait_names(combatant)
    for value: Variant in traits.get("positive", []):
        result.append("Buff : " + String(value))
    for value: Variant in traits.get("negative", []):
        result.append("Debuff : " + String(value))
    for value: Variant in combatant.get("buffs", []):
        result.append("Buff : " + _effect_name(value))
    for value: Variant in combatant.get("debuffs", []):
        result.append("Debuff : " + _effect_name(value))
    for value: Variant in combatant.get("persistent_injuries", []):
        var injury: Dictionary = value
        var definition := PersistentInjuryRuntime.definition(String(injury.get("id", "")))
        result.append("Blessure : %s (%s)" % [String(definition.get("name", injury.get("id", ""))), String(injury.get("severity", ""))])
    for status in ["bleeding", "stunned", "broken", "burning", "guarding"]:
        if bool(combatant.get(status, false)) or int(combatant.get(status, 0)) > 0:
            result.append(_status_name(status))
    if enemy and int(combatant.get("fear", 0)) > 0:
        result.append("Peur ennemie : %d" % int(combatant.get("fear", 0)))
    if result.is_empty():
        result.append("Aucune affliction active")
    return result

func _skill_lines(combatant: Dictionary, enemy: bool) -> Array[String]:
    var result: Array[String] = []
    if enemy:
        for value: Variant in combatant.get("skills", combatant.get("abilities", [])):
            result.append(_skill_name(value))
    else:
        for value: Variant in HeroSkillManager.known_combat_skills(combatant):
            var skill: Dictionary = value
            result.append("%s — %s" % [String(skill.get("name", "Technique")), String(skill.get("description", ""))])
    if result.is_empty():
        result.append("Aucune compétence révélée")
    return result

func _affliction_summary(combatant: Dictionary, enemy: bool, limit: int) -> String:
    return _limited(_affliction_lines(combatant, enemy), limit)

func _skill_summary(combatant: Dictionary, enemy: bool, limit: int) -> String:
    return _limited(_skill_lines(combatant, enemy), limit)

func _limited(lines: Array[String], limit: int) -> String:
    var visible := lines.slice(0, mini(lines.size(), limit))
    var result := ", ".join(visible)
    if lines.size() > limit:
        result += " (+%d)" % (lines.size() - limit)
    return result

func _effect_name(value: Variant) -> String:
    if value is Dictionary:
        return String(value.get("name", value.get("id", "Effet")))
    return String(value)

func _skill_name(value: Variant) -> String:
    if value is Dictionary:
        return "%s — %s" % [String(value.get("name", value.get("id", "Technique"))), String(value.get("description", ""))]
    return String(value)

func _status_name(status: String) -> String:
    return {"bleeding":"Saignement","stunned":"Étourdissement","broken":"Rupture","burning":"Brûlure","guarding":"Garde"}.get(status, status)

func _clear(container: Container) -> void:
    for child in container.get_children():
        child.queue_free()

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.55, 0.42, 0.22, 0.95)
    style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.set_meta(META_BASE_FONT, size)
    label.add_theme_font_size_override("font_size", maxi(10, int(round(float(size) * GameSettings.text_scale))))
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label
