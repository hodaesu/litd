extends Node

var active_id := ""
var phase := 0
var signature_used := false
var last_hp := -1
var last_counter_count := -1
var provocation_cycle := 0

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _on_started(encounter_id: String, _type: String) -> void:
    active_id = encounter_id if encounter_id in ["c07_opening_pilgrim","c07_boss_edras"] else ""
    phase = 1 if active_id != "" else 0
    signature_used = false
    last_hp = -1
    last_counter_count = -1
    provocation_cycle = 0
    if active_id == "c07_opening_pilgrim":
        GameState.add_log("Le Pèlerin ne protège pas son corps : il nourrit deux sceaux avec chaque geste violent dirigé contre lui.")
    elif active_id == "c07_boss_edras":
        GameState.add_log("Edras : « Vous appelez cela prudence parce que vous avez peur de savoir. » Les contre-rituels déterminent ce qui peut réellement l'atteindre.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active_id = ""
    phase = 0
    last_hp = -1

func _process(_delta: float) -> void:
    if active_id == "" or GameState.battle_enemies.is_empty(): return
    if active_id == "c07_opening_pilgrim": _refresh_pilgrim()
    elif active_id == "c07_boss_edras": _refresh_edras()

func _refresh_pilgrim() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var seals := Chapter07Runtime.pilgrim_seal_count()
    var reduction := [75,40,0][clampi(seals,0,2)]
    boss["damage_reduction"] = reduction
    var hp := int(boss.get("hp", 0))
    if last_hp >= 0 and hp < last_hp and reduction > 0:
        var raw_loss := last_hp - hp
        boss["hp"] = mini(int(boss.get("max_hp", hp)), hp + int(round(float(raw_loss) * float(reduction) / 100.0)))
        hp = int(boss["hp"])
        for hero in GameState.alive_heroes(): hero["madness"] = clampi(int(hero.get("madness", 0)) + 2, 0, 100)
        GameState.add_log("TRANSE ALIMENTÉE — les sceaux absorbent l'agression et la renvoient comme obsession.")
    last_hp = hp
    if seals >= 2 and not signature_used:
        signature_used = true
        GameState.add_log("SCEAUX ROMPUS — le Pèlerin ne peut plus transformer chaque coup en preuve de sa foi.")
    var ratio := float(hp) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.45 and phase < 2:
        phase = 2
        boss["damage"] = [10,16]
        for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear", 0)) + 5,0,100)
        GameState.add_log("LAISSEZ ENTRER — le Pèlerin tente de faire de sa propre défaite une ouverture.")

func _refresh_edras() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var counters := Chapter07Runtime.counter_ritual_count()
    if counters != last_counter_count:
        last_counter_count = counters
        boss["damage_reduction"] = [80,55,30,0][clampi(counters,0,3)]
        if counters < 3:
            GameState.add_log("OUVERTURE NON CONTESTÉE — protection d'Edras %d%%. Les témoignages doivent devenir des contre-rituels." % int(boss["damage_reduction"]))
        else:
            GameState.add_log("CAUSE, LIMITE, TÉMOIN — les trois contre-rituels empêchent Edras de redéfinir seul ce qui est réel.")
    var hp := int(boss.get("hp", 0))
    if last_hp >= 0 and hp < last_hp:
        var raw_loss := last_hp - hp
        var reduction := int(boss.get("damage_reduction",0))
        if reduction > 0:
            boss["hp"] = mini(int(boss.get("max_hp",hp)), hp + int(round(float(raw_loss) * float(reduction) / 100.0)))
            hp = int(boss["hp"])
        elif phase >= 2:
            provocation_cycle += 1
            if provocation_cycle % 3 == 1:
                var restored := int(round(float(raw_loss) * 0.60))
                boss["hp"] = mini(int(boss.get("max_hp",hp)), hp + restored)
                hp = int(boss["hp"])
                for hero in GameState.alive_heroes(): hero["madness"] = clampi(int(hero.get("madness",0)) + 3,0,100)
                GameState.add_log("FAUSSE URGENCE — Edras crée volontairement une ouverture séduisante. Frapper maintenant nourrit son rituel.")
            else:
                GameState.add_log("CONTRE-RITUEL ALIGNÉ — l'urgence est refusée ; Edras ne peut pas convertir cette attaque en ouverture.")
    last_hp = hp
    var ratio := float(hp) / float(maxi(1,int(boss.get("max_hp",1))))
    if ratio <= 0.30 and phase < 3:
        phase = 3
        boss["damage"] = [12,18]
        boss["fear"] = 11
        GameState.add_log("REGARDEZ ENFIN — Edras cesse de convaincre et tente de forcer le groupe à partager sa perception.")
    elif ratio <= 0.66 and phase < 2:
        phase = 2
        boss["damage"] = [10,16]
        _use_signature()

func _use_signature() -> void:
    if signature_used: return
    signature_used = true
    GameState.light = clampi(GameState.light - 12,0,100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear",0)) + 6,0,100)
        hero["madness"] = clampi(int(hero.get("madness",0)) + 5,0,100)
    GameState.add_log("REGARDEZ ENFIN — pendant un instant, chaque héros voit une version différente du monde qu'Edras promet de révéler.")
