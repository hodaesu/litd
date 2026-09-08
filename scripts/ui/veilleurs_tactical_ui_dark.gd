extends "res://scripts/ui/veilleurs_tactical_ui.gd"
class_name VeilleursTacticalUIDark

var party_bar: HBoxContainer

func _build() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = UITokens.COLOR_BACKGROUND
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)

    var root := VBoxContainer.new()
    root.name = "TacticalLayout"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", UITokens.SPACE_S)
    add_child(root)

    status_label = Label.new()
    status_label.text = "LITD : Les Veilleurs — combat tactique 6×5"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(0, 36)
    status_label.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    status_label.add_theme_font_size_override("font_size", UITokens.TEXT_BODY)
    root.add_child(status_label)

    party_bar = HBoxContainer.new()
    party_bar.name = "PartyBar"
    party_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    party_bar.add_theme_constant_override("separation", UITokens.SPACE_S)
    root.add_child(party_bar)

    grid_container = GridContainer.new()
    grid_container.name = "Grid6x5"
    grid_container.columns = GRID_WIDTH
    grid_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    grid_container.add_theme_constant_override("h_separation", UITokens.SPACE_XS)
    grid_container.add_theme_constant_override("v_separation", UITokens.SPACE_XS)
    root.add_child(grid_container)
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            var button := LITDBaseButton.new()
            button.button_kind = "secondary"
            button.custom_minimum_size = TOUCH_MIN
            button.text = "·"
            button.tooltip_text = "Case %d,%d" % [x, y]
            button.set_meta("cell", Vector2i(x, y))
            button.set_meta("occupant", "")
            button.pressed.connect(_on_cell_pressed.bind(Vector2i(x, y)))
            grid_container.add_child(button)
            cell_buttons.append(button)

    var zones := HBoxContainer.new()
    zones.name = "BodyZones"
    zones.alignment = BoxContainer.ALIGNMENT_CENTER
    zones.add_theme_constant_override("separation", UITokens.SPACE_XS)
    root.add_child(zones)
    var zone_labels := {"head":"Tête", "torso":"Torse", "left_arm":"Bras G", "right_arm":"Bras D", "left_leg":"Jambe G", "right_leg":"Jambe D"}
    for zone: String in ZONES:
        var button := LITDBaseButton.new()
        button.button_kind = "secondary"
        button.custom_minimum_size = Vector2(72, UITokens.TOUCH_MIN_SIZE)
        button.toggle_mode = true
        button.text = str(zone_labels.get(zone, zone))
        button.set_meta("zone", zone)
        button.set_meta("base_text", button.text)
        button.pressed.connect(_on_zone_pressed.bind(zone))
        zones.add_child(button)
        zone_buttons.append(button)

    var actions := HBoxContainer.new()
    actions.name = "Actions"
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", UITokens.SPACE_S)
    root.add_child(actions)
    for slot in range(4):
        var button := LITDSkillButton.new()
        button.custom_minimum_size = Vector2(124, UITokens.TOUCH_PRIMARY_SIZE)
        button.text = "Compétence %d" % [slot + 1]
        button.set_meta("slot", slot)
        button.pressed.connect(_on_skill_pressed.bind(slot))
        actions.add_child(button)
        skill_buttons.append(button)
        skill_names.append(button.text)

    inspect_button = LITDBaseButton.new()
    inspect_button.button_kind = "contextual"
    inspect_button.custom_minimum_size = Vector2(118, UITokens.TOUCH_PRIMARY_SIZE)
    inspect_button.text = "Inspecter"
    inspect_button.pressed.connect(_on_inspect_pressed)
    actions.add_child(inspect_button)

    retreat_button = LITDBaseButton.new()
    retreat_button.button_kind = "destructive"
    retreat_button.custom_minimum_size = Vector2(140, UITokens.TOUCH_PRIMARY_SIZE)
    retreat_button.text = "Retraite"
    retreat_button.pressed.connect(_on_retreat_pressed)
    actions.add_child(retreat_button)

    _apply_selection_visuals()
    _update_status_label()

func bind_snapshot(snapshot: Dictionary) -> void:
    super.bind_snapshot(snapshot)
    _refresh_party_cards()

func set_skill_labels(names: Array[String]) -> void:
    super.set_skill_labels(names)
    for index in range(skill_buttons.size()):
        var skill_button := skill_buttons[index] as LITDSkillButton
        if skill_button == null:
            continue
        skill_button.skill_id = "slot_%d" % index
        skill_button.blocked_reason = "Compétence indisponible dans cette configuration." if skill_button.disabled else ""
        skill_button.refresh_state()

func set_armed_skill(slot: int) -> void:
    super.set_armed_skill(slot)
    _sync_skill_states()

func set_targeting_mode(enabled: bool, candidates: Array = [], blocked: Array = [], confirmed: bool = false) -> void:
    super.set_targeting_mode(enabled, candidates, blocked, confirmed)
    _sync_skill_states()

func _refresh_party_cards() -> void:
    if party_bar == null:
        return
    for child in party_bar.get_children():
        child.queue_free()
    var combatants: Dictionary = runtime_snapshot.get("combatants", {})
    var watcher_ids: Array[String] = []
    for id_value: Variant in combatants.keys():
        var entity_id := str(id_value)
        var row: Dictionary = combatants[entity_id]
        if str(row.get("team", "")) == "watcher" or entity_id.begins_with("ENT_WATCHER_"):
            watcher_ids.append(entity_id)
    watcher_ids.sort()
    for entity_id: String in watcher_ids:
        var row: Dictionary = combatants[entity_id].duplicate(true)
        row["entity_id"] = entity_id
        if not row.has("statuses"):
            row["statuses"] = _status_payload(row)
        var card := LITDCharacterCard.new()
        card.bind_character(row, entity_id == selected_watcher)
        card.character_pressed.connect(_select_character_from_card)
        party_bar.add_child(card)

func _status_payload(row: Dictionary) -> Array:
    var result: Array = []
    if int(row.get("hp", 0)) <= maxi(1, int(row.get("max_hp", 1)) / 4):
        result.append({"id":"critical_hp", "name":"Vitalité critique", "glyph":"!", "severity":4})
    if bool(row.get("bleeding", false)):
        result.append({"id":"bleeding", "name":"Saignement", "glyph":"◆", "severity":3})
    if bool(row.get("fractured", false)):
        result.append({"id":"fracture", "name":"Fracture", "glyph":"×", "severity":3})
    return result

func _select_character_from_card(entity_id: String) -> void:
    selected_watcher = entity_id
    _apply_selection_visuals()
    _refresh_party_cards()
    _update_status_label()

func _sync_skill_states() -> void:
    for index in range(skill_buttons.size()):
        var skill_button := skill_buttons[index] as LITDSkillButton
        if skill_button == null:
            continue
        skill_button.set_interaction_state(index == armed_skill_slot, target_selection_mode and index == armed_skill_slot)
