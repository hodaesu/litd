extends "res://scripts/ui/main_v7.gd"

# Combat v8 : IA adaptative après mutilation.
var post_mutilation_ai: Dictionary = {}

func _ready() -> void:
    _load_post_mutilation_ai()
    super._ready()

func _load_post_mutilation_ai() -> void:
    if not post_mutilation_ai.is_empty():
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_post_mutilation_ai.json"))
    post_mutilation_ai = parsed if parsed is Dictionary else {}

func enemy_turn() -> void:
    _apply_adaptive_enemy_states()
    super.enemy_turn()

func _apply_adaptive_enemy_states() -> void:
    _load_post_mutilation_ai()
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        AnatomyRuntime.ensure_state(enemy)
        _ensure_adaptive_baseline(enemy)
        var lost: Array = enemy.get("dismembered_parts", [])
        var injuries: Dictionary = enemy.get("anatomy_injuries", {})
        if lost.is_empty() and injuries.is_empty():
            _restore_adaptive_baseline(enemy)
            continue
        var family_id := _adaptive_family(enemy)
        var rule: Dictionary = post_mutilation_ai.get("families", {}).get(family_id, post_mutilation_ai.get("families", {}).get("humanoid", {}))
        var hp_ratio := float(enemy.get("hp", 0)) / float(maxi(1, int(enemy.get("max_hp", 1))))
        if _can_panic_flee(enemy) and hp_ratio <= float(post_mutilation_ai.get("global", {}).get("panic_hp_ratio", 0.25)) and lost.size() >= int(post_mutilation_ai.get("global", {}).get("panic_lost_parts", 2)):
            if randi_range(1, 100) <= int(post_mutilation_ai.get("global", {}).get("flee_chance_regular", 35)):
                enemy["fled"] = true
                enemy["hp"] = 0
                GameState.add_log("%s, mutilé et acculé, rompt le combat et fuit." % str(enemy.get("name", "L'ennemi")))
                continue
        _apply_adaptive_rule(enemy, family_id, rule)

func _ensure_adaptive_baseline(enemy: Dictionary) -> void:
    if not enemy.has("adaptive_original_damage"):
        enemy["adaptive_original_damage"] = enemy.get("damage", [1, 1]).duplicate(true)
    if not enemy.has("adaptive_original_fear"):
        enemy["adaptive_original_fear"] = int(enemy.get("fear", 0))

func _restore_adaptive_baseline(enemy: Dictionary) -> void:
    if enemy.has("adaptive_original_damage"):
        enemy["damage"] = enemy.get("adaptive_original_damage", [1, 1]).duplicate(true)
    if enemy.has("adaptive_original_fear"):
        enemy["fear"] = int(enemy.get("adaptive_original_fear", 0))
    enemy["adaptive_ai_state"] = "normal"
    enemy["protected_anatomy_part"] = ""

func _apply_adaptive_rule(enemy: Dictionary, family_id: String, rule: Dictionary) -> void:
    var old_state := str(enemy.get("adaptive_ai_state", "normal"))
    var new_state := str(rule.get("state", "wounded"))
    enemy["adaptive_ai_state"] = new_state
    enemy["adaptive_skill_mode"] = new_state
    enemy["guarding"] = bool(rule.get("guard", false))

    var base_damage: Array = enemy.get("adaptive_original_damage", enemy.get("damage", [1, 1]))
    var damage_multiplier := float(rule.get("damage_multiplier", 1.0)) * _lost_attack_multiplier(enemy)
    if base_damage.size() >= 2:
        enemy["damage"] = [
            maxi(1, int(round(float(base_damage[0]) * damage_multiplier))),
            maxi(1, int(round(float(base_damage[1]) * damage_multiplier)))
        ]
    var base_fear := int(enemy.get("adaptive_original_fear", enemy.get("fear", 0)))
    enemy["fear"] = maxi(0, int(round(float(base_fear) * float(rule.get("fear_multiplier", 1.0)) * _lost_fear_multiplier(enemy))))

    var move := int(rule.get("self_move", 0))
    if move != 0:
        _move_enemy_relative(enemy, move)
    if bool(rule.get("protect_remaining", false)):
        enemy["protected_anatomy_part"] = _best_part_to_protect(enemy)
    else:
        enemy["protected_anatomy_part"] = ""

    if old_state != new_state:
        GameState.add_log("IA ADAPTATIVE — %s adopte « %s » après ses blessures." % [str(enemy.get("name", "L'ennemi")), new_state])

func _adaptive_family(enemy: Dictionary) -> String:
    if bool(enemy.get("is_miniboss", false)):
        return "elite"
    if bool(enemy.get("is_boss", false)) or bool(enemy.get("boss", false)) or bool(enemy.get("deep_vestige_boss", false)) or str(enemy.get("chapter_boss_id", "")) != "":
        return "boss"
    var family := _family_for_enemy(enemy)
    return family if family != "" else "humanoid"

func _can_panic_flee(enemy: Dictionary) -> bool:
    return not bool(enemy.get("is_miniboss", false)) and not bool(enemy.get("is_boss", false)) and not bool(enemy.get("boss", false)) and not bool(enemy.get("deep_vestige_boss", false)) and str(enemy.get("chapter_boss_id", "")) == ""

func _lost_attack_multiplier(enemy: Dictionary) -> float:
    var multiplier := 1.0
    var penalty := float(post_mutilation_ai.get("global", {}).get("attack_part_damage_multiplier", 0.78))
    for part_id_value in enemy.get("dismembered_parts", []):
        var part := AnatomyRuntime.part_definition(enemy, str(part_id_value))
        var tags: Array = part.get("tags", [])
        if tags.has("attack") or tags.has("weapon"):
            multiplier *= penalty
    return multiplier

func _lost_fear_multiplier(enemy: Dictionary) -> float:
    var multiplier := 1.0
    var penalty := float(post_mutilation_ai.get("global", {}).get("fear_part_multiplier", 0.80))
    for part_id_value in enemy.get("dismembered_parts", []):
        var part := AnatomyRuntime.part_definition(enemy, str(part_id_value))
        var tags: Array = part.get("tags", [])
        if tags.has("fear") or tags.has("sensor"):
            multiplier *= penalty
    return multiplier

func _best_part_to_protect(enemy: Dictionary) -> String:
    var rows := AnatomyRuntime.anatomy_status(enemy)
    var best_id := ""
    var best_ratio := 2.0
    for row_value in rows:
        var row: Dictionary = row_value
        if str(row.get("state", "")) == "lost":
            continue
        var ratio := float(row.get("trauma", 0)) / float(maxi(1, int(row.get("threshold", 1))))
        if ratio < best_ratio:
            best_ratio = ratio
            best_id = str(row.get("id", ""))
    return best_id
