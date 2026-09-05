extends "res://scripts/ui/main_v37.gd"

# v38 : séquence dédiée du premier ultime jouable des Veilleurs.
# L'ultime reste hors des quatre compétences équipées et consomme l'action du héros.

func show_combat() -> void:
    VeilleursSkillResolverRouter.begin_ultimate_encounter(GameState.battle_enemies)
    super.show_combat()
    _render_hemocorde_ultimate_action()

func _render_hemocorde_ultimate_action() -> void:
    var hero := _active_combat_hero()
    if hero.is_empty() or str(hero.get("id", "")) != "aisha_maren" or str(hero.get("specialization", "")) != "hemocorde":
        return
    var target := _selected_living_enemy()
    if target.is_empty():
        return
    var contract := VeilleursSkillResolverRouter.ultimate_contract(hero, "hemocorde")
    if str(contract.get("status", "required")) != "implemented":
        return
    var status := VeilleursSkillResolverRouter.ultimate_status(hero, "hemocorde", target, GameState.battle_enemies)
    var charges := int(status.get("charges_remaining", 0))
    var button := make_button("ULTIME · LE DERNIER BATTEMENT ×%d" % charges, func(): _use_hemocorde_ultimate(), Vector2(285, 48))
    button.position = Vector2(700, 580)
    button.disabled = battle_locked or not bool(status.get("available", false))
    button.tooltip_text = _ultimate_reason_text(str(status.get("reason", "ultimate_unavailable")))
    content.add_child(button)

func _use_hemocorde_ultimate() -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    var target := _selected_living_enemy()
    if hero.is_empty() or target.is_empty():
        return
    var status := VeilleursSkillResolverRouter.ultimate_status(hero, "hemocorde", target, GameState.battle_enemies)
    if not bool(status.get("available", false)):
        GameState.add_log("Le Dernier Battement : %s." % _ultimate_reason_text(str(status.get("reason", "ultimate_unavailable"))))
        show_screen("combat")
        return

    battle_locked = true
    CombatBodyPresentation.stage_action(hero, false, "ultimate_hemocorde_last_beat")
    GameState.add_log("Aïsha écoute le dernier rythme de %s." % str(target.get("name", "la cible")))
    await get_tree().create_timer(0.18).timeout

    var result := VeilleursSkillResolverRouter.resolve_ultimate(hero, "hemocorde", target, GameState.battle_enemies)
    if not bool(result.get("ok", false)):
        GameState.add_log("Le Dernier Battement échoue : %s." % _ultimate_reason_text(str(result.get("reason", "ultimate_unavailable"))))
        battle_locked = false
        show_screen("combat")
        return

    var part_id := str(result.get("part_id", "torso"))
    CombatBodyPresentation.stage_hit(target, true, part_id, "heavy")
    await get_tree().create_timer(0.16).timeout
    if int(target.get("hp", 0)) <= 0:
        CombatBodyPresentation.stage_death(target, true)
        GameState.add_log("Le Dernier Battement : %s s'effondre, sa circulation déjà ruinée ne repart pas." % str(target.get("name", "La cible")))
    else:
        GameState.add_log("Le Dernier Battement : collapsus circulatoire de %s · %d charge(s) restante(s)." % [str(target.get("name", "la cible")), int(result.get("charges_remaining", 0))])
    _complete_active_hero_turn()

func finish_victory() -> void:
    VeilleursSkillResolverRouter.end_ultimate_encounter()
    super.finish_victory()

func finish_defeat() -> void:
    VeilleursSkillResolverRouter.end_ultimate_encounter()
    super.finish_defeat()

func _ultimate_reason_text(reason: String) -> String:
    return {
        "ready": "prêt",
        "expedition_required": "utilisable uniquement en expédition",
        "ultimate_level_locked": "se débloque au niveau 16",
        "wrong_specialization": "l'arbre Hémocorde doit être choisi",
        "no_ultimate_charges": "aucune charge restante dans cette expédition",
        "ultimate_already_used_this_encounter": "déjà utilisé dans cette rencontre",
        "valid_target_required": "aucune cible valide",
        "vascular_knowledge_required": "physiologie vasculaire insuffisamment connue",
        "target_not_compromised_enough": "la cible n'est pas encore assez compromise",
        "ultimate_resolver_required": "séquence d'ultime non implémentée",
        "ultimate_not_implemented_for_tree": "ultime non implémenté pour cet arbre"
    }.get(reason, reason.replace("_", " "))
