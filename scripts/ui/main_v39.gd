extends "res://scripts/ui/main_v38.gd"

# v39 — compatibilité des hotspots du Sanctuaire et garde-fous tactiles.
# Le texte technique complet du bouton est restauré pour les sélecteurs runtime
# et QA, mais il reste invisible : le décor porte le nom visible du lieu et le
# Control transparent reste uniquement sa zone tactile. Aucun rectangle n'est
# réintroduit autour ou sous les noms de lieux.

const CANON_MIN_TOUCH := Vector2(96.0, 48.0)

func _restore_sanctuary_clickable_names() -> void:
    if not is_instance_valid(content):
        return
    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.has_meta("litd_location_hotspot"):
            continue
        var original_text := str(button.get_meta("litd_location_original_text", button.text)).strip_edges()
        if original_text != "":
            button.text = original_text
        _make_location_button_invisible(button)

func _install_header_controls() -> void:
    if not is_instance_valid(root):
        return
    var header := root.get_node_or_null("Header") as HBoxContainer
    if header == null:
        return
    if header.get_node_or_null("CanonicalMenu") == null:
        var menu := _make_header_text_button("CanonicalMenu", "MENU", func(): GameState.request_screen("navigation"))
        menu.custom_minimum_size = Vector2(110.0, CANON_MIN_TOUCH.y)
        header.add_child(menu)
    if header.get_node_or_null("CanonicalContext") == null:
        var context := _make_header_text_button("CanonicalContext", "?", func(): GameState.request_screen("contextual"))
        context.custom_minimum_size = CANON_MIN_TOUCH
        header.add_child(context)

func _display_location_name(value: String) -> String:
    return value
