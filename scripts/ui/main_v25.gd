extends "res://scripts/ui/main_v24.gd"

# v25 : la campagne et les donjons utilisent désormais deux politiques de niveau
# volontairement différentes. La campagne suit le niveau moyen des héros ; un
# donjon conserve son niveau requis et ses niveaux ennemis fixes, quelle que soit
# la puissance actuelle du groupe.
#
# Cette couche porte aussi les garde-fous d'équilibrage transversaux : cadence de
# Lumière, efficacité de soin par rôle, anti-stall et résistance aux chaînes de stun.

const LEVEL_SCALING_POLICY := preload("res://scripts/core/level_scaling_policy.gd")
var level_scaling_policy := LEVEL_SCALING_POLICY.new()

func _render_roguelike_departure() -> void:
    super._render_roguelike_departure()
    var profile: Dictionary = level_scaling_policy.dungeon_profile()
    var gate: Dictionary = level_scaling_policy.dungeon_entry_check()
    var base_level: int = int(profile.get("enemy_base_level", 3))
    var per_depth: int = int(profile.get("enemy_level_per_depth", 0))
    var max_depth: int = int(level_scaling_policy._load_roguelike_rules().get("depth", {}).get("max", 5))
    var highest_normal_level: int = base_level + maxi(0, max_depth - 1) * per_depth
    var info_color: Color = GOLD if bool(gate.get("allowed", false)) else RED
    var info := make_label(
        "%s · NIVEAU REQUIS %d\nNiveau du groupe %d · Ennemis fixes niv. %d à %d (+ élites/boss)\nLe donjon ne s'adapte jamais au niveau des héros." % [
            str(profile.get("title", "Donjon")),
            int(gate.get("required_level", 1)),
            int(gate.get("party_level", 1)),
            base_level,
            highest_normal_level
        ],
        14,
        info_color
    )
    info.position = Vector2(735, 202)
    info.size = Vector2(500, 70)
    content.add_child(info)

    for node_value in content.find_children("*", "Button", true, false):
        var button: Button = node_value as Button
        if button != null and button.text == "DESCENDRE DANS LE DONJON":
            button.disabled = not bool(gate.get("allowed", false))
            if button.disabled:
                button.tooltip_text = "Niveau moyen requis : %d" % int(gate.get("required_level", 1))

func _start_roguelike_expedition() -> void:
    var gate: Dictionary = level_scaling_policy.dungeon_entry_check()
    if not bool(gate.get("allowed", false)):
        GameState.add_log("Le groupe est niveau %d. Ce donjon exige le niveau %d." % [
            int(gate.get("party_level", 1)),
            int(gate.get("required_level", 1))
        ])
        show_screen("expedition")
        return
    super._start_roguelike_expedition()

func _enter_roguelike_room(room_id: String) -> void:
    # Le runtime historique consomme une unité à chaque nouvelle salle. Le pass
    # d'équilibrage garde ce comportement mais compense les salles intermédiaires,
    # ce qui rend room_decay_interval effectif sans casser les sauvegardes anciennes.
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime != null:
        var active_run: Dictionary = runtime.active_run
        var visited: Array = active_run.get("visited", [])
        if not visited.has(room_id):
            var light_rules: Dictionary = level_scaling_policy._load_roguelike_rules().get("light", {})
            var interval := maxi(1, int(light_rules.get("room_decay_interval", 1)))
            var next_room_count := int(active_run.get("rooms_cleared", 0)) + 1
            if interval > 1 and next_room_count % interval != 0:
                var decay := maxi(0, int(light_rules.get("room_decay", 1)))
                ExpeditionManager.inventory["light"] = int(ExpeditionManager.inventory.get("light", 0)) + decay
    super._enter_roguelike_room(room_id)

func hero_bonuses(hero: Dictionary) -> Dictionary:
    var result: Dictionary = super.hero_bonuses(hero)
    # Tous les héros gardent l'action de soin comme solution d'urgence, mais les
    # spécialistes restent nettement meilleurs. Cela évite quatre soins de 18 PV
    # par round tout en conservant les bonus d'équipement et les synergies.
    var balance: Dictionary = level_scaling_policy.combat_balance()
    var bases: Dictionary = balance.get("class_heal_base", {})
    var class_id := str(hero.get("class_id", ""))
    var desired_base := float(bases.get(class_id, bases.get("default", 6)))
    var original_power := float(result.get("healing_power", 0))
    var class_ratio := desired_base / 18.0
    var stall_start := int(balance.get("stall_round_start", 5))
    var stall_decay := float(balance.get("stall_healing_decay_per_round", 0.12))
    var stall_floor := float(balance.get("stall_healing_efficiency_floor", 0.50))
    var extra_rounds := maxi(0, round_number - stall_start)
    var stall_efficiency := maxf(stall_floor, 1.0 - float(extra_rounds) * stall_decay)
    var final_multiplier := class_ratio * (1.0 + original_power / 100.0) * stall_efficiency
    result["healing_power"] = int(round((final_multiplier - 1.0) * 100.0))
    return result

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    var living: Array = GameState.alive_enemies()
    if living.is_empty():
        super._hero_attack_action(hero, action)
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp", 0)) <= 0:
        target = living[0]
    var was_stunned := bool(target.get("stunned", false))
    super._hero_attack_action(hero, action)
    if was_stunned or not bool(target.get("stunned", false)):
        return

    var recovery_until := int(target.get("stun_recovery_until_round", -1))
    var balance := level_scaling_policy.combat_balance()
    var chain_resistance := int(balance.get("stun_chain_resistance", 35))
    var is_boss := bool(target.get("boss", false)) or bool(target.get("is_boss", false)) or bool(target.get("deep_vestige_boss", false))
    if is_boss:
        chain_resistance = int(balance.get("boss_stun_chain_resistance", 55))
    if round_number <= recovery_until and randi_range(1, 100) <= chain_resistance:
        target["stunned"] = false
        GameState.add_log("%s résiste à une nouvelle chaîne d'étourdissement." % str(target.get("name", "L'ennemi")))
        return
    target["stun_recovery_until_round"] = round_number + 1

func _encounter_group_size(encounter_class: String, encounter_key: String) -> int:
    var balance: Dictionary = level_scaling_policy.combat_balance()
    var ranges: Dictionary = balance.get("encounter_group_sizes", {})
    var bounds_value: Variant = ranges.get(encounter_class, [4, 4])
    if not (bounds_value is Array):
        return 1
    var bounds: Array = bounds_value
    var minimum := maxi(1, int(bounds[0]) if bounds.size() >= 1 else 1)
    var maximum := maxi(minimum, int(bounds[1]) if bounds.size() >= 2 else minimum)
    if minimum == maximum:
        return minimum
    var run_seed := 0
    if ExpeditionManager.roguelike_runtime != null:
        run_seed = int(ExpeditionManager.roguelike_runtime.active_run.get("seed", 0))
    var signature := "%s:%s:%d" % [encounter_class, encounter_key, run_seed]
    return minimum + abs(signature.hash()) % (maximum - minimum + 1)

func _start_roguelike_room_battle(room: Dictionary) -> void:
    GameState.battle_enemies = []
    var room_type: String = str(room.get("type", "combat"))
    var depth: int = int(room.get("depth", 1))
    var room_key := str(room.get("id", room.get("room_id", "%s_%d" % [room_type, depth])))
    var encounter_class := "normal"
    if room_type == "elite":
        encounter_class = "elite"
    elif room_type == "miniboss":
        encounter_class = "miniboss"
    elif room_type == "boss":
        encounter_class = "boss"

    # Contrat de composition LITD : 4 ennemis simples, 2-3 élites,
    # 1-2 ennemis autour d'un mini-boss, et un boss toujours seul.
    var ids: Array[int] = []
    if room_type == "creature":
        ids = [10]
    else:
        var group_size := _encounter_group_size(encounter_class, room_key)
        var templates: Array[int] = [1, 8]
        if encounter_class == "elite":
            templates = [10, 8]
        elif encounter_class == "miniboss":
            templates = [30, 8]
        elif encounter_class == "boss":
            templates = [38]
        for index in range(group_size):
            ids.append(templates[index % templates.size()])

    var risk: Dictionary = ExpeditionManager.current_risk_profile()
    var fixed_level: int = level_scaling_policy.dungeon_enemy_level(depth, room_type)
    for enemy_index in range(ids.size()):
        var enemy_id: int = ids[enemy_index]
        var enemy: Dictionary = DataLoader.find_by_id(DataLoader.enemies, enemy_id).duplicate(true)
        if enemy.is_empty():
            continue
        var scaling_room_type := room_type
        if room_type == "miniboss" and enemy_index > 0:
            scaling_room_type = "combat"
        level_scaling_policy.apply_dungeon_scaling(enemy, depth, scaling_room_type, risk)
        if room_type != "creature":
            level_scaling_policy.apply_encounter_member_scaling(enemy, encounter_class)
        enemy["guarding"] = false
        if room_type == "miniboss" and enemy_index == 0:
            enemy["is_miniboss"] = true
        if room_type == "boss":
            enemy["boss"] = true
            enemy["is_boss"] = true
        GameState.battle_enemies.append(enemy)
        ExpeditionManager.record_enemy_knowledge(str(enemy.get("id", enemy_id)), false)

    battle_locked = false
    selected_enemy = 0
    GameState.add_log("La salle verrouille ses issues. %d ennemi(s) · niveau fixe %d." % [GameState.battle_enemies.size(), fixed_level])
    GameState.request_screen("combat")
