extends Node

const SurrenderRuntime := preload("res://scripts/core/veilleurs_surrender_runtime.gd")

var layer: CanvasLayer
var blocker: Control
var panel: PanelContainer
var title: Label
var body: Label
var choices_box: GridContainer
var target_enemy: Dictionary = {}
var _poll_accumulator := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    set_process(true)

func _process(delta: float) -> void:
    _poll_accumulator += delta
    if _poll_accumulator < 0.12:
        return
    _poll_accumulator = 0.0
    if GameState.current_screen != "combat" or (panel != null and panel.visible):
        return
    var candidate := _first_available_enemy()
    if not candidate.is_empty():
        open_for_enemy(candidate)

func _build() -> void:
    layer = CanvasLayer.new()
    layer.layer = 98
    add_child(layer)

    blocker = Control.new()
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    blocker.visible = false
    layer.add_child(blocker)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.0, 0.0, 0.0, 0.72)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    blocker.add_child(dim)

    panel = PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(720, 360)
    panel.position = Vector2(-360, -180)
    blocker.add_child(panel)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    panel.add_child(root)

    title = Label.new()
    title.text = "REDDITION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    root.add_child(title)

    body = Label.new()
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.custom_minimum_size = Vector2(650, 92)
    body.add_theme_font_size_override("font_size", 17)
    root.add_child(body)

    choices_box = GridContainer.new()
    choices_box.columns = 2
    choices_box.add_theme_constant_override("h_separation", 10)
    choices_box.add_theme_constant_override("v_separation", 10)
    root.add_child(choices_box)

func open_for_enemy(enemy: Dictionary) -> void:
    if enemy.is_empty() or not bool(enemy.get("former_kin_surrender_available", false)):
        return
    target_enemy = enemy
    title.text = "%s — REDDITION" % str(enemy.get("name", "Adversaire"))
    var former_name := str(enemy.get("former_kin_source_name", "l'ancien Némésis"))
    body.text = "%s reconnaît %s. La cible baisse son arme. Choisis la manière dont cette reddition entre dans l'histoire." % [str(enemy.get("name", "L'adversaire")), former_name]
    _rebuild_choices()
    blocker.visible = true
    panel.visible = true

func resolve_choice(choice_id: String) -> Dictionary:
    if target_enemy.is_empty():
        return {"resolved": false, "reason": "no_target"}
    var result := SurrenderRuntime.resolve(target_enemy, choice_id, {"region_id": AshlandsRuntime.current_zone_id})
    if bool(result.get("resolved", false)):
        var outcome := str(result.get("outcome", choice_id))
        GameState.add_log(_outcome_text(outcome, str(target_enemy.get("name", "La cible"))))
        blocker.visible = false
        panel.visible = false
        target_enemy = {}
        GameState.state_changed.emit()
    elif str(result.get("message", "")) != "":
        body.text = str(result.get("message", ""))
    return result

func _rebuild_choices() -> void:
    for child in choices_box.get_children():
        child.queue_free()
    for choice: Dictionary in SurrenderRuntime.choices(target_enemy):
        var button := Button.new()
        button.custom_minimum_size = Vector2(320, 58)
        button.text = str(choice.get("label", "Choisir"))
        button.tooltip_text = str(choice.get("summary", ""))
        button.disabled = not bool(choice.get("enabled", true))
        if button.disabled and str(choice.get("disabled_reason", "")) != "":
            button.tooltip_text = str(choice.get("disabled_reason", ""))
        var choice_id := str(choice.get("id", ""))
        button.pressed.connect(func(): resolve_choice(choice_id))
        choices_box.add_child(button)

func _first_available_enemy() -> Dictionary:
    for enemy_value: Variant in GameState.battle_enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0 or bool(enemy.get("captured", false)):
            continue
        if bool(enemy.get("former_kin_surrender_available", false)) and not bool(enemy.get("surrender_choice_resolved", false)):
            return enemy
    return {}

func _on_screen_requested(screen_name: String) -> void:
    if screen_name != "combat" and blocker != null:
        blocker.visible = false
        panel.visible = false
        target_enemy = {}

func _outcome_text(outcome: String, enemy_name: String) -> String:
    match outcome:
        "surrender_accepted": return "%s se rend. La parole donnée sera mémorisée." % enemy_name
        "surrender_refused": return "La reddition de %s est refusée ; la rancœur durcit le combat." % enemy_name
        "surrender_negotiated": return "%s accepte les conditions négociées et quitte le combat." % enemy_name
        "rallied": return "%s rallie les Veilleurs sous le regard de l'ancien Némésis." % enemy_name
        _: return "La reddition de %s est résolue : %s." % [enemy_name, outcome]
