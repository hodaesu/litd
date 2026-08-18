extends Node

signal ash_witness_phase_changed(phase: int)

var active := false
var phase := 0
var signature_used := false
var _updating := false

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_combat_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)
    GameState.state_changed.connect(_on_state_changed)

func _on_combat_started(encounter_id: String, _encounter_type: String) -> void:
    if encounter_id != "c01_boss_ash_witness":
        return
    active = true
    phase = 1
    signature_used = false
    _mark_boss_phase(1)
    GameState.add_log("Le Témoin des Cendres reproduit des gestes d'une vie disparue.")
    ash_witness_phase_changed.emit(1)

func _on_combat_finished(encounter_id: String, _victory: bool, _loot: Dictionary) -> void:
    if encounter_id != "c01_boss_ash_witness":
        return
    active = false
    phase = 0
    signature_used = false

func _on_state_changed() -> void:
    if not active or _updating:
        return
    var boss := _boss()
    if boss.is_empty() or int(boss.get("max_hp", 0)) <= 0:
        return
    var ratio := float(boss.get("hp", 0)) / float(boss.get("max_hp", 1))
    if ratio <= 0.25 and phase < 3:
        _enter_phase_three(boss)
    elif ratio <= 0.60 and phase < 2:
        _enter_phase_two(boss)

func _enter_phase_two(boss: Dictionary) -> void:
    _updating = true
    phase = 2
    boss["chapter_phase"] = 2
    boss["damage"] = [9, 14]
    boss["fear"] = 8
    GameState.add_log("Le réel glisse autour du Témoin. La Lumière devient instable.")
    if not signature_used:
        signature_used = true
        GameState.light = maxi(0, GameState.light - 15)
        for hero_value in GameState.alive_heroes():
            var hero: Dictionary = hero_value
            hero["fear"] = mini(100, int(hero.get("fear", 0)) + 6)
        GameState.add_log("Dernier Souvenir du Jour : le monde d'avant réapparaît puis se brise.")
    ash_witness_phase_changed.emit(2)
    _updating = false

func _enter_phase_three(boss: Dictionary) -> void:
    _updating = true
    phase = 3
    boss["chapter_phase"] = 3
    boss["damage"] = [7, 11]
    boss["fear"] = 4
    boss["recognition_window"] = true
    GameState.add_log("Le Témoin hésite. Derrière la déformation, quelqu'un semble encore reconnaître le groupe.")
    GameState.add_log("Reconnaissance : les issues non létales seront disponibles après le combat.")
    ash_witness_phase_changed.emit(3)
    _updating = false

func _mark_boss_phase(value: int) -> void:
    var boss := _boss()
    if not boss.is_empty():
        boss["chapter_phase"] = value

func _boss() -> Dictionary:
    for enemy_value in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if String(enemy.get("chapter_boss_id", "")) == "c01_boss_ash_witness":
            return enemy
    return {}
