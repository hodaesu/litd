extends "res://scripts/ui/main_v46.gd"

# v47 — formation tactique cohérente.
# - R1 reste le front / au contact, R4 l'arrière.
# - Les contrôles de formation sont affichés de gauche à droite R4, R3, R2, R1,
#   afin que R1 soit visuellement du côté des ennemis comme dans le combat.
# - Le premier placement d'un quatuor est normalisé une seule fois selon le rôle
#   réel de chaque héros : mêlée / contrôle devant, soin / soutien / distance derrière.

const FORMATION_V47_MARKER := "formation_v47_initialized"

func _ensure_combat_positions() -> void:
    super._ensure_combat_positions()
    _apply_logical_starting_formation_v47()

func _show_formation_editor() -> void:
    super._show_formation_editor()
    _reverse_rank_controls_v47(content)
    var hint := make_label("ARRIÈRE  ·  R4   R3   R2   R1  ·  FRONT / ENNEMIS →", 12, CANON_MUTED)
    hint.name = "FormationDirectionV47"
    hint.position = Vector2(52, 150)
    hint.size = Vector2(1160, 22)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(hint)

func _render_combat_position_menu(hero: Dictionary) -> void:
    super._render_combat_position_menu(hero)
    var panel := content.get_node_or_null("CombatPositionMenuV42") as Control
    if panel != null:
        _reverse_rank_controls_v47(panel)

func _reverse_rank_controls_v47(root: Node) -> void:
    for node_value: Variant in root.find_children("*", "HBoxContainer", true, false):
        var row := node_value as HBoxContainer
        if row == null:
            continue
        var rank_buttons: Dictionary = {}
        for child_value: Variant in row.get_children():
            var button := child_value as Button
            if button == null:
                continue
            for rank in range(1, 5):
                if button.text.begins_with("R%d" % rank) or button.text.begins_with("◆ R%d" % rank):
                    rank_buttons[rank] = button
                    break
        if rank_buttons.size() != 4:
            continue
        var visual_order := [4, 3, 2, 1]
        for index in range(visual_order.size()):
            var rank := int(visual_order[index])
            row.move_child(rank_buttons[rank] as Node, index)

func _apply_logical_starting_formation_v47() -> void:
    if GameState.party.size() != 4:
        return
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        if bool(hero.get(FORMATION_V47_MARKER, false)):
            return

    var ordered: Array[Dictionary] = []
    for hero_value: Variant in GameState.party:
        ordered.append(hero_value as Dictionary)
    ordered.sort_custom(func(left: Dictionary, right: Dictionary):
        return _frontline_score_v47(left) > _frontline_score_v47(right)
    )

    for rank in range(ordered.size()):
        var hero: Dictionary = ordered[rank]
        hero["combat_position"] = rank
        hero[FORMATION_V47_MARKER] = true
    GameState.add_log("Formation initiale ajustée : mêlée au front, soutien et distance à l'arrière.")

func _frontline_score_v47(hero: Dictionary) -> int:
    var score := 0
    var class_id := str(hero.get("class_id", "")).to_lower()
    for token in ["tank", "guard", "knight", "warrior", "brute", "melee", "front", "duelist"]:
        if class_id.contains(token):
            score += 8
    for token in ["heal", "medic", "support", "ranged", "archer", "mage", "occult", "scholar"]:
        if class_id.contains(token):
            score -= 8

    for skill_id: String in HeroSkillManager.combat_loadout(hero):
        var skill := HeroSkillManager.combat_skill(hero, skill_id)
        if skill.is_empty():
            continue
        var effect := str(skill.get("effect", "attack")).to_lower()
        var allowed: Array[int] = COMBAT_POSITION_RULES.allowed_positions(hero, skill)
        if effect in ["heal", "support"]:
            score -= 5
        elif effect in ["guard", "riposte"]:
            score += 4
        elif effect == "attack":
            if allowed.has(0):
                score += 3
            if allowed.has(1):
                score += 1
            if allowed.has(3) and not allowed.has(0):
                score -= 3
            var scope := str(skill.get("target_scope", skill.get("target_group", ""))).to_lower()
            if scope in ["rear", "all", "aoe"]:
                score -= 1
    return score
