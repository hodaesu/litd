extends CanvasLayer

var panel: PanelContainer
var row: HBoxContainer
var label: Label
var back_button: Button
var forward_button: Button

func _ready() -> void:
    layer = 40
    _build()
    GameState.screen_requested.connect(_on_screen_requested)
    GameState.state_changed.connect(_refresh)
    call_deferred("_refresh")

func _build() -> void:
    panel = PanelContainer.new()
    panel.name = "CombatPositionOverlay"
    panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    panel.offset_left = 18
    panel.offset_top = -74
    panel.offset_right = 420
    panel.offset_bottom = -12
    add_child(panel)
    row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    panel.add_child(row)
    label = Label.new()
    label.custom_minimum_size = Vector2(170, 44)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(label)
    back_button = Button.new()
    back_button.text = "← RECULER"
    back_button.custom_minimum_size = Vector2(100, 44)
    back_button.pressed.connect(func(): _move_acting_hero(-1))
    row.add_child(back_button)
    forward_button = Button.new()
    forward_button.text = "AVANCER →"
    forward_button.custom_minimum_size = Vector2(100, 44)
    forward_button.pressed.connect(func(): _move_acting_hero(1))
    row.add_child(forward_button)

func _on_screen_requested(_screen_name: String) -> void:
    call_deferred("_refresh")

func _refresh() -> void:
    if panel == null:
        return
    panel.visible = GameState.current_screen == "combat"
    if not panel.visible:
        return
    CombatPositionRuntime.initialize_battle(GameState.party, GameState.battle_enemies)
    var heroes := GameState.alive_heroes()
    if heroes.is_empty():
        label.text = "Aucun Veilleur actif"
        back_button.disabled = true
        forward_button.disabled = true
        return
    var hero: Dictionary = heroes[0]
    var current := CombatPositionRuntime.position_of(hero)
    var available := CombatPositionRuntime.available_moves(hero, GameState.alive_heroes(), "hero")
    label.text = "%s · POSITION %d" % [str(hero.get("name", "Veilleur")), current + 1]
    back_button.disabled = not available.has(current - 1)
    forward_button.disabled = not available.has(current + 1)
    back_button.tooltip_text = "Recule d'une position. Le déplacement consomme l'action du tour."
    forward_button.tooltip_text = "Avance d'une position. Un cadavre ou un allié peut bloquer la case."

func _move_acting_hero(direction: int) -> void:
    if GameState.current_screen != "combat":
        return
    var heroes := GameState.alive_heroes()
    if heroes.is_empty():
        return
    var hero: Dictionary = heroes[0]
    var destination := CombatPositionRuntime.position_of(hero) + direction
    var result := CombatPositionRuntime.move(hero, destination, heroes, "hero", "player_ui")
    if not bool(result.get("ok", false)):
        GameState.add_log("Déplacement impossible : la position est occupée ou bloquée.")
        _refresh()
        return
    hero["combat_move_action_pending"] = true
    GameState.add_log("%s se déplace de la position %d vers %d." % [str(hero.get("name", "Le Veilleur")), int(result.get("from", 0)) + 1, int(result.get("to", 0)) + 1])
    _refresh()
