extends CanvasLayer

var panel: PanelContainer
var box: VBoxContainer

func _ready() -> void:
    layer = 29
    panel = PanelContainer.new()
    panel.position = Vector2(720,410)
    panel.size = Vector2(510,270)
    panel.visible = false
    add_child(panel)
    box = VBoxContainer.new()
    panel.add_child(box)
    GameState.screen_requested.connect(_on_screen)
    DeepVestigeRuntime.vestige_changed.connect(_refresh)
    _on_screen(GameState.current_screen)

func _on_screen(screen_name: String) -> void:
    panel.visible = screen_name == "quest_journal" and _has_any_unlocked()
    if panel.visible: _refresh()

func _has_any_unlocked() -> bool:
    for id in ["vestige_ashai_seven_resonances","vestige_or_silex_black_glass","vestige_saan_last_seal"]:
        if DeepVestigeRuntime.is_unlocked(id): return true
    return false

func _refresh() -> void:
    if box == null: return
    for child in box.get_children(): child.queue_free()
    var title := Label.new(); title.text = "VESTIGES PROFONDS — facultatifs · difficulté supérieure"; box.add_child(title)
    _add_vestige("vestige_ashai_seven_resonances","Temple des Sept Résonances",10,"ENTRER DANS LE TEMPLE",Callable(AshlandsSceneRouter,"start_ashai_deep_vestige"))
    _add_vestige("vestige_or_silex_black_glass","Citadelle sous le Verre Noir",8,"ENTRER DANS LA CITADELLE",Callable(AshlandsSceneRouter,"start_or_silex_deep_vestige"))
    _add_vestige("vestige_saan_last_seal","Monastère du Dernier Sceau",8,"ENTRER DANS LE MONASTÈRE",Callable(AshlandsSceneRouter,"start_saan_deep_vestige"))

func _add_vestige(id: String, title: String, total: int, action: String, callback: Callable) -> void:
    if not DeepVestigeRuntime.is_unlocked(id): return
    var complete := bool(DeepVestigeRuntime.completed.get(id,false))
    var label := Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.text = "%s · %d/%d fragments · %s" % [title,DeepVestigeRuntime.fragment_count_for(id),total,"Vérité Profonde obtenue" if complete else "récompenses exceptionnelles"]
    box.add_child(label)
    var button := Button.new()
    button.text = "VESTIGE TERMINÉ" if complete else action
    button.disabled = complete
    if not complete: button.pressed.connect(callback)
    box.add_child(button)
