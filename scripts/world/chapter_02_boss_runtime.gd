extends Node

var active := false
var phase := 0
var signature_used := false

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_combat_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)

func _on_combat_started(encounter_id: String, _encounter_type: String) -> void:
    active = encounter_id == "c02_marker_warden"
    phase = 1 if active else 0
    signature_used = false
    if active:
        GameState.add_log("Sahra Vel déplie une carte qui ne correspond plus au monde.")

func _on_combat_finished(_encounter_id: String, _victory: bool, _loot: Dictionary) -> void:
    active = false
    phase = 0

func refresh() -> void:
    if not active or GameState.battle_enemies.is_empty():
        return
    var boss: Dictionary = GameState.battle_enemies[0]
    var max_hp := maxi(1, int(boss.get("max_hp", 1)))
    var ratio := float(boss.get("hp", 0)) / float(max_hp)
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [6, 10]
        boss["fear"] = 8
        GameState.add_log("LE CHEMIN INTERDIT — Sahra tente de fermer la route plutôt que de gagner le combat.")
    elif ratio <= 0.65 and phase < 2:
        phase = 2
        boss["damage"] = [8, 13]
        boss["fear"] = 7
        GameState.add_log("ROUTES SUPERPOSÉES — plusieurs positions semblent vraies en même temps.")
        _use_signature()

func _use_signature() -> void:
    if signature_used:
        return
    signature_used = true
    GameState.light = clampi(GameState.light - 8, 0, 100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear", 0)) + 7, 0, 100)
    GameState.add_log("LA CARTE QUI SE SOUVIENT — les chemins du passé recouvrent l'arène.")
