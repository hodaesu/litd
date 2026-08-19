extends "res://scripts/ui/main_v20.gd"

# v21 : Sanctuaire vivant, mémoire collective et quêtes émergentes.
# Les personnes revenues du terrain ont un rôle visible ; les rumeurs circulent
# sans jauge morale et certaines histoires ouvrent des quêtes qui n'existent
# que si les bonnes personnes ont réellement survécu.

func show_screen(name: String) -> void:
    if name == "community":
        GameState.current_screen = name
        clear_content()
        show_community()
        call_deferred("_postprocess_mobile_screen")
        return
    super.show_screen(name)

func show_sanctuary() -> void:
    super.show_sanctuary()
    var community_button := make_button(
        "COMMUNAUTÉ\nHabitants, rumeurs, quêtes",
        func(): GameState.request_screen("community"),
        Vector2(270, 70)
    )
    community_button.position = Vector2(690, 535)
    content.add_child(community_button)

    var living := make_label("SANCTUAIRE VIVANT — " + CommunityRuntime.community_summary(), 14, MUTED)
    living.position = Vector2(40, 650)
    living.size = Vector2(1160, 28)
    content.add_child(living)

func show_tavern() -> void:
    super.show_tavern()
    var community_button := make_button(
        "VOIR LE RÉSEAU DU SANCTUAIRE",
        func(): GameState.request_screen("community"),
        Vector2(360, 56)
    )
    community_button.position = Vector2(760, 268)
    content.add_child(community_button)

func _tavern_rumor() -> void:
    var rumor: Dictionary = CommunityRuntime.listen_next_rumor()
    if not rumor.is_empty():
        show_screen("tavern")
        return
    var active := CampaignState.active_main_quests()
    if active.is_empty():
        GameState.add_log("Rumeur — aucune nouvelle histoire précise ne domine les conversations aujourd'hui.")
    else:
        var quest: Dictionary = active[0]
        GameState.add_log("Rumeur — « %s » revient dans plusieurs conversations." % str(quest.get("title", quest.get("id", "un objectif"))))
    show_screen("tavern")

func show_community() -> void:
    _sanctuary_building_background()

    var title := make_label("COMMUNAUTÉ — CEUX QUI SONT REVENUS AVEC L'HISTOIRE", 25, GOLD)
    title.position = Vector2(36, 20)
    title.size = Vector2(1180, 38)
    content.add_child(title)

    var intro := make_label(
        "Le Sanctuaire ne gagne pas une réputation abstraite. Des personnes précises arrivent, racontent ce qu'elles ont vu, occupent une place et peuvent faire naître de nouvelles demandes.",
        14, MUTED
    )
    intro.position = Vector2(36, 62)
    intro.size = Vector2(1180, 48)
    content.add_child(intro)

    _render_people_column()
    _render_rumor_column()
    _render_quest_column()

    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(270, 50))
    back.position = Vector2(36, 640)
    content.add_child(back)

func _render_people_column() -> void:
    var header := make_label("PRÉSENCES ET RÔLES", 18, GOLD)
    header.position = Vector2(36, 128)
    content.add_child(header)

    var people: Array[Dictionary] = CommunityRuntime.sanctuary_people()
    if people.is_empty():
        var empty := make_label("Aucun survivant rencontré sur le terrain n'a encore rejoint durablement le réseau du Sanctuaire.", 14, MUTED)
        empty.position = Vector2(36, 166)
        empty.size = Vector2(350, 100)
        content.add_child(empty)
        return

    var y: float = 166.0
    for person in people:
        var state_value: Variant = person.get("state", {})
        var state: Dictionary = state_value if state_value is Dictionary else {}
        var line := make_label(
            "%s\n%s" % [str(person.get("name", "Survivant")), str(state.get("role", "Présence du Sanctuaire"))],
            15,
            TEXT
        )
        line.position = Vector2(36, y)
        line.size = Vector2(350, 72)
        content.add_child(line)
        y += 82.0

func _render_rumor_column() -> void:
    var header := make_label("MÉMOIRE COLLECTIVE", 18, GOLD)
    header.position = Vector2(426, 128)
    content.add_child(header)

    var lines: Array[String] = CommunityRuntime.recent_rumor_lines(4)
    if lines.is_empty():
        var empty := make_label("Les récits du terrain n'ont pas encore assez circulé pour former une mémoire commune.", 14, MUTED)
        empty.position = Vector2(426, 166)
        empty.size = Vector2(390, 90)
        content.add_child(empty)
        return

    var y: float = 166.0
    for text_value in lines:
        var rumor := make_label("• " + text_value, 13, MUTED)
        rumor.position = Vector2(426, y)
        rumor.size = Vector2(390, 92)
        content.add_child(rumor)
        y += 102.0

func _render_quest_column() -> void:
    var header := make_label("QUÊTES NÉES DE LA CAMPAGNE", 18, GOLD)
    header.position = Vector2(846, 128)
    content.add_child(header)

    var quests: Array[Dictionary] = CommunityRuntime.quest_entries()
    if quests.is_empty():
        var empty := make_label("Aucune quête émergente. Certaines n'existeront que si des personnes précises survivent et atteignent le réseau du Sanctuaire.", 14, MUTED)
        empty.position = Vector2(846, 166)
        empty.size = Vector2(390, 110)
        content.add_child(empty)
        return

    var y: float = 166.0
    for quest in quests:
        var quest_id: String = str(quest.get("id", ""))
        var state: String = str(quest.get("state", ""))
        var giver: Dictionary = CommunityRuntime.quest_definition(quest_id)
        var objective_value: Variant = quest.get("objective", {})
        var objective: Dictionary = objective_value if objective_value is Dictionary else {}
        var text := make_label(
            "%s — %s\n%s\nObjectif : %s" % [
                _quest_state_label(state),
                str(quest.get("name", quest_id)),
                str(quest.get("summary", "")),
                str(objective.get("text", ""))
            ],
            13,
            TEXT if state != "completed" else MUTED
        )
        text.position = Vector2(846, y)
        text.size = Vector2(390, 120)
        content.add_child(text)
        y += 126.0
        if state == "offered":
            var accept := make_button(
                "ACCEPTER",
                func(id_value = quest_id):
                    CommunityRuntime.accept_quest(str(id_value))
                    SaveManager.save_game()
                    show_screen("community"),
                Vector2(180, 42)
            )
            accept.position = Vector2(846, y)
            content.add_child(accept)
            y += 52.0

func _quest_state_label(state: String) -> String:
    match state:
        "offered": return "PROPOSÉE"
        "active": return "EN COURS"
        "completed": return "ACCOMPLIE"
        _: return "INCONNUE"
