extends Node

var active_id := ""
var phase := 0
var signature_used := false
var adaptation := 0
var last_hp := -1
var consecutive_damage_events := 0

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _process(_delta: float) -> void:
    if active_id == "" or GameState.battle_enemies.is_empty(): return
    var boss: Dictionary = GameState.battle_enemies[0]
    var hp := int(boss.get("hp",0))
    if last_hp >= 0 and hp < last_hp:
        consecutive_damage_events += 1
        if consecutive_damage_events >= 3:
            consecutive_damage_events = 0
            adaptation += 1
            boss["damage_reduction"] = mini(_max_reduction(),adaptation * 15)
            GameState.add_log(_adaptation_log())
    last_hp = hp
    _refresh_phase(boss)

func _on_started(encounter_id: String, _type: String) -> void:
    if encounter_id not in ["vestige_ashai_boss_seventh_voice","vestige_silex_boss_last_strategist","vestige_saan_boss_last_watch"]:
        active_id = ""
        return
    active_id = encounter_id
    phase = 1
    signature_used = false
    adaptation = 0
    last_hp = -1
    consecutive_damage_events = 0
    if active_id == "vestige_ashai_boss_seventh_voice": GameState.add_log("La Septième Voix écoute la manière dont le groupe agit.")
    elif active_id == "vestige_silex_boss_last_strategist": GameState.add_log("Le Dernier Stratège transforme chaque habitude du groupe en doctrine ennemie.")
    else: GameState.add_log("La Dernière Veille protège encore des sceaux dont certains retiennent peut-être des survivants.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active_id = ""
    phase = 0
    last_hp = -1

func _max_reduction() -> int:
    return 60 if active_id == "vestige_saan_boss_last_watch" else 70

func _adaptation_log() -> String:
    if active_id == "vestige_ashai_boss_seventh_voice": return "ACCORD FORCÉ — la répétition offensive renforce la Septième Voix."
    if active_id == "vestige_silex_boss_last_strategist": return "VICTOIRE PRÉDITE — le Stratège a compris la tactique répétée et la neutralise."
    return "SCEAU RÉACTIF — la Dernière Veille renforce les barrières face à une approche trop brutale."

func notify_player_action(action_type: String) -> void:
    if active_id == "": return
    if action_type in ["heal","guard","capture","environment","stabilize"]:
        consecutive_damage_events = 0
        if not GameState.battle_enemies.is_empty():
            var boss: Dictionary = GameState.battle_enemies[0]
            boss["damage_reduction"] = maxi(0,int(boss.get("damage_reduction",0)) - 15)

func _refresh_phase(boss: Dictionary) -> void:
    var ratio := float(boss.get("hp",0)) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3
        if active_id == "vestige_ashai_boss_seventh_voice":
            boss["damage"] = [10,16]
            GameState.add_log("LA SEPTIÈME VOIX — l'accord parfait devient une prison.")
        elif active_id == "vestige_silex_boss_last_strategist":
            boss["damage"] = [13,19]
            GameState.add_log("DERNIÈRE STRATÉGIE — toutes les anciennes doctrines sont jouées à la fois.")
        else:
            boss["damage"] = [12,18]
            GameState.add_log("DERNIER SCEAU — la Veille préfère s'enfermer avec vous plutôt que risquer une rupture.")
    elif ratio <= 0.65 and phase < 2:
        phase = 2
        _signature(boss)

func _signature(boss: Dictionary) -> void:
    if signature_used: return
    signature_used = true
    if active_id == "vestige_ashai_boss_seventh_voice":
        boss["damage"] = [9,14]
        GameState.light = clampi(GameState.light - 10,0,100)
        for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear",0)) + 8,0,100)
        GameState.add_log("LE MONDE QUE NOUS ACCORDONS — les différences du groupe commencent à disparaître.")
    elif active_id == "vestige_silex_boss_last_strategist":
        boss["damage"] = [12,18]
        boss["damage_reduction"] = mini(70,int(boss.get("damage_reduction",0)) + 20)
        GameState.add_log("VICTOIRE AVANT LA BATAILLE — le Stratège annonce vos prochains gestes avant qu'ils n'arrivent.")
    else:
        boss["damage"] = [11,17]
        GameState.light = clampi(GameState.light - 8,0,100)
        for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear",0)) + 6,0,100)
        GameState.add_log("QUE PERSONNE NE PASSE — plusieurs sceaux se ferment, mais tous ne protègent pas la même chose.")
