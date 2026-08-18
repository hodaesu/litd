extends Node

var active_id := ""
var phase := 0
var signature_used := false
var last_hp := -1
var last_authority_count := -1

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _on_started(encounter_id: String, _type: String) -> void:
    active_id = encounter_id if encounter_id in ["c08_boss_varkhane","c08_boss_azravel"] else ""
    phase = 1 if active_id != "" else 0
    signature_used = false
    last_hp = -1
    last_authority_count = -1
    if active_id == "c08_boss_varkhane":
        GameState.add_log("Le Maréchal ne tient pas seulement par ses armes : il tient parce qu'il prétend être la seule autorité encore possible.")
    elif active_id == "c08_boss_azravel":
        GameState.add_log("Le Saint de la Faille transforme l'obéissance en protection. Les preuves autour de lui sont une partie du combat.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active_id = ""
    phase = 0
    last_hp = -1
    last_authority_count = -1

func _process(_delta: float) -> void:
    if active_id == "" or GameState.battle_enemies.is_empty(): return
    if active_id == "c08_boss_varkhane": _refresh_varkhane()
    elif active_id == "c08_boss_azravel": _refresh_azravel()

func _refresh_varkhane() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var count := Chapter08Runtime.authority_node_count("varkhane")
    _apply_authority_reduction(boss, count, [75,50,25,0], "VARKHANE")
    var hp := _restore_reduced_damage(boss)
    var ratio := float(hp) / float(maxi(1, int(boss.get("max_hp", 1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [12,18]
        GameState.add_log("QUI COMMANDE MAINTENANT ? — le Maréchal perd le contrôle de la province et tente de transformer chaque soldat en dernier ordre vivant.")
    elif ratio <= 0.66 and phase < 2:
        phase = 2
        boss["damage"] = [11,17]
        _use_varkhane_signature()

func _refresh_azravel() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var count := Chapter08Runtime.authority_node_count("azravel")
    _apply_authority_reduction(boss, count, [80,55,30,0], "AZRAVEL")
    var hp := _restore_reduced_damage(boss)
    var ratio := float(hp) / float(maxi(1, int(boss.get("max_hp", 1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [12,19]
        GameState.add_log("LA FAILLE PUBLIQUE — les fidèles entendent désormais plusieurs récits incompatibles et l'autorité du Saint cesse d'être une évidence.")
    elif ratio <= 0.66 and phase < 2:
        phase = 2
        boss["damage"] = [11,18]
        _use_azravel_signature()

func _apply_authority_reduction(boss: Dictionary, count: int, reductions: Array, label: String) -> void:
    if count == last_authority_count: return
    last_authority_count = count
    boss["damage_reduction"] = int(reductions[clampi(count, 0, 3)])
    if count < 3:
        GameState.add_log("%s — autorité encore active : résistance %d%%. Rendez visibles les contre-autorités et les preuves." % [label, int(boss["damage_reduction"])])
    else:
        GameState.add_log("%s — trois voix indépendantes sont publiques. La protection de légitimité tombe." % label)

func _restore_reduced_damage(boss: Dictionary) -> int:
    var hp := int(boss.get("hp", 0))
    if last_hp >= 0 and hp < last_hp:
        var raw_loss := last_hp - hp
        var reduction := int(boss.get("damage_reduction", 0))
        if reduction > 0:
            var restored := int(round(float(raw_loss) * float(reduction) / 100.0))
            boss["hp"] = mini(int(boss.get("max_hp", hp)), hp + restored)
            hp = int(boss["hp"])
    last_hp = hp
    return hp

func _use_varkhane_signature() -> void:
    if signature_used: return
    signature_used = true
    GameState.light = clampi(GameState.light - 6, 0, 100)
    for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear", 0)) + 7, 0, 100)
    GameState.add_log("ORDRE DU TRÔNE VIDE — le Maréchal désigne un ennemi commun pour recréer artificiellement l'unité de ses troupes.")

func _use_azravel_signature() -> void:
    if signature_used: return
    signature_used = true
    GameState.light = clampi(GameState.light - 8, 0, 100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear", 0)) + 8, 0, 100)
        hero["madness"] = clampi(int(hero.get("madness", 0)) + 3, 0, 100)
    GameState.add_log("UNE SEULE VÉRITÉ — le Saint tente de transformer toute contradiction en preuve de culpabilité.")
