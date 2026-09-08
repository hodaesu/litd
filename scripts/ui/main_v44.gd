extends "res://scripts/ui/main_v43.gd"

# v44 — économie du Sanctuaire réellement jouable depuis l'interface.
# Le Marché noir consomme VeilleursMarketService ; la Taverne consomme
# VeilleursHeroRecruitmentService. Les règles de prix/recrutement restent hors UI.

var _sanctuary_market_service := VeilleursMarketService.new()
var _sanctuary_recruitment_service := VeilleursHeroRecruitmentService.new()
var _market_offer_seed: int = 6101

func show_screen(name: String) -> void:
    if name == "tavern":
        GameState.current_screen = name
        clear_content()
        show_tavern()
        _install_header_controls()
        call_deferred("_postprocess_mobile_screen")
        return
    super.show_screen(name)

func show_market() -> void:
    var bg := full_texture("res://assets/backgrounds/forgotten_city.webp")
    bg.modulate = Color(0.38, 0.38, 0.42, 1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var title := make_label("MARCHÉ NOIR", 28, GOLD)
    title.position = Vector2(32, 18)
    content.add_child(title)
    var purse := make_label("OR · %d" % GameState.gold, 18, GOLD)
    purse.position = Vector2(1030, 22)
    purse.size = Vector2(190, 28)
    purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(purse)

    var columns := HBoxContainer.new()
    columns.position = Vector2(32, 66)
    columns.size = Vector2(1216, 540)
    columns.add_theme_constant_override("separation", 18)
    content.add_child(columns)

    var offers := VBoxContainer.new()
    offers.custom_minimum_size = Vector2(590, 0)
    offers.add_theme_constant_override("separation", 6)
    columns.add_child(offers)
    offers.add_child(make_label("OFFRES", 18, GOLD))
    for offer_value in _sanctuary_market_service.generate_offers(_market_offer_seed):
        var offer: Dictionary = offer_value
        var row := HBoxContainer.new()
        var label := make_label("%s · %s · %d or" % [str(offer.get("name", "Objet")), str(offer.get("rarity", "common")).to_upper(), int(offer.get("price", 0))], 13)
        label.custom_minimum_size = Vector2(400, 44)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(label)
        var buy := make_button("ACHETER", func(value = offer.duplicate(true)): _buy_market_offer(value), Vector2(150, 44))
        buy.disabled = GameState.gold < int(offer.get("price", 0))
        row.add_child(buy)
        offers.add_child(row)

    var sales_scroll := ScrollContainer.new()
    sales_scroll.custom_minimum_size = Vector2(590, 500)
    columns.add_child(sales_scroll)
    var sales := VBoxContainer.new()
    sales.custom_minimum_size = Vector2(560, 0)
    sales.add_theme_constant_override("separation", 6)
    sales_scroll.add_child(sales)
    sales.add_child(make_label("VENDRE · INVENTAIRE ET COFFRE", 18, GOLD))
    var sale_items: Array = EquipmentManager.items.duplicate(true)
    sale_items.append_array(EquipmentManager.guild_stash.duplicate(true))
    if sale_items.is_empty():
        sales.add_child(make_label("Aucun objet vendable.", 14, MUTED))
    for item_value in sale_items:
        var item: Dictionary = item_value
        var instance_id := str(item.get("instance_id", ""))
        var price := _sanctuary_market_service.quote_item(item, false)
        var row := HBoxContainer.new()
        var label := make_label("%s · %d or" % [str(item.get("name", "Objet")), price], 13)
        label.custom_minimum_size = Vector2(390, 44)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(label)
        row.add_child(make_button("VENDRE", func(id_value = instance_id): _sell_market_item(str(id_value)), Vector2(150, 44)))
        sales.add_child(row)

    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(280, 48))
    back.position = Vector2(32, 625)
    content.add_child(back)

func _buy_market_offer(offer: Dictionary) -> void:
    var result := _sanctuary_market_service.buy_offer(offer, "sanctuary_market_%d" % _market_offer_seed)
    if bool(result.get("ok", false)):
        _market_offer_seed += 1
    else:
        GameState.add_log("Marché noir : achat impossible (%s)." % str(result.get("reason", "erreur")))
    show_screen("market")

func _sell_market_item(instance_id: String) -> void:
    var result := _sanctuary_market_service.sell(instance_id)
    if not bool(result.get("ok", false)):
        GameState.add_log("Marché noir : vente impossible (%s)." % str(result.get("reason", "erreur")))
    show_screen("market")

func show_company() -> void:
    super.show_company()
    var tavern := make_button("TAVERNE DES VEILLEURS", func(): GameState.request_screen("tavern"), Vector2(250, 48))
    tavern.position = Vector2(995, 630)
    content.add_child(tavern)

func show_tavern() -> void:
    var bg := full_texture("res://assets/backgrounds/forgotten_city.webp")
    bg.modulate = Color(0.34, 0.31, 0.30, 1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var title := make_label("TAVERNE DES VEILLEURS", 28, GOLD)
    title.position = Vector2(32, 18)
    content.add_child(title)
    var purse := make_label("OR · %d" % GameState.gold, 18, GOLD)
    purse.position = Vector2(1030, 22)
    purse.size = Vector2(190, 28)
    purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(purse)

    var dead_ids := _sanctuary_recruitment_service.dead_hero_ids()
    var list := VBoxContainer.new()
    list.position = Vector2(42, 78)
    list.size = Vector2(1180, 510)
    list.add_theme_constant_override("separation", 12)
    content.add_child(list)

    if dead_ids.is_empty():
        list.add_child(make_label("Aucun poste de Veilleur n'est vacant. La Taverne ne remplace que les morts permanentes.", 18, MUTED))
    else:
        for dead_id_value in dead_ids:
            var dead_id := str(dead_id_value)
            var fallen := _hero_by_id(dead_id)
            list.add_child(make_label("POSTE VACANT · %s · %s" % [str(fallen.get("name", "Veilleur tombé")), str(fallen.get("class_id", "classe"))], 18, GOLD))
            var seed_value := abs((dead_id + ":" + str(fallen.get("recruit_generation", 0))).hash())
            for candidate_value in _sanctuary_recruitment_service.generate_replacement_candidates(dead_id, seed_value):
                var wrapper: Dictionary = candidate_value
                var candidate: Dictionary = wrapper.get("candidate", {})
                var row := HBoxContainer.new()
                var label := make_label("%s · niveau %d · %d or" % [str(wrapper.get("name", "Recrue")), int(wrapper.get("level", 1)), int(wrapper.get("cost", 0))], 14)
                label.custom_minimum_size = Vector2(850, 48)
                label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_child(label)
                var recruit := make_button("RECRUTER", func(target_id = dead_id, recruit_value = candidate.duplicate(true)): _recruit_replacement(str(target_id), recruit_value), Vector2(190, 46))
                recruit.disabled = GameState.gold < int(wrapper.get("cost", 0))
                row.add_child(recruit)
                list.add_child(row)

    var back := make_button("RETOUR À LA COMPAGNIE", func(): GameState.request_screen("company"), Vector2(280, 48))
    back.position = Vector2(32, 625)
    content.add_child(back)

func _recruit_replacement(dead_hero_id: String, candidate: Dictionary) -> void:
    var result := _sanctuary_recruitment_service.replace_dead(dead_hero_id, candidate)
    if not bool(result.get("ok", false)):
        GameState.add_log("Taverne : recrutement impossible (%s)." % str(result.get("reason", "erreur")))
    show_screen("tavern")

func _hero_by_id(hero_id: String) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}
