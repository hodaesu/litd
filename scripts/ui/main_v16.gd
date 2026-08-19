extends "res://scripts/ui/main_v15.gd"

# v16 : psychologie événementielle.
# Une seule ressource psychologique reste visible en direct : la Peur.
# La Folie devient un ensemble de traces durables et l'Espoir un événement positif,
# jamais une monnaie ni une seconde jauge.

const PSY_CHAPEL_APPEASE_GOLD: int = 12
const PSY_TAVERN_MEAL_SUPPLIES: int = 1

func show_company() -> void:
    super.show_company()
    PsychologyRuntime.prepare_party()
    var status_labels: Array[Label] = []
    for node_value in content.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label == null:
            continue
        if label.text.begins_with("PV ") and label.text.contains("Peur ") and label.text.contains("Folie "):
            status_labels.append(label)
    var count := mini(status_labels.size(), GameState.party.size())
    for index in range(count):
        var hero: Dictionary = GameState.party[index]
        status_labels[index].text = "PV %d/%d   Peur %d — %s\n%s" % [
            int(hero.get("hp", 0)),
            int(hero.get("max_hp", 1)),
            int(hero.get("fear", 0)),
            PsychologyRuntime.fear_band_label(hero),
            PsychologyRuntime.mental_summary(hero)
        ]

func show_combat() -> void:
    super.show_combat()
    var hero := _active_round_hero()
    if hero.is_empty():
        return
    PsychologyRuntime.ensure_hero(hero)
    var label := make_label(
        "PEUR · %s · %d/100" % [PsychologyRuntime.fear_band_label(hero), int(hero.get("fear", 0))],
        11,
        GOLD if int(hero.get("fear", 0)) >= 75 else MUTED
    )
    label.position = Vector2(475, 112)
    label.size = Vector2(250, 24)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(label)

    var meter := ProgressBar.new()
    meter.min_value = 0.0
    meter.max_value = 100.0
    meter.value = float(hero.get("fear", 0))
    meter.show_percentage = false
    meter.position = Vector2(735, 116)
    meter.size = Vector2(220, 16)
    meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(meter)

func _hero_heal_action(hero: Dictionary) -> void:
    var snapshots: Dictionary = {}
    for hero_value in GameState.party:
        var candidate: Dictionary = hero_value
        snapshots[str(candidate.get("id", ""))] = {
            "hp": int(candidate.get("hp", 0)),
            "hope": int(candidate.get("hope", 0))
        }
    super._hero_heal_action(hero)

    var supported: Array = []
    for hero_value in GameState.party:
        var candidate: Dictionary = hero_value
        var hero_id := str(candidate.get("id", ""))
        var before: Dictionary = snapshots.get(hero_id, {})
        if before.is_empty():
            continue
        # Compatibilité des anciennes sauvegardes : la valeur historique reste présente,
        # mais v16 ne l'utilise plus comme ressource et annule donc tout gain numérique.
        candidate["hope"] = int(before.get("hope", candidate.get("hope", 0)))
        if int(candidate.get("hp", 0)) > int(before.get("hp", 0)):
            supported.append(candidate)
    if not supported.is_empty():
        PsychologyRuntime.apply_named_event(
            "combat_ally_support",
            {"supporter_id": str(hero.get("id", "")), "source": "heal"},
            supported
        )

func enemy_turn() -> void:
    var fear_before: Dictionary = {}
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        fear_before[str(hero.get("id", ""))] = int(hero.get("fear", 0))
    super.enemy_turn()
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        PsychologyRuntime.record_external_fear(
            hero,
            int(fear_before.get(hero_id, int(hero.get("fear", 0)))),
            "terrifying_enemy",
            {"screen": "combat", "round": round_number}
        )

func _apply_mutilation_psychology(target: Dictionary, attacker: Dictionary) -> void:
    var is_boss := bool(target.get("is_boss", false)) \
        or bool(target.get("boss", false)) \
        or bool(target.get("deep_vestige_boss", false))
    PsychologyRuntime.apply_named_event(
        "combat_dismemberment_witnessed",
        {
            "attacker_id": str(attacker.get("id", "")),
            "target_id": str(target.get("id", "")),
            "boss": is_boss
        },
        GameState.alive_heroes()
    )

func show_chapel() -> void:
    _sanctuary_building_background()
    var title := make_label("CHAPELLE OUVERTE — VEILLE ET APAISEMENT", 27, GOLD)
    title.position = Vector2(40, 22)
    content.add_child(title)

    var intro := make_label(
        "La Peur peut reculer. Les traces de Folie peuvent être stabilisées, mais elles ne sont plus effacées par une simple dépense. L'Espoir apparaît lorsqu'un acte redonne prise sur le monde.",
        15, MUTED
    )
    intro.position = Vector2(40, 64)
    intro.size = Vector2(1180, 62)
    content.add_child(intro)

    var hero := _selected_sanctuary_hero()
    var selector := HBoxContainer.new()
    selector.position = Vector2(40, 132)
    selector.size = Vector2(1180, 60)
    selector.add_theme_constant_override("separation", 10)
    content.add_child(selector)
    for hero_value in GameState.party:
        var candidate: Dictionary = hero_value
        var hero_id := str(candidate.get("id", ""))
        var selected := hero_id == selected_hero_id
        var button := make_button(
            "%s%s" % [str(candidate.get("name", "Héros")), " · CHOISI" if selected else ""],
            func(id_value = hero_id):
                selected_hero_id = str(id_value)
                show_screen("chapel"),
            Vector2(250, 50)
        )
        button.disabled = selected
        selector.add_child(button)

    if hero.is_empty():
        content.add_child(_building_message("Aucun héros disponible.", Vector2(40, 220)))
    else:
        var psychology := PsychologyRuntime.state_for(hero)
        var status := make_label(
            "%s · PV %d/%d · Peur %d — %s\n%s" % [
                str(hero.get("name", "Héros")),
                int(hero.get("hp", 0)),
                int(hero.get("max_hp", 1)),
                int(hero.get("fear", 0)),
                PsychologyRuntime.fear_band_label(hero),
                PsychologyRuntime.mental_summary(hero)
            ],
            19, TEXT
        )
        status.position = Vector2(40, 216)
        status.size = Vector2(1180, 72)
        content.add_child(status)

        var effect := make_label(
            "APAISER — %d or · Peur -18 · stabilise l'exposition récente sans supprimer les traces durables." % PSY_CHAPEL_APPEASE_GOLD,
            16, MUTED
        )
        effect.position = Vector2(40, 304)
        effect.size = Vector2(790, 52)
        content.add_child(effect)
        var appease := make_button("APAISER", func(): _chapel_appease(), Vector2(220, 54))
        appease.position = Vector2(850, 296)
        appease.disabled = GameState.gold < PSY_CHAPEL_APPEASE_GOLD or (
            int(hero.get("fear", 0)) <= 0 and int(psychology.get("madness_exposure", 0)) <= 0
        )
        content.add_child(appease)

    _add_building_footer("chapel")

func _chapel_appease() -> void:
    var hero := _selected_sanctuary_hero()
    if hero.is_empty() or GameState.gold < PSY_CHAPEL_APPEASE_GOLD:
        GameState.add_log("La Chapelle ne peut pas proposer cet accompagnement pour l'instant.")
        show_screen("chapel")
        return
    GameState.gold -= PSY_CHAPEL_APPEASE_GOLD
    PsychologyRuntime.apply_named_event("sanctuary_chapel_appease", {"screen": "chapel"}, [hero])
    GameState.add_log("%s retrouve assez de prise pour choisir malgré ce qui demeure." % str(hero.get("name", "Le héros")))
    show_screen("chapel")

func show_tavern() -> void:
    _sanctuary_building_background()
    var title := make_label("TAVERNE — RUMEURS, RENCONTRES ET REPAS", 27, GOLD)
    title.position = Vector2(40, 22)
    content.add_child(title)

    var intro := make_label(
        "La Taverne rassemble survivants, voyageurs et futurs compagnons. Le repos collectif agit sur la Peur ; l'Espoir se manifeste par la cohésion créée, sans devenir une ressource à accumuler.",
        15, MUTED
    )
    intro.position = Vector2(40, 64)
    intro.size = Vector2(1180, 62)
    content.add_child(intro)

    var chapter := CampaignState.current_chapter()
    var chapter_title := str(chapter.get("title", CampaignState.current_chapter_id))
    var social := make_label(
        "Chapitre %d — %s\nConfiance civique : %d · Tension : %d · Vivres : %d" % [
            CampaignState.current_chapter_number(),
            chapter_title,
            PoliticalState.trust,
            PoliticalState.tension,
            GameState.supplies
        ],
        18, TEXT
    )
    social.position = Vector2(40, 158)
    social.size = Vector2(1180, 72)
    content.add_child(social)

    var rumor := make_button("ÉCOUTER LES RUMEURS", func(): _tavern_rumor(), Vector2(320, 56))
    rumor.position = Vector2(40, 268)
    content.add_child(rumor)

    var meal := make_button("REPAS PARTAGÉ · 1 VIVRE", func(): _tavern_shared_meal(), Vector2(340, 56))
    meal.position = Vector2(390, 268)
    meal.disabled = GameState.supplies < PSY_TAVERN_MEAL_SUPPLIES
    content.add_child(meal)

    var effect := make_label(
        "Le repas partagé réduit la Peur de 5 pour chaque héros vivant et déclenche une manifestation d'Espoir liée à la cohésion.",
        15, MUTED
    )
    effect.position = Vector2(40, 346)
    effect.size = Vector2(1060, 52)
    content.add_child(effect)

    _add_building_footer("tavern")

func _tavern_shared_meal() -> void:
    if GameState.supplies < PSY_TAVERN_MEAL_SUPPLIES:
        GameState.add_log("Il ne reste pas assez de vivres pour un repas partagé.")
        show_screen("tavern")
        return
    GameState.supplies -= PSY_TAVERN_MEAL_SUPPLIES
    PsychologyRuntime.apply_named_event("sanctuary_shared_meal", {"screen": "tavern"}, GameState.alive_heroes())
    GameState.add_log("La compagnie partage un repas. La peur recule devant la présence des autres.")
    show_screen("tavern")

func show_memorial() -> void:
    _sanctuary_building_background()
    var title := make_label("MÉMORIAL — CEUX QUI NE DOIVENT PAS DISPARAÎTRE DEUX FOIS", 25, GOLD)
    title.position = Vector2(40, 22)
    content.add_child(title)

    var intro := make_label(
        "Le Mémorial conserve des noms et des vies. Le recueillement ne remplit aucune jauge : il peut seulement faire reculer la Peur et provoquer un moment d'Espoir partagé.",
        15, MUTED
    )
    intro.position = Vector2(40, 64)
    intro.size = Vector2(1180, 58)
    content.add_child(intro)

    var fallen: Array[String] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            fallen.append(str(hero.get("name", "Sans nom")))
    var names_text := "Aucun héros de la compagnie actuelle n'est tombé." if fallen.is_empty() else "Noms portés aujourd'hui : " + ", ".join(fallen)
    var names := make_label(names_text, 19, TEXT)
    names.position = Vector2(40, 158)
    names.size = Vector2(1180, 54)
    content.add_child(names)

    var sanctuary := make_label("État du Sanctuaire : %s" % SanctuaryState.summary(), 15, MUTED)
    sanctuary.position = Vector2(40, 226)
    sanctuary.size = Vector2(1180, 42)
    content.add_child(sanctuary)

    var flag := _memorial_flag()
    var honored := bool(CampaignState.chapter_flags.get(flag, false))
    var gather := make_button("DÉJÀ HONORÉ CE CHAPITRE" if honored else "SE RECUEILLIR", func(): _memorial_gather(), Vector2(330, 58))
    gather.position = Vector2(40, 306)
    gather.disabled = honored
    content.add_child(gather)

    var effect := make_label(
        "Une fois par chapitre : Peur -2 pour les héros vivants et manifestation d'Espoir par le souvenir commun. Aucun coût.",
        15, MUTED
    )
    effect.position = Vector2(400, 310)
    effect.size = Vector2(780, 56)
    content.add_child(effect)

    _add_building_footer("memorial")

func _memorial_gather() -> void:
    var flag := _memorial_flag()
    if bool(CampaignState.chapter_flags.get(flag, false)):
        show_screen("memorial")
        return
    CampaignState.set_chapter_flag(flag, true)
    PsychologyRuntime.apply_named_event(
        "sanctuary_memorial_remembrance",
        {"screen": "memorial", "chapter_id": CampaignState.current_chapter_id},
        GameState.alive_heroes()
    )
    GameState.add_log("La compagnie se recueille. Le souvenir reste une action, pas une monnaie.")
    show_screen("memorial")
