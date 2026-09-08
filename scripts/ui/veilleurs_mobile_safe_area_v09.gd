extends Node
class_name VeilleursMobileSafeAreaV09

# Safe-area et mise à l'échelle typographique de la verticale mobile v0.9.
# Le gameplay reste inchangé : cette couche ne fait que déplacer les surfaces
# interactives hors des encoches/indicateurs système et appliquer text_scale.

const BASE_MARGIN_LEFT := 12.0
const BASE_MARGIN_TOP := 8.0
const BASE_MARGIN_RIGHT := 12.0
const BASE_MARGIN_BOTTOM := 8.0
const BASE_FONT_SIZE := 16
const MIN_FONT_SIZE := 10
const META_BASE_FONT := "litd_mobile_base_font_size"

var qa: VeilleursVerticalSliceQAV09
var safe_root: VBoxContainer
var installed := false
var apply_scheduled := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_install")

func _install() -> void:
    qa = _root_qa()
    if qa == null:
        return
    safe_root = _find_safe_root()
    if safe_root == null:
        call_deferred("_install")
        return

    if not GameSettings.settings_changed.is_connected(_on_settings_changed):
        GameSettings.settings_changed.connect(_on_settings_changed)
    if not qa.resized.is_connected(_schedule_apply):
        qa.resized.connect(_schedule_apply)
    if not get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.connect(_on_node_added)

    installed = true
    _apply_all()

func _root_qa() -> VeilleursVerticalSliceQAV09:
    var node: Node = get_parent()
    while node != null:
        if node is VeilleursVerticalSliceQAV09:
            return node as VeilleursVerticalSliceQAV09
        node = node.get_parent()
    return null

func _find_safe_root() -> VBoxContainer:
    if qa == null:
        return null
    for child: Node in qa.get_children():
        if child is VBoxContainer:
            return child as VBoxContainer
    return null

func _on_settings_changed() -> void:
    _schedule_apply()

func _on_node_added(node: Node) -> void:
    if not installed or qa == null or node == null:
        return
    if not qa.is_ancestor_of(node):
        return
    if node is Label or node is Button:
        call_deferred("_apply_text_node", node)
    if node is CanvasLayer:
        _schedule_apply()

func _schedule_apply() -> void:
    if not installed or apply_scheduled:
        return
    apply_scheduled = true
    call_deferred("_apply_all")

func _apply_all() -> void:
    apply_scheduled = false
    if not installed or qa == null or safe_root == null:
        return

    var reference_size := qa.size
    if reference_size.x <= 0.0 or reference_size.y <= 0.0:
        reference_size = qa.get_viewport_rect().size
    var insets := _logical_safe_insets(reference_size)

    safe_root.offset_left = BASE_MARGIN_LEFT + insets.x
    safe_root.offset_top = BASE_MARGIN_TOP + insets.y
    safe_root.offset_right = -(BASE_MARGIN_RIGHT + insets.z)
    safe_root.offset_bottom = -(BASE_MARGIN_BOTTOM + insets.w)

    _apply_overlay_shell("SubmissionOverlay", insets)
    _apply_overlay_shell("MobileCombatPreviewLayer", insets)
    _apply_text_scale()

    qa.set_meta("litd_mobile_safe_area_ready", true)
    qa.set_meta("litd_mobile_safe_area_insets", insets)
    qa.set_meta("litd_mobile_text_scale", GameSettings.text_scale)

func _apply_overlay_shell(layer_name: String, insets: Vector4) -> void:
    if qa == null:
        return
    var layer := qa.find_child(layer_name, true, false) as CanvasLayer
    if layer == null:
        return
    var shell: Control = null
    for child: Node in layer.get_children():
        if child is Control:
            shell = child as Control
            break
    if shell == null:
        return
    shell.offset_left = insets.x
    shell.offset_top = insets.y
    shell.offset_right = -insets.z
    shell.offset_bottom = -insets.w

func _apply_text_scale() -> void:
    if qa == null:
        return
    for node_value: Node in qa.find_children("*", "Control", true, false):
        if node_value is Label or node_value is Button:
            _apply_text_node(node_value)

func _apply_text_node(node: Node) -> void:
    if not (node is Label or node is Button):
        return
    var control := node as Control
    var base_size := BASE_FONT_SIZE
    if control.has_meta(META_BASE_FONT):
        base_size = int(control.get_meta(META_BASE_FONT, BASE_FONT_SIZE))
    else:
        base_size = control.get_theme_font_size("font_size")
        if base_size <= 0:
            base_size = BASE_FONT_SIZE
        control.set_meta(META_BASE_FONT, base_size)
    var scaled_size := maxi(MIN_FONT_SIZE, int(round(float(base_size) * GameSettings.text_scale)))
    control.add_theme_font_size_override("font_size", scaled_size)

func _is_mobile_runtime() -> bool:
    # Les exports Web n'exposent pas le tag générique "mobile". Godot fournit
    # des tags dédiés afin qu'une PWA iPhone/Android suive le même contrat UX.
    return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")

func _logical_safe_insets(reference_size: Vector2) -> Vector4:
    # Sur PC/headless, aucun décalage n'est appliqué. Sur iOS/Android natif
    # comme en PWA mobile, on tente d'utiliser la safe area fournie par Godot.
    if not _is_mobile_runtime():
        return Vector4.ZERO
    if reference_size.x <= 0.0 or reference_size.y <= 0.0:
        return Vector4.ZERO

    var screen_size_i := DisplayServer.screen_get_size()
    var screen_position_i := DisplayServer.screen_get_position()
    var safe_i := DisplayServer.get_display_safe_area()
    if screen_size_i.x <= 0 or screen_size_i.y <= 0 or safe_i.size.x <= 0 or safe_i.size.y <= 0:
        return Vector4.ZERO

    var screen_size := Vector2(screen_size_i)
    var safe_position := Vector2(safe_i.position - screen_position_i)
    var safe_size := Vector2(safe_i.size)

    # window/stretch/aspect="keep" centre le viewport logique dans l'écran.
    # On intersecte d'abord la safe area native avec ce rectangle réellement
    # affiché, ce qui évite de doubler les marges lorsque l'encoche tombe déjà
    # dans une bande de letterboxing.
    var content_scale := minf(screen_size.x / reference_size.x, screen_size.y / reference_size.y)
    if content_scale <= 0.0:
        return Vector4.ZERO
    var content_size := reference_size * content_scale
    var content_origin := (screen_size - content_size) * 0.5
    var content_end := content_origin + content_size
    var safe_end := safe_position + safe_size

    var clipped_left := maxf(content_origin.x, safe_position.x)
    var clipped_top := maxf(content_origin.y, safe_position.y)
    var clipped_right := minf(content_end.x, safe_end.x)
    var clipped_bottom := minf(content_end.y, safe_end.y)
    if clipped_right <= clipped_left or clipped_bottom <= clipped_top:
        return Vector4.ZERO

    return Vector4(
        maxf(0.0, (clipped_left - content_origin.x) / content_scale),
        maxf(0.0, (clipped_top - content_origin.y) / content_scale),
        maxf(0.0, (content_end.x - clipped_right) / content_scale),
        maxf(0.0, (content_end.y - clipped_bottom) / content_scale)
    )
