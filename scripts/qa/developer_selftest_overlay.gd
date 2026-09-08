extends CanvasLayer
class_name DeveloperSelftestOverlay

const CONTRACT_PATH := "res://data/veilleurs/developer_selftest_contract.json"
const REPORT_PATH := "user://veilleurs_developer_selftest.json"
const FLAG := "--developer-selftest"

var contract: Dictionary = {}
var steps: Array = []
var current_step := 0
var started_msec := 0
var events: Array[Dictionary] = []
var completed := false
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
    layer = 100
    contract = _load_contract()
    steps = contract.get("steps", [])
    started_msec = Time.get_ticks_msec()
    _build_ui()
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    _record("session_started", "Auto-test développeur lancé.")
    _refresh()

func _process(_delta: float) -> void:
    if not visible or panel == null or not panel.visible:
        return
    timer_label.text = "Temps : %s" % _format_seconds(_elapsed_seconds())
    screen_label.text = "Écran : %s" % str(GameState.current_screen)

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
    var index := clampi(current_step, 0, steps.size() - 1)
    var step: Dictionary = steps[index]
    _record("step_completed", str(step.get("id", "unknown")))
    if current_step >= steps.size() - 1:
        completed = true
        _record("session_completed", "Toutes les étapes développeur ont été parcourues.")
        step_label.text = "AUTO-TEST PARCOURU\nConsigner les P0/P1 avant tout playtest naïf."
        _save_report()
        return
    current_step += 1
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
    if not OS.get_cmdline_user_args().has(FLAG):
        return
    if event is InputEventKey:
        var key_event := event as InputEventKey
        if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F10:
            panel.visible = not panel.visible
            get_viewport().set_input_as_handled()

func _on_screen_requested(screen_name: String) -> void:
    _record("screen", screen_name)

func _record(kind: String, note: String) -> void:
    var step_id := ""
    if not steps.is_empty():
        var index := clampi(current_step, 0, steps.size() - 1)
        var step: Dictionary = steps[index]
        step_id = str(step.get("id", ""))
    events.append({
        "type": kind,
        "note": note,
        "elapsed_seconds": _elapsed_seconds(),
        "step_id": step_id,
        "screen": str(GameState.current_screen)
    })
    _save_report()

func _save_report() -> void:
    var report := {
        "schema_version": 1,
        "mode": "developer_selftest",
        "completed": completed,
        "current_step": current_step,
        "elapsed_seconds": _elapsed_seconds(),
        "target_duration_minutes": contract.get("target_duration_minutes", [30, 45]),
        "human_gate_promotion_allowed": false,
        "events": events
    }
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  "))

func _elapsed_seconds() -> float:
    if started_msec <= 0:
        return 0.0
    return float(Time.get_ticks_msec() - started_msec) / 1000.0

func _format_seconds(value: float) -> String:
    var total := maxi(0, int(value))
    return "%02d:%02d" % [int(total / 60), total % 60]
