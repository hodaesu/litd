extends Node

var active_id := ""
var phase := 0
var signature_used := false
var last_hp := -1
var last_node_count := -1
var repeated_damage_events := 0

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _on_started(encounter_id: String, _type: String) -> void:
    active_id = encounter_id if encounter_id in ["c09_fear_echo","c09_boss_consensus"] else ""
    phase = 1 if active_id != "" else 0
    signature_used = false
    last_hp = -1
    last_node_count = -1
    repeated_damage_events = 0
    if active_id == "c09_fear_echo":
        GameState.add_log("L'Issue Redoutée devient plus probable chaque fois que le groupe agit comme si elle était inévitable.")
    elif active_id == "c09_boss_consensus":
        GameState.add_log("Le Consensus Brisé contient mille versions incompatibles du même instant. Une seule version imposée le rend plus hostile.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active_id = ""
    phase = 0
    last_hp = -1
    last_node_count = -1

func _process(_delta: float) -> void:
    if active_id == "" or GameState.battle_enemies.is_empty(): return
    if active_id == "c09_boss_consensus": _refresh_consensus()
    else: _refresh_fear_echo()

func _refresh_consensus() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var count := Chapter09Runtime.node_count("perspective")
    if count != last_node_count:
        last_node_count = count
        boss["damage_reduction"] = [90,65,35,0][clampi(count,0,3)]
        if count < 3:
            GameState.add_log("CONSENSUS FORCÉ — %d perspective(s) active(s), résistance %d%%. Vécu, mesure et mémoire doivent coexister." % [count,int(boss["damage_reduction"])])
        else:
            GameState.add_log("DÉSACCORD HABITABLE — trois perspectives différentes restent actives. Le Consensus devient vulnérable.")
    var hp := int(boss.get("hp",0))
    if last_hp >= 0 and hp < last_hp:
        repeated_damage_events += 1
        var raw_loss := last_hp - hp
        var reduction := int(boss.get("damage_reduction",0))
        if reduction > 0:
            boss["hp"] = mini(int(boss.get("max_hp",hp)), hp + int(round(float(raw_loss) * float(reduction) / 100.0)))
            hp = int(boss["hp"])
        if repeated_damage_events >= 3 and count < 3:
            repeated_damage_events = 0
            boss["damage_reduction"] = mini(95,int(boss.get("damage_reduction",0)) + 10)
            GameState.add_log("UNE SEULE VERSION — répéter l'agression sans ouvrir d'autres perspectives renforce la réalité dominante.")
    last_hp = hp
    var ratio := float(hp) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [13,20]
        GameState.add_log("LE DÉSACCORD HABITABLE — les mémoires cessent d'essayer de devenir identiques et cherchent seulement à rester compatibles.")
    elif ratio <= 0.66 and phase < 2:
        phase = 2
        boss["damage"] = [12,19]
        _consensus_signature()

func _consensus_signature() -> void:
    if signature_used: return
    signature_used = true
    GameState.light = clampi(GameState.light - 10,0,100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear",0)) + 8,0,100)
        hero["madness"] = clampi(int(hero.get("madness",0)) + 4,0,100)
    GameState.add_log("NOUS NE VOYONS PAS LE MÊME MONDE — chaque héros perçoit brièvement une version différente de l'arène.")

func _refresh_fear_echo() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var hp := int(boss.get("hp",0))
    if last_hp >= 0 and hp < last_hp:
        repeated_damage_events += 1
        if repeated_damage_events >= 3:
            repeated_damage_events = 0
            boss["hp"] = mini(int(boss.get("max_hp",hp)), hp + int(round(float(last_hp - hp) * 0.65)))
            boss["damage"] = [11,17]
            GameState.add_log("C'ÉTAIT INÉVITABLE — traiter l'Issue Redoutée comme le seul danger possible la rend plus stable.")
            hp = int(boss["hp"])
    last_hp = hp

func notify_player_action(action_type: String) -> void:
    if active_id == "": return
    if action_type in ["guard","heal","stabilize","environment","capture"]:
        repeated_damage_events = 0
        if active_id == "c09_fear_echo": GameState.add_log("POSSIBILITÉ ALTERNATIVE — le groupe agit comme si une autre issue restait possible.")
