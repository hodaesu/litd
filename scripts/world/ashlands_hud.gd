extends CanvasLayer
class_name AshlandsHUD

@onready var zone_label: Label = $Margin/VBox/ZoneLabel
@onready var supplies_label: Label = $Margin/VBox/SuppliesLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var margin: Control = $Margin

var _party_controller: ExplorationPartyController = null
var _interaction_panel: PanelContainer
var _interaction_button: Button
var _interaction_feedback_label: Label
var _interaction_feedback_timer: Timer

func _ready() -> void:
    margin.visible = false
    ExpeditionManager.inventory_changed.connect(_on_inventory_changed)
    AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    AshlandsRuntime.lore_discovered.connect(_on_lore_discovered)
    _create_interaction_ui()
    _refresh()
    set_process(true)
    call_deferred("_bind_party_controller")

func _process(_delta: float) -> void:
    if _party_controller != null and is_instance_valid(_party_controller):
        set_process(false)
        return
    _bind_party_controller()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("back"):
        margin.visible = not margin.visible
        get_viewport().set_input_as_handled()

func _refresh() -> void:
    zone_label.text = _pretty_zone(AshlandsRuntime.current_zone_id)
    _on_inventory_changed(ExpeditionManager.inventory)
    var miniboss := AshlandsMinibossDirector.get_assignment(AshlandsRuntime.current_zone_id)
    status_label.text = "Mini-boss possible : %s" % str(miniboss.get("name", "aucun")) if not miniboss.is_empty() else "Exploration"

func _create_interaction_ui() -> void:
    _interaction_panel = PanelContainer.new()
    _interaction_panel.name = "ContextualInteraction"
    _interaction_panel.visible = false
    _interaction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_interaction_panel)
    _layout_interaction_panel()
    get_viewport().size_changed.connect(_layout_interaction_panel)

    var interaction_margin := MarginContainer.new()
    interaction_margin.add_theme_constant_override("margin_left", 12)
    interaction_margin.add_theme_constant_override("margin_right", 12)
    interaction_margin.add_theme_constant_override("margin_top", 10)
    interaction_margin.add_theme_constant_override("margin_bottom", 10)
    _interaction_panel.add_child(interaction_margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    interaction_margin.add_child(column)

    _interaction_button = Button.new()
    _interaction_button.name = "InteractionAction"
    _interaction_button.custom_minimum_size = Vector2(0, 48)
    _interaction_button.focus_mode = Control.FOCUS_NONE
    _interaction_button.visible = false
    _interaction_button.pressed.connect(_on_interaction_pressed)
    column.add_child(_interaction_button)

    _interaction_feedback_label = Label.new()
    _interaction_feedback_label.name = "InteractionFeedback"
    _interaction_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _interaction_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _interaction_feedback_label.visible = false
    column.add_child(_interaction_feedback_label)

    _interaction_feedback_timer = Timer.new()
    _interaction_feedback_timer.name = "InteractionFeedbackTimer"
    _interaction_feedback_timer.one_shot = true
    _interaction_feedback_timer.wait_time = 2.0
    _interaction_feedback_timer.timeout.connect(_on_interaction_feedback_timeout)
    add_child(_interaction_feedback_timer)

func _layout_interaction_panel() -> void:
    if _interaction_panel == null:
        return
    var viewport_width := get_viewport().get_visible_rect().size.x
    var panel_width := minf(460.0, maxf(240.0, viewport_width * 0.88))
    _interaction_panel.set_anchor(SIDE_LEFT, 0.5)
    _interaction_panel.set_anchor(SIDE_RIGHT, 0.5)
    _interaction_panel.set_anchor(SIDE_TOP, 1.0)
    _interaction_panel.set_anchor(SIDE_BOTTOM, 1.0)
    _interaction_panel.offset_left = -panel_width * 0.5
    _interaction_panel.offset_right = panel_width * 0.5
    _interaction_panel.offset_top = -126.0
    _interaction_panel.offset_bottom = -18.0

func _bind_party_controller() -> void:
    for candidate in get_tree().get_nodes_in_group("player_party"):
        if candidate is ExplorationPartyController:
            _set_party_controller(candidate as ExplorationPartyController)
            return

func _set_party_controller(controller: ExplorationPartyController) -> void:
    if controller == _party_controller:
        return
    if _party_controller != null and is_instance_valid(_party_controller):
        if _party_controller.interaction_target_changed.is_connected(_on_interaction_target_changed):
            _party_controller.interaction_target_changed.disconnect(_on_interaction_target_changed)
        if _party_controller.interaction_feedback.is_connected(_on_interaction_feedback):
            _party_controller.interaction_feedback.disconnect(_on_interaction_feedback)
        if _party_controller.tree_exiting.is_connected(_on_party_controller_tree_exiting):
            _party_controller.tree_exiting.disconnect(_on_party_controller_tree_exiting)
    _party_controller = controller
    if _party_controller == null:
        _on_interaction_target_changed({})
        set_process(true)
        return
    _party_controller.interaction_target_changed.connect(_on_interaction_target_changed)
    _party_controller.interaction_feedback.connect(_on_interaction_feedback)
    _party_controller.tree_exiting.connect(_on_party_controller_tree_exiting)
    _on_interaction_target_changed(_party_controller.get_interaction_descriptor())
    set_process(false)

func _on_party_controller_tree_exiting() -> void:
    _party_controller = null
    _on_interaction_target_changed({})
    set_process(true)

func _on_interaction_target_changed(descriptor: Dictionary) -> void:
    if descriptor.is_empty():
        _interaction_button.visible = false
        _interaction_button.disabled = false
        _interaction_button.text = ""
        _update_interaction_visibility()
        return
    _interaction_button.text = _interaction_prompt_text(descriptor)
    _interaction_button.disabled = not bool(descriptor.get("available", false))
    _interaction_button.visible = true
    _update_interaction_visibility()

func _on_interaction_pressed() -> void:
    if _party_controller == null or not is_instance_valid(_party_controller):
        return
    _party_controller.interact()

func _on_interaction_feedback(result: Dictionary) -> void:
    var text := _feedback_text(result)
    if text.is_empty():
        return
    _interaction_feedback_label.text = text
    _interaction_feedback_label.visible = true
    _interaction_feedback_timer.start()
    _update_interaction_visibility()

func _on_interaction_feedback_timeout() -> void:
    _interaction_feedback_label.visible = false
    _interaction_feedback_label.text = ""
    _update_interaction_visibility()

func _update_interaction_visibility() -> void:
    if _interaction_panel == null:
        return
    _interaction_panel.visible = _interaction_button.visible or _interaction_feedback_label.visible

func _interaction_prompt_text(descriptor: Dictionary) -> String:
    if descriptor.is_empty():
        return ""
    var label := str(descriptor.get("label", "Interaction")).strip_edges()
    if bool(descriptor.get("available", false)):
        var verb := str(descriptor.get("verb", "INTERAGIR")).strip_edges()
        return "%s — %s" % [verb, label]
    return "INDISPONIBLE — %s\n%s" % [label, _blocked_reason_text(str(descriptor.get("blocked_reason", "unavailable")))]

func _blocked_reason_text(reason: String) -> String:
    match reason:
        "already_used":
            return "Déjà utilisé."
        "already_collected", "depleted", "no_drop":
            return "Rien de plus ici."
        "locked":
            return "Accès bloqué."
        "missing_target":
            return "Plus rien à examiner."
        "unsupported_interaction":
            return "Interaction impossible."
        "unavailable", "interaction_failed", "":
            return "Impossible pour l’instant."
        _:
            return "Impossible pour l’instant."

func _feedback_text(result: Dictionary) -> String:
    if result.is_empty():
        return ""
    if not bool(result.get("success", false)):
        return _blocked_reason_text(str(result.get("reason", "interaction_failed")))
    match str(result.get("kind", "environment")):
        EnvironmentInteractionContract.KIND_RESOURCE:
            return "Ressource récupérée."
        EnvironmentInteractionContract.KIND_DOOR:
            return "Passage accessible."
        EnvironmentInteractionContract.KIND_CURIOSITY:
            return "Découverte examinée."
        EnvironmentInteractionContract.KIND_CORPSE:
            return "Corps examiné."
        EnvironmentInteractionContract.KIND_MECHANISM:
            return "Mécanisme activé."
        _:
            return "Action effectuée."

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
