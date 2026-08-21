extends "res://scripts/ui/main_v28.gd"

# v29 : exploration spatiale affinée. Les points d'intérêt peuvent être ciblés
# depuis la salle 3D ; E/Entrée ouvre directement l'interaction correspondante.
var proxy_interaction_prompt: Label = null

func show_dungeon_proxy() -> void:
    super.show_dungeon_proxy()
    if proxy_room_instance == null:
        return
    if proxy_room_instance.has_signal("interaction_focus_changed"):
        proxy_room_instance.connect("interaction_focus_changed", Callable(self, "_on_proxy_interaction_focus_changed"))
    if proxy_room_instance.has_signal("interaction_requested"):
        proxy_room_instance.connect("interaction_requested", Callable(self, "_on_proxy_interaction_requested"))

    proxy_interaction_prompt = make_label("Approche-toi d'un point d'intérêt pour interagir.", 13, MUTED)
    proxy_interaction_prompt.position = Vector2(390, 620)
    proxy_interaction_prompt.size = Vector2(520, 34)
    content.add_child(proxy_interaction_prompt)

    var controls_extra := make_label("Interaction : E / Entrée", 11, MUTED)
    controls_extra.position = Vector2(790, 50)
    controls_extra.size = Vector2(250, 24)
    content.add_child(controls_extra)

func _on_proxy_interaction_focus_changed(interaction_id: String, label: String) -> void:
    if proxy_interaction_prompt == null or not is_instance_valid(proxy_interaction_prompt):
        return
    if interaction_id == "":
        proxy_interaction_prompt.text = "Approche-toi d'un point d'intérêt pour interagir."
        proxy_interaction_prompt.modulate = MUTED
        return
    proxy_interaction_prompt.text = "E — %s" % label
    proxy_interaction_prompt.modulate = GOLD

func _on_proxy_interaction_requested(interaction_id: String, label: String) -> void:
    if interaction_id == "":
        return
    GameState.add_log("Interaction spatiale : %s." % label)
    GameState.request_screen("dungeon_room")
