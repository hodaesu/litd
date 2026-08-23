extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const PANEL := Color(0.025, 0.028, 0.038, 0.98)

var preview_panel: PanelContainer
var preview_content: VBoxContainer
var detail_overlay: Control
var detail_content: VBoxContainer
var detail_open := false

func _ready() -> void:
    layer = 75
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_preview()
    _build_detail()
    GameState.screen_requested.connect(func(_screen: String): close_detail(); hide_preview())

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
    preview_content.add_child(_label("Afflictions : " + _affliction_summary(combatant, enemy, 3), 12, MUTED))
    preview_content.add_child(_label("Compétences : " + _skill_summary(combatant, enemy, 3), 12, MUTED))
    preview_panel.visible = true

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
    detail_content.add_child(_label("AFFLICTIONS, BUFFS ET DEBUFFS", 18, GOLD))
    for line in _affliction_lines(combatant, enemy):
        detail_content.add_child(_label("• " + line, 14, TEXT))
    detail_content.add_child(_label("COMPÉTENCES", 18, GOLD))
    for line in _skill_lines(combatant, enemy):
        detail_content.add_child(_label("• " + line, 14, TEXT))

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
    preview_panel.position = Vector2(420, 72)
    preview_panel.custom_minimum_size = Vector2(440, 126)
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
    var frame := PanelContainer.new()
    frame.position = Vector2(210, 70)
    frame.size = Vector2(860, 580)
    frame.add_theme_stylebox_override("panel", _style())
    detail_overlay.add_child(frame)
    var root := VBoxContainer.new()
    frame.add_child(root)
    var header := HBoxContainer.new()
    root.add_child(header)
    var heading := _label("INSPECTION DU COMBATTANT", 17, MUTED)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(heading)
    var close := Button.new()
    close.text = "FERMER"
    close.custom_minimum_size = Vector2(140, 42)
    close.pressed.connect(close_detail)
    header.add_child(close)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    detail_content = VBoxContainer.new()
    detail_content.custom_minimum_size = Vector2(790, 500)
    detail_content.add_theme_constant_override("separation", 8)
    scroll.add_child(detail_content)
    detail_overlay.visible = false

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
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label
