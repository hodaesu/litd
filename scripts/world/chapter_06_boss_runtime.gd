extends Node

var active_id := ""
var phase := 0
var signature_used := false
var last_hp := -1
var last_anchor_count := -1
var wayfarer_step := 0

func _ready() -> void:
    AshlandsCombatBridge.ashlands_combat_started.connect(_on_started)
    AshlandsCombatBridge.ashlands_combat_finished.connect(_on_finished)
    set_process(true)

func _on_started(encounter_id: String, _type: String) -> void:
    active_id = encounter_id if encounter_id in ["c06_shifted_wayfarer","c06_boss_boundary"] else ""
    phase = 1 if active_id != "" else 0
    signature_used = false
    last_hp = -1
    last_anchor_count = -1
    wayfarer_step = 0
    if active_id == "c06_shifted_wayfarer":
        GameState.add_log("L'Arpenteur existe à plusieurs instants. Toutes ses silhouettes ne peuvent pas être blessées.")
    elif active_id == "c06_boss_boundary":
        GameState.add_log("La Frontière n'est pas un corps. Les ancrages de l'arène déterminent ce qui peut réellement être atteint ; rien n'établit que le phénomène possède une volonté.")

func _on_finished(_id: String, _victory: bool, _loot: Dictionary) -> void:
    active_id = ""
    phase = 0
    last_hp = -1

func _process(_delta: float) -> void:
    if active_id == "" or GameState.battle_enemies.is_empty(): return
    if active_id == "c06_shifted_wayfarer": _refresh_wayfarer()
    elif active_id == "c06_boss_boundary": _refresh_boundary()

func _refresh_wayfarer() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var hp := int(boss.get("hp", 0))
    if last_hp >= 0 and hp < last_hp:
        wayfarer_step += 1
        if wayfarer_step % 2 == 1:
            var raw_loss := last_hp - hp
            var restored := int(round(float(raw_loss) * 0.70))
            boss["hp"] = mini(int(boss.get("max_hp", hp)), hp + restored)
            hp = int(boss["hp"])
            for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear", 0)) + 2, 0, 100)
            GameState.add_log("POSITION DÉCALÉE — l'attaque traverse un instant qui n'est pas encore le présent.")
        else:
            GameState.add_log("CONVERGENCE — l'ombre, le son et le corps occupent enfin le même instant.")
    last_hp = hp
    var ratio := float(hp) / float(maxi(1, int(boss.get("max_hp", 1))))
    if ratio <= 0.50 and not signature_used:
        signature_used = true
        for hero in GameState.alive_heroes(): hero["fear"] = clampi(int(hero.get("fear", 0)) + 5, 0, 100)
        GameState.add_log("UN PAS TROP TÔT — l'Arpenteur frappe depuis l'instant précédent.")

func _refresh_boundary() -> void:
    var boss: Dictionary = GameState.battle_enemies[0]
    var anchors := Chapter06Runtime.anchor_count()
    if anchors != last_anchor_count:
        last_anchor_count = anchors
        var reduction_by_anchor := [85,60,35,0]
        boss["damage_reduction"] = reduction_by_anchor[clampi(anchors,0,3)]
        if anchors < 3:
            GameState.add_log("FRONTIÈRE INSTABLE — résistance %d%%. Stabilisez les ancrages hors du combat." % int(boss["damage_reduction"]))
        else:
            GameState.add_log("TROIS ANCRAGES — les références locales se recouvrent assez pour que les interventions du groupe produisent un effet mesurable.")
    var hp := int(boss.get("hp", 0))
    if last_hp >= 0 and hp < last_hp:
        var raw_loss := last_hp - hp
        var reduction := int(boss.get("damage_reduction", 0))
        if reduction > 0:
            var restored := int(round(float(raw_loss) * float(reduction) / 100.0))
            boss["hp"] = mini(int(boss.get("max_hp", hp)), hp + restored)
            hp = int(boss["hp"])
    last_hp = hp
    var ratio := float(hp) / float(maxi(1, int(boss.get("max_hp", 1))))
    if ratio <= 0.32 and phase < 3:
        phase = 3
        boss["damage"] = [11,17]
        GameState.add_log("DÉCOUPLAGE LOCAL — certaines positions du groupe cessent brièvement d'appartenir à la même référence spatiale.")
    elif ratio <= 0.66 and phase < 2:
        phase = 2
        boss["damage"] = [10,16]
        _use_boundary_signature()

func _use_boundary_signature() -> void:
    if signature_used: return
    signature_used = true
    GameState.light = clampi(GameState.light - 14, 0, 100)
    for hero in GameState.alive_heroes():
        hero["fear"] = clampi(int(hero.get("fear", 0)) + 8, 0, 100)
    GameState.add_log("ICI N'EST PLUS ICI — le décor glisse d'un instant à l'autre et la Lumière peine à maintenir un monde commun.")
