extends Node

func _ready() -> void:
    GameState.screen_requested.connect(_on_screen_requested)

func _on_screen_requested(screen_name: String) -> void:
    if EndgameState.active_cycle < 1 or screen_name not in ["hero_skills", "creatures"]:
        return
    call_deferred("_refresh_labels")

func _refresh_labels() -> void:
    await get_tree().process_frame
    var scene := get_tree().current_scene
    if scene == null:
        return
    _rewrite_tree(scene)

func _rewrite_tree(node: Node) -> void:
    if node is Label:
        var label := node as Label
        var text := label.text
        if " — VERROUILLÉ" in text:
            text = text.replace(" — VERROUILLÉ", " — OUVERT NG+")
        if " — CHOISI" in text:
            text = text.replace(" — CHOISI", " — OUVERT NG+")
        if "Les boss ne peuvent jamais être capturés." in text:
            text = text.replace("Les boss ne peuvent jamais être capturés.", "En NG+, les mini-boss et boss peuvent aussi être recrutés.")
        label.text = text
    for child in node.get_children():
        _rewrite_tree(child)
