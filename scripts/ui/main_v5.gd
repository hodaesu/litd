extends "res://scripts/ui/main_v4.gd"

# Combat v5 : déplacements forcés + démembrements fonctionnels.
# Les rangs restent ceux du v3 et les démembrements ceux du v4.
var displacement_data: Dictionary = {}
var dismemberment_target_context: Dictionary = {}

func _ready() -> void:
    _load_displacement_data()
    super._ready()

func _load_displacement_data() -> void:
    if not displacement_data.is_empty():
        return
    var text := FileAccess.get_file_as_string("res://data/combat_displacement.json")
    var parsed = JSON.parse_string(text)
    displacement_data = parsed if parsed is Dictionary else {}

func show_combat() -> void:
    _ensure_tactical_state()
    _apply_fear_recoil_once()
    super.show_combat()
    _decorate_displacement_status()

func _decorate_displacement_status() -> void:
    if GameState.battle_enemies.is_empty():
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var enemy: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(enemy.get("hp", 0)) <= 0:
        return
    var maneuver := _boss_maneuver_for(enemy)
    if maneuver.is_empty():
        return
    var required := str(maneuver.get("part_required", ""))
    var active := _part_is_available(enemy, required)
    var text := "%s · %s" % [
        str(maneuver.get("name", "Manœuvre de formation")),
        "ACTIVE" if active else "NEUTRALISÉE PAR DÉMEMBREMENT"
    ]
    var label := make_label(text, 11, GOLD if active else MUTED)
    label.position = Vector2(760, 145)
    label.size = Vector2(470, 26)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(label)

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    var target := _selected_target_for(hero, action)
    if target.is_empty():
        return
    dismemberment_target_context = target
    super._hero_attack_action(hero, action)
    dismemberment_target_context = {}
    if int(target.get("hp", 0)) > 0:
        _apply_hero_forced_movement(hero, target, action)

func _technique_damage(hero: Dictionary, target: Dictionary, power: float) -> int:
    dismemberment_target_context = target
    var damage := super._technique_damage(hero, target, power)
    dismemberment_target_context = {}
    return damage

func _report_dismemberment(result: Dictionary) -> void:
    super._report_dismemberment(result)
    if not bool(result.get("severed", false)) or dismemberment_target_context.is_empty():
        return
    var part_id := str(result.get("part_id", ""))
    _apply_limb_displacement(dismemberment_target_context, part_id)
    if bool(result.get("boss", false)):
        var maneuver := _boss_maneuver_for(dismemberment_target_context)
        if not maneuver.is_empty() and str(maneuver.get("part_required", "")) == part_id:
            GameState.add_log("PHASE ALTÉRÉE — %s" % str(maneuver.get("lost_part_transform", "La manœuvre de formation du boss est neutralisée.")))

func _apply_hero_forced_movement(hero: Dictionary, target: Dictionary, action: String) -> void:
    if action != "heavy":
        return
    var rules: Dictionary = displacement_data.get("hero_forced_movement", {})
    var hero_rule: Dictionary = rules.get(str(hero.get("id", "")), {})
    var effect := str(hero_rule.get(action, ""))
    match effect:
        "push_enemy_1":
            if _move_enemy_relative(target, 1):
                GameState.add_log("%s repousse %s d'un rang." % [str(hero.get("name", "Le héros")), str(target.get("name", "la cible"))])
        "pull_enemy_1":
            if _move_enemy_relative(target, -1):
                GameState.add_log("%s attire %s d'un rang vers l'avant." % [str(hero.get("name", "Le héros")), str(target.get("name", "la cible"))])

func _apply_limb_displacement(enemy: Dictionary, part_id: String) -> void:
    var effect := str(displacement_data.get("limb_displacement", {}).get(part_id, ""))
    match effect:
        "retreat_enemy_1":
            if _move_enemy_relative(enemy, 1):
                GameState.add_log("La perte de stabilité fait reculer %s dans sa formation." % str(enemy.get("name", "l'ennemi")))
        "pull_enemy_to_front":
            if _move_enemy_to_rank(enemy, 1):
                GameState.add_log("Privé de son ancrage, %s est ramené en première ligne." % str(enemy.get("name", "l'ennemi")))

func _enemy_at_rank(rank: int) -> Dictionary:
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        if _enemy_rank(enemy) == rank:
            return enemy
    return {}

func _move_enemy_relative(enemy: Dictionary, delta: int) -> bool:
    if int(enemy.get("hp", 0)) <= 0:
        return false
    var current := _enemy_rank(enemy)
    var destination := clampi(current + delta, 1, 4)
    if destination == current:
        return false
    var other := _enemy_at_rank(destination)
    enemy["battle_rank"] = destination
    if not other.is_empty() and other != enemy:
        other["battle_rank"] = current
    return true

func _move_enemy_to_rank(enemy: Dictionary, rank: int) -> bool:
    var destination := clampi(rank, 1, 4)
    var current := _enemy_rank(enemy)
    if destination == current:
        return false
    var other := _enemy_at_rank(destination)
    enemy["battle_rank"] = destination
    if not other.is_empty() and other != enemy:
        other["battle_rank"] = current
    return true

func _apply_fear_recoil_once() -> void:
    var rule: Dictionary = displacement_data.get("fear_recoil", {})
    var threshold := int(rule.get("threshold", 100))
    var distance := maxi(1, int(rule.get("ranks", 1)))
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        if int(hero.get("fear", 0)) < threshold:
            continue
        if int(hero.get("fear_recoil_round", -1)) == round_number:
            continue
        hero["fear_recoil_round"] = round_number
        var moved := false
        for _step in range(distance):
            moved = _move_hero_relative(hero, 1) or moved
        if moved:
            GameState.add_log("Sous l'effet de la Peur, %s recule dans la formation." % str(hero.get("name", "Un héros")))

func _move_hero_relative(hero: Dictionary, delta: int) -> bool:
    if int(hero.get("hp", 0)) <= 0:
        return false
    var current := _hero_rank(hero)
    var destination := clampi(current + delta, 1, 4)
    if destination == current:
        return false
    var other := _hero_at_rank(destination)
    hero["battle_rank"] = destination
    if not other.is_empty() and other != hero:
        other["battle_rank"] = current
    return true

func enemy_turn() -> void:
    _apply_boss_formation_maneuvers()
    super.enemy_turn()

func _apply_boss_formation_maneuvers() -> void:
    _load_displacement_data()
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        var maneuver := _boss_maneuver_for(enemy)
        if maneuver.is_empty():
            continue
        var cadence := maxi(1, int(maneuver.get("cadence", 2)))
        if round_number % cadence != 0:
            continue
        var required := str(maneuver.get("part_required", ""))
        if not _part_is_available(enemy, required):
            continue
        var changed := _execute_boss_maneuver(str(maneuver.get("effect", "")))
        if changed:
            GameState.add_log("%s — %s désorganise la formation." % [str(enemy.get("name", "Le boss")), str(maneuver.get("name", "Manœuvre"))])

func _boss_maneuver_for(enemy: Dictionary) -> Dictionary:
    var encounter_id := _encounter_id(enemy)
    if encounter_id == "":
        return {}
    return displacement_data.get("boss_maneuvers", {}).get(encounter_id, {})

func _encounter_id(enemy: Dictionary) -> String:
    for key in ["chapter_boss_id", "chapter_miniboss_id", "encounter_id"]:
        var value := str(enemy.get(key, ""))
        if value != "":
            return value
    return ""

func _part_is_available(enemy: Dictionary, part_id: String) -> bool:
    if part_id == "":
        return true
    var lost: Array = enemy.get("dismembered_parts", [])
    return not lost.has(part_id) and not bool(enemy.get("dismemberment_%s" % part_id, false))

func _execute_boss_maneuver(effect: String) -> bool:
    match effect:
        "push_front_hero_1":
            var front := _hero_at_rank(1)
            return not front.is_empty() and _move_hero_relative(front, 1)
        "swap_outer_heroes":
            return _swap_hero_ranks(1, 4)
        "rotate_party_right":
            return _rotate_party_right()
        "invert_pairs":
            var first := _swap_hero_ranks(1, 2)
            var second := _swap_hero_ranks(3, 4)
            return first or second
    return false

func _swap_hero_ranks(rank_a: int, rank_b: int) -> bool:
    var a := _hero_at_rank(rank_a)
    var b := _hero_at_rank(rank_b)
    if a.is_empty() or b.is_empty():
        return false
    a["battle_rank"] = rank_b
    b["battle_rank"] = rank_a
    return true

func _rotate_party_right() -> bool:
    var heroes: Array = []
    for rank in range(1, 5):
        var hero := _hero_at_rank(rank)
        if not hero.is_empty():
            heroes.append({"hero": hero, "rank": rank})
    if heroes.size() < 2:
        return false
    for entry_value in heroes:
        var entry: Dictionary = entry_value
        var new_rank := int(entry.get("rank", 1)) + 1
        if new_rank > 4:
            new_rank = 1
        var hero: Dictionary = entry.get("hero", {})
        hero["battle_rank"] = new_rank
    return true
