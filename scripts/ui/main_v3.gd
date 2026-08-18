extends "res://scripts/ui/main_v2.gd"

# Combat v3 : formation tactique à quatre rangs.
# Rang 1 = avant, rang 4 = arrière. Le déplacement consomme l'action.
var tactical_battle_key: String = ""
var tactical_data: Dictionary = {}

func _ready() -> void:
    _load_tactical_data()
    super._ready()

func _load_tactical_data() -> void:
    if not tactical_data.is_empty():
        return
    var text := FileAccess.get_file_as_string("res://data/combat_tactics.json")
    var parsed = JSON.parse_string(text)
    tactical_data = parsed if parsed is Dictionary else {}

func _ensure_tactical_state() -> void:
    _load_tactical_data()
    var key := _battle_key()
    if tactical_battle_key == key:
        return
    tactical_battle_key = key
    var formation: Dictionary = tactical_data.get("initial_formation", {})
    var used: Dictionary = {}
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var hero_id := str(hero.get("id", ""))
        var requested := int(formation.get(hero_id, 0))
        if requested >= 1 and requested <= 4 and not used.has(requested):
            hero["battle_rank"] = requested
            used[requested] = true
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("battle_rank", 0)) in [1, 2, 3, 4]:
            continue
        for rank in range(1, 5):
            if not used.has(rank):
                hero["battle_rank"] = rank
                used[rank] = true
                break
    _assign_enemy_ranks()

func _assign_enemy_ranks() -> void:
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        enemy["battle_rank"] = clampi(index + 1, 1, 4)

func _compact_enemy_ranks() -> void:
    var living: Array = []
    for enemy_value in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) > 0:
            living.append(enemy)
    living.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("battle_rank", 4)) < int(right.get("battle_rank", 4)))
    for index in range(living.size()):
        living[index]["battle_rank"] = clampi(index + 1, 1, 4)

func start_random_battle() -> void:
    tactical_battle_key = ""
    super.start_random_battle()

func show_combat() -> void:
    _ensure_tactical_state()
    super.show_combat()
    _decorate_tactical_combat()

func _decorate_tactical_combat() -> void:
    var hero := _active_round_hero()
    var formation_parts: Array[String] = []
    for rank in range(1, 5):
        var occupant := _hero_at_rank(rank)
        formation_parts.append("R%d %s" % [rank, str(occupant.get("name", "—")) if not occupant.is_empty() else "—"])
    var formation_label := make_label("FORMATION · " + "  |  ".join(formation_parts), 13, MUTED)
    formation_label.position = Vector2(360, 52)
    formation_label.size = Vector2(760, 28)
    formation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(formation_label)

    if hero.is_empty():
        return
    var rank := _hero_rank(hero)
    var profile := _profile_for(hero)
    var strike_targets: Array = profile.get("strike_targets", [])
    var heavy_targets: Array = profile.get("heavy_targets", [])
    var range_label := make_label(
        "%s · rang %d · Frappe → %s · Lourd → %s" % [
            str(profile.get("identity", "Combattant")), rank,
            _rank_list_text(strike_targets), _rank_list_text(heavy_targets)
        ],
        12, MUTED
    )
    range_label.position = Vector2(385, 535)
    range_label.size = Vector2(650, 30)
    range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(range_label)

    for node in content.find_children("*", "Button", true, false):
        if node is Button:
            var button := node as Button
            if button.text == "FRAPPE":
                button.disabled = not _can_use_attack_from_rank(hero, "strike")
            elif button.text == "COUP LOURD":
                button.disabled = not _can_use_attack_from_rank(hero, "heavy")

    var forward := make_button("AVANCER", func(): _move_active_hero(-1), Vector2(105, 55))
    forward.position = Vector2(1045, 575)
    forward.disabled = rank <= 1
    content.add_child(forward)
    var backward := make_button("RECULER", func(): _move_active_hero(1), Vector2(105, 55))
    backward.position = Vector2(1155, 575)
    backward.disabled = rank >= 4
    content.add_child(backward)

    var synergy_names := _active_synergy_names()
    if not synergy_names.is_empty():
        var synergy := make_label("SYNERGIES · " + " · ".join(synergy_names), 12, GOLD)
        synergy.position = Vector2(360, 82)
        synergy.size = Vector2(760, 26)
        synergy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        content.add_child(synergy)

func _rank_list_text(values: Array) -> String:
    var parts: Array[String] = []
    for value in values:
        parts.append("R%d" % int(value))
    return "/".join(parts)

func _profile_for(hero: Dictionary) -> Dictionary:
    var profiles: Dictionary = tactical_data.get("hero_profiles", {})
    var hero_id := str(hero.get("id", ""))
    if profiles.has(hero_id):
        return profiles[hero_id]
    return {
        "preferred_ranks": [1, 2, 3, 4],
        "strike_from": [1, 2, 3, 4],
        "strike_targets": [1, 2],
        "heavy_from": [1, 2],
        "heavy_targets": [1],
        "identity": "Combattant polyvalent"
    }

func _hero_rank(hero: Dictionary) -> int:
    return clampi(int(hero.get("battle_rank", 1)), 1, 4)

func _enemy_rank(enemy: Dictionary) -> int:
    return clampi(int(enemy.get("battle_rank", 1)), 1, 4)

func _hero_at_rank(rank: int) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if _hero_rank(hero) == rank:
            return hero
    return {}

func _hero_by_id(hero_id: String) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _can_use_attack_from_rank(hero: Dictionary, action: String) -> bool:
    var profile := _profile_for(hero)
    var allowed: Array = profile.get("heavy_from" if action == "heavy" else "strike_from", [])
    return allowed.has(_hero_rank(hero))

func _target_ranks_for(hero: Dictionary, action: String) -> Array:
    var profile := _profile_for(hero)
    return profile.get("heavy_targets" if action == "heavy" else "strike_targets", [])

func _selected_target_for(hero: Dictionary, action: String) -> Dictionary:
    var allowed := _target_ranks_for(hero, action)
    selected_enemy = clampi(selected_enemy, 0, maxi(0, GameState.battle_enemies.size() - 1))
    if not GameState.battle_enemies.is_empty():
        var selected: Dictionary = GameState.battle_enemies[selected_enemy]
        if int(selected.get("hp", 0)) > 0 and allowed.has(_enemy_rank(selected)):
            return selected
    return {}

func hero_action(action: String) -> void:
    if battle_locked:
        return
    _ensure_tactical_state()
    var hero := _active_round_hero()
    if not hero.is_empty() and action in ["strike", "heavy"]:
        if not _can_use_attack_from_rank(hero, action):
            GameState.add_log("%s ne peut pas utiliser cette attaque depuis le rang %d." % [str(hero.get("name", "Héros")), _hero_rank(hero)])
            show_screen("combat")
            return
        if _selected_target_for(hero, action).is_empty():
            GameState.add_log("La cible choisie est hors de portée pour %s." % str(hero.get("name", "ce héros")))
            show_screen("combat")
            return
    super.hero_action(action)

func _move_active_hero(delta: int) -> void:
    if battle_locked:
        return
    _ensure_tactical_state()
    var hero := _active_round_hero()
    if hero.is_empty():
        return
    var current := _hero_rank(hero)
    var target_rank := current + delta
    if target_rank < 1 or target_rank > 4:
        return
    battle_locked = true
    var other := _hero_at_rank(target_rank)
    hero["battle_rank"] = target_rank
    if not other.is_empty():
        other["battle_rank"] = current
    GameState.add_log("%s %s au rang %d." % [
        str(hero.get("name", "Héros")),
        "avance" if delta < 0 else "recule",
        target_rank
    ])
    _complete_hero_action(hero)

func hero_bonuses(hero: Dictionary) -> Dictionary:
    var result := super.hero_bonuses(hero)
    var hero_id := str(hero.get("id", ""))
    if _frontline_wall_active() and hero_id in ["malvor", "darius"]:
        result["physical_resistance"] = int(result.get("physical_resistance", 0)) + 5
    if _veil_concord_active() and hero_id in ["aurelien", "lysandra"]:
        result["fear_resistance"] = int(result.get("fear_resistance", 0)) + 5
    return result

func _hero_heal_action(hero: Dictionary) -> void:
    var wounded := GameState.alive_heroes()
    if wounded.is_empty():
        return
    wounded.sort_custom(func(left: Dictionary, right: Dictionary):
        var left_ratio := float(left.get("hp", 0)) / float(maxi(1, int(left.get("max_hp", 1))))
        var right_ratio := float(right.get("hp", 0)) / float(maxi(1, int(right.get("max_hp", 1))))
        return left_ratio < right_ratio
    )
    var target: Dictionary = wounded[0]
    var bonuses := hero_bonuses(hero)
    var amount := 18.0 * (1.0 + float(bonuses.get("healing_power", 0)) / 100.0)
    if str(hero.get("id", "")) == "lysandra" and _veil_concord_active():
        amount *= 1.15
    var final_amount := int(round(amount))
    target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + final_amount)
    var target_bonuses := hero_bonuses(target)
    var hope_cap := 100 + int(target_bonuses.get("max_hope", 0))
    target["hope"] = mini(hope_cap, int(target.get("hope", 0)) + 2)
    GameState.add_log("%s restaure %d PV à %s." % [str(hero.get("name", "Héros")), final_amount, str(target.get("name", "allié"))])

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    var target := _selected_target_for(hero, action)
    if target.is_empty():
        return
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
    if str(hero.get("id", "")) == "aurelien" and _opening_exploit_active() and (int(target.get("broken", 0)) > 0 or bool(target.get("stunned", false))):
        damage = int(round(float(damage) * 1.15))

    target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
    if int(bonuses.get("stun_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("stun_chance", 0)):
        target["stunned"] = true
    if int(bonuses.get("bleed_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("bleed_chance", 0)):
        target["bleeding"] = maxi(2, int(bonuses.get("bleed_chance", 0)) / 2)
    if int(bonuses.get("break_chance", 0)) > 0 and randi_range(1, 100) <= int(bonuses.get("break_chance", 0)):
        target["broken"] = 2
    if EquipmentManager.has_effect(str(hero.get("id", "")), "radiant_mercy"):
        _heal_most_wounded(4)
    GameState.add_log("%s inflige %d dégâts%s à %s (rang %d)." % [
        str(hero.get("name", "Héros")), damage, " critiques" if critical else "", str(target.get("name", "ennemi")), _enemy_rank(target)
    ])

func _complete_hero_action(hero: Dictionary) -> void:
    _compact_enemy_ranks()
    super._complete_hero_action(hero)

func enemy_turn() -> void:
    _compact_enemy_ranks()
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
        var targets := _legal_enemy_targets(enemy)
        if targets.is_empty():
            targets = GameState.alive_heroes()
        if targets.is_empty():
            finish_defeat()
            return
        var target: Dictionary = targets[randi() % targets.size()]
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

        var riposte_chance := int(target_bonuses.get("riposte_chance", 0))
        if EquipmentManager.has_effect(str(target.get("id", "")), "steadfast_counter"):
            riposte_chance += 10
        if riposte_chance > 0 and randi_range(1, 100) <= riposte_chance:
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - 4)
            GameState.add_log("%s riposte contre %s." % [str(target.get("name", "Héros")), str(enemy.get("name", "Ennemi"))])
        GameState.add_log("%s (rang %d) frappe %s (rang %d) pour %d dégâts." % [
            str(enemy.get("name", "Ennemi")), _enemy_rank(enemy), str(target.get("name", "Héros")), _hero_rank(target), damage
        ])

    if GameState.alive_heroes().is_empty():
        finish_defeat()
        return
    _reset_round_state()
    battle_locked = false
    show_screen("combat")

func _legal_enemy_targets(enemy: Dictionary) -> Array:
    var targets: Array = []
    if bool(enemy.get("boss", false)) or bool(enemy.get("is_boss", false)):
        return GameState.alive_heroes()
    var enemy_rank := _enemy_rank(enemy)
    var allowed := [1, 2] if enemy_rank <= 2 else [2, 3, 4]
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        if allowed.has(_hero_rank(hero)):
            targets.append(hero)
    return targets

func _frontline_wall_active() -> bool:
    var malvor := _hero_by_id("malvor")
    var darius := _hero_by_id("darius")
    if malvor.is_empty() or darius.is_empty() or int(malvor.get("hp", 0)) <= 0 or int(darius.get("hp", 0)) <= 0:
        return false
    var ranks := [_hero_rank(malvor), _hero_rank(darius)]
    ranks.sort()
    return ranks == [1, 2]

func _veil_concord_active() -> bool:
    var aurelien := _hero_by_id("aurelien")
    var lysandra := _hero_by_id("lysandra")
    if aurelien.is_empty() or lysandra.is_empty() or int(aurelien.get("hp", 0)) <= 0 or int(lysandra.get("hp", 0)) <= 0:
        return false
    return absi(_hero_rank(aurelien) - _hero_rank(lysandra)) == 1

func _opening_exploit_active() -> bool:
    var malvor := _hero_by_id("malvor")
    var aurelien := _hero_by_id("aurelien")
    if malvor.is_empty() or aurelien.is_empty() or int(malvor.get("hp", 0)) <= 0 or int(aurelien.get("hp", 0)) <= 0:
        return false
    return _hero_rank(malvor) == _hero_rank(aurelien) - 1

func _active_synergy_names() -> Array[String]:
    var names: Array[String] = []
    if _frontline_wall_active():
        names.append("Mur de la Veille")
    if _veil_concord_active():
        names.append("Concorde du Voile")
    if _opening_exploit_active():
        names.append("Faille préparée")
    return names
