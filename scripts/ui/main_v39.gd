extends "res://scripts/ui/main_v38.gd"

# v39 — compatibilité des libellés canoniques du Sanctuaire.
# Les noms restent directement cliquables et sans rectangle grâce à v38,
# mais leur texte original est conservé pour les sélecteurs runtime et QA.

func _display_location_name(value: String) -> String:
    return value
