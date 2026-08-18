extends Node

const BOSS_PROFILES := {
    "vestige_ashai_boss_seventh_voice":{"intro":"La Septième Voix écoute la manière dont le groupe agit.","adapt":"ACCORD FORCÉ — la répétition offensive renforce la Septième Voix.","signature":"LE MONDE QUE NOUS ACCORDONS — les différences du groupe commencent à disparaître.","phase3":"LA SEPTIÈME VOIX — l'accord parfait devient une prison.","max_reduction":70,"phase2_damage":[9,14],"phase3_damage":[10,16],"light":10,"fear":8,"madness":0,"signature_reduction":0},
    "vestige_silex_boss_last_strategist":{"intro":"Le Dernier Stratège transforme chaque habitude du groupe en doctrine ennemie.","adapt":"VICTOIRE PRÉDITE — le Stratège a compris la tactique répétée et la neutralise.","signature":"VICTOIRE AVANT LA BATAILLE — le Stratège annonce vos prochains gestes avant qu'ils n'arrivent.","phase3":"DERNIÈRE STRATÉGIE — toutes les anciennes doctrines sont jouées à la fois.","max_reduction":70,"phase2_damage":[12,18],"phase3_damage":[13,19],"light":0,"fear":0,"madness":0,"signature_reduction":20},
    "vestige_saan_boss_last_watch":{"intro":"La Dernière Veille protège encore des sceaux dont certains retiennent peut-être des survivants.","adapt":"SCEAU RÉACTIF — la Dernière Veille renforce les barrières face à une approche trop brutale.","signature":"QUE PERSONNE NE PASSE — plusieurs sceaux se ferment, mais tous ne protègent pas la même chose.","phase3":"DERNIER SCEAU — la Veille préfère s'enfermer avec vous plutôt que risquer une rupture.","max_reduction":60,"phase2_damage":[11,17],"phase3_damage":[12,18],"light":8,"fear":6,"madness":0,"signature_reduction":0},
    "vestige_vaor_boss_command_without_body":{"intro":"Le Commandement Sans Corps distribue déjà des priorités alors qu'aucun dirigeant vivant ne les émet.","adapt":"ORDRE VALIDÉ — votre répétition devient une priorité officielle du réseau et renforce sa protection.","signature":"OBÉISSEZ ET LE CHEMIN S'OUVRIRA — les routes de l'arène refusent momentanément toute action hors de la priorité imposée.","phase3":"PLUS PERSONNE NE COMMANDE — le réseau continue pourtant d'ordonner, comme si l'autorité était devenue une propriété du lieu.","max_reduction":75,"phase2_damage":[12,18],"phase3_damage":[13,20],"light":6,"fear":7,"madness":0,"signature_reduction":20},
    "vestige_lyrmar_boss_absent_cartographer":{"intro":"La Cartographe des Mers Absentes dessine la prochaine action du groupe comme si elle était déjà une route maritime.","adapt":"ROUTE PRÉDITE — la stratégie répétée devient un itinéraire que la Cartographe sait refermer sur lui-même.","signature":"TOUTES LES ROUTES REVIENNENT — chaque trajectoire sûre se recourbe vers le même point de départ.","phase3":"MER ABSENTE — l'arène montre des rivages qui ne sont plus reliés au monde commun.","max_reduction":70,"phase2_damage":[12,18],"phase3_damage":[13,20],"light":8,"fear":8,"madness":0,"signature_reduction":15},
    "vestige_sahmir_boss_single_interpreter":{"intro":"L'Interprète Unique transforme chaque geste répété en preuve qu'une seule lecture du combat est possible.","adapt":"SENS UNIQUE — la répétition confirme sa doctrine et rend toute autre interprétation plus difficile.","signature":"UN SEUL SENS — le boss tente d'imposer la même signification à la peur, à la lumière et aux actions du groupe.","phase3":"PAROLE INTERDITE — toute contradiction est désormais traitée comme une anomalie à effacer.","max_reduction":75,"phase2_damage":[12,19],"phase3_damage":[14,20],"light":8,"fear":8,"madness":5,"signature_reduction":15},
    "vestige_ydris_boss_living_theorem":{"intro":"Le Théorème Vivant attend que le groupe agisse pour démontrer ensuite que ce choix était inévitable.","adapt":"CAUSE DOMINANTE — la répétition est intégrée au modèle comme preuve de ce qui devait nécessairement arriver.","signature":"DÉJÀ CALCULÉ — le modèle ferme les issues qu'il considère désormais comme statistiquement impossibles.","phase3":"CAUSE APRÈS EFFET — le Théorème réécrit ses hypothèses pour rendre chaque événement passé nécessaire.","max_reduction":80,"phase2_damage":[13,19],"phase3_damage":[14,21],"light":7,"fear":7,"madness":5,"signature_reduction":25}
}

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

func _profile() -> Dictionary:
    return BOSS_PROFILES.get(active_id, {})

func _process(_delta: float) -> void:
    if active_id == "" or GameState.battle_enemies.is_empty(): return
    var boss: Dictionary = GameState.battle_enemies[0]
    var hp := int(boss.get("hp",0))
    if last_hp >= 0 and hp < last_hp:
        consecutive_damage_events += 1
        if consecutive_damage_events >= 3:
            consecutive_damage_events = 0
            adaptation += 1
            boss["damage_reduction"] = mini(_max_reduction(), adaptation * 15)
            GameState.add_log(String(_profile().get("adapt", "Le Vestige s'adapte à la répétition.")))
    last_hp = hp
    _refresh_phase(boss)

func _on_started(encounter_id: String, _type: String) -> void:
    if not BOSS_PROFILES.has(encounter_id):
        active_id = ""
        return
    active_id = encounter_id
    phase = 1
    signature_used = false
    adaptation = 0
    last_hp = -1
    consecutive_damage_events = 0
    GameState.add_log(String(_profile().get("intro", "Le Vestige profond réagit à votre présence.")))

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active_id = ""
    phase = 0
    last_hp = -1

func _max_reduction() -> int:
    return int(_profile().get("max_reduction", 70))

func notify_player_action(action_type: String) -> void:
    if active_id == "": return
    if action_type in ["heal","guard","capture","environment","stabilize"]:
        consecutive_damage_events = 0
        adaptation = maxi(0, adaptation - 1)
        if not GameState.battle_enemies.is_empty():
            var boss: Dictionary = GameState.battle_enemies[0]
            boss["damage_reduction"] = maxi(0,int(boss.get("damage_reduction",0)) - 15)

func _refresh_phase(boss: Dictionary) -> void:
    var ratio := float(boss.get("hp",0)) / float(maxi(1,int(boss.get("max_hp",1))))
    var profile := _profile()
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = profile.get("phase3_damage", [12,18])
        GameState.add_log(String(profile.get("phase3", "Le Vestige atteint sa dernière phase.")))
    elif ratio <= 0.65 and phase < 2:
        phase = 2
        _signature(boss)

func _signature(boss: Dictionary) -> void:
    if signature_used: return
    signature_used = true
    var profile := _profile()
    boss["damage"] = profile.get("phase2_damage", [11,17])
    var reduction := int(profile.get("signature_reduction", 0))
    if reduction > 0: boss["damage_reduction"] = mini(_max_reduction(),int(boss.get("damage_reduction",0)) + reduction)
    GameState.light = clampi(GameState.light - int(profile.get("light",0)),0,100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear",0)) + int(profile.get("fear",0)),0,100)
        hero["madness"] = clampi(int(hero.get("madness",0)) + int(profile.get("madness",0)),0,100)
    GameState.add_log(String(profile.get("signature", "Le Vestige révèle sa signature.")))
