extends "res://scripts/ui/main_v14.gd"

# v15 : rend les trois derniers bâtiments du Sanctuaire réellement interactifs.
# La Chapelle ouverte travaille Peur/Folie/Espoir, la Taverne les rumeurs et
# le repos collectif, et le Mémorial donne un recueillement limité par chapitre.

const CHAPEL_APPEASE_GOLD: int = 12
const CHAPEL_FEAR_REDUCTION: int = 18
const CHAPEL_MADNESS_REDUCTION: int = 4
const CHAPEL_HOPE_GAIN: int = 4
const TAVERN_MEAL_SUPPLIES: int = 1
const TAVERN_FEAR_REDUCTION: int = 5
const TAVERN_HOPE_GAIN: int = 5
const MEMORIAL_FEAR_REDUCTION: int = 2
const MEMORIAL_HOPE_GAIN: int = 4

func show_screen(name: String) -> void:
    if name in ["chapel", "tavern", "memorial"]:
        GameState.current_screen = name
        clear_content()
        match name:
            "chapel": show_chapel()
            "tavern": show_tavern()
            "memorial": show_memorial()
        call_deferred("_postprocess_mobile_screen")
        return
    super.show_screen(name)

func show_sanctuary() -> void:
    super.show_sanctuary()
    _add_functional_sanctuary_button(
        "CHAPELLE\nPeur, folie et espoir",
        "chapel",
        Vector2(520, 105)
    )
    _add_functional_sanctuary_button(
        "TAVERNE\nRecruter et rumeurs",
        "tavern",
        Vector2(980, 180)
    )
    _add_functional_sanctuary_button(
        "MÉMORIAL\nHéros tombés",
        "memorial",
        Vector2(250, 535)
    )

func _add_functional_sanctuary_button(text: String, screen_name: String, position_value: Vector2) -> void:
    var button := make_button(text, func(): GameState.request_screen(screen_name), Vector2(230, 70))
    button.position = position_value
    button.modulate = Color(1, 1, 1, 0.96)
    content.add_child(button)
    _keep_last_button_with_text(text)

func show_chapel() -> void:
    _sanctuary_building_background()
    var title := make_label("CHAPELLE OUVERTE — VEILLE, PEUR ET ESPOIR", 27, GOLD)
    title.position = Vector2(40, 22)
    content.add_child(title)

    var intro := make_label(
        "Ici, aucune doctrine n'est imposée. On s'assoit, on écoute et on aide chacun à retrouver un peu de prise sur ce que la Peur et la Folie déforment.",
        15, MUTED
    )
    intro.position = Vector2(40, 64)
    intro.size = Vector2(1180, 58)
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
        var status := make_label(
            "%s · PV %d/%d · Peur %d · Folie %d · Espoir %d" % [
                str(hero.get("name", "Héros")),
                int(hero.get("hp", 0)), int(hero.get("max_hp", 1)),
                int(hero.get("fear", 0)), int(hero.get("madness", 0)), int(hero.get("hope", 0))
            ],
            21, TEXT
        )
        status.position = Vector2(40, 220)
        status.size = Vector2(1180, 42)
        content.add_child(status)

        var effect := make_label(
            "APAISER — %d or · Peur -%d · Folie -%d · Espoir +%d" % [
                CHAPEL_APPEASE_GOLD, CHAPEL_FEAR_REDUCTION, CHAPEL_MADNESS_REDUCTION, CHAPEL_HOPE_GAIN
            ],
            16, MUTED
        )
        effect.position = Vector2(40, 284)
        effect.size = Vector2(750, 42)
        content.add_child(effect)
        var appease := make_button("APAISER", func(): _chapel_appease(), Vector2(220, 54))
        appease.position = Vector2(810, 276)
        appease.disabled = GameState.gold < CHAPEL_APPEASE_GOLD or (
            int(hero.get("fear", 0)) <= 0 and int(hero.get("madness", 0)) <= 0 and int(hero.get("hope", 0)) >= 100
        )
        content.add_child(appease)

    _add_building_footer("chapel")

func _chapel_appease() -> void:
    var hero := _selected_sanctuary_hero()
    if hero.is_empty() or GameState.gold < CHAPEL_APPEASE_GOLD:
        GameState.add_log("La Chapelle ne peut pas proposer cet accompagnement pour l'instant.")
        show_screen("chapel")
        return
    GameState.gold -= CHAPEL_APPEASE_GOLD
    hero["fear"] = maxi(0, int(hero.get("fear", 0)) - CHAPEL_FEAR_REDUCTION)
    hero["madness"] = maxi(0, int(hero.get("madness", 0)) - CHAPEL_MADNESS_REDUCTION)
    var hope_cap := 100 + int(hero_bonuses(hero).get("max_hope", 0))
    hero["hope"] = mini(hope_cap, int(hero.get("hope", 0)) + CHAPEL_HOPE_GAIN)
    GameState.add_log("%s trouve un peu d'espace intérieur à la Chapelle ouverte." % str(hero.get("name", "Le héros")))
    GameState.state_changed.emit()
    show_screen("chapel")

func show_tavern() -> void:
    _sanctuary_building_background()
    var title := make_label("TAVERNE — RUMEURS, RENCONTRES ET REPAS", 27, GOLD)
    title.position = Vector2(40, 22)
    content.add_child(title)

    var intro := make_label(
        "La Taverne rassemble survivants, voyageurs et futurs compagnons. Le roster actuel ne contient pas encore de héros de réserve, mais les rumeurs et le repos collectif sont déjà actifs.",
        15, MUTED
    )
    intro.position = Vector2(40, 64)
    intro.size = Vector2(1180, 62)
    content.add_child(intro)

    var chapter := CampaignState.current_chapter()
    var chapter_title := str(chapter.get("title", CampaignState.current_chapter_id))
    var social := make_label(
        "Chapitre %d — %s\nConfiance civique : %d · Tension : %d · Vivres : %d" % [
            CampaignState.current_chapter_number(), chapter_title,
            PoliticalState.trust, PoliticalState.tension, GameState.supplies
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
    meal.disabled = GameState.supplies < TAVERN_MEAL_SUPPLIES
    content.add_child(meal)

    var effect := make_label(
        "Le repas partagé réduit la Peur de %d et augmente l'Espoir de %d pour chaque héros vivant." % [
            TAVERN_FEAR_REDUCTION, TAVERN_HOPE_GAIN
        ],
        15, MUTED
    )
    effect.position = Vector2(40, 346)
    effect.size = Vector2(1060, 52)
    content.add_child(effect)

    _add_building_footer("tavern")

func _tavern_rumor() -> void:
    var active := CampaignState.active_main_quests()
    if active.is_empty():
        GameState.add_log("Rumeur — la Taverne ne parle plus d'un objectif précis ; tous attendent la suite.")
    else:
        var quest: Dictionary = active[0]
        GameState.add_log("Rumeur — « %s » revient dans plusieurs conversations." % str(quest.get("title", quest.get("id", "un objectif"))))
    show_screen("tavern")

func _tavern_shared_meal() -> void:
    if GameState.supplies < TAVERN_MEAL_SUPPLIES:
        GameState.add_log("Il ne reste pas assez de vivres pour un repas partagé.")
        show_screen("tavern")
        return
    GameState.supplies -= TAVERN_MEAL_SUPPLIES
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        hero["fear"] = maxi(0, int(hero.get("fear", 0)) - TAVERN_FEAR_REDUCTION)
        var hope_cap := 100 + int(hero_bonuses(hero).get("max_hope", 0))
        hero["hope"] = mini(hope_cap, int(hero.get("hope", 0)) + TAVERN_HOPE_GAIN)
    GameState.add_log("La compagnie partage un repas. La peur recule un instant devant la présence des autres.")
    GameState.state_changed.emit()
    show_screen("tavern")

func show_memorial() -> void:
    _sanctuary_building_background()
    var title := make_label("MÉMORIAL — CEUX QUI NE DOIVENT PAS DISPARAÎTRE DEUX FOIS", 25, GOLD)
    title.position = Vector2(40, 22)
    content.add_child(title)

    var intro := make_label(
        "Le Mémorial ne transforme pas les morts en symboles utiles. Il conserve des noms, des vies et ce que les survivants refusent d'oublier.",
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
        "Une fois par chapitre : Peur -%d · Espoir +%d pour les héros vivants. Aucun coût : le souvenir n'est pas une marchandise." % [
            MEMORIAL_FEAR_REDUCTION, MEMORIAL_HOPE_GAIN
        ],
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
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        hero["fear"] = maxi(0, int(hero.get("fear", 0)) - MEMORIAL_FEAR_REDUCTION)
        var hope_cap := 100 + int(hero_bonuses(hero).get("max_hope", 0))
        hero["hope"] = mini(hope_cap, int(hero.get("hope", 0)) + MEMORIAL_HOPE_GAIN)
    CampaignState.set_chapter_flag(flag, true)
    GameState.add_log("La compagnie se recueille. Se souvenir n'efface rien, mais empêche l'absence de tout avaler.")
    GameState.state_changed.emit()
    show_screen("memorial")

func _memorial_flag() -> String:
    return "memorial_honored_%s" % CampaignState.current_chapter_id

func _selected_sanctuary_hero() -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == selected_hero_id:
            return hero
    if not GameState.party.is_empty():
        var first: Dictionary = GameState.party[0]
        selected_hero_id = str(first.get("id", ""))
        return first
    return {}

func _sanctuary_building_background() -> void:
    var bg := full_texture("res://assets/backgrounds/sanctuary.png")
    bg.modulate = Color(0.42, 0.42, 0.47, 1)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.74)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

func _building_message(text: String, position_value: Vector2) -> Label:
    var label := make_label(text, 18, MUTED)
    label.position = position_value
    label.size = Vector2(1100, 48)
    return label

func _add_building_footer(_screen_name: String) -> void:
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(300, 50))
    back.position = Vector2(40, 620)
    content.add_child(back)
