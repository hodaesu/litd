extends Node

signal ashlands_combat_started(encounter_id: String, encounter_type: String)
signal ashlands_combat_finished(encounter_id: String, victory: bool, loot: Dictionary)

const MAIN_SCENE := "res://scenes/Main.tscn"
var active := false
var encounter_id := ""
var encounter_type := ""
var return_zone_id := ""
var return_position := Vector3.ZERO
var has_return_position := false
var miniboss_data: Dictionary = {}
var pending_loot: Dictionary = {}
var _resolving := false

func _ready() -> void: GameState.screen_requested.connect(_on_screen_requested)
func begin(encounter_id_value: String, encounter_type_value: String, miniboss: Dictionary = {}) -> void:
    if active: return
    active = true; _resolving = false; encounter_id = encounter_id_value; encounter_type = encounter_type_value; return_zone_id = AshlandsRuntime.current_zone_id
    _capture_return_position(); miniboss_data = miniboss.duplicate(true); pending_loot = {}; _prepare_placeholder_enemies(); GameState.current_screen = "combat"
    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    if error == OK: call_deferred("_show_combat_after_load")
    ashlands_combat_started.emit(encounter_id,encounter_type)
func _show_combat_after_load() -> void:
    await get_tree().process_frame; GameState.request_screen("combat")
func _on_screen_requested(screen_name: String) -> void:
    if not active or _resolving: return
    if screen_name == "rewards": _resolving = true; call_deferred("resolve_victory")
    elif screen_name == "sanctuary": _resolving = true; call_deferred("resolve_defeat")

func _prepare_placeholder_enemies() -> void:
    GameState.battle_enemies = []
    var ids: Array[int] = [1,8,10]
    if encounter_type == "miniboss": ids = [30]
    elif encounter_type == "boss": ids = [38]
    for enemy_id in ids:
        var e := DataLoader.find_by_id(DataLoader.enemies,enemy_id).duplicate(true)
        if e.is_empty(): continue
        e["max_hp"] = int(e.get("hp",1)); e["guarding"] = false
        if encounter_type == "miniboss" and not miniboss_data.is_empty():
            e["name"] = str(miniboss_data.get("name",e.get("name","Mini-boss"))); e["recruitable"] = false; e["is_miniboss"] = true
            if encounter_id == "c02_broken_curator": e["hp"] = 82; e["max_hp"] = 82; e["damage"] = [6,11]; e["fear"] = 6; e["chapter_miniboss_id"] = encounter_id
            elif encounter_id == "c03_threshold_sentinel": e["name"] = "La Sentinelle du Seuil"; e["hp"] = 96; e["max_hp"] = 96; e["damage"] = [7,12]; e["fear"] = 7; e["chapter_miniboss_id"] = encounter_id; e["signature"] = "Protocole de Purge"
            elif encounter_id == "c04_faceless_measure": e["name"] = "Le Mesureur Sans Visage"; e["hp"] = 108; e["max_hp"] = 108; e["damage"] = [7,13]; e["fear"] = 8; e["chapter_miniboss_id"] = encounter_id; e["signature"] = "Accord Impossible"
            elif encounter_id == "c05_glass_strategist": e["name"] = "Le Stratège de Verre"; e["hp"] = 122; e["max_hp"] = 122; e["damage"] = [8,14]; e["fear"] = 8; e["chapter_miniboss_id"] = encounter_id; e["signature"] = "Doctrine de Contre-Mesure"
            elif encounter_id == "va_miniboss_dissonant_custodian": e["name"] = "Le Custode Dissonant"; e["hp"] = 132; e["max_hp"] = 132; e["damage"] = [9,14]; e["fear"] = 9; e["chapter_miniboss_id"] = encounter_id; e["signature"] = "Accord Refusé"
        if encounter_type == "boss":
            e["recruitable"] = false; e["is_boss"] = true
            if encounter_id == "c01_boss_ash_witness": e["name"] = "Le Témoin des Cendres"; e["hp"] = 110; e["max_hp"] = 110; e["damage"] = [7,12]; e["fear"] = 7; e["chapter_boss_id"] = encounter_id; e["signature"] = "Dernier Souvenir du Jour"
            elif encounter_id == "c02_marker_warden": e["name"] = "Sahra Vel — La Veilleuse des Bornes"; e["hp"] = 128; e["max_hp"] = 128; e["damage"] = [7,12]; e["fear"] = 6; e["chapter_boss_id"] = encounter_id; e["signature"] = "La Carte qui se Souvient"
            elif encounter_id == "c03_boss_threshold_echo": e["name"] = "L'Écho du Seuil"; e["hp"] = 148; e["max_hp"] = 148; e["damage"] = [8,13]; e["fear"] = 8; e["chapter_boss_id"] = encounter_id; e["signature"] = "Zéro Seconde"
            elif encounter_id == "c04_boss_unfinished_chorus": e["name"] = "Le Chœur Inachevé"; e["hp"] = 166; e["max_hp"] = 166; e["damage"] = [8,13]; e["fear"] = 8; e["chapter_boss_id"] = encounter_id; e["signature"] = "Nous étions plusieurs"
            elif encounter_id == "c05_boss_silex_general": e["name"] = "Le Général de Silex"; e["hp"] = 188; e["max_hp"] = 188; e["damage"] = [9,15]; e["fear"] = 9; e["chapter_boss_id"] = encounter_id; e["signature"] = "Ordre qui ne finit jamais"
            elif encounter_id == "vestige_ashai_boss_seventh_voice": e["name"] = "La Septième Voix"; e["hp"] = 230; e["max_hp"] = 230; e["damage"] = [10,16]; e["fear"] = 11; e["chapter_boss_id"] = encounter_id; e["signature"] = "Le Monde que Nous Accordons"; e["deep_vestige_boss"] = true
        GameState.battle_enemies.append(e)

func resolve_victory() -> Dictionary:
    if not active: return {}
    AshlandsRuntime.mark_encounter_cleared(encounter_id); pending_loot = _roll_loot(); _apply_loot(pending_loot); var finished_id := encounter_id; ashlands_combat_finished.emit(finished_id,true,pending_loot.duplicate(true)); _return_to_exploration(); return pending_loot.duplicate(true)
func resolve_defeat() -> void:
    if not active: return
    var finished_id := encounter_id; ashlands_combat_finished.emit(finished_id,false,{}); active = false; _resolving = false; encounter_id = ""; encounter_type = ""; miniboss_data = {}; AshlandsSceneRouter.return_to_hub("defeat")
func _roll_loot() -> Dictionary:
    if encounter_id == "vestige_ashai_boss_seventh_voice": return {"gold":70,"essence":16,"equipment_rarity":"rare"}
    if encounter_type != "miniboss": return {"gold":18,"essence":2,"equipment_rarity":"common"}
    var tier := str(miniboss_data.get("loot_tier","major")); var table := AshlandsMinibossDirector.get_loot_table(tier); return {"gold":45,"essence":8,"tier":tier,"guaranteed":table.get("guaranteed",[]),"possible":table.get("possible",[]),"rolls":int(table.get("rolls",0)),"equipment_rarity":"rare"}
func _apply_loot(loot: Dictionary) -> void:
    GameState.gold += int(loot.get("gold",0)); GameState.essence += int(loot.get("essence",0)); var rarity := str(loot.get("equipment_rarity","")); if rarity != "": loot["equipment"] = EquipmentManager.grant_random_party_weapon(rarity,encounter_id)
    for item in loot.get("guaranteed",[]): ExpeditionManager.add_resource(str(item),1)
func _return_to_exploration() -> void:
    var target := return_zone_id; var target_position := return_position; var restore := has_return_position; active = false; _resolving = false; encounter_id = ""; encounter_type = ""; miniboss_data = {}
    if target != "" and AshlandsSceneRouter.load_zone(target) and restore: _restore_exploration_position.call_deferred(target_position)
func _capture_return_position() -> void:
    has_return_position = false; var parties := get_tree().get_nodes_in_group("player_party"); if not parties.is_empty() and parties[0] is Node3D: return_position = (parties[0] as Node3D).global_position; has_return_position = true
func _restore_exploration_position(target_position: Vector3) -> void:
    await get_tree().process_frame; await get_tree().process_frame; var parties := get_tree().get_nodes_in_group("player_party"); if not parties.is_empty() and parties[0] is Node3D: (parties[0] as Node3D).global_position = target_position
func serialize() -> Dictionary: return {"active":active,"encounter_id":encounter_id,"encounter_type":encounter_type,"return_zone_id":return_zone_id,"return_position":[return_position.x,return_position.y,return_position.z],"has_return_position":has_return_position,"miniboss_data":miniboss_data,"pending_loot":pending_loot}
func deserialize(data: Dictionary) -> void:
    active = bool(data.get("active",false)); _resolving = false; encounter_id = str(data.get("encounter_id","")); encounter_type = str(data.get("encounter_type","")); return_zone_id = str(data.get("return_zone_id","")); var position_data: Array = data.get("return_position",[0,0,0]); if position_data.size() >= 3: return_position = Vector3(float(position_data[0]),float(position_data[1]),float(position_data[2])); has_return_position = bool(data.get("has_return_position",false)); miniboss_data = data.get("miniboss_data",{}).duplicate(true); pending_loot = data.get("pending_loot",{}).duplicate(true)
