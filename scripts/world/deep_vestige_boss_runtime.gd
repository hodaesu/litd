extends Node

var active := false
var phase := 0
var forced_agreement := 0
var signature_used := false
var last_hp := -1
var consecutive_damage_events := 0

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _process(_delta: float) -> void:
    if not active or GameState.battle_enemies.is_empty(): return
    var boss: Dictionary = GameState.battle_enemies[0]
    var hp := int(boss.get("hp", 0))
    if last_hp >= 0 and hp < last_hp:
        consecutive_damage_events += 1
        if consecutive_damage_events >= 3:
            forced_agreement += 1
            consecutive_damage_events = 0
            boss["damage_reduction"] = mini(70, forced_agreement * 15)
            GameState.add_log("ACCORD FORCÉ — la répétition offensive renforce la Septième Voix.")
    last_hp = hp
    refresh()

func _on_started(encounter_id: String, _type: String) -> void:
    active = encounter_id == "vestige_ashai_boss_seventh_voice"
    phase = 1 if active else 0
    forced_agreement = 0
    signature_used = false
    last_hp = -1
    consecutive_damage_events = 0
    GameState.set_meta("vestige_action_history", [])
    if active:
        GameState.add_log("La Septième Voix écoute la manière dont le groupe agit, pas seulement ses attaques.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active = false
    phase = 0
    last_hp = -1

func notify_player_action(action_type: String) -> void:
    if not active: return
    var history: Array = GameState.get_meta("vestige_action_history", [])
    history.append(action_type)
    if history.size() > 3: history.pop_front()
    GameState.set_meta("vestige_action_history", history)
    if action_type in ["heal", "guard", "capture", "environment"]:
        consecutive_damage_events = 0
        if not GameState.battle_enemies.is_empty():
            GameState.battle_enemies[0]["damage_reduction"] = maxi(0, int(GameState.battle_enemies[0].get("damage_reduction", 0)) - 15)

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
