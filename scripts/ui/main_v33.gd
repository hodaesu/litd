extends "res://scripts/ui/main_v32.gd"

# v33 : résolution propre de l'ancienne PR #33 sur la pile UI actuelle.
# On conserve le loadout de quatre compétences de v30 et on ajoute un arbre
# focalisé : onglets, paliers, états lisibles et panneau de détail avant achat.

var selected_skill_branch: String = "offense"
var selected_skill_id: String = ""

func show_hero_skills() -> void:
    var hero: Dictionary = _selected_skill_hero()
    if hero.is_empty():
        GameState.request_screen("company")
        return
    HeroSkillManager.prepare_hero(hero)
    if not HeroSkillManager.BRANCHES.has(selected_skill_branch):
        selected_skill_branch = "offense"
        selected_skill_id = ""

    var title := make_label("%s · NIVEAU %d" % [str(hero.get("name", "Héros")), int(hero.get("level", 1))], 24, GOLD)
    title.position = Vector2(24, 8)
    title.size = Vector2(720, 32)
    content.add_child(title)
    var production_scope := make_label("10 TECHNIQUES PAR ARBRE · 5 CONCEPTS CONSERVÉS EN RÉSERVE", 12, MUTED)
    production_scope.position = Vector2(520, 14)
    production_scope.size = Vector2(430, 22)
    content.add_child(production_scope)

    var points := make_label("POINTS DISPONIBLES  ◆ %d" % int(hero.get("skill_points", 0)), 16, TEXT)
    points.position = Vector2(965, 12)
    points.size = Vector2(290, 28)
    content.add_child(points)

    var loadout_label := make_label("4 COMPÉTENCES ÉQUIPÉES — sélectionnez un emplacement à remplacer", 14, GOLD)
    loadout_label.position = Vector2(24, 42)
    loadout_label.size = Vector2(900, 24)
    content.add_child(loadout_label)

    var loadout_row := HBoxContainer.new()
    loadout_row.position = Vector2(24, 68)
    loadout_row.size = Vector2(1220, 56)
    loadout_row.add_theme_constant_override("separation", 8)
    content.add_child(loadout_row)
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    for slot in range(HeroSkillManager.COMBAT_LOADOUT_SIZE):
        var skill: Dictionary = HeroSkillManager.combat_skill(hero, loadout[slot])
        var slot_button := make_button(
            "%d · %s%s" % [
                slot + 1,
                str(skill.get("name", "Technique")),
                "\nÀ REMPLACER" if slot == selected_loadout_slot else ""
            ],
            func(slot_index = slot):
                selected_loadout_slot = int(slot_index)
                show_hero_skills(),
            Vector2(292, 54)
        )
        loadout_row.add_child(slot_button)

    var base_label := make_label("TECHNIQUES DE BASE — toujours disponibles", 13, MUTED)
    base_label.position = Vector2(24, 128)
    base_label.size = Vector2(600, 22)
    content.add_child(base_label)

    var base_row := HBoxContainer.new()
    base_row.position = Vector2(24, 152)
    base_row.size = Vector2(1220, 54)
    base_row.add_theme_constant_override("separation", 8)
    content.add_child(base_row)
    for skill_value in HeroSkillManager.BASE_COMBAT_SKILLS:
        var base_skill: Dictionary = skill_value
        var base_button := make_button(
            str(base_skill.get("name", "Technique")),
            func(skill_id = str(base_skill.get("id", ""))): _equip_selected_combat_skill(hero, skill_id),
            Vector2(292, 48)
        )
        base_button.tooltip_text = str(base_skill.get("description", ""))
        base_row.add_child(base_button)

    var specialization: String = str(hero.get("specialization", ""))
    var tabs := HBoxContainer.new()
    tabs.position = Vector2(24, 214)
    tabs.size = Vector2(800, 46)
    tabs.add_theme_constant_override("separation", 10)
    content.add_child(tabs)
    for branch_value in HeroSkillManager.BRANCHES:
        var branch: String = str(branch_value)
        var locked: bool = specialization != "" and specialization != branch and not HeroSkillManager.multi_tree_enabled()
        var chosen: bool = specialization == branch
        var tab_text: String = "%s%s" % [
            branch.to_upper(),
            "  🔒" if locked else ("  ◆" if chosen else "")
        ]
        var tab := make_button(
            tab_text,
            func(branch_id = branch):
                selected_skill_branch = str(branch_id)
                selected_skill_id = ""
                show_hero_skills(),
            Vector2(250, 44)
        )
        tab.modulate = _skill_branch_color(branch) if selected_skill_branch == branch else Color(0.62, 0.62, 0.66, 1)
        tabs.add_child(tab)

    var nodes: Array = HeroSkillManager.production_skill_nodes(hero, selected_skill_branch)
    var selected_exists: bool = false
    for node_value in nodes:
        var candidate: Dictionary = node_value
        if str(candidate.get("id", "")) == selected_skill_id:
            selected_exists = true
            break
    if not selected_exists:
        selected_skill_id = str((nodes[0] as Dictionary).get("id", "")) if not nodes.is_empty() else ""

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(24, 270)
    scroll.size = Vector2(805, 330)
    content.add_child(scroll)
    var tree := GridContainer.new()
    tree.columns = 3
    tree.custom_minimum_size = Vector2(770, 0)
    tree.add_theme_constant_override("h_separation", 12)
    tree.add_theme_constant_override("v_separation", 12)
    scroll.add_child(tree)

    for index in range(nodes.size()):
        var node: Dictionary = nodes[index]
        var node_id: String = str(node.get("id", ""))
        var unlocked: bool = (hero.get("unlocked_skills", []) as Array).has(node_id)
        var available: bool = HeroSkillManager.can_unlock(hero, node_id)
        var state: String = "◆ ACQUIS" if unlocked else ("◇ DISPONIBLE" if available else "🔒 VERROUILLÉ")
        var button := make_button(
            "PALIER %02d · NIV. %d\n%s\n%s" % [
                index + 1,
                int(node.get("required_level", 1)),
                str(node.get("name", "Compétence")),
                state
            ],
            func(skill_id = node_id):
                selected_skill_id = str(skill_id)
                show_hero_skills(),
            Vector2(248, 76)
        )
        button.modulate = _skill_branch_color(selected_skill_branch) if unlocked or available else Color(0.35, 0.35, 0.38, 1)
        tree.add_child(button)

    var detail := VBoxContainer.new()
    detail.position = Vector2(850, 270)
    detail.size = Vector2(405, 330)
    detail.add_theme_constant_override("separation", 10)
    content.add_child(detail)

    var selected_node: Dictionary = {}
    for node_value in nodes:
        var node: Dictionary = node_value
        if str(node.get("id", "")) == selected_skill_id:
            selected_node = node
            break
    if not selected_node.is_empty():
        detail.add_child(make_label(str(selected_node.get("name", "Compétence")), 21, _skill_branch_color(selected_skill_branch)))
        detail.add_child(make_label(
            "NIVEAU REQUIS  %d\nCOÛT  ◆ %d\nPRÉREQUIS  %s" % [
                int(selected_node.get("required_level", 1)),
                int(selected_node.get("cost", 1)),
                "Aucun" if str(selected_node.get("requires", "")) == "" else str(selected_node.get("requires", ""))
            ],
            14,
            MUTED
        ))
        detail.add_child(make_label(str(selected_node.get("description", "")), 16, TEXT))
        var acquired: bool = (hero.get("unlocked_skills", []) as Array).has(str(selected_node.get("id", "")))
        var can_buy: bool = HeroSkillManager.can_unlock(hero, str(selected_node.get("id", "")))
        if acquired:
            detail.add_child(make_button(
                "ACQUIS · ÉQUIPER DANS LE SLOT %d" % (selected_loadout_slot + 1),
                func(skill_id = str(selected_node.get("id", ""))): _equip_selected_combat_skill(hero, skill_id),
                Vector2(390, 52)
            ))
        else:
            var buy := make_button(
                "DÉBLOQUER" if can_buy else "INDISPONIBLE",
                func(skill_id = str(selected_node.get("id", ""))):
                    HeroSkillManager.unlock(hero, str(skill_id))
                    show_hero_skills(),
                Vector2(390, 52)
            )
            buy.disabled = not can_buy
            detail.add_child(buy)

    detail.add_child(make_label(
        "◆ Acquis   ◇ Disponible   🔒 Verrouillé\nLe premier arbre choisi condamne les deux autres hors NG+ multi-arbres.",
        12,
        MUTED
    ))

    _decorate_loadout_tooltips(hero, false)

    var back := make_button("RETOUR À LA GUILDE", func(): GameState.request_screen("company"), Vector2(220, 42))
    back.position = Vector2(24, 608)
    content.add_child(back)

func _skill_branch_color(branch: String) -> Color:
    return {
        "offense": Color("#b9413f"),
        "defense": Color("#5e8fc4"),
        "special": Color("#9b6bc5")
    }.get(branch, GOLD)
