class_name EnemyFearGauge
extends VBoxContainer

var _title: Label
var _bar: ProgressBar
var _state: Label

func _ready() -> void:
    custom_minimum_size = Vector2(145, 38)
    add_theme_constant_override("separation", 1)
    _title = Label.new()
    _title.text = "PEUR"
    _title.add_theme_font_size_override("font_size", 10)
    _title.add_theme_color_override("font_color", Color("#b8a58b"))
    add_child(_title)
    _bar = ProgressBar.new()
    _bar.min_value = 0
    _bar.max_value = 100
    _bar.show_percentage = false
    _bar.custom_minimum_size = Vector2(145, 9)
    add_child(_bar)
    _state = Label.new()
    _state.add_theme_font_size_override("font_size", 10)
    add_child(_state)

func bind_enemy(enemy: Dictionary) -> void:
    if not is_node_ready():
        await ready
    var value := clampi(int(enemy.get("enemy_fear", 0)), 0, 100)
    var state := EnemyFearDirector.state_for(value)
    _bar.value = value
    _state.text = "%d/100 · %s" % [value, _label_for(state)]
    var color := _color_for(state)
    _state.add_theme_color_override("font_color", color)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.corner_radius_top_left = 3
    fill.corner_radius_top_right = 3
    fill.corner_radius_bottom_left = 3
    fill.corner_radius_bottom_right = 3
    _bar.add_theme_stylebox_override("fill", fill)

func _label_for(state: String) -> String:
    return str({"calm": "CALME", "wary": "MÉFIANT", "shaken": "ÉBRANLÉ", "terrified": "TERRIFIÉ", "panic": "PANIQUE"}.get(state, state.to_upper()))

func _color_for(state: String) -> Color:
    return {
        "calm": Color("#817a70"),
        "wary": Color("#b79a52"),
        "shaken": Color("#d4773d"),
        "terrified": Color("#b43b35"),
        "panic": Color("#7d256d")
    }.get(state, Color.WHITE)
