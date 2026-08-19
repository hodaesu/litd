extends "res://scripts/ui/main_v16.gd"

# v17 : psychologie sociale du combat.
# Les ennemis peuvent exploiter la peur visible, les compagnons peuvent intervenir
# pour protéger un allié fragile, et les boss obtiennent des réactions contextuelles.

func start_random_battle() -> void:
    PsychologyCombatDirector.reset_runtime()
    super.start_random_battle()

func _select_enemy_target(enemy: Dictionary, targets: Array) -> Dictionary:
    var target := PsychologyCombatDirector.select_enemy_target(enemy, targets, round_number)
    if target.is_empty():
        return super._select_enemy_target(enemy, targets)
    return target

func _after_enemy_attack(enemy: Dictionary, target: Dictionary, damage: int, fear_gain: int) -> void:
    super._after_enemy_attack(enemy, target, damage, fear_gain)
    var pressure := PsychologyCombatDirector.apply_enemy_pressure(enemy, target, round_number)
    if pressure.is_empty():
        return
    var line := str(pressure.get("line", ""))
    if line != "":
        GameState.add_log(line)
    var extra_fear := int(pressure.get("extra_fear", 0))
    if extra_fear > 0:
        GameState.add_log("PRESSION PSYCHOLOGIQUE — %s gagne %d Peur supplémentaire." % [str(target.get("name", "Le héros")), extra_fear])

func _before_companion_turn() -> void:
    super._before_companion_turn()
    var intervention := PsychologyCombatDirector.companion_intervention(round_number)
    if intervention.is_empty():
        return
    var line := str(intervention.get("line", ""))
    if line != "":
        GameState.add_log(line)
    if bool(intervention.get("guard", false)):
        GameState.add_log("INTERVENTION — le compagnon couvre %s pour le prochain impact." % _hero_name(str(intervention.get("hero_id", ""))))

func show_combat() -> void:
    super.show_combat()
    var hero := _active_round_hero()
    if hero.is_empty():
        return
    var threat := _highest_threat_for(hero)
    if threat.is_empty():
        return
    var label := make_label(
        "MENACE · %s cherche à exploiter cette peur" % str(threat.get("name", "Un ennemi")),
        10,
        GOLD if int(hero.get("fear", 0)) >= 75 else MUTED
    )
    label.position = Vector2(475, 158)
    label.size = Vector2(480, 22)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(label)

func _highest_threat_for(hero: Dictionary) -> Dictionary:
    var best: Dictionary = {}
    var best_score := -INF
    var heroes := GameState.alive_heroes()
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        var chosen := PsychologyCombatDirector.select_enemy_target(enemy, heroes, round_number)
        if chosen.is_empty() or str(chosen.get("id", "")) != str(hero.get("id", "")):
            continue
        var score := PsychologyCombatDirector.target_score(enemy, hero, round_number)
        if score > best_score:
            best = enemy
            best_score = score
    return best

func _hero_name(hero_id: String) -> String:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return str(hero.get("name", "le héros"))
    return "le héros"
