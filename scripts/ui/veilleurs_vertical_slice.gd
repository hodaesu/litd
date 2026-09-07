extends "res://scripts/ui/veilleurs_vertical_slice_qa_v09.gd"
class_name VeilleursVerticalSliceUI

const MAIN_SCENE := "res://scenes/Main.tscn"

func _ready() -> void:
    super._ready()
    slice = VeilleursRuntime.runtime
    _promote_shell()
    if VeilleursRuntime.is_active():
        _repair_selection()
        if slice.combat != null:
            tactical_ui.visible = true
            _refresh_combat()
            message_label.text = "Expédition reprise."
        else:
            _render_node()
            message_label.text = "Expédition reprise."
    else:
        _start_dungeon("DUNGEON_KHAR_SEN")

func _on_save() -> void:
    message_label.text = "Partie sauvegardée." if SaveManager.save_game() else "Échec de sauvegarde."

func _on_load() -> void:
    if not SaveManager.load_game():
        message_label.text = "Aucune sauvegarde compatible disponible."
        return
    slice = VeilleursRuntime.runtime
    _repair_selection()
    if slice.combat != null:
        tactical_ui.visible = true
        _refresh_combat()
        message_label.text = "Combat et Rémanence restaurés."
    elif VeilleursRuntime.is_active():
        message_label.text = "Expédition et Rémanence restaurées."
        _render_node()
    else:
        message_label.text = "La sauvegarde chargée n'est pas une expédition Les Veilleurs."

func _promote_shell() -> void:
    var labels := find_children("*", "Label", true, false)
    for value: Node in labels:
        var label := value as Label
        if label != null and label.text.begins_with("LITD : LES VEILLEURS — VERTICAL SLICE"):
            label.text = "LITD : LES VEILLEURS"
            break

    var old_back := _find_button_with_text(self, "Retour QA")
    if old_back != null:
        old_back.visible = false
        var quit_button := Button.new()
        quit_button.text = "Retour"
        quit_button.custom_minimum_size = Vector2(104, 46)
        quit_button.pressed.connect(_return_to_main)
        old_back.get_parent().add_child(quit_button)

func _find_button_with_text(root: Node, text: String) -> Button:
    for child: Node in root.get_children():
        if child is Button and (child as Button).text == text:
            return child as Button
        var nested := _find_button_with_text(child, text)
        if nested != null:
            return nested
    return null

func _return_to_main() -> void:
    if VeilleursRuntime.is_active():
        SaveManager.autosave("sortie des Veilleurs")
    get_tree().change_scene_to_file(MAIN_SCENE)
