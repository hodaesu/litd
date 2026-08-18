extends Node

var active := false
var phase := 0
var signature_used := false

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)

func _on_started(encounter_id: String, _type: String) -> void:
    active = encounter_id == "c03_boss_threshold_echo"
    phase = 1 if active else 0
    signature_used = false
    if active:
        GameState.add_log("L'Écho du Seuil recommence les dernières secondes du rituel.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active = false
    phase = 0

func refresh() -> void:
    if not active or GameState.battle_enemies.is_empty():
        return
    var boss: Dictionary = GameState.battle_enemies[0]
    var ratio := float(boss.get("hp",0)) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [9,14]
        boss["fear"] = 10
        GameState.add_log("OUVERTURE — une réponse étrangère aux opérateurs traverse la boucle.")
    elif ratio <= 0.65 and phase < 2:
        phase = 2
        boss["damage"] = [8,13]
        boss["fear"] = 8
        GameState.add_log("ORDRES CONTRADICTOIRES — arrêter, poursuivre, saboter : toutes les voix parlent ensemble.")
        _signature()

func _signature() -> void:
    if signature_used:
        return
    signature_used = true
    GameState.light = clampi(GameState.light - 12,0,100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear",0)) + 8,0,100)
    GameState.add_log("ZÉRO SECONDE — le rituel atteint encore une fois l'instant où le monde s'est brisé.")
