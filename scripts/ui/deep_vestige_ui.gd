extends CanvasLayer

var panel: PanelContainer
var box: VBoxContainer

func _ready() -> void:
    layer = 29
    panel = PanelContainer.new()
    panel.position = Vector2(700,300)
    panel.size = Vector2(530,370)
    panel.visible = false
    add_child(panel)
    var scroll := ScrollContainer.new()
    panel.add_child(scroll)
    box = VBoxContainer.new()
    box.custom_minimum_size = Vector2(500,0)
    scroll.add_child(box)
    GameState.screen_requested.connect(_on_screen)
    DeepVestigeRuntime.vestige_changed.connect(_refresh)
    _on_screen(GameState.current_screen)

func _on_screen(screen_name: String) -> void:
    panel.visible = screen_name == "quest_journal" and _has_any_unlocked()
    if panel.visible: _refresh()

func _has_any_unlocked() -> bool:
    for value in DeepVestigeRuntime.index_entries():
        var entry: Dictionary = value
        if DeepVestigeRuntime.is_unlocked(String(entry.get("id", ""))): return true
    return false

func _refresh() -> void:
    if box == null: return
    for child in box.get_children(): child.queue_free()
    var title := Label.new()
    title.text = "VESTIGES PROFONDS — facultatifs · difficulté supérieure"
    box.add_child(title)
    for value in DeepVestigeRuntime.index_entries():
        var entry: Dictionary = value
        var id := String(entry.get("id", ""))
        if id == "" or not DeepVestigeRuntime.is_unlocked(id): continue
        _add_vestige(id, String(entry.get("name", id)), String(entry.get("civilization", "Civilisation inconnue")))

func _add_vestige(id: String, title: String, civilization: String) -> void:
    var complete := bool(DeepVestigeRuntime.completed.get(id, false))
    var total := DeepVestigeRuntime.total_fragments_for(id)
    var label := Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.text = "%s — %s · %d/%d fragments · %s" % [title,civilization,DeepVestigeRuntime.fragment_count_for(id),total,"Vérité Profonde obtenue" if complete else "récompenses exceptionnelles"]
    box.add_child(label)
    var button := Button.new()
    button.text = "VESTIGE TERMINÉ" if complete else "ENTRER DANS LE VESTIGE"
    button.disabled = complete
    if not complete:
        button.pressed.connect(func(id_value = id): AshlandsSceneRouter.start_deep_vestige(String(id_value)))
    box.add_child(button)
