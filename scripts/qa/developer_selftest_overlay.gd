extends CanvasLayer
class_name DeveloperSelftestOverlay

const CONTRACT_PATH := "res://data/veilleurs/developer_selftest_contract.json"
const DEFAULT_REPORT_PATH := "user://veilleurs_developer_selftest.json"
const FLAG := "--developer-selftest"
const REPORT_ARG_PREFIX := "--selftest-report="
const HESITATION_SECONDS := 12.0
const FPS_SAMPLE_INTERVAL := 1.0
const AUTOSAVE_INTERVAL := 5.0
const LOW_FPS_THRESHOLD := 45.0
const SEVERE_FPS_THRESHOLD := 30.0

var contract: Dictionary = {}
var steps: Array = []
var current_step := 0
var started_msec := 0
var step_started_msec := 0
var events: Array[Dictionary] = []
var completed := false
var enabled := false
var report_path := ""

var current_screen_name := ""
var screen_entered_msec := 0
var screen_durations: Dictionary = {}
var step_durations: Dictionary = {}

var last_input_msec := 0
var hesitation_active := false
var hesitation_started_msec := 0
var input_events := 0
var pointer_presses := 0
var key_presses := 0
var controller_presses := 0

var fps_sample_accum := 0.0
var fps_sample_count := 0
var fps_sum := 0.0
var fps_min := 99999.0
var fps_max := 0.0
var low_fps_samples := 0
var severe_fps_samples := 0
var autosave_accum := 0.0

var last_state_snapshot_key := ""
var state_change_count := 0

var panel: PanelContainer
var step_label: Label
var screen_label: Label
var timer_label: Label
var note_edit: LineEdit

func _ready() -> void:
    if not OS.get_cmdline_user_args().has(FLAG):
        process_mode = Node.PROCESS_MODE_DISABLED
        visible = false
        return

    enabled = true
    layer = 100
    contract = _load_contract()
    steps = contract.get("steps", [])
    started_msec = Time.get_ticks_msec()
    step_started_msec = started_msec
    last_input_msec = started_msec
    current_screen_name = str(GameState.current_screen)
    screen_entered_msec = started_msec
    report_path = _resolve_report_path()

    _build_ui()
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if not GameState.state_changed.is_connected(_on_state_changed):
        GameState.state_changed.connect(_on_state_changed)

    _record_data("session_started", "Auto-test développeur lancé.", {
        "report_path": report_path,
        "hesitation_threshold_seconds": HESITATION_SECONDS,
        "low_fps_threshold": LOW_FPS_THRESHOLD
    })
    if not steps.is_empty():
        var first_step: Dictionary = steps[0]
        _record("step_started", str(first_step.get("id", "unknown")))
    _record_data("state_snapshot", "État initial.", _state_snapshot())
    _refresh()

func _process(delta: float) -> void:
    if not enabled:
        return

    _sample_performance(delta)
    _update_hesitation()

    autosave_accum += delta
    if autosave_accum >= AUTOSAVE_INTERVAL:
        autosave_accum = 0.0
        _save_report()

    if panel == null or not panel.visible:
        return
    timer_label.text = "Temps : %s" % _format_seconds(_elapsed_seconds())
    screen_label.text = "Écran : %s" % str(GameState.current_screen)

func _input(event: InputEvent) -> void:
    if not enabled:
        return

    var pressed := false
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.pressed:
            pointer_presses += 1
            pressed = true
    elif event is InputEventScreenTouch:
        var touch_event := event as InputEventScreenTouch
        if touch_event.pressed:
            pointer_presses += 1
            pressed = true
    elif event is InputEventKey:
        var key_event := event as InputEventKey
        if key_event.pressed and not key_event.echo:
            key_presses += 1
            pressed = true
    elif event is InputEventJoypadButton:
        var joy_event := event as InputEventJoypadButton
        if joy_event.pressed:
            controller_presses += 1
            pressed = true

    if pressed:
        input_events += 1
        _mark_player_input()

func _exit_tree() -> void:
    if enabled:
        _save_report()

func _load_contract() -> Dictionary:
    if not FileAccess.file_exists(CONTRACT_PATH):
        push_error("DeveloperSelftestOverlay: contrat absent: %s" % CONTRACT_PATH)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("DeveloperSelftestOverlay: contrat invalide")
        return {}
    var parsed_dict: Dictionary = parsed
    return parsed_dict

func _resolve_report_path() -> String:
    for arg_value in OS.get_cmdline_user_args():
        var arg := str(arg_value)
        if arg.begins_with(REPORT_ARG_PREFIX):
            var candidate := arg.substr(REPORT_ARG_PREFIX.length()).strip_edges()
            if candidate != "":
                return candidate
    return ProjectSettings.globalize_path(DEFAULT_REPORT_PATH)

func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "DeveloperSelftestPanel"
    panel.position = Vector2(18, 18)
    panel.size = Vector2(430, 250)
    add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    panel.add_child(box)

    var title := Label.new()
    title.text = "AUTO-TEST DÉVELOPPEUR · VERTICALE CHAPITRE I"
    title.add_theme_font_size_override("font_size", 16)
    box.add_child(title)

    var warning := Label.new()
    warning.text = "Observation interne uniquement — ne valide aucun gate joueur."
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(warning)

    step_label = Label.new()
    step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    step_label.custom_minimum_size = Vector2(400, 66)
    box.add_child(step_label)

    var meta := HBoxContainer.new()
    meta.add_theme_constant_override("separation", 12)
    box.add_child(meta)
    timer_label = Label.new()
    timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meta.add_child(timer_label)
    screen_label = Label.new()
    screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    screen_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meta.add_child(screen_label)

    note_edit = LineEdit.new()
    note_edit.placeholder_text = "Note P0/P1 ou friction observée…"
    note_edit.custom_minimum_size = Vector2(400, 42)
    box.add_child(note_edit)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 6)
    box.add_child(actions)

    var issue_button := Button.new()
    issue_button.text = "NOTER PROBLÈME"
    issue_button.custom_minimum_size = Vector2(132, 44)
    issue_button.pressed.connect(_on_issue)
    actions.add_child(issue_button)

    var next_button := Button.new()
    next_button.text = "ÉTAPE SUIVANTE"
    next_button.custom_minimum_size = Vector2(132, 44)
    next_button.pressed.connect(_on_next_step)
    actions.add_child(next_button)

    var hide_button := Button.new()
    hide_button.text = "MASQUER (F10)"
    hide_button.custom_minimum_size = Vector2(126, 44)
    hide_button.pressed.connect(_toggle_panel)
    actions.add_child(hide_button)

func _refresh() -> void:
    if steps.is_empty():
        step_label.text = "Contrat d'auto-test indisponible."
        return
    var index := clampi(current_step, 0, steps.size() - 1)
    var step: Dictionary = steps[index]
    var target: Array = step.get("target_minutes", [])
    var target_text := ""
    if target.size() >= 2:
        target_text = " · cible %s–%s min" % [str(target[0]), str(target[1])]
    step_label.text = "%d/%d · %s%s\n%s" % [
        index + 1,
        steps.size(),
        str(step.get("label", step.get("id", "Étape"))),
        target_text,
        str(step.get("question", ""))
    ]
    timer_label.text = "Temps : %s" % _format_seconds(_elapsed_seconds())
    screen_label.text = "Écran : %s" % str(GameState.current_screen)

func _on_next_step() -> void:
    if steps.is_empty() or completed:
        return

    var now := Time.get_ticks_msec()
    var index := clampi(current_step, 0, steps.size() - 1)
    var step: Dictionary = steps[index]
    var step_id := str(step.get("id", "unknown"))
    var duration := float(now - step_started_msec) / 1000.0
    step_durations[step_id] = float(step_durations.get(step_id, 0.0)) + duration
    _record_data("step_completed", step_id, {"duration_seconds": duration})

    if current_step >= steps.size() - 1:
        completed = true
        _record("session_completed", "Toutes les étapes développeur ont été parcourues.")
        step_label.text = "AUTO-TEST PARCOURU\nConsigner les P0/P1 avant tout playtest naïf."
        _save_report()
        return

    current_step += 1
    step_started_msec = now
    var next_step: Dictionary = steps[current_step]
    _record("step_started", str(next_step.get("id", "unknown")))
    _refresh()

func _on_issue() -> void:
    var note := note_edit.text.strip_edges()
    if note == "":
        note = "Problème observé sans note."
    _record("issue", note)
    note_edit.clear()

func _toggle_panel() -> void:
    panel.visible = not panel.visible

func _unhandled_input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventKey:
        var key_event := event as InputEventKey
        if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F10:
            panel.visible = not panel.visible
            get_viewport().set_input_as_handled()

func _on_screen_requested(screen_name: String) -> void:
    var now := Time.get_ticks_msec()
    var previous := current_screen_name
    var duration := float(now - screen_entered_msec) / 1000.0
    if previous != "":
        screen_durations[previous] = float(screen_durations.get(previous, 0.0)) + duration
    current_screen_name = screen_name
    screen_entered_msec = now
    _record_data("screen", screen_name, {
        "previous_screen": previous,
        "previous_duration_seconds": duration
    })

func _on_state_changed() -> void:
    var snapshot := _state_snapshot()
    var snapshot_key := JSON.stringify(snapshot)
    if snapshot_key == last_state_snapshot_key:
        return
    last_state_snapshot_key = snapshot_key
    state_change_count += 1
    _record_data("state_changed", "État de jeu modifié.", snapshot)

func _state_snapshot() -> Dictionary:
    return {
        "screen": str(GameState.current_screen),
        "gold": int(GameState.gold),
        "essence": int(GameState.essence),
        "light": int(GameState.light),
        "supplies": int(GameState.supplies),
        "expedition_room": int(GameState.expedition_room),
        "expedition_rooms": int(GameState.expedition_rooms),
        "battle_rounds": int(GameState.battle_rounds),
        "selected_hero": int(GameState.selected_hero),
        "alive_heroes": GameState.alive_heroes().size(),
        "alive_enemies": GameState.alive_enemies().size(),
        "party": _combatant_snapshot(GameState.party),
        "enemies": _combatant_snapshot(GameState.battle_enemies),
        "latest_log": str(GameState.log_lines[0]) if not GameState.log_lines.is_empty() else ""
    }

func _combatant_snapshot(rows: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in rows:
        if not value is Dictionary:
            continue
        var row: Dictionary = value
        result.append({
            "id": str(row.get("canonical_id", row.get("id", ""))),
            "name": str(row.get("name", "")),
            "hp": int(row.get("hp", 0)),
            "max_hp": int(row.get("max_hp", row.get("hp_max", 0))),
            "fear": float(row.get("fear", row.get("peur", 0.0))),
            "madness": float(row.get("madness", row.get("folie", 0.0))),
            "stress": float(row.get("stress", 0.0)),
            "rank": int(row.get("rank", row.get("position", -1)))
        })
    return result

func _mark_player_input() -> void:
    var now := Time.get_ticks_msec()
    if hesitation_active:
        var duration := float(now - hesitation_started_msec) / 1000.0
        hesitation_active = false
        _record_data("hesitation_resolved", "Entrée joueur après hésitation.", {
            "duration_seconds": duration
        })
    last_input_msec = now

func _update_hesitation() -> void:
    if hesitation_active or last_input_msec <= 0:
        return
    if str(GameState.current_screen) == "title":
        return
    var idle_seconds := float(Time.get_ticks_msec() - last_input_msec) / 1000.0
    if idle_seconds < HESITATION_SECONDS:
        return
    hesitation_active = true
    hesitation_started_msec = last_input_msec
    _record_data("hesitation_started", "Aucune entrée joueur pendant %.1f s." % idle_seconds, {
        "idle_seconds": idle_seconds
    })

func _sample_performance(delta: float) -> void:
    fps_sample_accum += delta
    if fps_sample_accum < FPS_SAMPLE_INTERVAL:
        return
    fps_sample_accum = 0.0
    var fps := float(Engine.get_frames_per_second())
    fps_sample_count += 1
    fps_sum += fps
    fps_min = minf(fps_min, fps)
    fps_max = maxf(fps_max, fps)
    if fps < LOW_FPS_THRESHOLD:
        low_fps_samples += 1
    if fps < SEVERE_FPS_THRESHOLD:
        severe_fps_samples += 1

func _record(kind: String, note: String) -> void:
    _record_data(kind, note, {})

func _record_data(kind: String, note: String, data: Dictionary) -> void:
    var step_id := ""
    if not steps.is_empty():
        var index := clampi(current_step, 0, steps.size() - 1)
        var step: Dictionary = steps[index]
        step_id = str(step.get("id", ""))
    var entry: Dictionary = {
        "type": kind,
        "note": note,
        "elapsed_seconds": _elapsed_seconds(),
        "step_id": step_id,
        "screen": str(GameState.current_screen)
    }
    if not data.is_empty():
        entry["data"] = data
    events.append(entry)
    _save_report()

func _save_report() -> void:
    if report_path == "":
        return
    var base_dir := report_path.get_base_dir()
    if base_dir != "":
        DirAccess.make_dir_recursive_absolute(base_dir)

    var performance := _performance_summary()
    var summary := {
        "screen_seconds": _screen_duration_snapshot(),
        "step_seconds": _step_duration_snapshot(),
        "hesitation_count": _count_events("hesitation_started"),
        "issue_count": _count_events("issue"),
        "state_change_count": state_change_count,
        "input_events": input_events,
        "pointer_presses": pointer_presses,
        "key_presses": key_presses,
        "controller_presses": controller_presses,
        "performance": performance
    }

    var report := {
        "schema_version": 2,
        "mode": "developer_selftest",
        "completed": completed,
        "current_step": current_step,
        "elapsed_seconds": _elapsed_seconds(),
        "target_duration_minutes": contract.get("target_duration_minutes", [30, 45]),
        "human_gate_promotion_allowed": false,
        "report_path": report_path,
        "summary": summary,
        "analysis_flags": _analysis_flags(performance),
        "events": events
    }
    var file := FileAccess.open(report_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  "))

func _performance_summary() -> Dictionary:
    var average := 0.0
    var minimum := 0.0
    if fps_sample_count > 0:
        average = fps_sum / float(fps_sample_count)
        minimum = fps_min
    return {
        "samples": fps_sample_count,
        "fps_average": average,
        "fps_min": minimum,
        "fps_max": fps_max,
        "low_fps_samples_under_45": low_fps_samples,
        "severe_fps_samples_under_30": severe_fps_samples
    }

func _screen_duration_snapshot() -> Dictionary:
    var snapshot: Dictionary = screen_durations.duplicate(true)
    if current_screen_name != "" and screen_entered_msec > 0:
        var current_duration := float(Time.get_ticks_msec() - screen_entered_msec) / 1000.0
        snapshot[current_screen_name] = float(snapshot.get(current_screen_name, 0.0)) + current_duration
    return snapshot

func _step_duration_snapshot() -> Dictionary:
    var snapshot: Dictionary = step_durations.duplicate(true)
    if not completed and not steps.is_empty() and step_started_msec > 0:
        var index := clampi(current_step, 0, steps.size() - 1)
        var step: Dictionary = steps[index]
        var step_id := str(step.get("id", "unknown"))
        var current_duration := float(Time.get_ticks_msec() - step_started_msec) / 1000.0
        snapshot[step_id] = float(snapshot.get(step_id, 0.0)) + current_duration
    return snapshot

func _analysis_flags(performance: Dictionary) -> Array[Dictionary]:
    var flags: Array[Dictionary] = []
    var hesitation_count := _count_events("hesitation_started")
    var issue_count := _count_events("issue")

    if issue_count > 0:
        flags.append({
            "kind": "manual_issue_review",
            "severity_hint": "P0-P2",
            "reason": "%d problème(s) noté(s) manuellement pendant la session." % issue_count
        })
    if hesitation_count >= 3:
        flags.append({
            "kind": "clarity_review",
            "severity_hint": "P1-P2",
            "reason": "%d hésitations automatiques de %.0f s ou plus." % [hesitation_count, HESITATION_SECONDS]
        })

    if int(performance.get("samples", 0)) > 0:
        var average := float(performance.get("fps_average", 0.0))
        var minimum := float(performance.get("fps_min", 0.0))
        if minimum < SEVERE_FPS_THRESHOLD or average < LOW_FPS_THRESHOLD:
            flags.append({
                "kind": "performance_review",
                "severity_hint": "P1-P2",
                "reason": "FPS moyen %.1f, minimum %.1f." % [average, minimum]
            })

    var elapsed_minutes := _elapsed_seconds() / 60.0
    var target: Array = contract.get("target_duration_minutes", [30, 45])
    if target.size() >= 2:
        var minimum_minutes := float(target[0])
        var maximum_minutes := float(target[1])
        if completed and elapsed_minutes < minimum_minutes:
            flags.append({
                "kind": "pace_review",
                "severity_hint": "P2",
                "reason": "Session terminée trop vite : %.1f min pour une cible de %.0f–%.0f min." % [elapsed_minutes, minimum_minutes, maximum_minutes]
            })
        elif elapsed_minutes > maximum_minutes:
            flags.append({
                "kind": "pace_review",
                "severity_hint": "P1-P2",
                "reason": "Session au-delà de la cible : %.1f min pour une cible de %.0f–%.0f min." % [elapsed_minutes, minimum_minutes, maximum_minutes]
            })

    for step_value in steps:
        if not step_value is Dictionary:
            continue
        var step: Dictionary = step_value
        var step_id := str(step.get("id", ""))
        if not step_durations.has(step_id):
            continue
        var target_minutes: Array = step.get("target_minutes", [])
        if target_minutes.size() < 2:
            continue
        var duration_seconds := float(step_durations.get(step_id, 0.0))
        var lower_seconds := float(target_minutes[0]) * 60.0
        var upper_seconds := float(target_minutes[1]) * 60.0
        if duration_seconds > upper_seconds * 1.5:
            flags.append({
                "kind": "step_pace_review",
                "severity_hint": "P1-P2",
                "step_id": step_id,
                "reason": "Étape %.1f min, nettement au-dessus de la cible %s–%s min." % [duration_seconds / 60.0, str(target_minutes[0]), str(target_minutes[1])]
            })
        elif duration_seconds < lower_seconds * 0.5:
            flags.append({
                "kind": "step_pace_review",
                "severity_hint": "P2",
                "step_id": step_id,
                "reason": "Étape %.1f min, nettement sous la cible %s–%s min." % [duration_seconds / 60.0, str(target_minutes[0]), str(target_minutes[1])]
            })

    return flags

func _count_events(kind: String) -> int:
    var count := 0
    for event in events:
        if str(event.get("type", "")) == kind:
            count += 1
    return count

func _elapsed_seconds() -> float:
    if started_msec <= 0:
        return 0.0
    return float(Time.get_ticks_msec() - started_msec) / 1000.0

func _format_seconds(value: float) -> String:
    var total := maxi(0, int(value))
    return "%02d:%02d" % [int(total / 60), total % 60]
