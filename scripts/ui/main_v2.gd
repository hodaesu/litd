extends "res://scripts/ui/main.gd"

# Combat v2: chaque héros vivant agit une fois par round, puis le compagnon,
# puis les ennemis. Cette surcouche conserve toute l'UI/hub du prototype v1.
# Les hooks de sélection/intervention gardent le comportement historique par défaut
# et permettent aux couches supérieures d'ajouter une IA psychologique sans dupliquer
# toute la boucle de combat.
var round_number: int = 1
var acted_hero_ids: Dictionary = {}
var battle_round_key: String = ""

func _battle_key() -> String:
    if AshlandsCombatBridge.active:
        return "campaign:%s" % AshlandsCombatBridge.encounter_id
    return "prototype:%d" % GameState.expedition_room

func _ensure_round_state() -> void:
    var key := _battle_key()
    if battle_round_key != key:
        battle_round_key = key
        round_number = 1
        acted_hero_ids = {}
    _sync_skill_vitals()

func _reset_round_state() -> void:
    acted_hero_ids = {}
    round_number += 1

func _active_round_hero() -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            continue
        var hero_id := str(hero.get("id", ""))
        if not bool(acted_hero_ids.get(hero_id, false)):
            return hero
    return {}

func _mark_hero_acted(hero: Dictionary) -> void:
    acted_hero_ids[str(hero.get("id", ""))] = true

func _sync_skill_vitals() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var skill_stats := HeroSkillManager.stats_for(hero)
        var desired_hp_bonus := int(skill_stats.get("max_hp", 0))
        var applied_hp_bonus := int(hero.get("skill_max_hp_applied", 0))
        var delta := desired_hp_bonus - applied_hp_bonus
        if delta != 0:
            hero["max_hp"] = maxi(1, int(hero.get("max_hp", 1)) + delta)
            if delta > 0:
                hero["hp"] = mini(int(hero["max_hp"]), int(hero.get("hp", 0)) + delta)
            else:
                hero["hp"] = mini(int(hero.get("hp", 0)), int(hero["max_hp"]))
            hero["skill_max_hp_applied"] = desired_hp_bonus
        var madness_cap := 100 + int(skill_stats.get("max_madness", 0))
        hero["madness"] = clampi(int(hero.get("madness", 0)), 0, madness_cap)
        var hope_cap := 100 + int(skill_stats.get("max_hope", 0))
        hero["hope"] = clampi(int(hero.get("hope", 0)), 0, hope_cap)

func start_random_battle() -> void:
    acted_hero_ids = {}
    round_number = 1
    battle_round_key = ""
    super.start_random_battle()

func show_combat() -> void:
    _ensure_round_state()
    super.show_combat()
    var hero := _active_round_hero()
    var actor_text := "Aucun héros disponible"
    if not hero.is_empty():
        actor_text = "%s agit" % str(hero.get("name", "Héros"))
    var round_label := make_label("ROUND %d · %s" % [round_number, actor_text], 17, GOLD)
    round_label.position = Vector2(525, 18)
    round_label.size = Vector2(300, 35)
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(round_label)

func hero_action(action: String) -> void:
    if battle_locked:
        return
    _ensure_round_state()
    var hero := _active_round_hero()
    if hero.is_empty():
        if GameState.alive_heroes().is_empty():
            finish_defeat()
            return
        _finish_party_round()
        return

    battle_locked = true
    if action == "capture":
        _hero_capture_action(hero)
        return
    if action == "heal":
        _hero_heal_action(hero)
    elif action == "guard":
        hero["guarding"] = true
        hero["guard_power"] = int(hero_bonuses(hero).get("guard_power", 0))
        GameState.add_log("%s se met en garde." % str(hero.get("name", "Héros")))
    else:
        _hero_attack_action(hero, action)

    _apply_passive_party_heal(hero)
    _complete_hero_action(hero)

func _hero_capture_action(hero: Dictionary) -> void:
    var living_targets: Array = GameState.alive_enemies()
    if living_targets.is_empty():
        finish_victory()
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var capture_target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(capture_target.get("hp", 0)) <= 0:
        capture_target = living_targets[0]
    var capture_result := CreatureManager.attempt_capture(capture_target)
    GameState.add_log(str(capture_result.get("message", "Le sceau échoue.")))
    if bool(capture_result.get("success", false)) and GameState.alive_enemies().is_empty():
        finish_victory()
        return
    if bool(capture_result.get("consumed", false)):
        _complete_hero_action(hero)
    else:
        battle_locked = false
        show_screen("combat")

func _hero_heal_action(hero: Dictionary) -> void:
    var wounded: Array = GameState.alive_heroes()
    if wounded.is_empty():
        return
    wounded.sort_custom(func(left: Dictionary, right: Dictionary):
        var left_ratio := float(left.get("hp", 0)) / float(maxi(1, int(left.get("max_hp", 1))))
        var right_ratio := float(right.get("hp", 0)) / float(maxi(1, int(right.get("max_hp", 1))))
        return left_ratio < right_ratio
    )
    var target: Dictionary = wounded[0]
    var bonuses := hero_bonuses(hero)
    var amount := int(round(18.0 * (1.0 + float(bonuses.get("healing_power", 0)) / 100.0)))
    target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + amount)
    var target_bonuses := hero_bonuses(target)
    var hope_cap := 100 + int(target_bonuses.get("max_hope", 0))
    target["hope"] = mini(hope_cap, int(target.get("hope", 0)) + 2)
    GameState.add_log("%s restaure %d PV à %s." % [str(hero.get("name", "Héros")), amount, str(target.get("name", "allié"))])

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    var living: Array = GameState.alive_enemies()
    if living.is_empty():
        finish_victory()
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp", 0)) <= 0:
        target = living[0]

    var power := 1.0 if action == "strike" else 1.35
    var cls := DataLoader.find_by_id(DataLoader.classes, hero.get("class_id"))
    var bonuses := hero_bonuses(hero)
    var base_damage := randi_range(int(cls.damage[0]), int(cls.damage[1])) + int(bonuses.get("damage_bonus", 0))
    var damage := int(round(float(base_damage) * power))
    damage = int(round(float(damage) * (1.0 + float(bonuses.get("precision", 0)) / 100.0)))
    damage = int(round(float(damage) * (1.0 + float(bonuses.get("damage_percent", 0)) / 100.0)))

    var critical_chance := int(bonuses.get("critical_chance", 0))
    var critical := critical_chance > 0 and randi_range(1, 100) <= critical_chance
    if critical:
        damage = int(round(float(damage) * 1.5))
    if EquipmentManager.has_effect(str(hero.get("id", "")), "bone_fury") and int(hero.get("hp", 0)) * 2 <= int(hero.get("max_hp", 1)):
        damage = int(round(float(damage) * 1.25))
    if int(target.get("broken", 0)) > 0:
        damage = int(round(float(damage) * 1.15))
        target["broken"] = int(target.get("broken", 0)) - 1
    if EquipmentManager.has_effect(str(hero.get("id", "")), "void_echo"):
        damage += int(round(float(damage) * 0.20))

    var hp_ratio := float(target.get("hp", 1)) / float(maxi(1, int(target.get("max_hp", 1))))
    if hp_ratio <= 0.25 and int(bonuses.get("execute_percent", 0)) > 0:
        damage = int(round(float(damage) * (1.0 + float(bonuses.get("execute_percent", 0)) / 100.0)))

    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    if int(bonuses.get("stun_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("stun_chance", 0)):
        target["stunned"] = true
    if int(bonuses.get("bleed_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("bleed_chance", 0)):
        target["bleeding"] = maxi(2, int(bonuses.get("bleed_chance", 0)) / 2)
    if int(bonuses.get("break_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("break_chance", 0)):
        target["broken"] = 2
    if EquipmentManager.has_effect(str(hero.get("id", "")), "radiant_mercy"):
        _heal_most_wounded(4)
    GameState.add_log("%s inflige %d dégâts%s à %s." % [str(hero.get("name", "Héros")), damage, " critiques" if critical else "", str(target.get("name", "ennemi"))])

func _apply_passive_party_heal(hero: Dictionary) -> void:
    var heal := int(hero_bonuses(hero).get("party_heal", 0))
    if heal > 0:
        _heal_most_wounded(heal)

func _heal_most_wounded(amount: int) -> void:
    var wounded: Array = GameState.alive_heroes()
    if wounded.is_empty() or amount <= 0:
        return
    wounded.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("hp", 0)) < int(right.get("hp", 0)))
    var target: Dictionary = wounded[0]
    target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + amount)

func _complete_hero_action(hero: Dictionary) -> void:
    if GameState.alive_enemies().is_empty():
        finish_victory()
        return
    _mark_hero_acted(hero)
    if not _active_round_hero().is_empty():
        battle_locked = false
        show_screen("combat")
        return
    _finish_party_round()

func _before_companion_turn() -> void:
    pass

func _select_enemy_target(_enemy: Dictionary, targets: Array) -> Dictionary:
    if targets.is_empty():
        return {}
    return targets[randi() % targets.size()]

func _after_enemy_attack(_enemy: Dictionary, _target: Dictionary, _damage: int, _fear_gain: int) -> void:
    pass

func _finish_party_round() -> void:
    _before_companion_turn()
    var companion_targets: Array = GameState.alive_enemies()
    if not companion_targets.is_empty():
        var companion_result := CreatureManager.companion_turn(companion_targets[0])
        if not companion_result.is_empty():
            GameState.add_log("%s inflige %d dégâts." % [str(companion_result.get("name", "Le compagnon")), int(companion_result.get("damage", 0))])
    if GameState.alive_enemies().is_empty():
        finish_victory()
        return
    enemy_turn()

func enemy_turn() -> void:
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        if int(enemy.get("bleeding", 0)) > 0:
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - int(enemy.get("bleeding", 0)))
            if int(enemy.get("hp", 0)) <= 0:
                continue
        if bool(enemy.get("stunned", false)):
            enemy["stunned"] = false
            GameState.add_log("%s est étourdi et perd son tour." % str(enemy.get("name", "Ennemi")))
            continue
        var targets: Array = GameState.alive_heroes()
        if targets.is_empty():
            finish_defeat()
            return
        var target: Dictionary = _select_enemy_target(enemy, targets)
        if target.is_empty():
            target = targets[randi() % targets.size()]
        var target_bonuses := hero_bonuses(target)
        var creature_bonuses := CreatureManager.party_bonuses()
        for bonus_key_value in creature_bonuses.keys():
            var bonus_key := str(bonus_key_value)
            target_bonuses[bonus_key] = int(target_bonuses.get(bonus_key, 0)) + int(creature_bonuses.get(bonus_key, 0))

        var damage := randi_range(int(enemy.damage[0]), int(enemy.damage[1]))
        damage = maxi(1, int(round(float(damage) * (1.0 - float(target_bonuses.get("physical_resistance", 0)) / 100.0))))
        if bool(target.get("guarding", false)):
            var guard_reduction := clampf(0.5 + float(target.get("guard_power", 0)) / 100.0, 0.5, 0.85)
            damage = maxi(1, int(round(float(damage) * (1.0 - guard_reduction))))
            target["guarding"] = false
        target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)

        var fear_gain := maxi(0, int(enemy.fear) - int(target_bonuses.get("fear_resistance", 0)))
        target["fear"] = mini(100, int(target.get("fear", 0)) + fear_gain)
        if int(target.get("fear", 0)) >= 100 and fear_gain > 0:
            var base_madness_gain := maxi(1, int(ceil(float(fear_gain) * 0.5)))
            var madness_reduction := int(round(float(target_bonuses.get("madness_resistance", 0)) / 5.0))
            var madness_gain := maxi(0, base_madness_gain - madness_reduction)
            var madness_cap := 100 + int(target_bonuses.get("max_madness", 0))
            target["madness"] = mini(madness_cap, int(target.get("madness", 0)) + madness_gain)

        _after_enemy_attack(enemy, target, damage, fear_gain)

        var riposte_chance := int(target_bonuses.get("riposte_chance", 0))
        if EquipmentManager.has_effect(str(target.get("id", "")), "steadfast_counter"):
            riposte_chance += 10
        if riposte_chance > 0 and randi_range(1, 100) <= riposte_chance:
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - 4)
            GameState.add_log("%s riposte contre %s." % [str(target.get("name", "Héros")), str(enemy.get("name", "Ennemi"))])
        GameState.add_log("%s frappe %s pour %d dégâts." % [str(enemy.get("name", "Ennemi")), str(target.get("name", "Héros")), damage])

    if GameState.alive_heroes().is_empty():
        finish_defeat()
        return
    _reset_round_state()
    battle_locked = false
    show_screen("combat")
