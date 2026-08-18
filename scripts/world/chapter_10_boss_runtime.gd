extends Node

var active_id := ""
var phase := 0
var signature_used := false
var last_hp := -1
var last_anchor_count := -1

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _on_started(encounter_id: String, _type: String) -> void:
    active_id = encounter_id if encounter_id in ["c10_unpaid_cost","c10_boss_final"] else ""
    phase = 1 if active_id != "" else 0
    signature_used = false; last_hp = -1; last_anchor_count = -1
    if active_id == "c10_unpaid_cost": GameState.add_log("Le Coût Oublié ne protège aucune solution : il protège seulement les sacrifices que personne ne veut nommer.")
    elif active_id == "c10_boss_final": GameState.add_log("La Rupture Commune cherche une seule règle assez forte pour remplacer toutes les autres. Corps, Esprit et Cité doivent rester présents ensemble.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active_id = ""; phase = 0; last_hp = -1; last_anchor_count = -1

func _process(_delta: float) -> void:
    if active_id == "" or GameState.battle_enemies.is_empty(): return
    if active_id == "c10_unpaid_cost": _refresh_cost()
    else: _refresh_rupture()

func _refresh_cost() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var count := Chapter10Runtime.cost_count()
    _apply_reduction(boss,count,[85,55,25,0],"COÛT RECONNU")
    var ratio := float(_restore_reduced_damage(boss)) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3; boss["damage"] = [14,20]
        GameState.add_log("PERSONNE NE VEUT PAYER — la manifestation tente de transférer tous les coûts sur la voix la moins représentée.")
    elif ratio <= 0.66 and phase < 2:
        phase = 2; boss["damage"] = [13,19]; _cost_signature()

func _refresh_rupture() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var count := Chapter10Runtime.node_count("rupture_anchor")
    _apply_reduction(boss,count,[95,70,40,0],"MONDE COMMUN")
    var ratio := float(_restore_reduced_damage(boss)) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3; boss["damage"] = [16,23]
        GameState.add_log("CE QUE NOUS REFUSONS DE SACRIFIER — la Rupture ne peut plus réduire le monde à une seule nécessité.")
    elif ratio <= 0.66 and phase < 2:
        phase = 2; boss["damage"] = [15,22]; _rupture_signature()

func _apply_reduction(boss: Dictionary, count: int, reductions: Array, label: String) -> void:
    if count == last_anchor_count: return
    last_anchor_count = count
    boss["damage_reduction"] = int(reductions[clampi(count,0,3)])
    if count < 3: GameState.add_log("%s — %d/3 ancrages ; résistance %d%%." % [label,count,int(boss["damage_reduction"])])
    else: GameState.add_log("%s — les trois ancrages coexistent. La crise devient vulnérable." % label)

func _restore_reduced_damage(boss: Dictionary) -> int:
    var hp := int(boss.get("hp",0))
    if last_hp >= 0 and hp < last_hp:
        var raw_loss := last_hp - hp; var reduction := int(boss.get("damage_reduction",0))
        if reduction > 0:
            boss["hp"] = mini(int(boss.get("max_hp",hp)), hp + int(round(float(raw_loss) * float(reduction) / 100.0)))
            hp = int(boss["hp"])
    last_hp = hp
    return hp

func _cost_signature() -> void:
    if signature_used: return
    signature_used = true
    for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear",0)) + 8,0,100)
    GameState.add_log("QUELQU'UN PAIERA — le coût non nommé devient peur et fatigue pour ceux qui restent visibles.")

func _rupture_signature() -> void:
    if signature_used: return
    signature_used = true
    var missing_voices := maxi(0, 6 - Chapter10Runtime.council_count())
    GameState.light = clampi(GameState.light - 6 - missing_voices,0,100)
    for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear",0)) + 6 + missing_voices,0,100)
    GameState.add_log("UNE SOLUTION POUR TOUS — chaque voix absente du Conseil rend plus facile l'illusion qu'un seul intérêt peut parler pour le monde entier.")
