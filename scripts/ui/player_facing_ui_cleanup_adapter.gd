extends Node

# Dernière passe de nettoyage joueur : les écrans techniques historiques restent
# disponibles pour les QA, mais les accès normaux passent par le vrai menu en
# onglets et les contrôles du Sanctuaire ne dupliquent plus des fonctions déjà
# présentes dans ce menu. Aucun état de jeu ni format de sauvegarde n'est modifié.

const GOLD := Color("#d5b26c")
const PALE := Color("#e4c989")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")

var _main: Node
var _cleanup_scheduled := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _install() -> void:
    _main = get_parent()
    if _main == null:
        push_warning("PlayerFacingUICleanupAdapter: Main indisponible.")
        return
    if not GameState.screen_requested.is_connected(_on_screen_requested):
        GameState.screen_requested.connect(_on_screen_requested)
    if is_instance_valid(GameMenuUI.overlay) and not GameMenuUI.overlay.visibility_changed.is_connected(_on_menu_visibility_changed):
        GameMenuUI.overlay.visibility_changed.connect(_on_menu_visibility_changed)
    _schedule_cleanup()

func _on_screen_requested(_screen_name: String) -> void:
    _schedule_cleanup()

func _on_menu_visibility_changed() -> void:
    _schedule_cleanup()

func _schedule_cleanup() -> void:
    if _cleanup_scheduled:
        return
    _cleanup_scheduled = true
    call_deferred("_apply_cleanup")

func _apply_cleanup() -> void:
    _cleanup_scheduled = false
    _bind_header_to_real_menu()
    _polish_game_menu_launcher()
    if str(GameState.current_screen) == "sanctuary":
        _clean_sanctuary_actions()

func _main_root() -> Control:
    if _main == null:
        return null
    var value: Variant = _main.get("root")
    if value is Control:
        return value as Control
    return null

func _main_content() -> Control:
    if _main == null:
        return null
    var value: Variant = _main.get("content")
    if value is Control:
        return value as Control
    return null

func _header() -> HBoxContainer:
    var root := _main_root()
    if root == null:
        return null
    return root.get_node_or_null("Header") as HBoxContainer

func _bind_header_to_real_menu() -> void:
    var header := _header()
    if header == null:
        return

    var menu_button := header.get_node_or_null("CanonicalMenu") as Button
    if menu_button != null:
        menu_button.text = "MENU"
        menu_button.tooltip_text = "Ouvrir le menu du jeu"
        _replace_pressed_callback(menu_button, Callable(self, "_open_game_menu"), "game_menu")

    var help_button := header.get_node_or_null("CanonicalContext") as Button
    if help_button != null:
        help_button.text = "AIDE"
        help_button.tooltip_text = "Ouvrir l'aide"
        help_button.custom_minimum_size = Vector2(96.0, 48.0)
        _replace_pressed_callback(help_button, Callable(self, "_open_help"), "help_tab")

func _replace_pressed_callback(button: Button, callback: Callable, target_id: String) -> void:
    if str(button.get_meta("litd_player_facing_target", "")) == target_id:
        return
    for connection_value: Variant in button.get_signal_connection_list("pressed"):
        var connection: Dictionary = connection_value
        var existing: Callable = connection.get("callable", Callable())
        if existing.is_valid() and button.pressed.is_connected(existing):
            button.pressed.disconnect(existing)
    if not button.pressed.is_connected(callback):
        button.pressed.connect(callback)
    button.set_meta("litd_player_facing_target", target_id)

func _open_game_menu() -> void:
    GameMenuUI.open_menu()

func _open_help() -> void:
    GameMenuUI.open_menu("help")

func _polish_game_menu_launcher() -> void:
    var launcher := GameMenuUI.launcher as Button
    if launcher == null:
        return

    launcher.text = "MENU"
    launcher.tooltip_text = "Ouvrir le menu du jeu"
    launcher.position = Vector2(1144.0, 78.0)
    launcher.custom_minimum_size = Vector2(100.0, 44.0)
    launcher.focus_mode = Control.FOCUS_ALL
    launcher.flat = true
    launcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    launcher.add_theme_font_size_override("font_size", 13)
    launcher.add_theme_constant_override("outline_size", 2)
    launcher.add_theme_color_override("font_color", PALE)
    launcher.add_theme_color_override("font_hover_color", TEXT)
    launcher.add_theme_color_override("font_pressed_color", PALE)
    launcher.add_theme_color_override("font_focus_color", TEXT)
    launcher.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))

    var empty := StyleBoxEmpty.new()
    launcher.add_theme_stylebox_override("normal", empty)
    launcher.add_theme_stylebox_override("disabled", empty)
    launcher.add_theme_stylebox_override("hover", _underline_style(0.74))
    launcher.add_theme_stylebox_override("focus", _underline_style(0.86))
    launcher.add_theme_stylebox_override("pressed", _underline_style(1.0))

    var header := _header()
    var header_visible := header != null and header.visible
    launcher.visible = str(GameState.current_screen) != "title" and not GameMenuUI.overlay.visible and not header_visible

func _clean_sanctuary_actions() -> void:
    var content := _main_content()
    if content == null:
        return

    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or bool(button.get_meta("litd_location_hotspot", false)):
            continue

        if button.text == "SAUVEGARDER":
            # La sauvegarde complète est désormais dans l'onglet Sauvegardes.
            # On retire le doublon posé sur le décor sans supprimer la fonction.
            button.visible = false
            button.focus_mode = Control.FOCUS_NONE
        elif button.text == "CARACTÉRISTIQUES DU HÉROS" or button.text == "TRAITS DU VEILLEUR":
            button.text = "TRAITS DU VEILLEUR"
            button.tooltip_text = "Choisir les traits du Veilleur"
            button.position = Vector2(930.0, 18.0)
            button.custom_minimum_size = Vector2(230.0, 44.0)
            button.size = Vector2(280.0, 44.0)
            button.focus_mode = Control.FOCUS_ALL
            button.flat = true
            button.add_theme_font_size_override("font_size", 13)
            button.add_theme_constant_override("outline_size", 2)
            button.add_theme_color_override("font_color", PALE)
            button.add_theme_color_override("font_hover_color", TEXT)
            button.add_theme_color_override("font_pressed_color", PALE)
            button.add_theme_color_override("font_focus_color", TEXT)
            button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
            var empty := StyleBoxEmpty.new()
            button.add_theme_stylebox_override("normal", empty)
            button.add_theme_stylebox_override("disabled", empty)
            button.add_theme_stylebox_override("hover", _underline_style(0.64))
            button.add_theme_stylebox_override("focus", _underline_style(0.82))
            button.add_theme_stylebox_override("pressed", _underline_style(1.0))

func _underline_style(alpha: float) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.020, 0.027, 0.30)
    style.border_color = Color(GOLD, alpha)
    style.border_width_bottom = 1
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 5.0
    style.content_margin_bottom = 5.0
    return style
