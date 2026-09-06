extends Control
class_name VeilleursTacticalUI

signal tactical_cell_pressed(cell: Vector2i)
signal skill_slot_pressed(slot: int)
signal body_zone_pressed(zone: String)
signal retreat_pressed

const GRID_WIDTH := 6
const GRID_HEIGHT := 5
const TOUCH_MIN := Vector2(56, 56)
const ZONES: Array[String] = ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]

var cell_buttons: Array[Button] = []
var skill_buttons: Array[Button] = []
var zone_buttons: Array[Button] = []
var status_label: Label
var grid_container: GridContainer

func _ready() -> void:
    if get_child_count() == 0:
        _build()

func _build() -> void:
    var root := VBoxContainer.new()
    root.name = "TacticalLayout"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 8)
    add_child(root)

    status_label = Label.new()
    status_label.text = "LITD : Les Veilleurs — combat tactique 6×5"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(status_label)

    grid_container = GridContainer.new()
    grid_container.name = "Grid6x5"
    grid_container.columns = GRID_WIDTH
    grid_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    root.add_child(grid_container)
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            var button := Button.new()
            button.custom_minimum_size = TOUCH_MIN
            button.text = "·"
            button.tooltip_text = "Case %d,%d" % [x, y]
            button.set_meta("cell", Vector2i(x, y))
            button.pressed.connect(_on_cell_pressed.bind(Vector2i(x, y)))
            grid_container.add_child(button)
            cell_buttons.append(button)

    var zones := HBoxContainer.new()
    zones.name = "BodyZones"
    zones.alignment = BoxContainer.ALIGNMENT_CENTER
    root.add_child(zones)
    var zone_labels := {"head":"Tête", "torso":"Torse", "left_arm":"Bras G", "right_arm":"Bras D", "left_leg":"Jambe G", "right_leg":"Jambe D"}
    for zone: String in ZONES:
        var button := Button.new()
        button.custom_minimum_size = Vector2(72, 48)
        button.text = str(zone_labels.get(zone, zone))
        button.pressed.connect(_on_zone_pressed.bind(zone))
        zones.add_child(button)
        zone_buttons.append(button)

    var actions := HBoxContainer.new()
    actions.name = "Actions"
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    root.add_child(actions)
    for slot in range(4):
        var button := Button.new()
        button.custom_minimum_size = Vector2(112, 56)
        button.text = "Compétence %d" % [slot + 1]
        button.pressed.connect(_on_skill_pressed.bind(slot))
        actions.add_child(button)
        skill_buttons.append(button)
    var retreat := Button.new()
    retreat.custom_minimum_size = Vector2(112, 56)
    retreat.text = "Retraite"
    retreat.pressed.connect(func() -> void: retreat_pressed.emit())
    actions.add_child(retreat)

func bind_snapshot(snapshot: Dictionary) -> void:
    var runtime: Dictionary = snapshot.get("runtime", snapshot)
    var grid: Dictionary = runtime.get("grid", {})
    for button: Button in cell_buttons:
        var cell: Vector2i = button.get_meta("cell", Vector2i(-1, -1))
        var entity_id := str(grid.get("%d:%d" % [cell.x, cell.y], ""))
        button.text = _short_name(entity_id) if entity_id != "" else "·"
        button.tooltip_text = entity_id if entity_id != "" else "Case libre %d,%d" % [cell.x, cell.y]
    status_label.text = "Round %d — %d combattants" % [int(runtime.get("round", 1)), (runtime.get("combatants", {}) as Dictionary).size()]

func set_skill_labels(names: Array[String]) -> void:
    for index in range(skill_buttons.size()):
        skill_buttons[index].text = names[index] if index < names.size() else "—"
        skill_buttons[index].disabled = index >= names.size()

func touch_contract_ok() -> bool:
    if cell_buttons.size() != GRID_WIDTH * GRID_HEIGHT or skill_buttons.size() != 4 or zone_buttons.size() != 6:
        return false
    for button: Button in cell_buttons:
        if button.custom_minimum_size.x < 44 or button.custom_minimum_size.y < 44:
            return false
    return true

func _short_name(entity_id: String) -> String:
    if entity_id.begins_with("ENT_WATCHER_"):
        return entity_id.trim_prefix("ENT_WATCHER_").substr(0, 2)
    if entity_id.begins_with("ENT_ENEMY_"):
        return "E"
    return "?"

func _on_cell_pressed(cell: Vector2i) -> void:
    tactical_cell_pressed.emit(cell)

func _on_skill_pressed(slot: int) -> void:
    skill_slot_pressed.emit(slot)

func _on_zone_pressed(zone: String) -> void:
    body_zone_pressed.emit(zone)
