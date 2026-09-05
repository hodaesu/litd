extends "res://scripts/ui/main_v35.gd"

# v36 : réactions/passifs des arbres cliniques des Veilleurs.
# Cette couche conserve les règles d'objets ennemis de v34 et la résolution
# clinique manuelle de v35, puis instrumente précisément la phase ennemie.

const CLINICAL_REACTION_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_clinical_reaction_runtime.gd")

var _clinical_reactions: Node = null

func show_combat() -> void:
    _reaction_runtime().refresh_passive_states(GameState.party, GameState.battle_enemies)
    super.show_combat()

func enemy_turn() -> void:
    _ensure_personal_combat_inventories()
    var original_enemies: Array = GameState.battle_enemies
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var action_consumers: Array[String] = []

    # Règle héritée de v34 : transmettre un objet est gratuit, l'utiliser consomme l'action.
    for enemy_value: Variant in original_enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        if _enemy_try_use_healing_item(enemy, original_enemies, item_rules):
            action_consumers.append(str(enemy.get("combat_uid", "")))
        else:
            _enemy_try_free_item_transfer(enemy, original_enemies, item_rules)

    var attacking_enemies: Array = []
    for enemy_value: Variant in original_enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        var uid := str(enemy.get("combat_uid", ""))
        if int(enemy.get("hp", 0)) <= 0 or not action_consumers.has(uid):
            attacking_enemies.append(enemy)

    GameState.battle_enemies = attacking_enemies
    await _clinical_enemy_attack_phase(attacking_enemies)
    GameState.battle_enemies = original_enemies

    _reaction_runtime().advance_round_state(GameState.party)
    _reaction_runtime().refresh_passive_states(GameState.party, GameState.battle_enemies)

    if GameState.alive_enemies().is_empty():
        finish_victory()
        return
    if GameState.alive_heroes().is_empty():
        finish_defeat()
        return
    if GameState.current_screen == "combat":
        battle_locked = false
        show_screen("combat")

func _clinical_enemy_attack_phase(attacking_enemies: Array) -> void:
    for enemy_value: Variant in attacking_enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        if int(enemy.get("bleeding", 0)) > 0:
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - int(enemy.get("bleeding", 0)))
            if int(enemy.get("hp", 0)) <= 0:
                CombatBodyPresentation.stage_death(enemy, true)
                continue
        if bool(enemy.get("stunned", false)):
            enemy["stunned"] = false
            GameState.add_log("%s est étourdi et perd son tour." % str(enemy.get("name", "L'ennemi")))
            continue
        if EnemyFearDirector.should_panic(enemy, GameState.expedition_room):
            GameState.add_log("%s panique et perd son action." % str(enemy.get("name", "L'ennemi")))
            continue

        var targets: Array = GameState.alive_heroes()
        if targets.is_empty():
            finish_defeat()
            return
        var enemy_action: Dictionary = EnemyCombatDirector.choose_action(enemy, targets)
        var target_index := clampi(int(enemy_action.get("target_index", 0)), 0, targets.size() - 1)
        var target: Dictionary = targets[target_index]
        var target_bonuses: Dictionary = hero_bonuses(target)
        for contextual_key: Variant in CharacterTraitDirector.contextual_modifiers(target, CharacterTraitDirector.context_for_enemy(enemy)).keys():
            target_bonuses[str(contextual_key)] = int(target_bonuses.get(str(contextual_key), 0)) + int(round(float(CharacterTraitDirector.contextual_modifiers(target, CharacterTraitDirector.context_for_enemy(enemy)).get(contextual_key, 0.0))))
        var creature_bonuses: Dictionary = CreatureManager.party_bonuses()
        for bonus_key_value: Variant in creature_bonuses.keys():
            var bonus_key := str(bonus_key_value)
            target_bonuses[bonus_key] = int(target_bonuses.get(bonus_key, 0)) + int(creature_bonuses.get(bonus_key, 0))

        var damage_range: Array = enemy.get("damage", [4, 8])
        var damage := int(round(float(randi_range(int(damage_range[0]), int(damage_range[1]))) * float(enemy_action.get("power", 1.0))))
        damage = maxi(1, damage)
        var enemy_fear_modifiers := EnemyFearDirector.combat_modifiers(enemy)
        if randf() > float(enemy_fear_modifiers.get("accuracy_multiplier", 1.0)):
            GameState.add_log("%s hésite sous l’effet de la Peur et manque %s." % [str(enemy.get("name", "L'ennemi")), str(target.get("name", "sa cible"))])
            var miss_reaction: Dictionary = _reaction_runtime().on_enemy_miss(enemy, target, combat_round_number, GameState.party)
            _log_clinical_reaction(miss_reaction, enemy, target)
            if int(enemy.get("hp", 0)) <= 0:
                CombatBodyPresentation.stage_death(enemy, true)
            continue

        damage = maxi(1, int(round(float(damage) * float(enemy_fear_modifiers.get("damage_multiplier", 1.0)))))
        var enemy_trait_modifiers: Dictionary = CharacterTraitDirector.modifiers(enemy, CharacterTraitDirector.context_for_enemy(target))
        damage = maxi(1, int(round(float(damage) * (1.0 + float(enemy_trait_modifiers.get("damage_bonus", 0.0)) / 100.0))))
        damage = maxi(1, int(round(float(damage) * (1.0 - float(target_bonuses.get("physical_resistance", 0)) / 100.0))))
        if bool(target.get("guarding", false)):
            var guard_reduction := clampf(0.5 + float(target.get("guard_power", 0)) / 100.0, 0.5, 0.85)
            damage = maxi(1, int(round(float(damage) * (1.0 - guard_reduction))))
            target["guarding"] = false

        var before_damage: Dictionary = _reaction_runtime().before_enemy_damage(enemy, target, damage, combat_round_number, GameState.party)
        damage = int(before_damage.get("damage", damage))
        _log_clinical_reaction(before_damage.get("reaction", {}) as Dictionary, enemy, target)

        var hp_before := int(target.get("hp", 0))
        var bleeding_before := int(target.get("bleeding", 0))
        var enemy_position_before := _enemy_position(enemy)

        CombatBodyPresentation.stage_action(enemy, true, str(enemy_action.get("id", "strike")))
        await get_tree().create_timer(0.16).timeout
        target["hp"] = maxi(0, hp_before - damage)
        CombatBodyPresentation.stage_hit(target, false, "torso", "heavy" if damage >= int(damage_range[1]) else "light")
        if int(target.get("hp", 0)) <= 0:
            CombatBodyPresentation.stage_death(target, false)
        await get_tree().create_timer(0.12).timeout

        var fear_gain := maxi(0, int(enemy.get("fear", 0)) - int(target_bonuses.get("fear_resistance", 0)))
        target["fear"] = mini(100, int(target.get("fear", 0)) + fear_gain)
        var riposte_chance := int(target_bonuses.get("riposte_chance", 0))
        if EquipmentManager.has_effect(str(target.get("id", "")), "steadfast_counter"):
            riposte_chance += 10
        if riposte_chance > 0 and randi_range(1, 100) <= riposte_chance:
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - 4)
            GameState.add_log("%s riposte contre %s." % [str(target.get("name", "Le Veilleur")), str(enemy.get("name", "l'ennemi"))])

        GameState.add_log("%s utilise %s sur %s pour %d dégâts." % [str(enemy.get("name", "L'ennemi")), str(enemy_action.get("name", "une attaque")), str(target.get("name", "le Veilleur")), damage])
        for secondary_message: String in EnemyCombatDirector.apply_secondary(enemy_action, enemy, target, targets):
            GameState.add_log(secondary_message)

        var hit_reaction: Dictionary = _reaction_runtime().after_enemy_hit(enemy, target, hp_before, bleeding_before, combat_round_number, GameState.party)
        _log_clinical_reaction(hit_reaction, enemy, target)
        var movement_reactions: Array[Dictionary] = _reaction_runtime().on_enemy_movement(enemy, enemy_position_before, _enemy_position(enemy), combat_round_number, GameState.party)
        for reaction_value: Variant in movement_reactions:
            if reaction_value is Dictionary:
                _log_clinical_reaction(reaction_value, enemy, target)

        if damage >= int(damage_range[1]):
            EnemyFearDirector.apply_event(enemy, "enemy_lands_heavy_hit")
        if int(enemy.get("hp", 0)) <= 0:
            CombatBodyPresentation.stage_death(enemy, true)

func _reaction_runtime() -> Node:
    if _clinical_reactions == null:
        _clinical_reactions = get_node_or_null("ClinicalReactionRuntime")
    if _clinical_reactions == null:
        _clinical_reactions = CLINICAL_REACTION_RUNTIME_SCRIPT.new()
        _clinical_reactions.name = "ClinicalReactionRuntime"
        add_child(_clinical_reactions)
    return _clinical_reactions

func _enemy_position(enemy: Dictionary) -> int:
    if enemy.has("combat_position"):
        return int(enemy.get("combat_position", 0))
    if enemy.has("rank"):
        return int(enemy.get("rank", 0))
    return int(enemy.get("position", 0))

func _log_clinical_reaction(result: Dictionary, enemy: Dictionary, target: Dictionary) -> void:
    if result.is_empty() or not bool(result.get("ok", false)):
        return
    match str(result.get("skill_id", "")):
        "TA-ENT-04":
            GameState.add_log("Tarek · Retour de lame : %d dégâts à %s après l'attaque manquée." % [int(result.get("damage", 0)), str(enemy.get("name", "l'ennemi"))])
        "TA-ENT-13":
            GameState.add_log("Tarek · Fauchage réflexe intercepte le changement de rang de %s." % str(enemy.get("name", "l'ennemi")))
        "AÏ-ANA-04":
            GameState.add_log("Aïsha · Déviation anatomique détourne %d dégâts destinés à %s." % [int(result.get("prevented_damage", 0)), str(target.get("name", "un allié"))])
        "AÏ-ANA-13":
            GameState.add_log("Aïsha · Réflexe musculaire frappe le groupe locomoteur sollicité par %s." % str(enemy.get("name", "l'ennemi")))
        "AÏ-SUT-04":
            GameState.add_log("Aïsha · Main réflexe jugule immédiatement l'hémorragie de %s." % str(target.get("name", "un allié")))
        "AÏ-SUT-13":
            GameState.add_log("Aïsha · Intervention immédiate stabilise %s au seuil critique." % str(target.get("name", "un allié")))
