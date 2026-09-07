@tool
extends EditorPlugin

var _toolbar: HBoxContainer
var _quick_button: Button
var _full_button: Button


func _enter_tree() -> void:
    _toolbar = HBoxContainer.new()
    _toolbar.name = "VeilleursPipelineToolbar"

    _quick_button = Button.new()
    _quick_button.text = "Veilleurs QA"
    _quick_button.tooltip_text = "Import strict + audits + smokes Veilleurs ciblés"
    _quick_button.pressed.connect(_run_quick)
    _toolbar.add_child(_quick_button)

    _full_button = Button.new()
    _full_button.text = "Veilleurs QA complète"
    _full_button.tooltip_text = "Lance la suite Godot complète du dépôt"
    _full_button.pressed.connect(_run_full)
    _toolbar.add_child(_full_button)

    add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar)


func _exit_tree() -> void:
    if is_instance_valid(_toolbar):
        remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar)
        _toolbar.queue_free()


func _run_quick() -> void:
    _spawn_pipeline("quick")


func _run_full() -> void:
    _spawn_pipeline("full")


func _spawn_pipeline(mode: String) -> void:
    var root := ProjectSettings.globalize_path("res://")
    OS.set_environment("GODOT_BIN", OS.get_executable_path())

    var executable := ""
    var args := PackedStringArray()

    if OS.get_name() == "Windows":
        executable = "powershell.exe"
        var script := root.path_join("tools/godot/run_veilleurs_pipeline.ps1")
        args = PackedStringArray([
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", script,
            "-Mode", mode,
            "-RequireGodot"
        ])
    else:
        executable = "/bin/bash"
        var script := root.path_join("tools/godot/run_veilleurs_pipeline.sh")
        args = PackedStringArray([script, mode, "origin/main", "--require-godot"])

    var pid := OS.create_process(executable, args, true)
    if pid <= 0:
        push_error("Impossible de lancer le pipeline Veilleurs. Vérifier Python et le shell local.")
        return

    print("Veilleurs pipeline lancé en mode %s (PID %s). Rapport: build/automation/veilleurs_pipeline_report.json" % [mode, pid])
