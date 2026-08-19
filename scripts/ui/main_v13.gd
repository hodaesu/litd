extends "res://scripts/ui/main_v12.gd"

# v13 : rend l'Infirmerie du Sanctuaire réellement utilisable pour la convalescence des créatures liées.

func show_screen(name: String) -> void:
    if name == "infirmary":
        GameState.current_screen = name
        clear_content()
        show_infirmary()
        return
    super.show_screen(name)

func show_sanctuary() -> void:
    super.show_sanctuary()
    var infirmary := make_button("INFIRMERIE\nSoins et blessures", func(): GameState.request_screen("infirmary"), Vector2(230, 70))
    infirmary.position = Vector2(790, 135)
    infirmary.modulate = Color(1, 1, 1, 0.96)
    content.add_child(infirmary)

func show_expedition() -> void:
    var bg := full_texture("res://assets/backgrounds/crypts.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.58)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var chapter := CampaignState.current_chapter()
    var chapter_number := CampaignState.current_chapter_number()
    var chapter_title := str(chapter.get("title", "Terre des Cendres"))
    var active_quests := CampaignState.active_main_quests()
    var quest_lines: Array[String] = []
    for quest_value in active_quests:
        var quest: Dictionary = quest_value
        quest_lines.append("• %s" % str(quest.get("title", quest.get("id", "Objectif"))))
    if quest_lines.is_empty():
        quest_lines.append("• Poursuivre l'objectif du chapitre en cours.")

    var box := VBoxContainer.new()
    box.position = Vector2(90, 62)
    box.size = Vector2(650, 565)
    box.add_theme_constant_override("separation", 12)
    content.add_child(box)
    box.add_child(make_label("EXPÉDITION — CHAPITRE %d" % chapter_number, 26, GOLD))
    box.add_child(make_label(chapter_title, 31, TEXT))
    box.add_child(make_label("Compagnie : %d héros\nVivres : %d\nLumière : %d" % [GameState.party.size(), GameState.supplies, GameState.light], 18, MUTED))
    box.add_child(make_label("OBJECTIFS ACTIFS\n%s" % "\n".join(quest_lines), 16))
    box.add_child(make_label("La Porte ouvre désormais la véritable expédition du chapitre courant. Le retour au Sanctuaire reste possible depuis le menu contextuel d'exploration.", 14, MUTED))
    box.add_child(make_button("LANCER L'EXPÉDITION", func(): _launch_current_campaign_expedition(), Vector2(520, 60)))
    box.add_child(make_button("RETOUR", func(): GameState.request_screen("sanctuary"), Vector2(520, 52)))

func _launch_current_campaign_expedition() -> void:
    var chapter_id := CampaignState.current_chapter_id
    GameState.current_screen = "exploration"
    var started := false
    match chapter_id:
        "chapter_01_ashlands": started = AshlandsSceneRouter.start_ashlands()
        "chapter_02_before_fall": started = AshlandsSceneRouter.start_chapter_02()
        "chapter_03_threshold": started = AshlandsSceneRouter.start_chapter_03()
        "chapter_04_first_rupture": started = AshlandsSceneRouter.start_chapter_04()
        "chapter_05_great_closure": started = AshlandsSceneRouter.start_chapter_05()
        "chapter_06_absent": started = AshlandsSceneRouter.start_chapter_06()
        "chapter_07_living_responsible": started = AshlandsSceneRouter.start_chapter_07()
        "chapter_08_outer_world": started = AshlandsSceneRouter.start_chapter_08()
        "chapter_09_veil_nature": started = AshlandsSceneRouter.start_chapter_09()
        "chapter_10_final_choice": started = AshlandsSceneRouter.start_chapter_10()
        _: started = false
    if not started:
        GameState.current_screen = "expedition"
        GameState.add_log("La Porte ne parvient pas à ouvrir l'expédition du chapitre courant.")
        show_expedition()

func show_rewards() -> void:
    if not AshlandsCombatBridge.active:
        super.show_rewards()
        return

    var loot := AshlandsCombatBridge.preview_loot()
    var bg := full_texture("res://assets/backgrounds/ossuary.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.62)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var box := VBoxContainer.new()
    box.position = Vector2(340, 105)
    box.size = Vector2(600, 500)
    box.add_theme_constant_override("separation", 14)
    content.add_child(box)
    box.add_child(make_label("VICTOIRE", 42, GOLD))
    box.add_child(make_label("La compagnie reprend son souffle avant de retourner dans l'expédition.", 17, MUTED))

    var reward_lines: Array[String] = []
    reward_lines.append("+%d or" % int(loot.get("gold", 0)))
    reward_lines.append("+%d essence" % int(loot.get("essence", 0)))
    var rarity := str(loot.get("equipment_rarity", ""))
    if rarity != "":
        reward_lines.append("Équipement : rareté %s" % rarity)
    for guaranteed_value in loot.get("guaranteed", []):
        reward_lines.append("Garanti : %s" % str(guaranteed_value))
    box.add_child(make_label("\n".join(reward_lines), 18))
    box.add_child(make_button("RETOUR À L'EXPLORATION", func(): AshlandsCombatBridge.resolve_victory(), Vector2(540, 60)))

func show_infirmary() -> void:
    var bg := full_texture("res://assets/backgrounds/sanctuary.png")
    bg.modulate = Color(0.42, 0.42, 0.46, 1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var title := make_label("INFIRMERIE — SOINS DES CRÉATURES LIÉES", 26, GOLD)
    title.position = Vector2(32, 18)
    content.add_child(title)
    var rule := make_label(
        "Une créature capturée très blessée doit être stabilisée avant de reprendre le combat. Chaque traitement fait progresser sa convalescence sans effacer son histoire ni sa confiance initiale.",
        14, MUTED
    )
    rule.position = Vector2(32, 58)
    rule.size = Vector2(1190, 55)
    content.add_child(rule)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(32, 118)
    scroll.size = Vector2(1216, 485)
    content.add_child(scroll)
    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(1170, 0)
    list.add_theme_constant_override("separation", 12)
    scroll.add_child(list)

    var wounded_count := 0
    for creature_value in CreatureManager.captured_creatures:
        var creature: Dictionary = creature_value
        if CaptureWoundRuntime.can_fight(creature):
            continue
        wounded_count += 1
        var instance_id := str(creature.get("instance_id", ""))
        var row := HBoxContainer.new()
        var info := make_label(
            "%s · confiance %d · %s" % [
                str(creature.get("evolution_name", creature.get("name", "Créature"))),
                int(creature.get("bond", 50)),
                CaptureWoundRuntime.care_status(creature)
            ],
            17, GOLD
        )
        info.custom_minimum_size = Vector2(870, 42)
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info)
        row.add_child(make_button("TRAITER", func(id_value = instance_id): _treat_in_infirmary(str(id_value)), Vector2(180, 42)))
        list.add_child(row)

    if wounded_count == 0:
        list.add_child(make_label("Aucune créature n'est actuellement en convalescence.", 18, MUTED))
        list.add_child(make_label("Les créatures aptes au combat restent visibles dans le Bestiaire.", 14, MUTED))

    var bestiary := make_button("OUVRIR LE BESTIAIRE", func(): GameState.request_screen("creatures"), Vector2(250, 46))
    bestiary.position = Vector2(32, 625)
    content.add_child(bestiary)
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(280, 46))
    back.position = Vector2(300, 625)
    content.add_child(back)

func _treat_in_infirmary(instance_id: String) -> void:
    var creature := CaptureWoundRuntime.provide_sanctuary_care(instance_id)
    if creature.is_empty():
        GameState.add_log("Aucun soin n'a pu être appliqué.")
    elif CaptureWoundRuntime.can_fight(creature):
        GameState.add_log("%s termine sa convalescence et peut de nouveau combattre." % str(creature.get("name", "La créature")))
    else:
        GameState.add_log("Soin appliqué à %s : %s." % [str(creature.get("name", "la créature")), CaptureWoundRuntime.care_status(creature)])
    show_screen("infirmary")
