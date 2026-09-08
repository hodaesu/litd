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
const RETREAT_CONFIRM_MS := 2500

var cell_buttons: Array[Button] = []
var skill_buttons: Array[Button] = []
var zone_buttons: Array[Button] = []
var skill_names: Array[String] = []
var status_label: Label
var grid_container: GridContainer
var inspect_button: Button
var retreat_button: Button

var runtime_snapshot: Dictionary = {}
var selected_watcher := ""
var selected_target := ""
var selected_zone := "torso"
var armed_skill_slot := -1
var retreat_armed_until_ms := 0

func _ready() -> void:
    if get_child_count() == 0:
        _build()
    set_process(true)

func _process(_delta: float) -> void:
    if retreat_armed_until_ms > 0 and Time.get_ticks_msec() > retreat_armed_until_ms:
        _disarm_retreat()

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
            button.set_meta("occupant", "")
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
        button.toggle_mode = true
        button.text = str(zone_labels.get(zone, zone))
        button.set_meta("zone", zone)
        button.set_meta("base_text", button.text)
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
        button.set_meta("slot", slot)
        button.pressed.connect(_on_skill_pressed.bind(slot))
        actions.add_child(button)
        skill_buttons.append(button)
        skill_names.append(button.text)

    inspect_button = Button.new()
    inspect_button.custom_minimum_size = Vector2(112, 56)
    inspect_button.text = "Inspecter"
    inspect_button.pressed.connect(_on_inspect_pressed)
    actions.add_child(inspect_button)

    retreat_button = Button.new()
    retreat_button.custom_minimum_size = Vector2(140, 56)
    retreat_button.text = "Retraite"
    retreat_button.pressed.connect(_on_retreat_pressed)
    actions.add_child(retreat_button)
    _apply_selection_visuals()

func bind_snapshot(snapshot: Dictionary) -> void:
    runtime_snapshot = (snapshot.get("runtime", snapshot) as Dictionary).duplicate(true)
    var grid: Dictionary = runtime_snapshot.get("grid", {})
    for button: Button in cell_buttons:
        var cell: Vector2i = button.get_meta("cell", Vector2i(-1, -1))
        var entity_id := str(grid.get("%d:%d" % [cell.x, cell.y], ""))
        button.set_meta("occupant", entity_id)
        button.tooltip_text = _entity_tooltip(entity_id) if entity_id != "" else "Case libre %d,%d" % [cell.x, cell.y]
    _repair_local_selection()
    _apply_selection_visuals()
    status_label.text = "Round %d — %d combattants" % [int(runtime_snapshot.get("round", 1)), (runtime_snapshot.get("combatants", {}) as Dictionary).size()]

func set_skill_labels(names: Array[String]) -> void:
    skill_names.clear()
    for index in range(skill_buttons.size()):
        var name := names[index] if index < names.size() else "—"
        skill_names.append(name)
        skill_buttons[index].disabled = index >= names.size()
    _refresh_skill_labels()

func set_external_selection(watcher_id: String, target_id: String, zone: String) -> void:
    selected_watcher = watcher_id
    selected_target = target_id
    if zone in ZONES:
        selected_zone = zone
    _repair_local_selection()
    _apply_selection_visuals()

func set_armed_skill(slot: int) -> void:
    armed_skill_slot = slot if slot >= 0 and slot < skill_buttons.size() else -1
    _refresh_skill_labels()

func touch_contract_ok() -> bool:
    if cell_buttons.size() != GRID_WIDTH * GRID_HEIGHT or skill_buttons.size() != 4 or zone_buttons.size() != 6:
        return false
    for button: Button in cell_buttons:
        if button.custom_minimum_size.x < 44 or button.custom_minimum_size.y < 44:
            return false
    for button: Button in zone_buttons:
        if button.custom_minimum_size.x < 44 or button.custom_minimum_size.y < 44:
            return false
    if inspect_button == null or retreat_button == null:
        return false
    return inspect_button.custom_minimum_size.y >= 44 and retreat_button.custom_minimum_size.y >= 44

func _repair_local_selection() -> void:
    var combatants: Dictionary = runtime_snapshot.get("combatants", {})
    if not _valid_living(selected_watcher, "watcher"):
        selected_watcher = _first_living(combatants, "watcher")
    if not _valid_living(selected_target, "enemy") or bool((combatants.get(selected_target, {}) as Dictionary).get("subdued", false)):
        selected_target = _first_living(combatants, "enemy", true)

func _valid_living(entity_id: String, team: String) -> bool:
    if entity_id == "":
        return false
    var combatants: Dictionary = runtime_snapshot.get("combatants", {})
    if not combatants.has(entity_id):
        return false
    var row: Dictionary = combatants[entity_id]
    return str(row.get("team", "")) == team and int(row.get("hp", 0)) > 0

func _first_living(combatants: Dictionary, team: String, exclude_subdued: bool = false) -> String:
    var ids: Array[String] = []
    for id_value: Variant in combatants.keys():
        var entity_id := str(id_value)
        var row: Dictionary = combatants[entity_id]
        if str(row.get("team", "")) != team or int(row.get("hp", 0)) <= 0:
            continue
        if exclude_subdued and bool(row.get("subdued", false)):
            continue
        ids.append(entity_id)
    ids.sort()
    return ids[0] if not ids.is_empty() else ""

func _apply_selection_visuals() -> void:
    for button: Button in cell_buttons:
        var entity_id := str(button.get_meta("occupant", ""))
        var marker := ""
        if entity_id != "" and entity_id == selected_watcher:
            marker = "▶"
            button.self_modulate = Color(0.78, 1.0, 0.82, 1.0)
        elif entity_id != "" and entity_id == selected_target:
            marker = "◎"
            button.self_modulate = Color(1.0, 0.78, 0.74, 1.0)
        else:
            button.self_modulate = Color.WHITE
        button.text = marker + _entity_badge(entity_id) if entity_id != "" else "·"

    for button: Button in zone_buttons:
        var zone := str(button.get_meta("zone", ""))
        var base_text := str(button.get_meta("base_text", zone))
        var active := zone == selected_zone
        button.button_pressed = active
        button.text = ("● " if active else "") + base_text
        button.self_modulate = Color(1.0, 0.88, 0.66, 1.0) if active else Color.WHITE

    if inspect_button != null:
        var inspected := selected_target if selected_target != "" else selected_watcher
        inspect_button.disabled = inspected == ""
        inspect_button.text = "Inspecter\n%s" % _short_display_name(inspected) if inspected != "" else "Inspecter"

func _refresh_skill_labels() -> void:
    for index in range(skill_buttons.size()):
        var base_name := skill_names[index] if index < skill_names.size() else "—"
        skill_buttons[index].text = ("✓ " if index == armed_skill_slot else "") + base_name
        skill_buttons[index].self_modulate = Color(1.0, 0.90, 0.67, 1.0) if index == armed_skill_slot else Color.WHITE

func _entity_badge(entity_id: String) -> String:
    if entity_id == "":
        return ""
    var combatants: Dictionary = runtime_snapshot.get("combatants", {})
    var row: Dictionary = combatants.get(entity_id, {})
    var initials := _initials(str(row.get("name", entity_id)), 2)
    if str(row.get("team", "")) == "watcher" or entity_id.begins_with("ENT_WATCHER_"):
        return initials
    if bool(row.get("subdued", false)):
        return "✓" + initials
    if bool(row.get("boss", false)) or entity_id.begins_with("ENT_BOSS_"):
        return "B:" + initials
    var stage := str(row.get("remanence_stage", "normal"))
    if stage == "nemesis":
        return "N:" + initials
    if stage == "elite":
        return "É:" + initials
    if stage == "veteran":
        return "V:" + initials
    if stage == "memorial":
        return "M:" + initials
    return "E:" + initials

func _entity_tooltip(entity_id: String) -> String:
    var row: Dictionary = (runtime_snapshot.get("combatants", {}) as Dictionary).get(entity_id, {})
    if row.is_empty():
        return entity_id
    var parts: Array[String] = [str(row.get("name", entity_id)), "%d/%d PV" % [int(row.get("hp", 0)), int(row.get("max_hp", 0))]]
    var stage := str(row.get("remanence_stage", "normal"))
    if stage != "normal":
        parts.append(stage.capitalize())
    if bool(row.get("boss", false)):
        parts.append("Boss")
    if bool(row.get("subdued", false)):
        parts.append("Soumis")
    return " · ".join(parts)

func _short_display_name(entity_id: String) -> String:
    if entity_id == "":
        return ""
    var row: Dictionary = (runtime_snapshot.get("combatants", {}) as Dictionary).get(entity_id, {})
    var name := str(row.get("name", entity_id))
    return name.substr(0, mini(name.length(), 12))

func _initials(name: String, limit: int) -> String:
    var cleaned := name.strip_edges()
    var words := cleaned.split(" ", false)
    var result := ""
    for word_value: String in words:
        if word_value.is_empty():
            continue
        result += word_value.substr(0, 1).to_upper()
        if result.length() >= limit:
            return result
    if result.length() < limit and cleaned.length() > result.length():
        result = cleaned.substr(0, mini(limit, cleaned.length())).to_upper()
    return result

func _on_cell_pressed(cell: Vector2i) -> void:
    _disarm_retreat()
    var occupant := ""
    for button: Button in cell_buttons:
        if button.get_meta("cell", Vector2i(-1, -1)) == cell:
            occupant = str(button.get_meta("occupant", ""))
            break
    var combatants: Dictionary = runtime_snapshot.get("combatants", {})
    if occupant != "" and combatants.has(occupant):
        var row: Dictionary = combatants[occupant]
        if str(row.get("team", "")) == "watcher":
            selected_watcher = occupant
        elif str(row.get("team", "")) == "enemy" and not bool(row.get("subdued", false)):
            selected_target = occupant
    set_armed_skill(-1)
    _apply_selection_visuals()
    tactical_cell_pressed.emit(cell)

func _on_skill_pressed(slot: int) -> void:
    _disarm_retreat()
    skill_slot_pressed.emit(slot)

func _on_zone_pressed(zone: String) -> void:
    _disarm_retreat()
    selected_zone = zone
    set_armed_skill(-1)
    _apply_selection_visuals()
    body_zone_pressed.emit(zone)

func _on_inspect_pressed() -> void:
    _disarm_retreat()
    var entity_id := selected_target if selected_target != "" else selected_watcher
    if entity_id == "":
        return
    var combatants: Dictionary = runtime_snapshot.get("combatants", {})
    var row: Dictionary = combatants.get(entity_id, {})
    if row.is_empty():
        return
    var enemy := str(row.get("team", "")) == "enemy"
    CombatantInspectionUI.open_detail(row, enemy)

func _on_retreat_pressed() -> void:
    set_armed_skill(-1)
    var now := Time.get_ticks_msec()
    if retreat_armed_until_ms > 0 and now <= retreat_armed_until_ms:
        _disarm_retreat()
        retreat_pressed.emit()
        return
    retreat_armed_until_ms = now + RETREAT_CONFIRM_MS
    retreat_button.text = "Confirmer\nretraite"
    retreat_button.self_modulate = Color(1.0, 0.72, 0.62, 1.0)

func _disarm_retreat() -> void:
    retreat_armed_until_ms = 0
    if retreat_button != null:
        retreat_button.text = "Retraite"
        retreat_button.self_modulate = Color.WHITE
