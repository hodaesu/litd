extends Node

var active := false
var phase := 0
var forced_agreement := 0
var signature_used := false

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)

func _on_started(encounter_id: String, _type: String) -> void:
    active = encounter_id == "vestige_ashai_boss_seventh_voice"
    phase = 1 if active else 0
    forced_agreement = 0
    signature_used = false
    if active:
        GameState.add_log("La Septième Voix écoute la manière dont le groupe agit, pas seulement ses attaques.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active = false
    phase = 0

func notify_player_action(action_type: String) -> void:
    if not active:
        return
    var history: Array = GameState.get_meta("vestige_action_history", [])
    history.append(action_type)
    if history.size() > 3: history.pop_front()
    GameState.set_meta("vestige_action_history", history)
    if history.size() == 3 and history[0] == history[1] and history[1] == history[2]:
        forced_agreement += 1
        GameState.add_log("ACCORD FORCÉ — répéter la même réponse renforce la Septième Voix.")
        if not GameState.battle_enemies.is_empty():
            GameState.battle_enemies[0]["damage_reduction"] = mini(70, forced_agreement * 15)

func refresh() -> void:
    if not active or GameState.battle_enemies.is_empty(): return
    var boss: Dictionary = GameState.battle_enemies[0]
    var ratio := float(boss.get("hp",0)) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [10,16]
        GameState.add_log("LA SEPTIÈME VOIX — l'accord parfait devient une prison.")
    elif ratio <= 0.65 and phase < 2:
        phase = 2
        boss["damage"] = [9,14]
        _signature()

func _signature() -> void:
    if signature_used: return
    signature_used = true
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear",0)) + 8, 0, 100)
    GameState.light = clampi(GameState.light - 10, 0, 100)
    GameState.add_log("LE MONDE QUE NOUS ACCORDONS — les différences du groupe commencent à disparaître.")
