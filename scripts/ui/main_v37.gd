extends "res://scripts/ui/main_v36.gd"

# v37 : cycle passif d'Hémocorde au-dessus des réactions cliniques validées en v36.
# Le resolver vasculaire reste séparé du runtime anatomique/médical et réutilise
# leurs états corporels réels au lieu d'introduire une jauge sanguine parallèle.
#
# Règle UI Sanctuaire / playtest : les lieux visitables n'affichent plus de
# boutons rectangulaires qui doublonnent les libellés intégrés au décor. Le
# bouton reste présent comme zone tactile invisible, recentrée sur le nom du
# lieu afin que le joueur clique/tape directement sur ce nom.

const SANCTUARY_LOCATION_NAMES: Array[String] = [
    "GUILDE",
    "COMPAGNIE",
    "CHAPELLE",
    "INFIRMERIE",
    "TAVERNE",
    "MARCHÉ NOIR",
    "LA PORTE",
    "MÉMORIAL",
    "BESTIAIRE",
    "COMMUNAUTÉ",
    "CONCORDE",
    "HALL DES DESCENDANTS",
]

func show_combat() -> void:
    VeilleursSkillResolverRouter.refresh_specialized_passives(GameState.party, GameState.battle_enemies)
    super.show_combat()

func enemy_turn() -> void:
    await super.enemy_turn()
    VeilleursSkillResolverRouter.advance_specialized_round_states(GameState.party)
    VeilleursSkillResolverRouter.refresh_specialized_passives(GameState.party, GameState.battle_enemies)
    if GameState.current_screen == "combat":
        battle_locked = false
        show_screen("combat")

func show_sanctuary() -> void:
    super.show_sanctuary()
    _apply_sanctuary_location_hotspots()

func _postprocess_mobile_screen() -> void:
    super._postprocess_mobile_screen()
    if GameState.current_screen == "sanctuary":
        _apply_sanctuary_location_hotspots()

func _apply_sanctuary_location_hotspots() -> void:
    if not is_instance_valid(content):
        return

    for node_value in content.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button == null:
            continue

        if button.has_meta("litd_location_hotspot"):
            _make_location_button_invisible(button)
            continue

        var original_text := button.text.strip_edges()
        if original_text == "":
            continue
        var lines := original_text.split("\n", false)
        if lines.is_empty():
            continue
        var location_name := str(lines[0]).strip_edges()
        if not SANCTUARY_LOCATION_NAMES.has(location_name):
            continue

        var description_parts: Array[String] = []
        for line_index in range(1, lines.size()):
            var description_line := str(lines[line_index]).strip_edges()
            if description_line != "":
                description_parts.append(description_line)

        button.set_meta("litd_location_hotspot", true)
        button.set_meta("litd_location_name", location_name)
        button.set_meta("litd_location_original_text", original_text)

        # Les libellés de lieux sont déjà intégrés au décor. On remonte la zone
        # tactile sur le nom visible au lieu de laisser le bouton sous celui-ci.
        button.position.y = maxf(0.0, button.position.y - 26.0)
        button.text = location_name
        if not description_parts.is_empty():
            button.tooltip_text = "%s — %s" % [location_name, " · ".join(description_parts)]
        else:
            button.tooltip_text = location_name
        _make_location_button_invisible(button)

func _make_location_button_invisible(button: Button) -> void:
    # On conserve la taille du Control : elle sert de cible tactile confortable
    # sur mobile, mais aucun rectangle ni texte dupliqué n'est dessiné.
    button.flat = true
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var empty_style := StyleBoxEmpty.new()
    button.add_theme_stylebox_override("normal", empty_style)
    button.add_theme_stylebox_override("hover", empty_style)
    button.add_theme_stylebox_override("pressed", empty_style)
    button.add_theme_stylebox_override("focus", empty_style)
    button.add_theme_stylebox_override("disabled", empty_style)
    var invisible := Color(1.0, 1.0, 1.0, 0.0)
    button.add_theme_color_override("font_color", invisible)
    button.add_theme_color_override("font_hover_color", invisible)
    button.add_theme_color_override("font_pressed_color", invisible)
    button.add_theme_color_override("font_focus_color", invisible)
    button.add_theme_color_override("font_disabled_color", invisible)
