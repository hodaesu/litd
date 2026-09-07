extends Node3D

const GRID_W := 6
const GRID_H := 5
const CELL := 1.6

const SAHEN_MAX_VIT := 120
const SAHEN_MAX_POST := 65
const RAMPANT_MAX_VIT := 46
const RAMPANT_MAX_POST := 38

const SHOULDER_VIT := 12
const SHOULDER_POST := 22
const BASIC_VIT := 14
const BASIC_POST := 12

const WALL_COLLISION_VIT := 6
const WALL_COLLISION_POST := 12

var sahen_cell := Vector2i(2, 2)
var rampant_cell := Vector2i(3, 2)
var wall_cell := Vector2i(5, 2)

var sahen_vit := SAHEN_MAX_VIT
var sahen_post := SAHEN_MAX_POST
var rampant_vit := RAMPANT_MAX_VIT
var rampant_post := RAMPANT_MAX_POST
var rampant_downed := false
var player_turn := true
var mode := "shoulder"
var busy := false

var camera: Camera3D
var sahen_mesh: MeshInstance3D
var rampant_mesh: MeshInstance3D
var wall_mesh: MeshInstance3D
var status_label: Label
var mode_label: Label
var hint_label: Label

func _ready() -> void:
    _build_world()
    _build_ui()
    _refresh_visuals()
    _set_status("Tour de Sahen — Coup d'épaule sélectionné.")

func _build_world() -> void:
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
    light.shadow_enabled = true
    add_child(light)

    var fill := OmniLight3D.new()
    fill.position = Vector3(3.5, 6.0, 3.0)
    fill.omni_range = 18.0
    fill.light_energy = 1.4
    add_child(fill)

    var floor_mat := _material(Color(0.18, 0.18, 0.20))
    var alt_mat := _material(Color(0.23, 0.23, 0.25))
    for z in GRID_H:
        for x in GRID_W:
            var tile := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(CELL - 0.06, 0.08, CELL - 0.06)
            tile.mesh = box
            tile.material_override = floor_mat if (x + z) % 2 == 0 else alt_mat
            tile.position = _cell_world(Vector2i(x, z)) + Vector3(0.0, -0.06, 0.0)
            add_child(tile)

    sahen_mesh = MeshInstance3D.new()
    var sahen_shape := CapsuleMesh.new()
    sahen_shape.radius = 0.48
    sahen_shape.height = 1.65
    sahen_mesh.mesh = sahen_shape
    sahen_mesh.material_override = _material(Color(0.32, 0.55, 0.85))
    add_child(sahen_mesh)

    rampant_mesh = MeshInstance3D.new()
    var rampant_shape := CapsuleMesh.new()
    rampant_shape.radius = 0.43
    rampant_shape.height = 1.45
    rampant_mesh.mesh = rampant_shape
    rampant_mesh.material_override = _material(Color(0.72, 0.28, 0.24))
    add_child(rampant_mesh)

    wall_mesh = MeshInstance3D.new()
    var wall_shape := BoxMesh.new()
    wall_shape.size = Vector3(CELL - 0.1, 1.6, CELL - 0.1)
    wall_mesh.mesh = wall_shape
    wall_mesh.material_override = _material(Color(0.28, 0.27, 0.25))
    wall_mesh.position = _cell_world(wall_cell) + Vector3(0.0, 0.8, 0.0)
    add_child(wall_mesh)

    camera = Camera3D.new()
    camera.fov = 40.0
    camera.position = Vector3(9.2, 11.5, 12.0)
    add_child(camera)
    camera.current = true
    _recenter_camera(false)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var root := MarginContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 24)
    root.add_theme_constant_override("margin_top", 20)
    root.add_theme_constant_override("margin_right", 24)
    root.add_theme_constant_override("margin_bottom", 20)
    layer.add_child(root)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    root.add_child(column)

    var title := Label.new()
    title.text = "LITD : Les Veilleurs — P0 Impact"
    title.add_theme_font_size_override("font_size", 26)
    column.add_child(title)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 20)
    column.add_child(status_label)

    mode_label = Label.new()
    mode_label.add_theme_font_size_override("font_size", 18)
    column.add_child(mode_label)

    hint_label = Label.new()
    hint_label.text = "Touchez une case. Objectif : pousser le Rampant contre le mur."
    hint_label.add_theme_font_size_override("font_size", 16)
    column.add_child(hint_label)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 12)
    column.add_child(spacer)

    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 10)
    column.add_child(buttons)

    _add_button(buttons, "Déplacement", func(): mode = "move"; _refresh_mode())
    _add_button(buttons, "Attaque", func(): mode = "attack"; _refresh_mode())
    _add_button(buttons, "Coup d'épaule", func(): mode = "shoulder"; _refresh_mode())
    _add_button(buttons, "Fin du tour", func(): _end_player_turn())
    _add_button(buttons, "Recentrer", func(): _recenter_camera(true))
    _add_button(buttons, "Réinitialiser", func(): _reset_combat())

func _add_button(parent: Control, text_value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(150, 54)
    button.add_theme_font_size_override("font_size", 17)
    button.pressed.connect(callback)
    parent.add_child(button)

func _material(color_value: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color_value
    mat.roughness = 0.85
    return mat

func _cell_world(cell: Vector2i) -> Vector3:
    return Vector3(cell.x * CELL, 0.0, cell.y * CELL)

func _world_cell(point: Vector3) -> Vector2i:
    return Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))

func _inside(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H

func _occupied(cell: Vector2i) -> bool:
    return cell == wall_cell or (cell == rampant_cell and not rampant_downed) or cell == sahen_cell

func _unhandled_input(event: InputEvent) -> void:
    if busy or not player_turn:
        return

    var screen_pos := Vector2.ZERO
    var pressed := false
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        screen_pos = event.position
        pressed = true
    elif event is InputEventScreenTouch and event.pressed:
        screen_pos = event.position
        pressed = true

    if pressed:
        _handle_tap(screen_pos)

    if event.is_action_pressed("end_turn"):
        _end_player_turn()
    elif event.is_action_pressed("recenter_camera"):
        _recenter_camera(true)

func _handle_tap(screen_pos: Vector2) -> void:
    var ray_origin := camera.project_ray_origin(screen_pos)
    var ray_direction := camera.project_ray_normal(screen_pos)
    var hit = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
    if hit == null:
        return

    var cell := _world_cell(hit)
    if not _inside(cell):
        return

    match mode:
        "move":
            _try_move(cell)
        "attack":
            if cell == rampant_cell:
                _try_basic_attack()
        "shoulder":
            if cell == rampant_cell:
                _try_shoulder_bash()

func _try_move(target: Vector2i) -> void:
    if not player_turn:
        return
    var delta := target - sahen_cell
    if abs(delta.x) + abs(delta.y) != 1:
        _set_status("P0 : déplacement limité à 1 case pour ce test.")
        return
    if _occupied(target):
        _set_status("Case occupée.")
        return
    sahen_cell = target
    _animate_unit_to(sahen_mesh, _cell_world(sahen_cell) + Vector3(0, 0.83, 0), 0.18)
    _set_status("Sahen se déplace.")
    await get_tree().create_timer(0.20).timeout
    _end_player_turn()

func _try_basic_attack() -> void:
    if _manhattan(sahen_cell, rampant_cell) != 1 or rampant_downed:
        _set_status("La cible doit être adjacente et debout.")
        return
    busy = true
    _camera_action_focus(sahen_cell, rampant_cell)
    await get_tree().create_timer(0.18).timeout
    rampant_vit = maxi(0, rampant_vit - BASIC_VIT)
    rampant_post = maxi(0, rampant_post - BASIC_POST)
    _impact_bump(rampant_mesh, rampant_cell - sahen_cell)
    _resolve_rampant_down()
    _refresh_visuals()
    _set_status("Attaque : -%d VIT / -%d POST." % [BASIC_VIT, BASIC_POST])
    await get_tree().create_timer(0.45).timeout
    _recenter_camera(true)
    busy = false
    _end_player_turn()

func _try_shoulder_bash() -> void:
    if _manhattan(sahen_cell, rampant_cell) != 1 or rampant_downed:
        _set_status("Coup d'épaule exige un Rampant adjacent et debout.")
        return

    busy = true
    var push_dir := _cardinal_direction(rampant_cell - sahen_cell)
    _camera_action_focus(sahen_cell, rampant_cell)
    await get_tree().create_timer(0.18).timeout

    rampant_vit = maxi(0, rampant_vit - SHOULDER_VIT)
    rampant_post = maxi(0, rampant_post - SHOULDER_POST)
    var collision_happened := false
    var collision_steps := 0

    for step in range(2):
        var next_cell := rampant_cell + push_dir
        if not _inside(next_cell) or next_cell == wall_cell:
            collision_happened = true
            collision_steps = 2 - step
            break
        if next_cell == sahen_cell:
            collision_happened = true
            collision_steps = 2 - step
            break
        rampant_cell = next_cell
        _animate_unit_to(rampant_mesh, _cell_world(rampant_cell) + Vector3(0, 0.73, 0), 0.16)
        await get_tree().create_timer(0.17).timeout

    if collision_happened:
        var extra_vit := WALL_COLLISION_VIT * collision_steps
        var extra_post := WALL_COLLISION_POST * collision_steps
        rampant_vit = maxi(0, rampant_vit - extra_vit)
        rampant_post = maxi(0, rampant_post - extra_post)
        _impact_bump(rampant_mesh, push_dir)
        _camera_collision_focus(rampant_cell)
        _set_status("COUP D'ÉPAULE → Push → COLLISION : -%d VIT / -%d POST au total." % [SHOULDER_VIT + extra_vit, SHOULDER_POST + extra_post])
    else:
        _set_status("COUP D'ÉPAULE : -%d VIT / -%d POST, Push 2." % [SHOULDER_VIT, SHOULDER_POST])

    _resolve_rampant_down()
    _refresh_visuals()
    await get_tree().create_timer(0.55).timeout
    _recenter_camera(true)
    busy = false
    _end_player_turn()

func _resolve_rampant_down() -> void:
    if rampant_vit <= 0 or rampant_post <= 0:
        rampant_downed = true
        rampant_post = 0
        rampant_mesh.rotation_degrees.z = 82.0

func _end_player_turn() -> void:
    if busy or not player_turn:
        return
    player_turn = false
    _refresh_mode()
    await get_tree().create_timer(0.25).timeout
    await _enemy_turn()
    sahen_post = mini(SAHEN_MAX_POST, sahen_post + roundi(SAHEN_MAX_POST * 0.15))
    if not rampant_downed:
        rampant_post = mini(RAMPANT_MAX_POST, rampant_post + roundi(RAMPANT_MAX_POST * 0.15))
    player_turn = true
    _refresh_visuals()
    _set_status("Tour de Sahen.")

func _enemy_turn() -> void:
    if rampant_downed:
        _set_status("Le Rampant est À TERRE.")
        return

    if _manhattan(sahen_cell, rampant_cell) == 1:
        var enemy_vit := 9
        var enemy_post := 10
        sahen_vit = maxi(0, sahen_vit - enemy_vit)
        sahen_post = maxi(0, sahen_post - enemy_post)
        _impact_bump(sahen_mesh, sahen_cell - rampant_cell)
        _set_status("Rampant attaque Sahen : -%d VIT / -%d POST." % [enemy_vit, enemy_post])
        if sahen_vit <= 0 or sahen_post <= 0:
            _set_status("Sahen est À TERRE — réinitialisez le P0.")
    else:
        var step := _step_toward(rampant_cell, sahen_cell)
        var candidate := rampant_cell + step
        if _inside(candidate) and candidate != wall_cell and candidate != sahen_cell:
            rampant_cell = candidate
            _animate_unit_to(rampant_mesh, _cell_world(rampant_cell) + Vector3(0, 0.73, 0), 0.20)
            _set_status("Le Rampant avance.")
            await get_tree().create_timer(0.22).timeout

func _step_toward(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
    var delta := to_cell - from_cell
    if abs(delta.x) >= abs(delta.y) and delta.x != 0:
        return Vector2i(signi(delta.x), 0)
    if delta.y != 0:
        return Vector2i(0, signi(delta.y))
    return Vector2i.ZERO

func _cardinal_direction(delta: Vector2i) -> Vector2i:
    if abs(delta.x) >= abs(delta.y):
        return Vector2i(signi(delta.x), 0)
    return Vector2i(0, signi(delta.y))

func _manhattan(a: Vector2i, b: Vector2i) -> int:
    return abs(a.x - b.x) + abs(a.y - b.y)

func _animate_unit_to(unit: Node3D, target: Vector3, duration: float) -> void:
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(unit, "position", target, duration)

func _impact_bump(unit: Node3D, direction: Vector2i) -> void:
    var base := unit.position
    var offset := Vector3(direction.x, 0.0, direction.y).normalized() * 0.18
    var tween := create_tween()
    tween.tween_property(unit, "position", base + offset, 0.07)
    tween.tween_property(unit, "position", base, 0.10)

func _camera_action_focus(a: Vector2i, b: Vector2i) -> void:
    var midpoint := (_cell_world(a) + _cell_world(b)) * 0.5
    var target_pos := midpoint + Vector3(5.4, 7.0, 7.2)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(camera, "position", target_pos, 0.16)
    tween.parallel().tween_property(camera, "fov", 35.0, 0.16)
    await tween.finished
    camera.look_at(midpoint + Vector3(0, 0.45, 0), Vector3.UP)

func _camera_collision_focus(cell: Vector2i) -> void:
    var focus := _cell_world(cell)
    var target_pos := focus + Vector3(4.4, 6.0, 5.5)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(camera, "position", target_pos, 0.12)
    tween.parallel().tween_property(camera, "fov", 33.0, 0.12)
    await tween.finished
    camera.look_at(focus + Vector3(0, 0.45, 0), Vector3.UP)

func _recenter_camera(animated: bool) -> void:
    if camera == null:
        return
    var center := Vector3((GRID_W - 1) * CELL * 0.5, 0.0, (GRID_H - 1) * CELL * 0.5)
    var target_pos := center + Vector3(7.8, 9.4, 10.0)
    if animated:
        var tween := create_tween()
        tween.set_trans(Tween.TRANS_QUAD)
        tween.set_ease(Tween.EASE_OUT)
        tween.tween_property(camera, "position", target_pos, 0.22)
        tween.parallel().tween_property(camera, "fov", 40.0, 0.22)
        await tween.finished
    else:
        camera.position = target_pos
        camera.fov = 40.0
    camera.look_at(center + Vector3(0, 0.35, 0), Vector3.UP)

func _refresh_visuals() -> void:
    sahen_mesh.position = _cell_world(sahen_cell) + Vector3(0, 0.83, 0)
    rampant_mesh.position = _cell_world(rampant_cell) + Vector3(0, 0.73, 0)
    status_label.text = "Sahen  VIT %d/%d  POST %d/%d    |    Rampant  VIT %d/%d  POST %d/%d%s" % [
        sahen_vit, SAHEN_MAX_VIT, sahen_post, SAHEN_MAX_POST,
        rampant_vit, RAMPANT_MAX_VIT, rampant_post, RAMPANT_MAX_POST,
        "  — À TERRE" if rampant_downed else ""
    ]
    _refresh_mode()

func _refresh_mode() -> void:
    if mode_label == null:
        return
    var turn_text := "SAHEN" if player_turn else "RAMPANT"
    mode_label.text = "Tour : %s    |    Mode : %s" % [turn_text, mode.to_upper()]

func _set_status(message: String) -> void:
    if hint_label != null:
        hint_label.text = message

func _reset_combat() -> void:
    sahen_cell = Vector2i(2, 2)
    rampant_cell = Vector2i(3, 2)
    sahen_vit = SAHEN_MAX_VIT
    sahen_post = SAHEN_MAX_POST
    rampant_vit = RAMPANT_MAX_VIT
    rampant_post = RAMPANT_MAX_POST
    rampant_downed = false
    rampant_mesh.rotation_degrees = Vector3.ZERO
    player_turn = true
    mode = "shoulder"
    busy = false
    _refresh_visuals()
    _recenter_camera(true)
    _set_status("P0 réinitialisé. Poussez le Rampant contre le mur.")
