extends "res://scripts/ui/main_v5.gd"

# Combat v6 : les familles ennemies possèdent leurs propres manœuvres de rang.
# Les membres perdus peuvent neutraliser ou transformer ces comportements.
var enemy_family_data: Dictionary = {}

func _ready() -> void:
    _load_enemy_family_data()
    super._ready()

func _load_enemy_family_data() -> void:
    if not enemy_family_data.is_empty():
        return
    var text := FileAccess.get_file_as_string("res://data/enemy_family_tactics.json")
    var parsed = JSON.parse_string(text)
    enemy_family_data = parsed if parsed is Dictionary else {}

func show_combat() -> void:
    super.show_combat()
    _decorate_enemy_family_status()

func _decorate_enemy_family_status() -> void:
    if GameState.battle_enemies.is_empty():
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var enemy: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(enemy.get("hp", 0)) <= 0:
        return
    var family_id := _family_for_enemy(enemy)
    if family_id == "":
        return
    var family := _family_rule(family_id)
    var required := _family_required_part(enemy, family_id, family)
    var active := required == "" or _part_is_available(enemy, required)
    var state_text := "ACTIVE" if active else "NEUTRALISÉE"
    var label := make_label("FAMILLE · %s · %s" % [str(family.get("name", family_id)), state_text], 11, MUTED)
    label.position = Vector2(760, 172)
    label.size = Vector2(470, 24)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(label)

func enemy_turn() -> void:
    _apply_enemy_family_maneuvers()
    super.enemy_turn()

func _apply_enemy_family_maneuvers() -> void:
    _load_enemy_family_data()
    for enemy_value in GameState.alive_enemies():
        var enemy: Dictionary = enemy_value
        var family_id := _family_for_enemy(enemy)
        if family_id == "":
            continue
        var family := _family_rule(family_id)
        var cadence := maxi(1, int(family.get("cadence", 3)))
        if round_number % cadence != 0:
            continue
        var required := _family_required_part(enemy, family_id, family)
        if required != "" and not _part_is_available(enemy, required):
            continue
        var effect := str(family.get("effect", ""))
        if _execute_family_effect(effect):
            GameState.add_log("%s — %s perturbe les rangs." % [str(enemy.get("name", "L'ennemi")), str(family.get("name", "Manœuvre de famille"))])

func _family_for_enemy(enemy: Dictionary) -> String:
    _load_enemy_family_data()
    if not _boss_maneuver_for(enemy).is_empty():
        return ""
    if bool(enemy.get("is_miniboss", false)):
        return "elite"
    if bool(enemy.get("is_boss", false)) or bool(enemy.get("boss", false)) or bool(enemy.get("deep_vestige_boss", false)):
        return "boss"
    var enemy_id := int(enemy.get("id", -1))
    var groups: Dictionary = enemy_family_data.get("generic_enemy_ids", {})
    for family_id_value in groups.keys():
        var family_id := str(family_id_value)
        var ids: Array = groups.get(family_id, [])
        if ids.has(enemy_id):
            return family_id
    return "humanoid"

func _family_rule(family_id: String) -> Dictionary:
    return enemy_family_data.get("families", {}).get(family_id, {})

func _family_required_part(enemy: Dictionary, family_id: String, family: Dictionary) -> String:
    if family_id == "boss":
        var encounter_id := _encounter_id(enemy)
        var overrides: Dictionary = enemy_family_data.get("boss_required_part_overrides", {})
        if encounter_id != "" and overrides.has(encounter_id):
            return str(overrides.get(encounter_id, ""))
    return str(family.get("required_part", ""))

func _execute_family_effect(effect: String) -> bool:
    match effect:
        "push_front_hero_1":
            var front := _hero_at_rank(1)
            return not front.is_empty() and _move_hero_relative(front, 1)
        "pull_rear_hero_1":
            var rear := _hero_at_rank(4)
            return not rear.is_empty() and _move_hero_relative(rear, -1)
        "swap_middle_heroes":
            return _swap_hero_ranks(2, 3)
        "swap_outer_heroes":
            return _swap_hero_ranks(1, 4)
    return false

func _report_dismemberment(result: Dictionary) -> void:
    super._report_dismemberment(result)
    if not bool(result.get("severed", false)) or dismemberment_target_context.is_empty():
        return
    var enemy := dismemberment_target_context
    var family_id := _family_for_enemy(enemy)
    if family_id == "":
        return
    var family := _family_rule(family_id)
    var required := _family_required_part(enemy, family_id, family)
    var part_id := str(result.get("part_id", ""))
    if required == "" or required != part_id:
        return
    _apply_family_limb_reaction(enemy, family_id, str(family.get("lost_reaction", "lose_maneuver")))

func _apply_family_limb_reaction(enemy: Dictionary, family_id: String, reaction: String) -> void:
    var family := _family_rule(family_id)
    match reaction:
        "retreat_self_1":
            _move_enemy_relative(enemy, 1)
            GameState.add_log("RÉACTION DE FAMILLE — privé de sa charge, %s recule." % str(enemy.get("name", "l'ennemi")))
        "pull_self_to_front":
            _move_enemy_to_rank(enemy, 1)
            GameState.add_log("RÉACTION DE FAMILLE — sans ancrage, %s dérive vers la première ligne." % str(enemy.get("name", "l'ennemi")))
        "none":
            pass
        _:
            GameState.add_log("RÉACTION DE FAMILLE — %s perd sa manœuvre « %s »." % [str(enemy.get("name", "L'ennemi")), str(family.get("name", family_id))])
