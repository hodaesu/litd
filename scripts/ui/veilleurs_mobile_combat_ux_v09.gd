extends Node
class_name VeilleursMobileCombatUXV09

const CONFIRM_WINDOW_MS := 3200
const NON_DAMAGE_ACTIONS := ["passive_modifier", "guard", "heal", "support", "observe", "psychological", "control", "move", "transform"]

var qa: VeilleursVerticalSliceQAV09
var preview_layer: CanvasLayer
var preview_panel: PanelContainer
var preview_label: Label
var armed_slot := -1
var armed_until_ms := 0
var installed := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _process(_delta: float) -> void:
    if not installed or qa == null:
        return
    if qa.tactical_ui != null:
        qa.tactical_ui.set_external_selection(qa.selected_watcher, qa.selected_target, qa.selected_zone)
    if armed_slot >= 0:
        if Time.get_ticks_msec() > armed_until_ms or qa.slice == null or qa.slice.combat == null:
            _disarm_preview()
        else:
            _show_preview(armed_slot)

func _install() -> void:
    qa = _root_qa()
    if qa == null:
        return
    if qa.tactical_ui == null:
        call_deferred("_install")
        return

    var direct_handler := Callable(qa, "_on_skill")
    if qa.tactical_ui.skill_slot_pressed.is_connected(direct_handler):
        qa.tactical_ui.skill_slot_pressed.disconnect(direct_handler)
    if not qa.tactical_ui.skill_slot_pressed.is_connected(_on_skill_pressed):
        qa.tactical_ui.skill_slot_pressed.connect(_on_skill_pressed)
    if not qa.tactical_ui.tactical_cell_pressed.is_connected(_on_selection_changed):
        qa.tactical_ui.tactical_cell_pressed.connect(func(_cell: Vector2i) -> void: call_deferred("_selection_changed_deferred"))
    if not qa.tactical_ui.body_zone_pressed.is_connected(_on_zone_changed):
        qa.tactical_ui.body_zone_pressed.connect(func(_zone: String) -> void: call_deferred("_selection_changed_deferred"))

    _build_preview()
    installed = true
    qa.tactical_ui.set_external_selection(qa.selected_watcher, qa.selected_target, qa.selected_zone)

func _root_qa() -> VeilleursVerticalSliceQAV09:
    var node: Node = get_parent()
    while node != null:
        if node is VeilleursVerticalSliceQAV09:
            return node as VeilleursVerticalSliceQAV09
        node = node.get_parent()
    return null

func _build_preview() -> void:
    preview_layer = CanvasLayer.new()
    preview_layer.layer = 118
    preview_layer.name = "MobileCombatPreviewLayer"
    add_child(preview_layer)

    var shell := Control.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    preview_layer.add_child(shell)

    preview_panel = PanelContainer.new()
    preview_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    preview_panel.offset_left = 16
    preview_panel.offset_top = -168
    preview_panel.offset_right = 468
    preview_panel.offset_bottom = -84
    preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(preview_panel)

    preview_label = Label.new()
    preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    preview_label.add_theme_font_size_override("font_size", 13)
    preview_panel.add_child(preview_label)
    preview_panel.visible = false

func _on_skill_pressed(slot: int) -> void:
    if qa == null or qa.slice == null or qa.slice.combat == null:
        return
    if slot < 0 or slot >= qa.skill_ids.size():
        return
    var now := Time.get_ticks_msec()
    if armed_slot == slot and now <= armed_until_ms:
        _disarm_preview()
        qa._on_skill(slot)
        call_deferred("_after_action")
        return
    armed_slot = slot
    armed_until_ms = now + CONFIRM_WINDOW_MS
    qa.tactical_ui.set_armed_skill(slot)
    _show_preview(slot)

func _selection_changed_deferred() -> void:
    if qa == null or qa.tactical_ui == null:
        return
    qa.tactical_ui.set_external_selection(qa.selected_watcher, qa.selected_target, qa.selected_zone)
    if armed_slot >= 0:
        armed_until_ms = Time.get_ticks_msec() + CONFIRM_WINDOW_MS
        _show_preview(armed_slot)

func _on_selection_changed(_cell: Vector2i) -> void:
    call_deferred("_selection_changed_deferred")

func _on_zone_changed(_zone: String) -> void:
    call_deferred("_selection_changed_deferred")

func _after_action() -> void:
    if qa == null or qa.tactical_ui == null:
        return
    qa.tactical_ui.set_external_selection(qa.selected_watcher, qa.selected_target, qa.selected_zone)

func _disarm_preview() -> void:
    armed_slot = -1
    armed_until_ms = 0
    if qa != null and qa.tactical_ui != null:
        qa.tactical_ui.set_armed_skill(-1)
    if preview_panel != null:
        preview_panel.visible = false

func _show_preview(slot: int) -> void:
    if preview_panel == null or preview_label == null or qa == null or qa.slice == null or qa.slice.combat == null:
        return
    var runtime: Variant = qa.slice.combat
    if slot < 0 or slot >= qa.skill_ids.size():
        _disarm_preview()
        return
    var skill_id := qa.skill_ids[slot]
    var skill: Dictionary = runtime.content_db.skill(skill_id)
    if skill.is_empty():
        preview_label.text = "APERÇU · compétence indisponible"
        preview_panel.visible = true
        return

    var action := str(skill.get("action_type", "attack"))
    if runtime.skill_behavior != null and runtime.skill_behavior.has_method("effective_action"):
        action = str(runtime.skill_behavior.effective_action(skill))
    var target_id := qa.selected_target
    if action in ["guard", "heal", "support", "passive_modifier", "move", "transform", "observe"]:
        target_id = qa.selected_watcher
    if target_id == "" or not runtime.combatants.has(target_id) or not runtime.combatants.has(qa.selected_watcher):
        preview_label.text = "APERÇU · %s\nSélectionnez une cible valide. Touchez une cible puis cette compétence." % str(skill.get("name_fr", skill_id))
        preview_panel.visible = true
        return

    var attacker: Dictionary = runtime.combatants[qa.selected_watcher]
    var target: Dictionary = runtime.combatants[target_id]
    var skill_name := str(skill.get("name_fr", skill_id))
    var target_name := str(target.get("name", target_id))
    var zone_name := _zone_label(qa.selected_zone)
    var first_line := "APERÇU · %s → %s · %s" % [skill_name, target_name, zone_name]
    var second_line := ""

    if action not in NON_DAMAGE_ACTIONS:
        var required_range := 0
        if runtime.skill_behavior != null and runtime.skill_behavior.has_method("range_for"):
            required_range = int(runtime.skill_behavior.range_for(skill))
        var distance := int(runtime.grid.distance(qa.selected_watcher, target_id))
        var chance := 0
        if runtime.has_method("_hit_chance"):
            chance = int(runtime.call("_hit_chance", attacker, target, skill, qa.selected_zone))
            chance += int(attacker.get("accuracy_bonus", 0))
            chance -= int(target.get("evasive_bonus", 0))
            var statuses: Dictionary = target.get("statuses", {})
            if statuses.has("EXPOSED"):
                chance += 8
            var clamps: Dictionary = runtime.content_db.combat_constants.get("hit_clamp", {})
            chance = clampi(chance, int(clamps.get("min_percent", 10)), int(clamps.get("max_percent", 97)))
        var damage := 0
        if runtime.has_method("_skill_damage"):
            damage = int(runtime.call("_skill_damage", attacker, target, skill))
        var range_text := "%d/%d" % [distance, required_range] if required_range > 0 else str(distance)
        second_line = "Toucher %d%% · dégâts ~%d · distance %s" % [chance, damage, range_text]
        if required_range > 0 and (distance < 0 or distance > required_range):
            second_line = "HORS PORTÉE · " + second_line
    else:
        var effect: Dictionary = skill.get("effect_spec", {})
        var effect_text := str(effect.get("status", effect.get("effect", action))).replace("_", " ").capitalize()
        second_line = "Effet : %s · cible : %s" % [effect_text, target_name]

    preview_label.text = "%s\n%s\nTouchez à nouveau la compétence pour confirmer." % [first_line, second_line]
    preview_panel.visible = true

func _zone_label(zone: String) -> String:
    return {
        "head":"Tête",
        "torso":"Torse",
        "left_arm":"Bras gauche",
        "right_arm":"Bras droit",
        "left_leg":"Jambe gauche",
        "right_leg":"Jambe droite"
    }.get(zone, zone)
