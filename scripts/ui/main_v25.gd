extends "res://scripts/ui/main_v24.gd"

# v25 : la campagne et les donjons utilisent désormais deux politiques de niveau
# volontairement différentes. La campagne suit le niveau moyen des héros ; un
# donjon conserve son niveau requis et ses niveaux ennemis fixes, quelle que soit
# la puissance actuelle du groupe.

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

func _start_roguelike_room_battle(room: Dictionary) -> void:
    GameState.battle_enemies = []
    var room_type: String = str(room.get("type", "combat"))
    var depth: int = int(room.get("depth", 1))
    var ids: Array[int] = [1, 8, 10]
    if room_type == "elite":
        ids = [10, 10, 8]
    elif room_type == "ambush":
        ids = [8, 8, 1]
    elif room_type == "creature":
        ids = [10]
    elif room_type == "boss":
        ids = [38]

    var risk: Dictionary = ExpeditionManager.current_risk_profile()
    var fixed_level: int = level_scaling_policy.dungeon_enemy_level(depth, room_type)
    for enemy_id in ids:
        var enemy: Dictionary = DataLoader.find_by_id(DataLoader.enemies, enemy_id).duplicate(true)
        if enemy.is_empty():
            continue
        level_scaling_policy.apply_dungeon_scaling(enemy, depth, room_type, risk)
        enemy["guarding"] = false
        if room_type == "boss":
            enemy["boss"] = true
            enemy["is_boss"] = true
        GameState.battle_enemies.append(enemy)
        ExpeditionManager.record_enemy_knowledge(str(enemy.get("id", enemy_id)), false)

    battle_locked = false
    selected_enemy = 0
    GameState.add_log("La salle verrouille ses issues. Ennemis de donjon : niveau fixe %d." % fixed_level)
    GameState.request_screen("combat")
