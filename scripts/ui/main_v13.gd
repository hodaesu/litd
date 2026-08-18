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
