extends CanvasLayer
class_name AshlandsHUD

@onready var zone_label: Label = $Margin/VBox/ZoneLabel
@onready var supplies_label: Label = $Margin/VBox/SuppliesLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var margin: Control = $Margin

func _ready() -> void:
    margin.visible = false
    ExpeditionManager.inventory_changed.connect(_on_inventory_changed)
    AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    AshlandsRuntime.lore_discovered.connect(_on_lore_discovered)
    _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("back"):
        margin.visible = not margin.visible
        get_viewport().set_input_as_handled()

func _refresh() -> void:
    zone_label.text = _pretty_zone(AshlandsRuntime.current_zone_id)
    _on_inventory_changed(ExpeditionManager.inventory)
    var miniboss := AshlandsMinibossDirector.get_assignment(AshlandsRuntime.current_zone_id)
    status_label.text = "Mini-boss possible : %s" % str(miniboss.get("name", "aucun")) if not miniboss.is_empty() else "Exploration"

func _on_inventory_changed(inv: Dictionary) -> void:
    supplies_label.text = "Nourriture %d  Eau %d  Bandages %d  Lumière %d  Camp %d" % [
        int(inv.get("food", 0)),
        int(inv.get("water", 0)),
        int(inv.get("bandages", 0)),
        int(inv.get("light", 0)),
        int(inv.get("camp_tools", 0))
    ]

func _on_zone_discovered(_zone_id: String) -> void:
    _refresh()

func _on_lore_discovered(entry: Dictionary) -> void:
    var overlay := ColorRect.new()
    overlay.name = "LoreReader"
    overlay.color = Color(0.02, 0.018, 0.025, 0.94)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var margin_reader := MarginContainer.new()
    margin_reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin_reader.add_theme_constant_override("margin_left", 120)
    margin_reader.add_theme_constant_override("margin_right", 120)
    margin_reader.add_theme_constant_override("margin_top", 70)
    margin_reader.add_theme_constant_override("margin_bottom", 70)
    overlay.add_child(margin_reader)

    var column := VBoxContainer.new()
    margin_reader.add_child(column)
    var collection := Label.new()
    var collection_id := str(entry.get("collection", ""))
    var collection_data: Dictionary = DataLoader.ashlands_lore.get("collections", {}).get(collection_id, {})
    collection.text = "%s  •  %d/%d" % [
        str(entry.get("collection_name", entry.get("collection", "Archive"))),
        AshlandsRuntime.lore_collection_count(collection_id),
        int(collection_data.get("total", 0))
    ]
    collection.modulate = Color(0.78, 0.62, 0.32)
    column.add_child(collection)
    var title := Label.new()
    title.text = str(entry.get("title", "Fragment sans titre"))
    title.add_theme_font_size_override("font_size", 30)
    column.add_child(title)
    var source := Label.new()
    source.text = "%s — %s" % [str(entry.get("document_type", "Texte")), str(entry.get("author", "Auteur inconnu"))]
    source.modulate = Color(0.72, 0.72, 0.75)
    column.add_child(source)
    var body := RichTextLabel.new()
    body.bbcode_enabled = false
    body.fit_content = false
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.text = str(entry.get("text", ""))
    body.add_theme_font_size_override("normal_font_size", 21)
    column.add_child(body)
    var close := Button.new()
    close.text = "REFERMER"
    close.custom_minimum_size = Vector2(220, 46)
    close.pressed.connect(overlay.queue_free)
    column.add_child(close)

func _pretty_zone(id_value: String) -> String:
    if id_value == "":
        return "TERRE DES CENDRES"
    return id_value.replace("zone_", "ZONE ").replace("_", " ").capitalize()

func _on_return_pressed() -> void:
    AshlandsSceneRouter.return_to_hub("voluntary")
