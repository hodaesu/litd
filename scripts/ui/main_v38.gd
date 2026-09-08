extends "res://scripts/ui/main_v37.gd"

# v38 — Interface canonique LITD : Les Veilleurs.
# Cette couche garde tous les systèmes et écrans fonctionnels des versions
# précédentes, mais unifie leur accès et leur présentation pour le playtest.
# Priorités : noms de lieux directement cliquables, navigation centrale,
# fiche héros, inventaire/équipement, compétences, bestiaire, HUD de combat,
# informations contextuelles, expédition et résultats/options.

const CANON_GOLD := Color("#d8b56d")
const CANON_TEXT := Color("#eee5d6")
const CANON_MUTED := Color("#9e9382")
const CANON_HOVER := Color("#fff0c2")
const CANON_BG := Color(0.018, 0.019, 0.025, 0.96)
const CANON_PANEL := Color(0.035, 0.036, 0.046, 0.94)

func show_screen(name: String) -> void:
    match name:
        "navigation":
            _open_canonical_screen(name, _show_navigation)
        "hero_profile":
            _open_canonical_screen(name, _show_hero_profile)
        "inventory_equipment":
            GameState.current_screen = name
            clear_content()
            show_guild_chest()
            _install_header_controls()
        "skills":
            GameState.current_screen = name
            clear_content()
            show_hero_skills()
            _install_header_controls()
        "bestiary":
            GameState.current_screen = name
            clear_content()
            show_creatures()
            _install_header_controls()
        "hud_reference":
            _open_canonical_screen(name, _show_hud_reference)
        "contextual":
            _open_canonical_screen(name, _show_contextual_screen)
        "results_options":
            _open_canonical_screen(name, _show_results_options)
        "options":
            _open_canonical_screen(name, _show_results_options)
        _:
            super.show_screen(name)
            if name != "title":
                _install_header_controls()
            else:
                _remove_header_controls()

func _open_canonical_screen(screen_name: String, renderer: Callable) -> void:
    GameState.current_screen = screen_name
    clear_content()
    renderer.call()
    _install_header_controls()
    call_deferred("_postprocess_mobile_screen")

func _postprocess_mobile_screen() -> void:
    super._postprocess_mobile_screen()
    if GameState.current_screen == "sanctuary":
        _restore_sanctuary_clickable_names()
    if GameState.current_screen != "title":
        _install_header_controls()

# -----------------------------------------------------------------------------
# 1. HUB — conserver tous les lieux ajoutés par les couches précédentes, mais
# rendre le nom lui-même visible et cliquable, sans rectangle de bouton.
# -----------------------------------------------------------------------------

func show_sanctuary() -> void:
    super.show_sanctuary()
    _restore_sanctuary_clickable_names()

func _restore_sanctuary_clickable_names() -> void:
    if not is_instance_valid(content):
        return
    for node_value in content.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.has_meta("litd_location_hotspot"):
            continue
        var location_name := str(button.get_meta("litd_location_name", button.text)).strip_edges()
        button.text = _display_location_name(location_name)
        button.flat = true
        button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        button.add_theme_font_size_override("font_size", 18)
        var empty_style := StyleBoxEmpty.new()
        button.add_theme_stylebox_override("normal", empty_style)
        button.add_theme_stylebox_override("hover", empty_style)
        button.add_theme_stylebox_override("pressed", empty_style)
        button.add_theme_stylebox_override("focus", empty_style)
        button.add_theme_stylebox_override("disabled", empty_style)
        button.add_theme_color_override("font_color", CANON_GOLD)
        button.add_theme_color_override("font_hover_color", CANON_HOVER)
        button.add_theme_color_override("font_pressed_color", CANON_TEXT)
        button.add_theme_color_override("font_focus_color", CANON_HOVER)
        button.add_theme_color_override("font_disabled_color", CANON_MUTED)

func _display_location_name(value: String) -> String:
    match value:
        "GUILDE": return "Guilde"
        "COMPAGNIE": return "Compagnie"
        "CHAPELLE": return "Chapelle"
        "INFIRMERIE": return "Infirmerie"
        "TAVERNE": return "Taverne"
        "MARCHÉ NOIR": return "Marché noir"
        "LA PORTE": return "La Porte"
        "MÉMORIAL": return "Mémorial"
        "BESTIAIRE": return "Bestiaire"
        "COMMUNAUTÉ": return "Communauté"
        "CONCORDE": return "Concorde"
        "HALL DES DESCENDANTS": return "Hall des Descendants"
        _: return value

# -----------------------------------------------------------------------------
# 2. NAVIGATION — un accès unique aux dix familles d'interface du playtest.
# -----------------------------------------------------------------------------

func _install_header_controls() -> void:
    if not is_instance_valid(root):
        return
    var header := root.get_node_or_null("Header") as HBoxContainer
    if header == null:
        return
    if header.get_node_or_null("CanonicalMenu") == null:
        var menu := _make_header_text_button("CanonicalMenu", "MENU", func(): GameState.request_screen("navigation"))
        header.add_child(menu)
    if header.get_node_or_null("CanonicalContext") == null:
        var context := _make_header_text_button("CanonicalContext", "?", func(): GameState.request_screen("contextual"))
        context.custom_minimum_size = Vector2(42, 38)
        header.add_child(context)

func _remove_header_controls() -> void:
    if not is_instance_valid(root):
        return
    var header := root.get_node_or_null("Header")
    if header == null:
        return
    for node_name in ["CanonicalMenu", "CanonicalContext"]:
        var node := header.get_node_or_null(node_name)
        if node != null:
            node.queue_free()

func _make_header_text_button(node_name: String, label: String, callback: Callable) -> Button:
    var button := Button.new()
    button.name = node_name
    button.text = label
    button.flat = true
    button.custom_minimum_size = Vector2(92, 38)
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_color_override("font_color", CANON_GOLD)
    button.add_theme_color_override("font_hover_color", CANON_HOVER)
    button.add_theme_color_override("font_pressed_color", CANON_TEXT)
    button.pressed.connect(callback)
    return button

func _show_navigation() -> void:
    _canonical_backdrop("NAVIGATION", "Tous les écrans du playtest depuis un seul point, sans casser la boucle de jeu.")
    var grid := GridContainer.new()
    grid.columns = 2
    grid.position = Vector2(120, 128)
    grid.size = Vector2(1040, 430)
    grid.add_theme_constant_override("h_separation", 18)
    grid.add_theme_constant_override("v_separation", 14)
    content.add_child(grid)

    _add_nav_entry(grid, "01 · HUB", "Sanctuaire et lieux visitables", "sanctuary")
    _add_nav_entry(grid, "02 · NAVIGATION", "Cet écran central", "navigation")
    _add_nav_entry(grid, "03 · FICHE HÉROS", "État, rôle, traits et accès rapides", "hero_profile")
    _add_nav_entry(grid, "04 · INVENTAIRE / ÉQUIPEMENT", "Coffre commun et objets", "inventory_equipment")
    _add_nav_entry(grid, "05 · COMPÉTENCES", "Arbres et progression du héros sélectionné", "skills")
    _add_nav_entry(grid, "06 · BESTIAIRE", "Créatures capturées et connaissances", "bestiary")
    _add_nav_entry(grid, "07 · HUD", "Référence du HUD réellement injecté en combat", "hud_reference")
    _add_nav_entry(grid, "08 · CONTEXTUELS", "Aide et interactions liées à l'écran", "contextual")
    _add_nav_entry(grid, "09 · EXPÉDITION", "Préparation, carte, extraction", "expedition")
    _add_nav_entry(grid, "10 · RÉSULTATS / OPTIONS", "Bilan de run et réglages", "results_options")

func _add_nav_entry(parent: GridContainer, title_text: String, subtitle: String, target: String) -> void:
    var button := make_button("%s\n%s" % [title_text, subtitle], func(screen_name = target): GameState.request_screen(screen_name), Vector2(505, 68))
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    parent.add_child(button)

# -----------------------------------------------------------------------------
# 3. FICHE HÉROS
# -----------------------------------------------------------------------------

func _show_hero_profile() -> void:
    _canonical_backdrop("FICHE HÉROS", "Une lecture unique du corps, de l'état mental, du rôle et de la progression.")
    var hero := _selected_hero()
    if hero.is_empty():
        var empty := make_label("Aucun Veilleur disponible.", 18, CANON_MUTED)
        empty.position = Vector2(60, 130)
        content.add_child(empty)
        return

    var selector := HBoxContainer.new()
    selector.position = Vector2(52, 104)
    selector.size = Vector2(1170, 44)
    selector.add_theme_constant_override("separation", 10)
    content.add_child(selector)
    for hero_value: Variant in GameState.party:
        var candidate: Dictionary = hero_value
        var candidate_id := str(candidate.get("id", ""))
        var selected := candidate_id == str(hero.get("id", ""))
        var button := make_button(("◆ " if selected else "") + str(candidate.get("name", "Veilleur")), func(id_value = candidate_id):
            selected_hero_id = id_value
            show_screen("hero_profile"), Vector2(210, 40))
        button.disabled = selected
        selector.add_child(button)

    var art := TextureRect.new()
    art.texture = load(hero_art(hero))
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.position = Vector2(52, 170)
    art.size = Vector2(360, 390)
    content.add_child(art)

    var cls: Dictionary = DataLoader.find_by_id(DataLoader.classes, hero.get("class_id", ""))
    var details := VBoxContainer.new()
    details.position = Vector2(448, 170)
    details.size = Vector2(760, 380)
    details.add_theme_constant_override("separation", 11)
    content.add_child(details)
    details.add_child(make_label("%s · NIVEAU %d" % [str(hero.get("name", "Veilleur")), int(hero.get("level", 1))], 29, CANON_GOLD))
    details.add_child(make_label("%s — %s" % [str(cls.get("name", hero.get("class_id", ""))), str(cls.get("role", ""))], 16, CANON_MUTED))
    details.add_child(make_label("PV %d / %d     PEUR %d     FOLIE %d     ESPOIR %d" % [
        int(hero.get("hp", 0)), int(hero.get("max_hp", 0)), int(hero.get("fear", 0)), int(hero.get("madness", 0)), int(hero.get("hope", 0))
    ], 18, CANON_TEXT))
    details.add_child(make_label("Points de compétence : %d" % int(hero.get("skill_points", 0)), 16, CANON_TEXT))
    var trait_names: Dictionary = CharacterTraitDirector.trait_names(hero)
    details.add_child(make_label("TRAITS POSITIFS\n%s" % (", ".join(trait_names.get("positive", [])) if not (trait_names.get("positive", []) as Array).is_empty() else "Aucun"), 14, CANON_TEXT))
    details.add_child(make_label("TRAITS NÉGATIFS\n%s" % (", ".join(trait_names.get("negative", [])) if not (trait_names.get("negative", []) as Array).is_empty() else "Aucun"), 14, CANON_MUTED))

    var actions := HBoxContainer.new()
    actions.position = Vector2(448, 566)
    actions.size = Vector2(760, 54)
    actions.add_theme_constant_override("separation", 12)
    content.add_child(actions)
    actions.add_child(make_button("COMPÉTENCES", func(): GameState.request_screen("skills"), Vector2(220, 48)))
    actions.add_child(make_button("INVENTAIRE", func(): GameState.request_screen("inventory_equipment"), Vector2(220, 48)))
    actions.add_child(make_button("GUILDE", func(): GameState.request_screen("company"), Vector2(220, 48)))

func _selected_hero() -> Dictionary:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == selected_hero_id:
            return hero
    if not GameState.party.is_empty():
        var first: Dictionary = GameState.party[0]
        selected_hero_id = str(first.get("id", ""))
        return first
    return {}

func show_company() -> void:
    super.show_company()
    var profile := make_button("FICHE DU HÉROS", func(): GameState.request_screen("hero_profile"), Vector2(220, 48))
    profile.position = Vector2(870, 630)
    content.add_child(profile)

# -----------------------------------------------------------------------------
# 4–6. INVENTAIRE / COMPÉTENCES / BESTIAIRE — conserver les interactions déjà
# fonctionnelles, avec un marquage canonique et l'accès par le menu central.
# -----------------------------------------------------------------------------

func show_guild_chest() -> void:
    super.show_guild_chest()
    _add_screen_kicker("INVENTAIRE & ÉQUIPEMENT")

func show_hero_skills() -> void:
    super.show_hero_skills()
    _add_screen_kicker("COMPÉTENCES")

func show_creatures() -> void:
    super.show_creatures()
    _add_screen_kicker("BESTIAIRE")

func _add_screen_kicker(text_value: String) -> void:
    var label := make_label(text_value, 11, CANON_GOLD)
    label.position = Vector2(1050, 8)
    label.size = Vector2(190, 22)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(label)

# -----------------------------------------------------------------------------
# 7. HUD — couche réellement ajoutée au combat, plus un écran de référence.
# -----------------------------------------------------------------------------

func show_combat() -> void:
    super.show_combat()
    _install_canonical_combat_hud()

func _install_canonical_combat_hud() -> void:
    if not is_instance_valid(content):
        return
    var old := content.get_node_or_null("CanonicalCombatHUD")
    if old != null:
        old.queue_free()
    var panel := PanelContainer.new()
    panel.name = "CanonicalCombatHUD"
    panel.position = Vector2(900, 8)
    panel.size = Vector2(350, 112)
    panel.z_index = 20
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.01, 0.01, 0.014, 0.78)
    style.border_color = Color(0.55, 0.42, 0.23, 0.75)
    style.set_border_width_all(1)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", style)
    content.add_child(panel)
    var lines: Array[String] = ["VEILLEURS · ÉTAT DE COMBAT"]
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        lines.append("%s  PV %d/%d  Peur %d  Folie %d" % [
            str(hero.get("name", "Veilleur")), int(hero.get("hp", 0)), int(hero.get("max_hp", 0)), int(hero.get("fear", 0)), int(hero.get("madness", 0))
        ])
    var label := make_label("\n".join(lines), 11, CANON_TEXT)
    panel.add_child(label)

func _show_hud_reference() -> void:
    _canonical_backdrop("HUD DE COMBAT", "Cette même synthèse est injectée dans le vrai combat ; cet écran sert de référence hors combat.")
    var box := VBoxContainer.new()
    box.position = Vector2(180, 150)
    box.size = Vector2(920, 330)
    box.add_theme_constant_override("separation", 16)
    content.add_child(box)
    box.add_child(make_label("ÉTAT DE L'ÉQUIPE", 22, CANON_GOLD))
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        box.add_child(make_label("%s · PV %d/%d · Peur %d · Folie %d · Espoir %d" % [
            str(hero.get("name", "Veilleur")), int(hero.get("hp", 0)), int(hero.get("max_hp", 0)), int(hero.get("fear", 0)), int(hero.get("madness", 0)), int(hero.get("hope", 0))
        ], 16, CANON_TEXT))
    box.add_child(make_label("En combat, les actions, cibles, effets corporels et retours contextuels restent pilotés par les runtimes existants ; cette couche ne duplique pas leurs règles.", 14, CANON_MUTED))

# -----------------------------------------------------------------------------
# 8. INFORMATIONS CONTEXTUELLES
# -----------------------------------------------------------------------------

func _show_contextual_screen() -> void:
    _canonical_backdrop("INFORMATIONS CONTEXTUELLES", "Les indications dépendent de l'écran, sans ajouter de boutons parasites au décor.")
    var lines := [
        "HUB · touche directement le nom d'un lieu pour l'ouvrir.",
        "HÉROS · sélectionne un nom pour changer de fiche.",
        "INVENTAIRE · déposer/retirer agit sur le coffre commun existant.",
        "COMPÉTENCES · les choix utilisent le gestionnaire de compétences réel.",
        "BESTIAIRE · les créatures visibles proviennent des captures de la sauvegarde.",
        "COMBAT · le HUD synthétise PV, Peur et Folie sans remplacer les informations corporelles.",
        "EXPÉDITION · la carte, la Lumière, l'extraction et le seed restent ceux du runtime roguelike.",
        "MENU · ouvre cette navigation depuis tous les écrans hors titre."
    ]
    var text := make_label("\n\n".join(lines), 17, CANON_TEXT)
    text.position = Vector2(130, 135)
    text.size = Vector2(1020, 410)
    content.add_child(text)
    var back := make_button("RETOUR À LA NAVIGATION", func(): GameState.request_screen("navigation"), Vector2(300, 50))
    back.position = Vector2(490, 570)
    content.add_child(back)

# -----------------------------------------------------------------------------
# 9. EXPÉDITION — l'écran v24+ reste la source de vérité ; on le conserve et
# l'intègre à la navigation canonique.
# -----------------------------------------------------------------------------

func show_expedition() -> void:
    super.show_expedition()
    _add_screen_kicker("EXPÉDITION")

# -----------------------------------------------------------------------------
# 10. RÉSULTATS / OPTIONS — le vrai écran de récompenses reste branché sur la
# fin de combat ; cette page ajoute un bilan consultable et des réglages actifs.
# -----------------------------------------------------------------------------

func show_rewards() -> void:
    super.show_rewards()
    _add_screen_kicker("RÉSULTATS")

func _show_results_options() -> void:
    _canonical_backdrop("RÉSULTATS & OPTIONS", "Bilan de la run en cours et réglages appliqués immédiatement.")
    var columns := HBoxContainer.new()
    columns.position = Vector2(70, 125)
    columns.size = Vector2(1140, 445)
    columns.add_theme_constant_override("separation", 28)
    content.add_child(columns)

    var results := VBoxContainer.new()
    results.custom_minimum_size = Vector2(535, 420)
    results.add_theme_constant_override("separation", 12)
    columns.add_child(results)
    results.add_child(make_label("BILAN", 21, CANON_GOLD))
    results.add_child(make_label("Or : %d\nEssence : %d\nLumière : %d\nVivres : %d" % [GameState.gold, GameState.essence, GameState.light, GameState.supplies], 17, CANON_TEXT))
    if ExpeditionManager.expedition_active:
        var risk: Dictionary = ExpeditionManager.current_risk_profile()
        results.add_child(make_label("Expédition active\nProfondeur %d · Lumière %d · Inventaire %d/%d" % [
            int(risk.get("depth", 1)), int(risk.get("light", 0)), ExpeditionManager.inventory_slots_used(), ExpeditionManager.inventory_capacity()
        ], 15, CANON_TEXT))
    elif not roguelike_last_summary.is_empty():
        results.add_child(make_label("Dernier bilan enregistré\n%s" % _dictionary_summary(roguelike_last_summary), 14, CANON_MUTED))
    else:
        results.add_child(make_label("Aucune expédition active. Le véritable écran de résultats s'affiche automatiquement à la fin d'une rencontre ou d'une extraction.", 14, CANON_MUTED))

    var options := VBoxContainer.new()
    options.custom_minimum_size = Vector2(535, 420)
    options.add_theme_constant_override("separation", 10)
    columns.add_child(options)
    options.add_child(make_label("OPTIONS", 21, CANON_GOLD))
    options.add_child(_setting_button("SOUS-TITRES", GameSettings.subtitles, func(): GameSettings.set_subtitles(not GameSettings.subtitles)))
    options.add_child(_setting_button("SECOUSSES D'ÉCRAN", GameSettings.screen_shake, func(): GameSettings.set_screen_shake(not GameSettings.screen_shake)))
    options.add_child(_setting_button("CONTRASTE ÉLEVÉ", GameSettings.high_contrast, func(): GameSettings.set_high_contrast(not GameSettings.high_contrast)))
    options.add_child(_setting_button("RÉDUIRE LES FLASHES", GameSettings.reduce_flashes, func(): GameSettings.set_reduce_flashes(not GameSettings.reduce_flashes)))
    options.add_child(_setting_button("SORTIE MONO", GameSettings.mono_output, func(): GameSettings.set_mono_output(not GameSettings.mono_output)))

    var volume_row := HBoxContainer.new()
    volume_row.add_theme_constant_override("separation", 8)
    volume_row.add_child(make_label("VOLUME %.0f %%" % (GameSettings.master_volume * 100.0), 14, CANON_TEXT))
    volume_row.add_child(make_button("−", func(): GameSettings.set_master_volume(GameSettings.master_volume - 0.1); show_screen("results_options"), Vector2(52, 40)))
    volume_row.add_child(make_button("+", func(): GameSettings.set_master_volume(GameSettings.master_volume + 0.1); show_screen("results_options"), Vector2(52, 40)))
    options.add_child(volume_row)

    var text_row := HBoxContainer.new()
    text_row.add_theme_constant_override("separation", 8)
    text_row.add_child(make_label("TAILLE TEXTE ×%.1f" % GameSettings.text_scale, 14, CANON_TEXT))
    text_row.add_child(make_button("−", func(): GameSettings.set_text_scale(GameSettings.text_scale - 0.1); show_screen("results_options"), Vector2(52, 40)))
    text_row.add_child(make_button("+", func(): GameSettings.set_text_scale(GameSettings.text_scale + 0.1); show_screen("results_options"), Vector2(52, 40)))
    options.add_child(text_row)

func _setting_button(label_text: String, enabled: bool, callback: Callable) -> Button:
    return make_button("%s · %s" % [label_text, "OUI" if enabled else "NON"], func(): callback.call(); show_screen("results_options"), Vector2(500, 42))

func _dictionary_summary(data: Dictionary) -> String:
    var lines: Array[String] = []
    for key_value: Variant in data.keys():
        if lines.size() >= 8:
            break
        var value: Variant = data.get(key_value)
        if value is String or value is int or value is float or value is bool:
            lines.append("%s : %s" % [str(key_value), str(value)])
    return "\n".join(lines) if not lines.is_empty() else "Bilan disponible dans les données de la run."

# -----------------------------------------------------------------------------
# Fond commun aux nouveaux écrans canoniques.
# -----------------------------------------------------------------------------

func _canonical_backdrop(title_text: String, subtitle: String) -> void:
    var bg := full_texture("res://assets/backgrounds/sanctuary.png")
    bg.modulate = Color(0.30, 0.30, 0.34, 1.0)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = CANON_BG
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(shade)
    var title := make_label(title_text, 31, CANON_GOLD)
    title.position = Vector2(52, 28)
    title.size = Vector2(1160, 42)
    content.add_child(title)
    var sub := make_label(subtitle, 14, CANON_MUTED)
    sub.position = Vector2(52, 72)
    sub.size = Vector2(1160, 38)
    content.add_child(sub)
