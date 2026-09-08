extends "res://scripts/ui/main_v38.gd"

# v39 — compatibilité des hotspots du Sanctuaire.
# Le texte technique complet du bouton est restauré pour les sélecteurs runtime
# et QA, mais il reste invisible : le décor porte le nom visible du lieu et le
# Control transparent reste uniquement sa zone tactile. Aucun rectangle n'est
# réintroduit autour ou sous les noms de lieux.

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

func _display_location_name(value: String) -> String:
    return value
