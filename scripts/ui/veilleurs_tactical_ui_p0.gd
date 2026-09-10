extends "res://scripts/ui/veilleurs_tactical_ui.gd"
class_name VeilleursTacticalUIP0

# P0 UX contract: the watcher formation reads from left to right as R4, R3, R2, R1,
# so R1 is always the right-most/front rank, closest to the enemy side.
const WATCHER_RANK_BY_ID := {
    "ENT_WATCHER_marec": 1,
    "ENT_WATCHER_anouk": 2,
    "ENT_WATCHER_aurelien": 3,
    "ENT_WATCHER_mathilde": 4,
}

var rank_legend: HBoxContainer

func _build() -> void:
    super._build()
    if status_label != null:
        # The outer combat shell already owns round/context information. Keeping a
        # second permanent status banner made the playtest look like a QA dashboard.
        status_label.visible = false
        status_label.custom_minimum_size = Vector2.ZERO
    _add_rank_legend()
    _apply_selection_visuals()
    _wire_explicit_focus_neighbors()

func bind_snapshot(snapshot: Dictionary) -> void:
    super.bind_snapshot(snapshot)
    _apply_rank_tooltips()
    _wire_explicit_focus_neighbors()

func _add_rank_legend() -> void:
    if grid_container == null or rank_legend != null:
        return
    var root := grid_container.get_parent()
    if root == null:
        return
    rank_legend = HBoxContainer.new()
    rank_legend.name = "WatcherRankLegend"
    rank_legend.alignment = BoxContainer.ALIGNMENT_CENTER
    rank_legend.add_theme_constant_override("separation", 12)
    for rank in [4, 3, 2, 1]:
        var label := Label.new()
        label.text = "R%d%s" % [rank, " · AVANT" if rank == 1 else ""]
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.custom_minimum_size = Vector2(72, 24)
        rank_legend.add_child(label)
    root.add_child(rank_legend)
    root.move_child(rank_legend, grid_container.get_index())

func _apply_selection_visuals() -> void:
    super._apply_selection_visuals()
    for button: Button in cell_buttons:
        var entity_id := str(button.get_meta("occupant", ""))
        if entity_id == "":
            # Empty tactical cells remain interactive for movement, but no longer
            # draw a permanent dot/table pattern across the whole screen.
            button.text = ""
            button.flat = true
            continue
        button.flat = false
        if not WATCHER_RANK_BY_ID.has(entity_id):
            continue
        var rank := int(WATCHER_RANK_BY_ID[entity_id])
        var badge := _entity_badge(entity_id)
        var marker := button.text.trim_suffix(badge)
        button.text = "%sR%d · %s" % [marker, rank, badge]

func _apply_rank_tooltips() -> void:
    for button: Button in cell_buttons:
        var entity_id := str(button.get_meta("occupant", ""))
        if not WATCHER_RANK_BY_ID.has(entity_id):
            continue
        var rank := int(WATCHER_RANK_BY_ID[entity_id])
        var suffix := "avant" if rank == 1 else ("arrière" if rank == 4 else "intermédiaire")
        button.tooltip_text = "%s · R%d (%s)" % [button.tooltip_text, rank, suffix]

func _wire_explicit_focus_neighbors() -> void:
    # Godot's geometric focus guess is fragile on a 6x5 tactical grid. Build an
    # explicit graph so keyboard/gamepad navigation is deterministic.
    for button: Button in cell_buttons:
        var cell: Vector2i = button.get_meta("cell", Vector2i(-1, -1))
        if cell.x < 0:
            continue
        var left := _cell_button(Vector2i(cell.x - 1, cell.y))
        var right := _cell_button(Vector2i(cell.x + 1, cell.y))
        var up := _cell_button(Vector2i(cell.x, cell.y - 1))
        var down := _cell_button(Vector2i(cell.x, cell.y + 1))
        button.focus_neighbor_left = button.get_path_to(left) if left != null else NodePath()
        button.focus_neighbor_right = button.get_path_to(right) if right != null else NodePath()
        button.focus_neighbor_top = button.get_path_to(up) if up != null else NodePath()
        button.focus_neighbor_bottom = button.get_path_to(down) if down != null else NodePath()

    for index in range(skill_buttons.size()):
        var button := skill_buttons[index]
        if index > 0:
            button.focus_neighbor_left = button.get_path_to(skill_buttons[index - 1])
        if index + 1 < skill_buttons.size():
            button.focus_neighbor_right = button.get_path_to(skill_buttons[index + 1])
    if not skill_buttons.is_empty() and inspect_button != null:
        var last_skill := skill_buttons[skill_buttons.size() - 1]
        last_skill.focus_neighbor_right = last_skill.get_path_to(inspect_button)
        inspect_button.focus_neighbor_left = inspect_button.get_path_to(last_skill)
    if inspect_button != null and retreat_button != null:
        inspect_button.focus_neighbor_right = inspect_button.get_path_to(retreat_button)
        retreat_button.focus_neighbor_left = retreat_button.get_path_to(inspect_button)

func _cell_button(cell: Vector2i) -> Button:
    if cell.x < 0 or cell.x >= GRID_WIDTH or cell.y < 0 or cell.y >= GRID_HEIGHT:
        return null
    var index := cell.y * GRID_WIDTH + cell.x
    if index < 0 or index >= cell_buttons.size():
        return null
    return cell_buttons[index]

func set_body_zone_choices_visible(visible_value: bool) -> void:
    for button: Button in zone_buttons:
        button.visible = visible_value
