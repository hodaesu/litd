extends CanvasLayer

# Le HUD général est invisible par défaut. Un écran doit être explicitement
# déclaré comme utile pour afficher les ressources globales.
const HUD_VISIBLE_SCREENS := {
    "combat": true,
    "market": true,
    "campfire": true
}

const HEADER_HEIGHT := 64.0

var _header: Control
var _main_content: Control

func _ready() -> void:
    layer = 40
    GameState.screen_requested.connect(_on_screen_requested)
    get_tree().node_added.connect(_on_tree_node_added)
    call_deferred("_apply_current_context")

func _on_screen_requested(screen_name: String) -> void:
    call_deferred("_apply_context", screen_name)

func _on_tree_node_added(node: Node) -> void:
    # Les autoloads sont prêts avant la scène principale. Au lieu de boucler
    # tant que le Header n'existe pas, on réessaie uniquement lorsqu'il apparaît.
    if node.name == "Header":
        _header = node as Control
        _main_content = null
        call_deferred("_apply_current_context")

func _apply_current_context() -> void:
    _apply_context(GameState.current_screen)

func hud_is_useful(screen_name: String) -> bool:
    return bool(HUD_VISIBLE_SCREENS.get(screen_name, false))

func _resolve_main_ui() -> bool:
    if is_instance_valid(_header) and is_instance_valid(_main_content):
        return true
    _header = get_tree().root.find_child("Header", true, false) as Control
    if not is_instance_valid(_header):
        return false
    var parent := _header.get_parent()
    if parent == null:
        return false
    # Dans l'UI principale, le contenu est le Control plein écran frère du Header.
    # On évite le fond ColorRect et les conteneurs du header lui-même.
    for child in parent.get_children():
        if child == _header:
            continue
        if child is Control and not (child is ColorRect) and not (child is Container):
            var candidate := child as Control
            if candidate.anchor_right == 1.0 and candidate.anchor_bottom == 1.0:
                _main_content = candidate
                break
    return is_instance_valid(_main_content)

func _apply_context(screen_name: String) -> void:
    if not _resolve_main_ui():
        return
    var visible := hud_is_useful(screen_name)
    _header.visible = visible
    # Quand le HUD disparaît, le décor reprend réellement tout l'écran :
    # aucune bande vide n'est conservée dans le hub ou l'exploration.
    _main_content.offset_top = HEADER_HEIGHT if visible else 0.0

func show_temporarily() -> void:
    # Hook prévu pour une interaction contextuelle ponctuelle sans changer d'écran.
    if _resolve_main_ui():
        _header.visible = true
        _main_content.offset_top = HEADER_HEIGHT

func restore_context() -> void:
    _apply_context(GameState.current_screen)
