extends "res://scripts/ui/main_v40.gd"

# v41 — couche de direction artistique canonique.
# Aucune règle de gameplay n'est modifiée ici. Cette couche expose les tokens,
# contrats d'écran, slots d'assets et contrats anatomiques afin que les assets
# définitifs puissent remplacer les placeholders progressivement et sans casse.
# Le gate juridique ajoute aussi un écran joueur Crédits & Licences, sans
# modifier les règles de gameplay.

var _canonical_art := CanonicalArtRegistry.new()

func show_screen(name: String) -> void:
    if name == "credits_licenses":
        _show_credits_licenses()
        call_deferred("_apply_v41_art_contract")
        return
    super.show_screen(name)
    call_deferred("_apply_v41_art_contract")

func _postprocess_mobile_screen() -> void:
    super._postprocess_mobile_screen()
    call_deferred("_apply_v41_art_contract")

func _apply_v41_art_contract() -> void:
    if not is_instance_valid(content):
        return
    var screen_name := str(GameState.current_screen)
    var contract := _canonical_art.screen_contract(screen_name)
    var asset_status := _canonical_art.screen_asset_status(screen_name)

    content.set_meta("litd_art_version", _canonical_art.version())
    content.set_meta("litd_art_screen", screen_name)
    content.set_meta("litd_art_screen_contract", contract)
    content.set_meta("litd_art_asset_status", asset_status)

    # Le contenu d'un écran est reconstruit à chaque navigation. Le marqueur de
    # contrat vit donc sous Main, et non dans content, afin de rester stable
    # pendant les remplacements d'écran et les audits automatisés.
    var marker := get_node_or_null("CanonicalArtContractV41")
    if marker == null:
        marker = Node.new()
        marker.name = "CanonicalArtContractV41"
        add_child(marker)
    marker.set_meta("screen", screen_name)
    marker.set_meta("contract", contract)
    marker.set_meta("asset_status", asset_status)

    _apply_v41_runtime_tokens()
    _install_credits_licenses_entry()

func _apply_v41_runtime_tokens() -> void:
    if not is_instance_valid(content):
        return
    var bronze := _art_color("worn_bronze", Color(0.66, 0.52, 0.29, 1.0))
    var pale_bronze := _art_color("pale_bronze", Color(0.83, 0.71, 0.46, 1.0))
    var text_color := _art_color("bone_text", Color(0.91, 0.87, 0.79, 1.0))
    var muted := _art_color("muted_text", Color(0.65, 0.62, 0.56, 1.0))

    var rule := content.find_child("CanonicalSectionRule", true, false) as ColorRect
    if rule != null:
        rule.color = Color(bronze.r, bronze.g, bronze.b, 0.42)

    for node_value in content.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label == null or not label.is_visible_in_tree():
            continue
        var size := label.get_theme_font_size("font_size")
        if size >= int(_canonical_art.token("typography", "title_px", 30)):
            label.add_theme_color_override("font_color", pale_bronze)
        elif label.modulate.a < 0.99:
            continue
        elif size <= int(_canonical_art.token("typography", "caption_px", 11)):
            label.add_theme_color_override("font_color", muted)
        elif not label.has_theme_color_override("font_color"):
            label.add_theme_color_override("font_color", text_color)

func _install_credits_licenses_entry() -> void:
    if not is_instance_valid(content):
        return
    if str(GameState.current_screen) not in ["options", "results_options"]:
        return
    if content.get_node_or_null("CreditsLicensesEntry") != null:
        return
    var button := Button.new()
    button.name = "CreditsLicensesEntry"
    button.text = "CRÉDITS & LICENCES"
    button.flat = true
    button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    button.offset_left = -285.0
    button.offset_top = -68.0
    button.offset_right = -28.0
    button.offset_bottom = -22.0
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_color_override("font_color", _art_color("pale_bronze", Color(0.83, 0.71, 0.46, 1.0)))
    button.add_theme_color_override("font_hover_color", _art_color("bone_text", Color(0.91, 0.87, 0.79, 1.0)))
    button.pressed.connect(func(): GameState.request_screen("credits_licenses"))
    content.add_child(button)

func _show_credits_licenses() -> void:
    GameState.current_screen = "credits_licenses"
    clear_content()
    _canonical_backdrop("CRÉDITS & LICENCES", "Licences du moteur et composants tiers embarqués dans cette version.")

    var scroll := ScrollContainer.new()
    scroll.name = "CreditsLicensesScroll"
    scroll.position = Vector2(58, 112)
    scroll.size = Vector2(1160, 500)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.add_child(scroll)

    var text := RichTextLabel.new()
    text.name = "CreditsLicensesText"
    text.bbcode_enabled = false
    text.fit_content = true
    text.custom_minimum_size = Vector2(1110, 500)
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_theme_font_size_override("normal_font_size", 14)
    text.add_theme_color_override("default_color", _art_color("bone_text", Color(0.91, 0.87, 0.79, 1.0)))
    text.text = _build_credits_license_text()
    scroll.add_child(text)

    var back := make_button("RETOUR AUX OPTIONS", func(): GameState.request_screen("options"), Vector2(240, 44))
    back.position = Vector2(58, 630)
    content.add_child(back)
    _install_header_controls()

func _build_credits_license_text() -> String:
    var blocks: Array[String] = []
    blocks.append("LITD : LES VEILLEURS\n\nCode et contenus originaux : droits réservés au titulaire du projet, sous réserve des éléments tiers listés ci-dessous.\n")
    blocks.append("GODOT ENGINE\n" + Engine.get_license_text())

    var copyrights: Array[Dictionary] = Engine.get_copyright_info()
    if not copyrights.is_empty():
        blocks.append("\n\nCOMPOSANTS TIERS EMBARQUÉS PAR GODOT")
        for entry: Dictionary in copyrights:
            var component_name := str(entry.get("name", "Composant tiers"))
            blocks.append("\n" + component_name)
            var parts: Array = entry.get("parts", [])
            for part_value: Variant in parts:
                var part: Dictionary = part_value
                var copyright_lines: Array = part.get("copyright", [])
                for copyright_value: Variant in copyright_lines:
                    blocks.append(str(copyright_value))
                var license_name := str(part.get("license", "")).strip_edges()
                if license_name != "":
                    blocks.append("Licence : " + license_name)

    var license_info: Dictionary = Engine.get_license_info()
    if not license_info.is_empty():
        blocks.append("\n\nTEXTES DES LICENCES TIERCES DU MOTEUR")
        var names: Array = license_info.keys()
        names.sort()
        for name_value: Variant in names:
            var license_name := str(name_value)
            blocks.append("\n--- " + license_name + " ---\n" + str(license_info.get(name_value, "")))

    blocks.append("\n\nRegistre projet : res://legal/THIRD_PARTY_NOTICES.txt")
    return "\n".join(blocks)

func apply_texture_slot(target: TextureRect, slot_id: String, bindings: Dictionary = {}) -> Dictionary:
    var resolved := _canonical_art.resolve_asset(slot_id, bindings)
    if target == null:
        return resolved
    target.set_meta("litd_art_slot", slot_id)
    target.set_meta("litd_art_resolution", resolved)
    var path := str(resolved.get("path", ""))
    if path == "":
        return resolved
    var resource: Resource = load(path)
    if resource is Texture2D:
        target.texture = resource as Texture2D
    return resolved

func art_contract_for_character(character: Dictionary, profile: Dictionary = {}) -> Dictionary:
    return _canonical_art.character_visual_contract(character, profile)

func art_contract_snapshot() -> Dictionary:
    var screen_name := str(GameState.current_screen)
    return {
        "version": _canonical_art.version(),
        "screen": screen_name,
        "screen_contract": _canonical_art.screen_contract(screen_name),
        "assets": _canonical_art.screen_asset_status(screen_name),
        "gameplay_untouched": true
    }

func _art_color(token_name: String, fallback: Color) -> Color:
    var value := str(_canonical_art.token("colors", token_name, ""))
    if value == "":
        return fallback
    return Color.from_string(value, fallback)
