extends Node
class_name VeilleursMobileCombatUXV09

const CONFIRM_WINDOW_MS := 3200
const TARGETING_WINDOW_MS := 12000
const NON_DAMAGE_ACTIONS := ["passive_modifier", "guard", "heal", "support", "observe", "psychological", "control", "move", "transform"]
const SELF_TARGET_ACTIONS := ["guard", "heal", "support", "passive_modifier", "move", "transform", "observe"]

var qa: VeilleursVerticalSliceQAV09
var preview_layer: CanvasLayer
var preview_panel: PanelContainer
var preview_label: Label
var armed_slot := -1
var armed_until_ms := 0
var target_choice_made := false
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
            _sync_targeting_visuals()
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
        qa.tactical_ui.tactical_cell_pressed.connect(_on_selection_changed)
    if not qa.tactical_ui.body_zone_pressed.is_connected(_on_zone_changed):
        qa.tactical_ui.body_zone_pressed.connect(_on_zone_changed)

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
    preview_panel.offset_top = -176
    preview_panel.offset_right = 500
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
    var requires_enemy_target := _slot_requires_enemy_target(slot)
    if armed_slot == slot and now <= armed_until_ms:
        if requires_enemy_target and not target_choice_made:
            armed_until_ms = now + TARGETING_WINDOW_MS
            _sync_targeting_visuals()
            _show_preview(slot)
            return
        _disarm_preview()
        qa._on_skill(slot)
        call_deferred("_after_action")
        return

    armed_slot = slot
    target_choice_made = not requires_enemy_target
    armed_until_ms = now + (TARGETING_WINDOW_MS if requires_enemy_target else CONFIRM_WINDOW_MS)
    qa.tactical_ui.set_armed_skill(slot)
    _sync_targeting_visuals()
    _show_preview(slot)

func _on_selection_changed(cell: Vector2i) -> void:
    if armed_slot >= 0 and _slot_requires_enemy_target(armed_slot) and qa != null and qa.slice != null and qa.slice.combat != null:
        var runtime: Variant = qa.slice.combat
        var occupant := str(runtime.grid.occupant(cell))
        var sets := _target_sets(armed_slot)
        var candidates: Array[String] = sets.get("candidates", [])
        if occupant != "" and candidates.has(occupant):
            target_choice_made = true
            armed_until_ms = Time.get_ticks_msec() + CONFIRM_WINDOW_MS
    call_deferred("_selection_changed_deferred")

func _on_zone_changed(_zone: String) -> void:
    if armed_slot >= 0:
        armed_until_ms = Time.get_ticks_msec() + (CONFIRM_WINDOW_MS if target_choice_made else TARGETING_WINDOW_MS)
    call_deferred("_selection_changed_deferred")

func _selection_changed_deferred() -> void:
    if qa == null or qa.tactical_ui == null:
        return
    qa.tactical_ui.set_external_selection(qa.selected_watcher, qa.selected_target, qa.selected_zone)
    if armed_slot >= 0:
        if _slot_requires_enemy_target(armed_slot):
            armed_until_ms = Time.get_ticks_msec() + (CONFIRM_WINDOW_MS if target_choice_made else TARGETING_WINDOW_MS)
        else:
            armed_until_ms = Time.get_ticks_msec() + CONFIRM_WINDOW_MS
        _sync_targeting_visuals()
        _show_preview(armed_slot)

func _after_action() -> void:
    if qa == null or qa.tactical_ui == null:
        return
    qa.tactical_ui.set_external_selection(qa.selected_watcher, qa.selected_target, qa.selected_zone)

func _disarm_preview() -> void:
    armed_slot = -1
    armed_until_ms = 0
    target_choice_made = false
    if qa != null and qa.tactical_ui != null:
        qa.tactical_ui.set_targeting_mode(false)
        qa.tactical_ui.set_armed_skill(-1)
    if preview_panel != null:
        preview_panel.visible = false

func _sync_targeting_visuals() -> void:
    if qa == null or qa.tactical_ui == null:
        return
    if armed_slot < 0 or not _slot_requires_enemy_target(armed_slot):
        qa.tactical_ui.set_targeting_mode(false)
        return
    var sets := _target_sets(armed_slot)
    var candidates: Array[String] = sets.get("candidates", [])
    var blocked: Array[String] = sets.get("blocked", [])
    qa.tactical_ui.set_targeting_mode(true, candidates, blocked, target_choice_made)

func _slot_requires_enemy_target(slot: int) -> bool:
    if qa == null or qa.slice == null or qa.slice.combat == null or slot < 0 or slot >= qa.skill_ids.size():
        return false
    var runtime: Variant = qa.slice.combat
    var skill: Dictionary = runtime.content_db.skill(qa.skill_ids[slot])
    if skill.is_empty():
        return false
    return _effective_action(runtime, skill) not in SELF_TARGET_ACTIONS

func _target_sets(slot: int) -> Dictionary:
    var candidates: Array[String] = []
    var blocked: Array[String] = []
    if qa == null or qa.slice == null or qa.slice.combat == null or slot < 0 or slot >= qa.skill_ids.size():
        return {"candidates":candidates, "blocked":blocked}

    var runtime: Variant = qa.slice.combat
    var skill: Dictionary = runtime.content_db.skill(qa.skill_ids[slot])
    if skill.is_empty():
        return {"candidates":candidates, "blocked":blocked}
    var action := _effective_action(runtime, skill)
    var required_range := 0
    if runtime.skill_behavior != null and runtime.skill_behavior.has_method("range_for"):
        required_range = int(runtime.skill_behavior.range_for(skill))

    for enemy_id: String in runtime.alive_ids("enemy"):
        if not runtime.combatants.has(enemy_id):
            continue
        var row: Dictionary = runtime.combatants[enemy_id]
        if int(row.get("hp", 0)) <= 0 or bool(row.get("subdued", false)):
            continue
        var distance := int(runtime.grid.distance(qa.selected_watcher, enemy_id))
        var selectable := action == "attack_move" or required_range <= 0 or (distance >= 0 and distance <= required_range)
        if selectable:
            candidates.append(enemy_id)
        else:
            blocked.append(enemy_id)
    return {"candidates":candidates, "blocked":blocked}

func _effective_action(runtime: Variant, skill: Dictionary) -> String:
    var action := str(skill.get("action_type", "attack"))
    if runtime.skill_behavior != null and runtime.skill_behavior.has_method("effective_action"):
        action = str(runtime.skill_behavior.effective_action(skill))
    return action

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

    var action := _effective_action(runtime, skill)
    var skill_name := str(skill.get("name_fr", skill_id))
    if _slot_requires_enemy_target(slot) and not target_choice_made:
        var sets := _target_sets(slot)
        var candidates: Array[String] = sets.get("candidates", [])
        var blocked: Array[String] = sets.get("blocked", [])
        var attacker_name := qa._display(qa.selected_watcher)
        if candidates.is_empty():
            preview_label.text = "CIBLAGE · %s\nAucune cible actuellement à portée pour %s.\n× indique les ennemis hors portée." % [skill_name, attacker_name]
        else:
            preview_label.text = "CIBLAGE · %s\n▶ %s attaque — touchez un ennemi marqué ○.\n○ %d cible(s) possible(s) · × %d hors portée" % [skill_name, attacker_name, candidates.size(), blocked.size()]
        preview_panel.visible = true
        return

    var target_id := qa.selected_target
    if action in SELF_TARGET_ACTIONS:
        target_id = qa.selected_watcher
    if target_id == "" or not runtime.combatants.has(target_id) or not runtime.combatants.has(qa.selected_watcher):
        preview_label.text = "APERÇU · %s\nSélectionnez une cible valide." % skill_name
        preview_panel.visible = true
        return

    var attacker: Dictionary = runtime.combatants[qa.selected_watcher]
    var target: Dictionary = runtime.combatants[target_id]
    var target_name := str(target.get("name", target_id))
    var zone_name := _zone_label(qa.selected_zone)
    var first_line := ("CIBLE VERROUILLÉE · " if _slot_requires_enemy_target(slot) else "APERÇU · ") + "%s → %s · %s" % [skill_name, target_name, zone_name]
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

    preview_label.text = "%s\n%s\n%s" % [first_line, second_line, "Retouchez la compétence pour exécuter." if _slot_requires_enemy_target(slot) else "Touchez à nouveau la compétence pour confirmer."]
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
