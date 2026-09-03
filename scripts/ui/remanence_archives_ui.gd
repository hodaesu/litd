extends Node

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const PANEL := Color(0.025, 0.027, 0.035, 0.98)

var layer: CanvasLayer
var launch_button: Button
var panel: PanelContainer
var list: ItemList
var detail: RichTextLabel
var summary: Label
var search: LineEdit
var stage_filter: OptionButton
var status_filter: OptionButton
var mode := "entities"
var search_text := ""
var minimum_stage_rank := 0
var status_mode := "all"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_build")

func _build() -> void:
    layer = CanvasLayer.new()
    layer.layer = 92
    add_child(layer)

    launch_button = Button.new()
    launch_button.text = "ARCHIVES"
    launch_button.custom_minimum_size = Vector2(138, 50)
    launch_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    launch_button.offset_left = -158
    launch_button.offset_top = 74
    launch_button.offset_right = -20
    launch_button.offset_bottom = 124
    launch_button.pressed.connect(open_archives)
    layer.add_child(launch_button)

    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 24
    panel.offset_top = 24
    panel.offset_right = -24
    panel.offset_bottom = -24
    panel.add_theme_stylebox_override("panel", _panel_style())
    panel.visible = false
    layer.add_child(panel)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    panel.add_child(root)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    root.add_child(header)
    var title := _label("ARCHIVES DES VEILLEURS", 28, GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close := _button("FERMER", close_archives, Vector2(120, 50))
    header.add_child(close)

    summary = _label("", 14, MUTED)
    root.add_child(summary)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    root.add_child(tabs)
    tabs.add_child(_button("ADVERSAIRES", func(): _switch_mode("entities"), Vector2(190, 48)))
    tabs.add_child(_button("CICATRICES", func(): _switch_mode("scars"), Vector2(190, 48)))
    tabs.add_child(_button("CHRONOLOGIE", func(): _switch_mode("timeline"), Vector2(190, 48)))

    var filters := HBoxContainer.new()
    filters.add_theme_constant_override("separation", 8)
    root.add_child(filters)
    search = LineEdit.new()
    search.placeholder_text = "Rechercher un adversaire, une trace, un événement…"
    search.custom_minimum_size = Vector2(390, 48)
    search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search.text_changed.connect(_on_search_changed)
    filters.add_child(search)

    stage_filter = OptionButton.new()
    stage_filter.custom_minimum_size = Vector2(180, 48)
    for label in ["Tous stades", "Mémoriel+", "Vétéran+", "Élite+", "Némésis"]:
        stage_filter.add_item(label)
    stage_filter.item_selected.connect(_on_stage_filter_selected)
    filters.add_child(stage_filter)

    status_filter = OptionButton.new()
    status_filter.custom_minimum_size = Vector2(165, 48)
    for label in ["Tous statuts", "Actifs", "Morts", "Recrutés", "Archivés"]:
        status_filter.add_item(label)
    status_filter.item_selected.connect(_on_status_filter_selected)
    filters.add_child(status_filter)

    var split := HSplitContainer.new()
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.split_offset = 430
    root.add_child(split)

    list = ItemList.new()
    list.custom_minimum_size = Vector2(405, 450)
    list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    list.item_selected.connect(_on_item_selected)
    split.add_child(list)

    detail = RichTextLabel.new()
    detail.bbcode_enabled = false
    detail.fit_content = false
    detail.scroll_active = true
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail.add_theme_font_size_override("normal_font_size", 17)
    detail.add_theme_color_override("default_color", TEXT)
    detail.text = "Sélectionne une entrée des Archives."
    split.add_child(detail)

    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not RemanenceRuntime.remanence_changed.is_connected(_on_remanence_changed):
        RemanenceRuntime.remanence_changed.connect(_on_remanence_changed)
    _sync_visibility(GameState.current_screen)

func open_archives() -> void:
    if panel == null:
        return
    panel.visible = true
    launch_button.visible = false
    _refresh()

func close_archives() -> void:
    if panel == null:
        return
    panel.visible = false
    _sync_visibility(GameState.current_screen)

func _switch_mode(next_mode: String) -> void:
    mode = next_mode
    var entity_filters_visible := mode == "entities"
    if stage_filter != null:
        stage_filter.visible = entity_filters_visible
    if status_filter != null:
        status_filter.visible = entity_filters_visible
    _refresh()

func _on_search_changed(value: String) -> void:
    search_text = value.strip_edges().to_lower()
    _refresh()

func _on_stage_filter_selected(index: int) -> void:
    minimum_stage_rank = clampi(index, 0, 4)
    _refresh()

func _on_status_filter_selected(index: int) -> void:
    status_mode = ["all", "active", "dead", "recruited", "archived"][clampi(index, 0, 4)]
    _refresh()

func _on_screen_requested(screen_name: String) -> void:
    if panel != null and screen_name != "sanctuary":
        panel.visible = false
    _sync_visibility(screen_name)

func _on_new_game_reset() -> void:
    search_text = ""
    minimum_stage_rank = 0
    status_mode = "all"
    if search != null:
        search.text = ""
    if stage_filter != null:
        stage_filter.select(0)
    if status_filter != null:
        status_filter.select(0)
    if panel != null:
        panel.visible = false
    _sync_visibility(GameState.current_screen)

func _on_remanence_changed() -> void:
    if panel != null and panel.visible:
        _refresh()

func _sync_visibility(screen_name: String) -> void:
    if launch_button == null:
        return
    launch_button.visible = screen_name == "sanctuary" and (panel == null or not panel.visible)

func _refresh() -> void:
    if list == null or detail == null:
        return
    list.clear()
    detail.text = "Sélectionne une entrée des Archives."
    var nemesis_count := 0
    for record_value: Variant in RemanenceRuntime.entities.values():
        if record_value is Dictionary and str((record_value as Dictionary).get("stage", "")) == "nemesis":
            nemesis_count += 1
    summary.text = "%d adversaire(s) actifs · %d Némésis · %d cicatrice(s) actives · %d événements" % [
        RemanenceRuntime.entities.size(), nemesis_count, RemanenceRuntime.world_scars.size(), RemanenceRuntime.event_timeline.size()
    ]
    match mode:
        "scars": _fill_scars()
        "timeline": _fill_timeline()
        _: _fill_entities()
    if list.item_count > 0:
        list.select(0)
        _on_item_selected(0)
    else:
        detail.text = "Aucune entrée ne correspond aux filtres actuels."

func _fill_entities() -> void:
    var rows: Array[Dictionary] = []
    for key_value: Variant in RemanenceRuntime.entities.keys():
        var record: Dictionary = RemanenceRuntime.entities[key_value]
        rows.append(record.duplicate(true))
    for value: Variant in RemanenceRuntime.archived_entities:
        var record: Dictionary = value
        var copy := record.duplicate(true)
        copy["archived"] = true
        rows.append(copy)
    rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_rank := _stage_rank(str(left.get("stage", "normal")))
        var right_rank := _stage_rank(str(right.get("stage", "normal")))
        if left_rank == right_rank:
            return int(left.get("score", 0)) > int(right.get("score", 0))
        return left_rank > right_rank
    )
    for record: Dictionary in rows:
        if not _entity_matches_filters(record):
            continue
        var entity_id := str(record.get("id", ""))
        var prefix := "[ARCHIVÉ] " if bool(record.get("archived", false)) else ""
        var row := "%s%s · %s · %s · score %d" % [
            prefix,
            str(record.get("name", "Adversaire")),
            _stage_name(str(record.get("stage", "normal"))),
            _status_name(str(record.get("status", "active"))),
            int(record.get("score", 0))
        ]
        var index := list.add_item(row)
        list.set_item_metadata(index, {"kind": "entity", "id": entity_id, "record": record})

func _fill_scars() -> void:
    var rows: Array[Dictionary] = []
    for key_value: Variant in RemanenceRuntime.world_scars.keys():
        var scar: Dictionary = RemanenceRuntime.world_scars[key_value]
        rows.append(scar.duplicate(true))
    for value: Variant in RemanenceRuntime.archived_scars:
        var scar: Dictionary = value
        var copy := scar.duplicate(true)
        copy["archived"] = true
        rows.append(copy)
    rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left.get("created_run", 0)) > int(right.get("created_run", 0))
    )
    for scar: Dictionary in rows:
        if not _scar_matches_search(scar):
            continue
        var prefix := "[ARCHIVÉ] " if bool(scar.get("archived", false)) else ""
        var payload: Dictionary = scar.get("payload", {})
        var owner := str(payload.get("owner_name", ""))
        var owner_suffix := " · %s" % owner if owner != "" else ""
        var row := "%s%s%s · %s · %s" % [prefix, _scar_type_name(str(scar.get("type", "trace"))), owner_suffix, str(scar.get("severity", "trace")), str(scar.get("age_stage", "fresh"))]
        var index := list.add_item(row)
        list.set_item_metadata(index, {"kind": "scar", "record": scar})

func _fill_timeline() -> void:
    for event: Dictionary in RemanenceRuntime.recent_events("", 120):
        if not _event_matches_search(event):
            continue
        var row := "#%d · %s · %s" % [int(event.get("seq", 0)), _event_name(str(event.get("type", "event"))), _entity_name(str(event.get("entity_id", "")))]
        var index := list.add_item(row)
        list.set_item_metadata(index, {"kind": "event", "record": event})

func _entity_matches_filters(record: Dictionary) -> bool:
    if _stage_rank(str(record.get("stage", "normal"))) < minimum_stage_rank:
        return false
    var archived := bool(record.get("archived", false))
    var status := str(record.get("status", "active"))
    match status_mode:
        "active":
            if archived or status != "active": return false
        "dead":
            if status != "dead": return false
        "recruited":
            if status != "recruited": return false
        "archived":
            if not archived: return false
    if search_text == "":
        return true
    var haystack := "%s %s %s %s" % [record.get("name", ""), record.get("id", ""), record.get("region_id", ""), record.get("stage", "")]
    return haystack.to_lower().contains(search_text)

func _scar_matches_search(scar: Dictionary) -> bool:
    if search_text == "":
        return true
    var payload: Dictionary = scar.get("payload", {})
    var haystack := "%s %s %s %s %s %s" % [scar.get("type", ""), scar.get("summary", ""), scar.get("anchor_id", ""), scar.get("zone_id", ""), payload.get("owner_name", ""), payload.get("owner_id", "")]
    return haystack.to_lower().contains(search_text)

func _event_matches_search(event: Dictionary) -> bool:
    if search_text == "":
        return true
    var haystack := "%s %s %s %s %s" % [event.get("type", ""), event.get("summary", ""), _entity_name(str(event.get("entity_id", ""))), event.get("hero_id", ""), event.get("object_id", "")]
    return haystack.to_lower().contains(search_text)

func _on_item_selected(index: int) -> void:
    if index < 0 or index >= list.item_count:
        return
    var metadata_value: Variant = list.get_item_metadata(index)
    if not (metadata_value is Dictionary):
        return
    var metadata: Dictionary = metadata_value
    match str(metadata.get("kind", "")):
        "entity": _show_entity(metadata)
        "scar": _show_scar(metadata.get("record", {}))
        "event": _show_event(metadata.get("record", {}))

func _show_entity(metadata: Dictionary) -> void:
    var record: Dictionary = metadata.get("record", {})
    var entity_id := str(metadata.get("id", record.get("id", "")))
    if RemanenceRuntime.entities.has(entity_id):
        record = RemanenceRuntime.entity_state(entity_id)
    var lines: Array[String] = []
    lines.append(str(record.get("name", "Adversaire")).to_upper())
    lines.append("Stade : %s" % _stage_name(str(record.get("stage", "normal"))))
    lines.append("Statut : %s" % _status_name(str(record.get("status", "inconnu"))))
    lines.append("Score mémoriel : %d" % int(record.get("score", 0)))
    lines.append("Rencontres : %d · événements majeurs : %d" % [int(record.get("encounters", 0)), int(record.get("major_events", 0))])
    lines.append("Région : %s" % str(record.get("region_id", "inconnue")))
    var adaptations: Array = record.get("adaptations", [])
    if not adaptations.is_empty():
        var adaptation_names: Array[String] = []
        for adaptation_value: Variant in adaptations:
            var adaptation_id := str(adaptation_value)
            if RemanenceCombatBridge.world_director != null and RemanenceCombatBridge.world_director.has_method("adaptation_label"):
                adaptation_names.append(str(RemanenceCombatBridge.world_director.call("adaptation_label", adaptation_id)))
            else:
                adaptation_names.append(adaptation_id.replace("_", " ").capitalize())
        lines.append("Adaptations : %s" % ", ".join(adaptation_names))

    var body: Dictionary = record.get("body_snapshot", {})
    var lost: Array = body.get("dismembered_parts", [])
    var injuries: Dictionary = body.get("anatomy_injuries", {})
    var persistent: Array = body.get("persistent_injuries", [])
    if not lost.is_empty() or not injuries.is_empty() or not persistent.is_empty():
        lines.append("")
        lines.append("MÉMOIRE DU CORPS")
        if not lost.is_empty(): lines.append("Parties perdues : %s" % ", ".join(lost))
        if not injuries.is_empty(): lines.append("Lésions anatomiques : %s" % _dictionary_pairs(injuries))
        if not persistent.is_empty(): lines.append("Blessures persistantes : %s" % _array_summary(persistent))

    lines.append("")
    lines.append("ÉVÉNEMENTS")
    var events := RemanenceRuntime.recent_events(entity_id, 12)
    if events.is_empty():
        lines.append("Aucun événement détaillé conservé.")
    for event: Dictionary in events:
        lines.append("• #%d %s — %s" % [int(event.get("seq", 0)), _event_name(str(event.get("type", "event"))), str(event.get("summary", ""))])
    var links := RemanenceRuntime.linked_entries(entity_id)
    if not links.is_empty():
        lines.append("")
        lines.append("LIENS D'ARCHIVES")
        for link: Dictionary in links:
            lines.append("• %s ↔ %s (%s)" % [str(link.get("source_id", "")), str(link.get("target_id", "")), str(link.get("relation", ""))])
    detail.text = "\n".join(lines)

func _show_scar(scar: Dictionary) -> void:
    var payload: Dictionary = scar.get("payload", {})
    var lines: Array[String] = [
        "CICATRICE DU MONDE",
        "Type : %s" % _scar_type_name(str(scar.get("type", "trace"))),
        "Sévérité : %s" % str(scar.get("severity", "trace")),
        "État : %s" % str(scar.get("age_stage", "fresh")),
        "Âge : %d expédition(s)" % int(scar.get("age_runs", 0)),
        "Ancrage : %s" % str(scar.get("anchor_id", "")),
        "Zone : %s" % str(scar.get("zone_id", ""))
    ]
    if str(payload.get("owner_name", "")) != "": lines.append("Identité liée : %s" % str(payload.get("owner_name", "")))
    if int(payload.get("visit_count", 0)) > 0: lines.append("Retrouvée : %d fois" % int(payload.get("visit_count", 0)))
    if bool(payload.get("great_remanence", false)): lines.append("Statut : GRANDE RÉMANENCE")
    var disturbances: Array = payload.get("disturbances", [])
    if not disturbances.is_empty(): lines.append("Perturbations : %s" % ", ".join(disturbances))
    lines.append("")
    lines.append(str(scar.get("summary", "Aucun récit conservé.")))
    detail.text = "\n".join(lines)

func _show_event(event: Dictionary) -> void:
    var lines: Array[String] = [
        "ÉVÉNEMENT #%d" % int(event.get("seq", 0)),
        _event_name(str(event.get("type", "event"))),
        "Adversaire : %s" % _entity_name(str(event.get("entity_id", ""))),
        "Expédition : %d" % int(event.get("run_index", 0)),
        "Zone : %s" % str(event.get("zone_id", "")),
        "Héros lié : %s" % str(event.get("hero_id", "")),
        "Objet lié : %s" % str(event.get("object_id", "")),
        "",
        str(event.get("summary", ""))
    ]
    detail.text = "\n".join(lines)

func _entity_name(entity_id: String) -> String:
    if RemanenceRuntime.entities.has(entity_id):
        return str(RemanenceRuntime.entities[entity_id].get("name", entity_id))
    for value: Variant in RemanenceRuntime.archived_entities:
        var record: Dictionary = value
        if str(record.get("id", "")) == entity_id:
            return str(record.get("name", entity_id))
    return entity_id

func _dictionary_pairs(values: Dictionary) -> String:
    var rows: Array[String] = []
    for key_value: Variant in values.keys():
        rows.append("%s=%s" % [str(key_value), str(values.get(key_value))])
    return ", ".join(rows)

func _array_summary(values: Array) -> String:
    var rows: Array[String] = []
    for value: Variant in values:
        if value is Dictionary:
            rows.append(str((value as Dictionary).get("name", (value as Dictionary).get("id", "blessure"))))
        else:
            rows.append(str(value))
    return ", ".join(rows)

func _stage_rank(stage: String) -> int:
    return int({"normal": 0, "memorial": 1, "veteran": 2, "elite": 3, "nemesis": 4}.get(stage, 0))

func _stage_name(stage: String) -> String:
    return str({"normal": "Normal", "memorial": "Mémoriel", "veteran": "Vétéran", "elite": "Élite", "nemesis": "Némésis"}.get(stage, stage.capitalize()))

func _status_name(status: String) -> String:
    return str({"active": "Actif", "dead": "Mort", "recruited": "Recruté", "nemesis": "Némésis", "archived": "Archivé"}.get(status, status.capitalize()))

func _scar_type_name(scar_type: String) -> String:
    return str({
        "persistent_corpse": "Cadavre persistant",
        "nemesis_mark": "Marque de Némésis",
        "old_blood": "Sang ancien",
        "burned_area": "Zone brûlée",
        "opened_shortcut": "Raccourci ouvert",
        "destroyed_door": "Porte détruite",
        "built_barricade": "Barricade",
        "major_item_removed": "Objet majeur retiré"
    }.get(scar_type, scar_type.replace("_", " ").capitalize()))

func _event_name(event_type: String) -> String:
    return str({
        "encountered": "Première rencontre",
        "reencountered": "Retrouvé",
        "survived_combat": "A survécu",
        "major_mutilation": "Mutilation majeure",
        "capture_escaped": "Échappe à la capture",
        "forced_retreat": "Retraite imposée",
        "relic_taken": "Relique prise",
        "killed_watcher": "Veilleur abattu",
        "great_remanence": "Grande Rémanence",
        "defeated_same_watcher": "Veilleur vaincu à nouveau"
    }.get(event_type, event_type.capitalize()))

func _label(text_value: String, size: int, color: Color) -> Label:
    var result := Label.new()
    result.text = text_value
    result.add_theme_font_size_override("font_size", size)
    result.add_theme_color_override("font_color", color)
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return result

func _button(text_value: String, callback: Callable, minimum: Vector2) -> Button:
    var result := Button.new()
    result.text = text_value
    result.custom_minimum_size = minimum
    result.add_theme_font_size_override("font_size", 16)
    result.pressed.connect(callback)
    return result

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.45, 0.34, 0.20, 0.9)
    style.set_border_width_all(1)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    return style
