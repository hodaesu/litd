extends CanvasLayer

var panel: PanelContainer
var label: Label
var button: Button

func _ready() -> void:
    layer = 29
    panel = PanelContainer.new()
    panel.position = Vector2(760, 520)
    panel.size = Vector2(470, 150)
    panel.visible = false
    add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)
    label = Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(label)
    button = Button.new()
    button.text = "ENTRER DANS LE TEMPLE DES SEPT RÉSONANCES"
    button.pressed.connect(_start_ashai)
    box.add_child(button)
    GameState.screen_requested.connect(_on_screen)
    DeepVestigeRuntime.vestige_changed.connect(_refresh)
    _on_screen(GameState.current_screen)

func _on_screen(screen_name: String) -> void:
    panel.visible = screen_name == "quest_journal" and DeepVestigeRuntime.is_unlocked("vestige_ashai_seven_resonances")
    if panel.visible: _refresh()

func _refresh() -> void:
    if panel == null: return
    var complete := bool(DeepVestigeRuntime.completed.get("vestige_ashai_seven_resonances", false))
    label.text = "VESTIGE PROFOND — Temple des Sept Résonances\nFacultatif · difficulté supérieure · %d/10 fragments\n%s" % [DeepVestigeRuntime.ash_fragment_count(), "Vérité Profonde obtenue" if complete else "Récompenses exceptionnelles et lore Ashaï"]
    button.disabled = complete
    button.text = "VESTIGE TERMINÉ" if complete else "ENTRER DANS LE TEMPLE DES SEPT RÉSONANCES"

func _start_ashai() -> void:
    AshlandsSceneRouter.start_ashai_deep_vestige()
