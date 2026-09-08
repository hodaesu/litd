extends "res://scripts/ui/main_v44.gd"

# v45 — Taverne de recrutement lisible et déterministe.
# Les candidats montrent leurs traits, un aperçu de compétences et une comparaison
# directe avec le Veilleur tombé. Le renouvellement change seulement la seed d'offre.

var _tavern_refresh_generation: Dictionary = {}

func show_tavern() -> void:
    var bg := full_texture("res://assets/backgrounds/forgotten_city.webp")
    bg.modulate = Color(0.34, 0.31, 0.30, 1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.76)
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

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(32, 66)
    scroll.size = Vector2(1216, 548)
    content.add_child(scroll)
    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(1180, 0)
    list.add_theme_constant_override("separation", 14)
    scroll.add_child(list)

    var dead_ids: Array = _sanctuary_recruitment_service.dead_hero_ids()
    if dead_ids.is_empty():
        list.add_child(make_label("Aucun poste de Veilleur n'est vacant. La Taverne ne remplace que les morts permanentes.", 18, MUTED))
    else:
        for dead_id_value in dead_ids:
            _render_vacant_post(list, str(dead_id_value))

    var back := make_button("RETOUR À LA COMPAGNIE", func(): GameState.request_screen("company"), Vector2(280, 48))
    back.position = Vector2(32, 625)
    content.add_child(back)

func _render_vacant_post(parent: VBoxContainer, dead_id: String) -> void:
    var fallen: Dictionary = _hero_by_id(dead_id)
    if fallen.is_empty():
        return
    var generation := int(_tavern_refresh_generation.get(dead_id, 0))
    var seed_value := abs((dead_id + ":" + str(fallen.get("recruit_generation", 0)) + ":" + str(generation)).hash())

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    parent.add_child(header)
    var heading := make_label("POSTE VACANT · %s · %s" % [str(fallen.get("name", "Veilleur tombé")), str(fallen.get("class_id", "classe"))], 18, GOLD)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(heading)
    header.add_child(make_button("RENOUVELER", func(target_id = dead_id): _refresh_tavern_candidates(str(target_id)), Vector2(180, 44)))

    var fallen_traits: Dictionary = CharacterTraitDirector.trait_names(fallen)
    parent.add_child(make_label(
        "Tombé · niv. %d · PV max %d · traits +%d / −%d" % [
            int(fallen.get("level", 1)),
            int(fallen.get("max_hp", fallen.get("hp", 1))),
            (fallen_traits.get("positive", []) as Array).size(),
            (fallen_traits.get("negative", []) as Array).size()
        ],
        13,
        MUTED
    ))

    var candidates: Array = _sanctuary_recruitment_service.generate_replacement_candidates(dead_id, seed_value)
    if candidates.is_empty():
        parent.add_child(make_label("Aucune recrue compatible disponible pour ce poste.", 14, MUTED))
        return

    for candidate_value in candidates:
        var wrapper: Dictionary = candidate_value
        var candidate: Dictionary = wrapper.get("candidate", {})
        parent.add_child(_candidate_card(dead_id, fallen, wrapper, candidate))

func _candidate_card(dead_id: String, fallen: Dictionary, wrapper: Dictionary, candidate: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(1160, 132)
    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 14)
    panel.add_child(body)

    var details := VBoxContainer.new()
    details.custom_minimum_size = Vector2(900, 0)
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.add_theme_constant_override("separation", 4)
    body.add_child(details)

    var level := int(wrapper.get("level", 1))
    var cost := int(wrapper.get("cost", 0))
    details.add_child(make_label("%s · niveau %d · %d or" % [str(wrapper.get("name", "Recrue")), level, cost], 16, GOLD))

    var traits: Dictionary = CharacterTraitDirector.trait_names(candidate)
    var positives: Array = traits.get("positive", [])
    var negatives: Array = traits.get("negative", [])
    details.add_child(make_label(
        "Traits : + %s   ·   − %s" % [
            ", ".join(positives) if not positives.is_empty() else "aucun",
            ", ".join(negatives) if not negatives.is_empty() else "aucun"
        ],
        12,
        TEXT
    ))

    var skill_names: Array[String] = []
    for skill_value in HeroSkillManager.known_combat_skills(candidate):
        var skill: Dictionary = skill_value
        var name := str(skill.get("name", ""))
        if name != "" and not skill_names.has(name):
            skill_names.append(name)
        if skill_names.size() >= 3:
            break
    details.add_child(make_label("Aperçu compétences : %s" % (", ".join(skill_names) if not skill_names.is_empty() else "aucune technique équipée"), 12, MUTED))

    var level_delta := level - int(fallen.get("level", 1))
    var hp_delta := int(candidate.get("max_hp", candidate.get("hp", 1))) - int(fallen.get("max_hp", fallen.get("hp", 1)))
    var fallen_traits: Dictionary = CharacterTraitDirector.trait_names(fallen)
    var positive_delta := positives.size() - (fallen_traits.get("positive", []) as Array).size()
    var negative_delta := negatives.size() - (fallen_traits.get("negative", []) as Array).size()
    details.add_child(make_label(
        "Comparaison au tombé : niveau %+d · PV max %+d · traits positifs %+d · traits négatifs %+d" % [level_delta, hp_delta, positive_delta, negative_delta],
        12,
        MUTED
    ))

    var recruit := make_button("RECRUTER", func(target_id = dead_id, recruit_value = candidate.duplicate(true)): _recruit_replacement(str(target_id), recruit_value), Vector2(190, 48))
    recruit.disabled = GameState.gold < cost
    body.add_child(recruit)
    return panel

func _refresh_tavern_candidates(dead_id: String) -> void:
    _tavern_refresh_generation[dead_id] = int(_tavern_refresh_generation.get(dead_id, 0)) + 1
    GameState.add_log("Taverne : de nouvelles recrues se présentent pour le poste vacant.")
    show_screen("tavern")
