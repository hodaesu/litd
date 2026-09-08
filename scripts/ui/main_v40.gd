extends "res://scripts/ui/main_v39.gd"

# v40 — finition UX canonique avant la passe artistique définitive.
# Cette couche ne change aucune règle de jeu : elle améliore la lisibilité,
# les retours tactiles/souris, l'aide contextuelle et les états rares.

const UX_GLOW_CLEAR := Color(1.0, 0.941, 0.761, 0.0)
const UX_GLOW_HOVER := Color(1.0, 0.941, 0.761, 0.82)
const UX_GLOW_PRESSED := Color(1.0, 0.941, 0.761, 1.0)
const UX_OUTLINE_CLEAR := Color(0.85, 0.71, 0.43, 0.0)
const UX_OUTLINE_HOVER := Color(0.85, 0.71, 0.43, 0.58)
const UX_LINE_CLEAR := Color(0.85, 0.71, 0.43, 0.0)
const UX_LINE_HOVER := Color(0.85, 0.71, 0.43, 0.72)
const UX_LINE_PRESSED := Color(1.0, 0.84, 0.50, 0.96)

const UX_CANONICAL_SURFACES: Array[String] = [
    "navigation",
    "hero_profile",
    "hud_reference",
    "contextual",
    "results_options",
    "options",
]

var _context_origin := "sanctuary"

func show_screen(name: String) -> void:
    var previous_screen := str(GameState.current_screen)
    if name == "contextual" and previous_screen != "" and previous_screen != "contextual":
        _context_origin = previous_screen
    super.show_screen(name)
    if name != "title":
        call_deferred("_apply_canonical_ux_polish")

func _postprocess_mobile_screen() -> void:
    super._postprocess_mobile_screen()
    if GameState.current_screen == "sanctuary":
        _install_sanctuary_location_feedback()
    call_deferred("_apply_canonical_ux_polish")

# -----------------------------------------------------------------------------
# HUB — le bouton technique reste totalement invisible. Un calque de feedback
# transparent est posé exactement dans sa zone : au survol/focus/tap, seul le
# nom intégré au décor reçoit un éclat et un trait fin. Aucun rectangle.
# -----------------------------------------------------------------------------

func _restore_sanctuary_clickable_names() -> void:
    super._restore_sanctuary_clickable_names()
    _install_sanctuary_location_feedback()

func _install_sanctuary_location_feedback() -> void:
    if not is_instance_valid(content):
        return
    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.has_meta("litd_location_hotspot"):
            continue
        button.focus_mode = Control.FOCUS_ALL
        button.custom_minimum_size = Vector2(
            maxf(button.custom_minimum_size.x, CANON_MIN_TOUCH.x),
            maxf(button.custom_minimum_size.y, CANON_MIN_TOUCH.y)
        )
        if button.get_node_or_null("CanonicalLocationFeedback") == null:
            _create_location_feedback(button)
        if not bool(button.get_meta("litd_feedback_connected", false)):
            button.set_meta("litd_feedback_connected", true)
            button.mouse_entered.connect(func(): _set_location_feedback(button, 1))
            button.mouse_exited.connect(func(): _set_location_feedback(button, 0))
            button.focus_entered.connect(func(): _set_location_feedback(button, 1))
            button.focus_exited.connect(func(): _set_location_feedback(button, 0))
            button.button_down.connect(func(): _set_location_feedback(button, 2))
            button.button_up.connect(func(): _set_location_feedback(button, 0))

func _create_location_feedback(button: Button) -> void:
    var overlay := Control.new()
    overlay.name = "CanonicalLocationFeedback"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    button.add_child(overlay)

    var glow := Label.new()
    glow.name = "Glow"
    glow.text = str(button.get_meta("litd_location_name", button.text)).strip_edges()
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    glow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    glow.add_theme_font_size_override("font_size", 18)
    glow.add_theme_constant_override("outline_size", 4)
    glow.add_theme_color_override("font_color", UX_GLOW_CLEAR)
    glow.add_theme_color_override("font_outline_color", UX_OUTLINE_CLEAR)
    overlay.add_child(glow)

    var underline := ColorRect.new()
    underline.name = "Underline"
    underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    underline.color = UX_LINE_CLEAR
    underline.anchor_left = 0.20
    underline.anchor_right = 0.80
    underline.anchor_top = 1.0
    underline.anchor_bottom = 1.0
    underline.offset_top = -4.0
    underline.offset_bottom = -2.0
    overlay.add_child(underline)

func _set_location_feedback(button: Button, state: int) -> void:
    if not is_instance_valid(button):
        return
    var overlay := button.get_node_or_null("CanonicalLocationFeedback") as Control
    if overlay == null:
        return
    var glow := overlay.get_node_or_null("Glow") as Label
    var underline := overlay.get_node_or_null("Underline") as ColorRect
    if glow == null or underline == null:
        return
    match state:
        2:
            glow.add_theme_color_override("font_color", UX_GLOW_PRESSED)
            glow.add_theme_color_override("font_outline_color", UX_OUTLINE_HOVER)
            underline.color = UX_LINE_PRESSED
        1:
            glow.add_theme_color_override("font_color", UX_GLOW_HOVER)
            glow.add_theme_color_override("font_outline_color", UX_OUTLINE_HOVER)
            underline.color = UX_LINE_HOVER
        _:
            glow.add_theme_color_override("font_color", UX_GLOW_CLEAR)
            glow.add_theme_color_override("font_outline_color", UX_OUTLINE_CLEAR)
            underline.color = UX_LINE_CLEAR

# -----------------------------------------------------------------------------
# TYPOGRAPHIE / COMPOSITION — hiérarchie commune aux nouveaux écrans, pensée
# pour rester lisible en paysage mobile sans simuler la future texture finale.
# -----------------------------------------------------------------------------

func _canonical_backdrop(title_text: String, subtitle: String) -> void:
    var bg := full_texture("res://assets/backgrounds/sanctuary.png")
    bg.modulate = Color(0.27, 0.27, 0.30, 1.0)
    content.add_child(bg)

    var shade := ColorRect.new()
    shade.color = Color(0.018, 0.019, 0.025, 0.965)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(shade)

    var eyebrow := make_label("LITD · LES VEILLEURS", 10, CANON_MUTED)
    eyebrow.position = Vector2(52, 16)
    eyebrow.size = Vector2(1160, 18)
    eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(eyebrow)

    var title := make_label(title_text, 30, CANON_GOLD)
    title.position = Vector2(52, 34)
    title.size = Vector2(1160, 40)
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title.add_theme_constant_override("outline_size", 2)
    title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
    content.add_child(title)

    var sub := make_label(subtitle, 14, CANON_MUTED)
    sub.position = Vector2(52, 76)
    sub.size = Vector2(1160, 30)
    sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(sub)

    var separator := ColorRect.new()
    separator.name = "CanonicalSectionRule"
    separator.position = Vector2(52, 108)
    separator.size = Vector2(1160, 1)
    separator.color = Color(0.85, 0.71, 0.43, 0.42)
    separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(separator)

func _add_nav_entry(parent: GridContainer, title_text: String, subtitle: String, target: String) -> void:
    var button := make_button("%s\n%s" % [title_text, subtitle], func(screen_name = target): GameState.request_screen(screen_name), Vector2(505, 76))
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_color_override("font_color", CANON_TEXT)
    button.add_theme_color_override("font_hover_color", CANON_HOVER)
    button.add_theme_color_override("font_pressed_color", CANON_GOLD)

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.035, 0.036, 0.046, 0.80)
    normal.border_color = Color(0.55, 0.42, 0.23, 0.42)
    normal.set_border_width_all(1)
    normal.corner_radius_top_left = 3
    normal.corner_radius_top_right = 3
    normal.corner_radius_bottom_left = 3
    normal.corner_radius_bottom_right = 3
    normal.content_margin_left = 16.0
    normal.content_margin_right = 14.0
    normal.content_margin_top = 8.0
    normal.content_margin_bottom = 8.0

    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.065, 0.058, 0.050, 0.90)
    hover.border_color = Color(0.85, 0.71, 0.43, 0.78)
    hover.set_border_width_all(1)
    hover.corner_radius_top_left = 3
    hover.corner_radius_top_right = 3
    hover.corner_radius_bottom_left = 3
    hover.corner_radius_bottom_right = 3
    hover.content_margin_left = 16.0
    hover.content_margin_right = 14.0
    hover.content_margin_top = 8.0
    hover.content_margin_bottom = 8.0

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_stylebox_override("pressed", hover)
    parent.add_child(button)

func _make_header_text_button(node_name: String, label: String, callback: Callable) -> Button:
    var button := super._make_header_text_button(node_name, label, callback)
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_constant_override("outline_size", 2)
    button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
    return button

# -----------------------------------------------------------------------------
# ÉTATS RARES — aucune impasse visuelle : une équipe vide, une absence de run
# ou un écran sans données donne une explication et une sortie claire.
# -----------------------------------------------------------------------------

func _show_hero_profile() -> void:
    if GameState.party.is_empty():
        _canonical_backdrop("FICHE HÉROS", "L'équipe active ne contient actuellement aucun héros jouable.")
        _show_recovery_state(
            "AUCUN HÉROS ACTIF",
            "La fiche ne peut rien afficher tant que l'équipe active est vide. Les héros humanoïdes comme les créatures recrutées utilisent cette même interface lorsqu'ils rejoignent l'équipe.",
            "OUVRIR LA COMPAGNIE",
            "company"
        )
        return
    super._show_hero_profile()

func _show_hud_reference() -> void:
    if GameState.party.is_empty():
        _canonical_backdrop("HUD DE COMBAT", "Le HUD reste volontairement vide tant qu'aucun héros n'est engagé.")
        _show_recovery_state(
            "AUCUNE ÉQUIPE À SYNTHÉTISER",
            "Constitue une équipe avant d'entrer en combat. Le HUD affichera ensuite l'état des héros réellement présents, quelle que soit leur morphologie.",
            "OUVRIR LA COMPAGNIE",
            "company"
        )
        return
    super._show_hud_reference()

func _show_recovery_state(title_text: String, body_text: String, action_text: String, target_screen: String) -> void:
    var panel := PanelContainer.new()
    panel.name = "CanonicalRecoveryState"
    panel.position = Vector2(220, 165)
    panel.size = Vector2(840, 310)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.036, 0.046, 0.90)
    style.border_color = Color(0.55, 0.42, 0.23, 0.62)
    style.set_border_width_all(1)
    style.content_margin_left = 28.0
    style.content_margin_right = 28.0
    style.content_margin_top = 24.0
    style.content_margin_bottom = 24.0
    panel.add_theme_stylebox_override("panel", style)
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 18)
    panel.add_child(box)
    box.add_child(make_label(title_text, 22, CANON_GOLD))
    var body := make_label(body_text, 16, CANON_TEXT)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.custom_minimum_size = Vector2(760, 90)
    box.add_child(body)
    box.add_child(make_button(action_text, func(): GameState.request_screen(target_screen), Vector2(300, 52)))

# -----------------------------------------------------------------------------
# AIDE CONTEXTUELLE — le bouton ? explique l'écran d'où vient le joueur au lieu
# d'afficher systématiquement un manuel générique.
# -----------------------------------------------------------------------------

func _show_contextual_screen() -> void:
    var origin := _context_origin if _context_origin != "" else "sanctuary"
    _canonical_backdrop("AIDE · %s" % _context_origin_title(origin), "Seulement les informations utiles à l'écran que tu viens de quitter.")

    var box := VBoxContainer.new()
    box.position = Vector2(130, 140)
    box.size = Vector2(1020, 390)
    box.add_theme_constant_override("separation", 16)
    content.add_child(box)

    var tip_index := 1
    for line_value in _contextual_lines(origin):
        var line := make_label("%02d  ·  %s" % [tip_index, line_value], 17, CANON_TEXT)
        line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        line.custom_minimum_size = Vector2(1000, 42)
        box.add_child(line)
        tip_index += 1

    var back := make_button("RETOUR", func(): GameState.request_screen(origin), Vector2(220, 52))
    back.position = Vector2(530, 570)
    content.add_child(back)

func _context_origin_title(origin: String) -> String:
    match origin:
        "sanctuary": return "HUB"
        "hero_profile", "company": return "HÉROS"
        "inventory_equipment", "guild_chest": return "INVENTAIRE"
        "skills": return "COMPÉTENCES"
        "bestiary", "creatures": return "BESTIAIRE"
        "combat", "hud_reference": return "COMBAT"
        "expedition", "exploration": return "EXPÉDITION"
        "results_options", "rewards", "options": return "RÉSULTATS / OPTIONS"
        "navigation": return "NAVIGATION"
        _: return origin.to_upper()

func _contextual_lines(origin: String) -> Array[String]:
    match origin:
        "sanctuary":
            return [
                "Touche directement le nom d'un lieu intégré au décor : aucun bouton rectangulaire n'est nécessaire.",
                "Un éclat discret confirme le survol, le focus clavier/manette ou l'appui tactile.",
                "Le menu donne accès aux autres familles d'interface sans modifier l'état du Refuge."
            ]
        "hero_profile", "company":
            return [
                "Sélectionne un héros pour lire son état, sa progression et ses traits.",
                "Les créatures recrutées sont traitées comme des héros jouables et utilisent une anatomie adaptée à leur morphologie.",
                "Une blessure ou une amputation persistante doit rester cohérente entre fiche, pose, équipement et compétences."
            ]
        "inventory_equipment", "guild_chest":
            return [
                "Le coffre commun reste la source de vérité pour les objets stockés au Refuge.",
                "L'équipement doit respecter la morphologie et l'état fonctionnel du héros sélectionné.",
                "Les changements visibles ici n'effacent jamais une blessure persistante."
            ]
        "skills":
            return [
                "Les arbres affichés utilisent la progression réelle du héros sélectionné.",
                "Une compétence incompatible avec un membre inutilisable ou absent doit être signalée comme telle.",
                "Les ultimes restent soumis à leurs règles de déblocage et d'utilisation existantes."
            ]
        "bestiary", "creatures":
            return [
                "Le Bestiaire reflète les connaissances réellement acquises pendant la campagne.",
                "Une créature recrutée conserve son identité, ses blessures et son historique après son intégration.",
                "Les boss restent gérés par leurs règles propres et ne sont pas convertis en héros via cet écran."
            ]
        "combat", "hud_reference":
            return [
                "Le HUD résume l'état sans remplacer les informations anatomiques et fonctionnelles détaillées.",
                "Les conséquences corporelles doivent rester lisibles dans la pose, les actions disponibles et les retours contextuels.",
                "Stabiliser une unité en agonie n'équivaut pas à la soigner."
            ]
        "expedition", "exploration":
            return [
                "La carte, la Lumière, le seed, la profondeur et l'extraction restent pilotés par le runtime d'expédition.",
                "Les états persistants des héros voyagent avec eux : aucune réinitialisation visuelle ou fonctionnelle au départ.",
                "Prépare l'équipe avant de valider une descente ; une équipe vide doit rester bloquante et explicite."
            ]
        "results_options", "rewards", "options":
            return [
                "Le bilan reprend l'état réel de la run ; en l'absence d'expédition, l'écran l'indique sans inventer de résultat.",
                "Les options d'accessibilité et audio sont appliquées par les gestionnaires existants.",
                "La taille des contrôles reste compatible avec les cibles tactiles mobiles."
            ]
        _:
            return [
                "Les informations affichées proviennent des systèmes actifs de la partie.",
                "Le menu permet de changer d'écran sans créer de règle parallèle.",
                "Utilise le retour pour reprendre exactement la famille d'interface précédente."
            ]

func _apply_canonical_ux_polish() -> void:
    if not is_instance_valid(content):
        return
    var current := str(GameState.current_screen)
    if not UX_CANONICAL_SURFACES.has(current):
        return
    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null:
            continue
        button.focus_mode = Control.FOCUS_ALL
        button.custom_minimum_size = Vector2(button.custom_minimum_size.x, maxf(button.custom_minimum_size.y, 48.0))
