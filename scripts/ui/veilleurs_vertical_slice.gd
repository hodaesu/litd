extends "res://scripts/ui/veilleurs_vertical_slice_qa_v09.gd"
class_name VeilleursVerticalSliceUI

const MAIN_SCENE := "res://scenes/Main.tscn"

func _ready() -> void:
    super._ready()
    slice = VeilleursRuntime.runtime
    _promote_shell()
    _apply_veilleurs_palette(self)
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
        var quit_button := LITDBaseButton.new()
        quit_button.button_kind = "secondary"
        quit_button.text = "Retour"
        quit_button.custom_minimum_size = Vector2(104, UITokens.TOUCH_MIN_SIZE)
        quit_button.pressed.connect(_return_to_main)
        old_back.get_parent().add_child(quit_button)

func _apply_veilleurs_palette(root: Node) -> void:
    for child: Node in root.get_children():
        if child is Label:
            var label := child as Label
            label.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
        elif child is PanelContainer:
            var panel := child as PanelContainer
            var style := StyleBoxFlat.new()
            style.bg_color = UITokens.COLOR_SURFACE
            style.border_color = UITokens.COLOR_BORDER_METAL
            style.set_border_width_all(1)
            style.corner_radius_top_left = UITokens.CORNER_RADIUS_M
            style.corner_radius_top_right = UITokens.CORNER_RADIUS_M
            style.corner_radius_bottom_left = UITokens.CORNER_RADIUS_M
            style.corner_radius_bottom_right = UITokens.CORNER_RADIUS_M
            panel.add_theme_stylebox_override("panel", style)
        elif child is Button and not (child is LITDBaseButton):
            _skin_legacy_button(child as Button)
        _apply_veilleurs_palette(child)

func _skin_legacy_button(button: Button) -> void:
    button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, UITokens.TOUCH_MIN_SIZE)
    button.add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    var style := StyleBoxFlat.new()
    style.bg_color = UITokens.COLOR_SURFACE
    style.border_color = UITokens.COLOR_OCHRE
    style.set_border_width_all(1)
    style.corner_radius_top_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_top_right = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_left = UITokens.CORNER_RADIUS_M
    style.corner_radius_bottom_right = UITokens.CORNER_RADIUS_M
    button.add_theme_stylebox_override("normal", style)
    var pressed := style.duplicate() as StyleBoxFlat
    pressed.bg_color = UITokens.COLOR_SURFACE_PRESSED
    pressed.border_color = UITokens.COLOR_GOLD
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover", pressed)

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
