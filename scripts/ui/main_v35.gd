extends "res://scripts/ui/main_v34.gd"

# v35 : pont de combat strictement limité aux resolvers cliniques des Veilleurs.
# Toutes les compétences LITD1 et toutes les familles Veilleurs encore non résolues
# continuent de passer par v34/v30 sans changement de comportement.

const CLINICAL_RESOLVERS := ["anatomical_lesion", "anatomical_diagnostic", "medical_treatment", "vascular_bleeding"]

func _use_combat_skill(slot: int) -> void:
    if battle_locked:
        return
    var hero: Dictionary = _active_combat_hero()
    if hero.is_empty():
        finish_defeat()
        return
    var loadout: Array[String] = HeroSkillManager.combat_loadout(hero)
    if slot < 0 or slot >= loadout.size():
        return
    var skill: Dictionary = HeroSkillManager.combat_skill(hero, loadout[slot])
    if skill.is_empty() or not _is_clinical_skill(skill):
        super._use_combat_skill(slot)
        return

    battle_locked = true
    match str(skill.get("effect", "")):
        "attack":
            _resolve_skill_attack(hero, skill)
        "diagnostic":
            _resolve_clinical_diagnostic(hero, skill)
        "medical":
            _resolve_clinical_medical(hero, skill)
        "posture":
            _resolve_clinical_posture(hero, skill)
        _:
            GameState.add_log("%s n'est pas encore exécutable dans ce contexte." % str(skill.get("name", "Cette technique")))
            battle_locked = false
            show_screen("combat")
            return
    _complete_active_hero_turn()

func _resolve_skill_attack(hero: Dictionary, skill: Dictionary) -> void:
    if not _is_clinical_skill(skill):
        super._resolve_skill_attack(hero, skill)
        return
    var target := _selected_living_enemy()
    if target.is_empty():
        finish_victory()
        return
    var hp_before := int(target.get("hp", 0))
    super._resolve_skill_attack(hero, skill)
    var direct_damage := maxi(0, hp_before - int(target.get("hp", 0)))
    var result := VeilleursSkillResolverRouter.resolve_combat(hero, target, skill, direct_damage, GameState.party)
    _log_clinical_result(hero, target, skill, result)

func _resolve_clinical_diagnostic(hero: Dictionary, skill: Dictionary) -> void:
    var target := _selected_living_enemy()
    if target.is_empty():
        return
    var result := VeilleursSkillResolverRouter.resolve_combat(hero, target, skill, 0, GameState.party)
    _log_clinical_result(hero, target, skill, result)

func _resolve_clinical_medical(hero: Dictionary, skill: Dictionary) -> void:
    var patient := VeilleursSkillResolverRouter.select_medical_target(GameState.alive_heroes())
    if patient.is_empty():
        patient = hero
    var result := VeilleursSkillResolverRouter.resolve_combat(hero, patient, skill, 0, GameState.party)
    _log_clinical_result(hero, patient, skill, result)

func _resolve_clinical_posture(hero: Dictionary, skill: Dictionary) -> void:
    var result := VeilleursSkillResolverRouter.resolve_combat(hero, hero, skill, 0, GameState.party)
    _log_clinical_result(hero, hero, skill, result)

func _selected_living_enemy() -> Dictionary:
    var living: Array[Dictionary] = GameState.alive_enemies()
    if living.is_empty():
        return {}
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp", 0)) <= 0:
        target = living[0]
    return target

func _is_clinical_skill(skill: Dictionary) -> bool:
    return str(skill.get("resolver_id", "")) in CLINICAL_RESOLVERS and str(skill.get("resolver_status", "")) == "prototype_bridge"

func _log_clinical_result(hero: Dictionary, target: Dictionary, skill: Dictionary, result: Dictionary) -> void:
    if not bool(result.get("ok", false)):
        GameState.add_log("%s : %s." % [str(skill.get("name", "Technique")), _clinical_failure_text(str(result.get("reason", "échec")))])
        return
    var effect := str(skill.get("effect", ""))
    if effect == "attack":
        var part_name := str(result.get("part_name", result.get("part_id", "zone ciblée")))
        var bleed := int(result.get("bleed_added", 0))
        var bonus_damage := int(result.get("bonus_damage", 0))
        var suffix := ""
        if bleed > 0:
            suffix += " · saignement +%d" % bleed
        if bonus_damage > 0:
            suffix += " · %d dégâts fonctionnels" % bonus_damage
        if result.has("circulatory_shock"):
            suffix += " · choc circulatoire %d" % int(result.get("circulatory_shock", 0))
        GameState.add_log("%s affecte %s%s." % [part_name, str(target.get("name", "la cible")), suffix])
    elif effect == "diagnostic":
        var diagnostic_suffix := ""
        if result.has("circulatory_shock"):
            diagnostic_suffix = " · choc %d · risque hémorragique %d%%" % [int(result.get("circulatory_shock", 0)), int(result.get("hemorrhage_risk", 0))]
        GameState.add_log("%s lit %s : %s%s." % [str(hero.get("name", "Aïsha")), str(target.get("name", "la cible")), str(result.get("part_name", result.get("part_id", "zone"))), diagnostic_suffix if diagnostic_suffix != "" else " · " + str(result.get("state", "intact"))])
    elif effect == "medical":
        var stabilized := str(result.get("stabilized_injury", ""))
        var downgraded := str(result.get("downgraded_injury", ""))
        var supplies := int(result.get("supplies_spent", 0))
        var detail := "stabilisation"
        if downgraded != "":
            detail = "gravité réduite : %s" % downgraded
        elif stabilized != "":
            detail = "blessure stabilisée : %s" % stabilized
        if result.has("bleeding_after"):
            detail += " · saignement %d→%d" % [int(result.get("bleeding_before", 0)), int(result.get("bleeding_after", 0))]
        if supplies > 0:
            detail += " · %d vivres médicalisés" % supplies
        GameState.add_log("%s traite %s : %s." % [str(hero.get("name", "Aïsha")), str(target.get("name", "un allié")), detail])
    elif effect == "posture":
        GameState.add_log("%s adopte %s pour %d rounds." % [str(hero.get("name", "Le Veilleur")), str(skill.get("name", "une posture")), int(result.get("duration_rounds", 0))])

func _clinical_failure_text(reason: String) -> String:
    return {
        "supplies_required": "ressources médicales insuffisantes",
        "patient_required": "aucun patient valide",
        "target_required": "aucune cible valide",
        "no_targetable_part": "aucune zone anatomique accessible",
        "clinical_runtime_unavailable": "resolver clinique indisponible",
        "specialized_runtime_unavailable": "resolver spécialisé indisponible"
    }.get(reason, reason.replace("_", " "))
