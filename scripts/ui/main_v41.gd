extends "res://scripts/ui/main_v40.gd"

# v41 — couche de direction artistique canonique.
# Aucune règle de gameplay n'est modifiée ici. Cette couche expose les tokens,
# contrats d'écran, slots d'assets et contrats anatomiques afin que les assets
# définitifs puissent remplacer les placeholders progressivement et sans casse.

var _canonical_art := CanonicalArtRegistry.new()

func show_screen(name: String) -> void:
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
