extends Node

var active := false
var phase := 0
var signature_used := false
var repeated_damage_events := 0
var last_hp := -1

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _process(_delta: float) -> void:
    if active:
        refresh()

func _on_started(encounter_id: String, _type: String) -> void:
    active = encounter_id == "c05_boss_silex_general"
    phase = 1 if active else 0
    signature_used = false
    repeated_damage_events = 0
    last_hp = -1
    if active:
        GameState.add_log("Le Général de Silex observe la compagnie comme une doctrine à neutraliser.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active = false
    phase = 0
    last_hp = -1

func refresh() -> void:
    if not active or GameState.battle_enemies.is_empty(): return
    var boss: Dictionary = GameState.battle_enemies[0]
    var hp := int(boss.get("hp",0))
    var max_hp := maxi(1,int(boss.get("max_hp",1)))
    if last_hp >= 0 and hp < last_hp:
        repeated_damage_events += 1
        if repeated_damage_events >= 3:
            boss["damage_reduction"] = mini(65,int(boss.get("damage_reduction",0)) + 15)
            repeated_damage_events = 0
            GameState.add_log("DOCTRINE ADAPTATIVE — le Général renforce la défense contre une compagnie trop prévisible.")
    last_hp = hp
    var ratio := float(hp) / float(max_hp)
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [11,17]
        boss["fear"] = 10
        GameState.add_log("ORDRE SANS ENNEMI — la machine continue la guerre même lorsqu'elle ne sait plus contre qui.")
    elif ratio <= 0.65 and phase < 2:
        phase = 2
        boss["damage"] = [9,15]
        _use_signature()

func _use_signature() -> void:
    if signature_used: return
    signature_used = true
    GameState.light = clampi(GameState.light - 10,0,100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear",0)) + 8,0,100)
    GameState.add_log("ORDRE QUI NE FINIT JAMAIS — les relais de commandement imposent une nouvelle doctrine au champ de bataille.")
