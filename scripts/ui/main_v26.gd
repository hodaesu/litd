extends "res://scripts/ui/main_v25.gd"

# v26 : le Hall des Descendants donne une présence physique aux exploits de
# Première Descente dans le Sanctuaire. L'écran reste volontairement sobre :
# une chronique sélectionnée, son récit, puis la vitrine des récompenses.

var selected_descent_chronicle_index: int = 0

func show_screen(name: String) -> void:
    if name == "descendants_hall":
        GameState.current_screen = name
        clear_content()
        show_descendants_hall()
        call_deferred("_postprocess_mobile_screen")
        return
    super.show_screen(name)

func show_sanctuary() -> void:
    super.show_sanctuary()
    var runtime: Node = ExpeditionManager.first_descent_runtime
    var chronicle_count := 0
    var relic_count := 0
    if runtime != null:
        chronicle_count = runtime.chronicle_entries().size()
        var collection: Dictionary = runtime.collection()
        relic_count = (collection.get("relics", {}) as Dictionary).size()
    var hall_label := "HALL DES DESCENDANTS\nChroniques et reliques"
    if chronicle_count > 0:
        hall_label = "HALL DES DESCENDANTS\n%d chronique(s) · %d relique(s)" % [chronicle_count, relic_count]
    var hall := make_button(
        hall_label,
        func(): GameState.request_screen("descendants_hall"),
        Vector2(270, 70)
    )
    hall.position = Vector2(970, 535)
    hall.modulate = Color(1, 1, 1, 0.94)
    content.add_child(hall)

func show_descendants_hall() -> void:
    _sanctuary_building_background()

    var title := make_label("HALL DES DESCENDANTS — MUR DES EXPÉDITIONS", 27, GOLD)
    title.position = Vector2(34, 20)
    title.size = Vector2(1160, 40)
    content.add_child(title)

    var intro := make_label(
        "Ici ne sont conservés ni des statistiques de puissance ni des trophées nécessaires. Le mur garde la mémoire des compagnies qui ont atteint le cœur d'un donjon dès leur toute première descente.",
        14,
        MUTED
    )
    intro.position = Vector2(34, 62)
    intro.size = Vector2(1160, 54)
    content.add_child(intro)

    var runtime: Node = ExpeditionManager.first_descent_runtime
    if runtime == null:
        var unavailable := make_label("Les archives des descentes sont indisponibles.", 16, MUTED)
        unavailable.position = Vector2(34, 145)
        content.add_child(unavailable)
        _add_descendants_hall_back_button()
        return

    var chronicles: Array = runtime.chronicle_entries()
    var collection: Dictionary = runtime.collection()
    _render_descent_chronicle_list(chronicles)
    _render_descent_chronicle_detail(chronicles)
    _render_descent_trophy_case(collection)
    _add_descendants_hall_back_button()

func _render_descent_chronicle_list(chronicles: Array) -> void:
    var header := make_label("MUR DES EXPÉDITIONS", 17, GOLD)
    header.position = Vector2(34, 132)
    content.add_child(header)

    var list_scroll := ScrollContainer.new()
    list_scroll.position = Vector2(34, 166)
    list_scroll.size = Vector2(292, 430)
    content.add_child(list_scroll)

    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(270, 0)
    list.add_theme_constant_override("separation", 8)
    list_scroll.add_child(list)

    if chronicles.is_empty():
        var empty := make_label(
            "Le mur attend sa première inscription.\n\nAtteindre un boss après plusieurs descentes reste une victoire ; seule la toute première tentative crée une chronique ici.",
            13,
            MUTED
        )
        empty.custom_minimum_size = Vector2(260, 180)
        list.add_child(empty)
        return

    selected_descent_chronicle_index = clampi(selected_descent_chronicle_index, 0, chronicles.size() - 1)
    for index in range(chronicles.size()):
        var chronicle: Dictionary = chronicles[index]
        var selected := index == selected_descent_chronicle_index
        var button := make_button(
            "%s%s\n%s" % [
                "◆ " if selected else "",
                str(chronicle.get("dungeon_title", "Donjon")),
                str(chronicle.get("title", "Première Descente"))
            ],
            func(index_value = index): _select_descent_chronicle(index_value),
            Vector2(260, 64)
        )
        button.disabled = selected
        list.add_child(button)

func _select_descent_chronicle(index: int) -> void:
    selected_descent_chronicle_index = maxi(0, index)
    show_screen("descendants_hall")

func _render_descent_chronicle_detail(chronicles: Array) -> void:
    var header := make_label("CHRONIQUE", 17, GOLD)
    header.position = Vector2(354, 132)
    content.add_child(header)

    var detail_scroll := ScrollContainer.new()
    detail_scroll.position = Vector2(354, 166)
    detail_scroll.size = Vector2(500, 430)
    content.add_child(detail_scroll)

    var detail := VBoxContainer.new()
    detail.custom_minimum_size = Vector2(474, 0)
    detail.add_theme_constant_override("separation", 9)
    detail_scroll.add_child(detail)

    if chronicles.is_empty():
        detail.add_child(make_label("Aucune Première Descente n'a encore été accomplie sur cette sauvegarde.", 15, MUTED))
        return

    selected_descent_chronicle_index = clampi(selected_descent_chronicle_index, 0, chronicles.size() - 1)
    var chronicle: Dictionary = chronicles[selected_descent_chronicle_index]
    detail.add_child(make_label(str(chronicle.get("title", "LA PREMIÈRE DESCENTE")), 23, GOLD))
    detail.add_child(make_label(
        "%s\nBoss vaincu : %s" % [
            str(chronicle.get("dungeon_title", "Donjon")),
            str(chronicle.get("boss_name", "Boss"))
        ],
        16,
        TEXT
    ))
    detail.add_child(make_label(
        "Tentative %d · Profondeur %d · %d salles\nLumière restante %d · Seed %d" % [
            int(chronicle.get("attempt_number", 1)),
            int(chronicle.get("deepest_depth", 0)),
            int(chronicle.get("rooms_cleared", 0)),
            int(chronicle.get("light_remaining", 0)),
            int(chronicle.get("seed", 0))
        ],
        13,
        MUTED
    ))

    detail.add_child(make_label("SURVIVANTS", 15, GOLD))
    detail.add_child(make_label(_descent_roster_text(chronicle.get("survivors", []), "Aucun survivant."), 13, TEXT))
    detail.add_child(make_label("TOMBÉS PENDANT LA DESCENTE", 15, GOLD))
    detail.add_child(make_label(_descent_roster_text(chronicle.get("fallen", []), "Aucun nom n'a été ajouté au mur des morts."), 13, MUTED))

    var start_party: Array = chronicle.get("party_started", [])
    if not start_party.is_empty():
        detail.add_child(make_label("COMPAGNIE AU DÉPART", 15, GOLD))
        detail.add_child(make_label(_descent_roster_text(start_party, ""), 12, MUTED))

func _descent_roster_text(entries_value: Variant, empty_text: String) -> String:
    var entries: Array = entries_value if entries_value is Array else []
    if entries.is_empty():
        return empty_text
    var lines: Array[String] = []
    for entry_value in entries:
        var entry: Dictionary = entry_value if entry_value is Dictionary else {}
        lines.append("• %s — niveau %d" % [
            str(entry.get("name", "Inconnu")),
            int(entry.get("level", 1))
        ])
    return "\n".join(lines)

func _render_descent_trophy_case(collection: Dictionary) -> void:
    var header := make_label("VITRINE DES RELIQUES", 17, GOLD)
    header.position = Vector2(884, 132)
    content.add_child(header)

    var case_scroll := ScrollContainer.new()
    case_scroll.position = Vector2(884, 166)
    case_scroll.size = Vector2(352, 430)
    content.add_child(case_scroll)

    var case_box := VBoxContainer.new()
    case_box.custom_minimum_size = Vector2(326, 0)
    case_box.add_theme_constant_override("separation", 9)
    case_scroll.add_child(case_box)

    var relics: Dictionary = collection.get("relics", {})
    if relics.is_empty():
        case_box.add_child(make_label("Les niches sont encore vides.", 14, MUTED))
    else:
        for relic_value in relics.values():
            var relic: Dictionary = relic_value if relic_value is Dictionary else {}
            case_box.add_child(make_label("◇ %s" % str(relic.get("name", "Relique")), 15, GOLD))
            case_box.add_child(make_label("Relique commémorative · aucun bonus de combat requis.", 11, MUTED))

    var titles: Dictionary = collection.get("titles", {})
    case_box.add_child(make_label("TITRES", 15, GOLD))
    if titles.is_empty():
        case_box.add_child(make_label("Aucun titre de Première Descente.", 12, MUTED))
    else:
        for title_value in titles.values():
            var title_reward: Dictionary = title_value if title_value is Dictionary else {}
            case_box.add_child(make_label("• %s" % str(title_reward.get("name", "Titre")), 13, TEXT))

    var achievements: Dictionary = collection.get("achievements", {})
    case_box.add_child(make_label("EXPLOITS CONSIGNÉS", 15, GOLD))
    if achievements.is_empty():
        case_box.add_child(make_label("Aucun exploit consigné.", 12, MUTED))
    else:
        for achievement_value in achievements.values():
            var achievement: Dictionary = achievement_value if achievement_value is Dictionary else {}
            case_box.add_child(make_label("✓ %s" % str(achievement.get("name", "Première Descente")), 12, TEXT))

func _add_descendants_hall_back_button() -> void:
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(280, 48))
    back.position = Vector2(34, 620)
    content.add_child(back)
