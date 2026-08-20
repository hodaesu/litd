extends Node

signal ashlands_combat_started(encounter_id: String, encounter_type: String)
signal ashlands_combat_finished(encounter_id: String, victory: bool, loot: Dictionary)

const MAIN_SCENE := "res://scenes/Main.tscn"
const SHARED_UI_GOLD_REWARD := 28
const SHARED_UI_ESSENCE_REWARD := 4
const SHARED_UI_XP_REWARD := 30
const LEVEL_SCALING_POLICY := preload("res://scripts/core/level_scaling_policy.gd")
var level_scaling_policy := LEVEL_SCALING_POLICY.new()
var active := false
var encounter_id := ""
var encounter_type := ""
var return_zone_id := ""
var return_position := Vector3.ZERO
var has_return_position := false
var miniboss_data: Dictionary = {}
var pending_loot: Dictionary = {}
var _resolving := false

func _ready() -> void:
    GameState.screen_requested.connect(_on_screen_requested)

func begin(encounter_id_value: String, encounter_type_value: String, miniboss: Dictionary = {}) -> void:
    if active: return
    active = true
    _resolving = false
    encounter_id = encounter_id_value
    encounter_type = encounter_type_value
    return_zone_id = AshlandsRuntime.current_zone_id
    _capture_return_position()
    miniboss_data = miniboss.duplicate(true)
    pending_loot = {}
    _prepare_placeholder_enemies()
    GameState.current_screen = "combat"
    var error := get_tree().change_scene_to_file(MAIN_SCENE)
    if error == OK: call_deferred("_show_combat_after_load")
    ashlands_combat_started.emit(encounter_id,encounter_type)

func _show_combat_after_load() -> void:
    await get_tree().process_frame
    GameState.request_screen("combat")

func _on_screen_requested(screen_name: String) -> void:
    if not active:
        return
    if screen_name == "rewards":
        # La victoire reste maintenant affichée jusqu'à l'action explicite du joueur.
        # _resolving sert ici à distinguer une victoire déjà acquise d'un abandon.
        _resolving = true
    elif screen_name == "sanctuary":
        if _resolving:
            call_deferred("resolve_victory")
        else:
            _resolving = true
            call_deferred("resolve_defeat")

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
            match encounter_id:
                "c02_broken_curator": _setup_enemy(e,"Le Conservateur Brisé",82,[6,11],6,"Classé à jamais")
                "c03_threshold_sentinel": _setup_enemy(e,"La Sentinelle du Seuil",96,[7,12],7,"Protocole de Purge")
                "c04_faceless_measure": _setup_enemy(e,"Le Mesureur Sans Visage",108,[7,13],8,"Accord Impossible")
                "c05_glass_strategist": _setup_enemy(e,"Le Stratège de Verre",122,[8,14],8,"Doctrine de Contre-Mesure")
                "c06_shifted_wayfarer": _setup_enemy(e,"L'Arpenteur Décalé",134,[9,14],9,"Un pas trop tôt")
                "c07_opening_pilgrim": _setup_enemy(e,"Le Pèlerin de l'Ouverture",154,[10,16],10,"Laissez entrer")
                "c09_fear_echo": _setup_enemy(e,"L'Issue Redoutée",176,[11,17],13,"C'était inévitable")
                "c10_unpaid_cost": _setup_enemy(e,"Le Coût Oublié",188,[12,19],14,"Quelqu'un paiera")
                "va_miniboss_dissonant_custodian": _setup_enemy(e,"Le Custode Dissonant",132,[9,14],9,"Accord Refusé")
                "vs_miniboss_doctrine_hound": _setup_enemy(e,"Le Limier de Doctrine",146,[10,15],10,"Chasse à la Répétition")
                "vn_miniboss_seal_keeper": _setup_enemy(e,"Le Gardien du Sceau Fendu",142,[9,15],10,"Scellement Réactif")
                "vv_miniboss_order_bearer": _setup_enemy(e,"Le Porte-Ordre de Basalte",158,[10,16],11,"Priorité absolue")
                "vm_miniboss_drowned_pilot": _setup_enemy(e,"Le Pilote Sans Horizon",160,[10,17],11,"Courant de retour")
                "vz_miniboss_stone_cantor": _setup_enemy(e,"Le Chantre de Pierre",162,[10,17],12,"Répétez après moi")
                "vy_miniboss_causal_auditor": _setup_enemy(e,"L'Auditeur Causal",164,[11,17],12,"Erreur prévue")
            e["chapter_miniboss_id"] = encounter_id
        if encounter_type == "boss":
            e["recruitable"] = false; e["is_boss"] = true
            match encounter_id:
                "c01_boss_ash_witness": _setup_enemy(e,"Le Témoin des Cendres",110,[7,12],7,"Dernier Souvenir du Jour")
                "c02_marker_warden": _setup_enemy(e,"Sahra Vel — La Veilleuse des Bornes",128,[7,12],6,"La Carte qui se Souvient")
                "c03_boss_threshold_echo": _setup_enemy(e,"L'Écho du Seuil",148,[8,13],8,"Zéro Seconde")
                "c04_boss_unfinished_chorus": _setup_enemy(e,"Le Chœur Inachevé",166,[8,13],8,"Nous étions plusieurs")
                "c05_boss_silex_general": _setup_enemy(e,"Le Général de Silex",188,[9,15],9,"Ordre qui ne finit jamais")
                "c06_boss_boundary": _setup_enemy(e,"La Frontière qui marche",210,[10,16],10,"Ici n'est plus ici")
                "c07_boss_edras": _setup_enemy(e,"Edras Nhal, l'Ouvert",224,[10,17],10,"Regardez enfin")
                "c08_boss_varkhane": _setup_enemy(e,"Maréchal du Trône Vide",236,[11,18],11,"Ordre du Trône Vide")
                "c08_boss_azravel": _setup_enemy(e,"Le Saint de la Faille",244,[11,19],12,"Une seule vérité")
                "c09_boss_consensus": _setup_enemy(e,"Le Consensus Brisé",272,[12,20],14,"Nous ne voyons pas le même monde")
                "c10_boss_final": _setup_enemy(e,"La Rupture Commune",320,[14,22],16,"Ce que nous refusons de sacrifier")
                "vestige_ashai_boss_seventh_voice": _setup_enemy(e,"La Septième Voix",230,[10,16],11,"Le Monde que Nous Accordons"); e["deep_vestige_boss"] = true
                "vestige_silex_boss_last_strategist": _setup_enemy(e,"Le Dernier Stratège",252,[11,17],12,"Victoire avant la bataille"); e["deep_vestige_boss"] = true
                "vestige_saan_boss_last_watch": _setup_enemy(e,"La Dernière Veille",248,[10,17],12,"Que personne ne passe"); e["deep_vestige_boss"] = true
                "vestige_vaor_boss_command_without_body": _setup_enemy(e,"Le Commandement Sans Corps",262,[12,18],13,"Obéissez et le chemin s'ouvrira"); e["deep_vestige_boss"] = true
                "vestige_lyrmar_boss_absent_cartographer": _setup_enemy(e,"La Cartographe des Mers Absentes",264,[12,18],13,"Toutes les routes reviennent"); e["deep_vestige_boss"] = true
                "vestige_sahmir_boss_single_interpreter": _setup_enemy(e,"L'Interprète Unique",268,[12,19],14,"Un seul sens"); e["deep_vestige_boss"] = true
                "vestige_ydris_boss_living_theorem": _setup_enemy(e,"Le Théorème Vivant",270,[13,19],14,"Déjà calculé"); e["deep_vestige_boss"] = true
            e["chapter_boss_id"] = encounter_id
        level_scaling_policy.apply_campaign_scaling(e, CampaignState.current_chapter_number(), encounter_type)
        EndgameState.apply_enemy_scaling(e)
        GameState.battle_enemies.append(e)

func _setup_enemy(enemy: Dictionary, name: String, hp: int, damage: Array, fear: int, signature: String) -> void:
    enemy["name"] = name; enemy["hp"] = hp; enemy["max_hp"] = hp; enemy["damage"] = damage; enemy["fear"] = fear; enemy["signature"] = signature

func preview_loot() -> Dictionary:
    if not active:
        return {}
    return _roll_loot().duplicate(true)

func resolve_victory() -> Dictionary:
    if not active: return {}
    _remove_shared_ui_currency_reward()
    _grant_campaign_xp_bonus()
    AshlandsRuntime.mark_encounter_cleared(encounter_id); pending_loot = _roll_loot(); _apply_loot(pending_loot)
    var finished_id := encounter_id; ashlands_combat_finished.emit(finished_id,true,pending_loot.duplicate(true)); _return_to_exploration(); return pending_loot.duplicate(true)

func _remove_shared_ui_currency_reward() -> void:
    # main.gd accorde encore la récompense du petit donjon prototype avant d'émettre
    # l'écran rewards. Les combats routés possèdent leur propre table : on retire donc
    # uniquement ce montant partagé avant d'appliquer le vrai butin de campagne.
    GameState.gold = maxi(0, GameState.gold - SHARED_UI_GOLD_REWARD)
    GameState.essence = maxi(0, GameState.essence - SHARED_UI_ESSENCE_REWARD)

func _campaign_xp_target() -> int:
    var target := 90 + CampaignState.current_chapter_number() * 10
    if encounter_type == "miniboss": target += 80
    elif encounter_type == "boss": target += 170
    if bool(miniboss_data.get("deep_vestige", false)): target += 40
    return target

func _grant_campaign_xp_bonus() -> void:
    # L'UI commune a déjà donné 30 XP. La campagne complète seulement jusqu'à
    # la cible de la rencontre afin d'éviter une progression nécessitant >1000 combats.
    var bonus := maxi(0, _campaign_xp_target() - SHARED_UI_XP_REWARD)
    if bonus <= 0: return
    CreatureManager.grant_active_xp(bonus)
    for hero_value in GameState.party:
        HeroSkillManager.grant_xp(hero_value, bonus)

func resolve_defeat() -> void:
    if not active: return
    var finished_id := encounter_id; ashlands_combat_finished.emit(finished_id,false,{}); active = false; _resolving = false; encounter_id = ""; encounter_type = ""; miniboss_data = {}; AshlandsSceneRouter.return_to_hub("defeat")

func _roll_loot() -> Dictionary:
    if encounter_id in ["vestige_ashai_boss_seventh_voice","vestige_silex_boss_last_strategist","vestige_saan_boss_last_watch","vestige_vaor_boss_command_without_body","vestige_lyrmar_boss_absent_cartographer","vestige_sahmir_boss_single_interpreter","vestige_ydris_boss_living_theorem"]: return {"gold":80,"essence":18,"equipment_rarity":"rare"}
    if encounter_id == "c10_boss_final": return {"gold":0,"essence":0,"equipment_rarity":""}
    if encounter_id in ["c06_boss_boundary","c07_boss_edras","c08_boss_varkhane","c08_boss_azravel","c09_boss_consensus"]: return {"gold":65,"essence":12,"equipment_rarity":"rare"}
    if encounter_type != "miniboss": return {"gold":18,"essence":2,"equipment_rarity":"common"}
    var tier := str(miniboss_data.get("loot_tier","major")); var table := AshlandsMinibossDirector.get_loot_table(tier)
    return {"gold":45,"essence":8,"tier":tier,"guaranteed":table.get("guaranteed",[]),"possible":table.get("possible",[]),"rolls":int(table.get("rolls",0)),"equipment_rarity":"rare"}

func _apply_loot(loot: Dictionary) -> void:
    GameState.gold += int(loot.get("gold",0)); GameState.essence += int(loot.get("essence",0)); var rarity := str(loot.get("equipment_rarity",""))
    if rarity != "": loot["equipment"] = EquipmentManager.grant_random_party_weapon(rarity,encounter_id)
    for item in loot.get("guaranteed",[]): ExpeditionManager.add_resource(str(item),1)

func _return_to_exploration() -> void:
    var target := return_zone_id; var target_position := return_position; var restore := has_return_position
    active = false; _resolving = false; encounter_id = ""; encounter_type = ""; miniboss_data = {}
    if target != "" and AshlandsSceneRouter.load_zone(target) and restore: _restore_exploration_position.call_deferred(target_position)

func _capture_return_position() -> void:
    has_return_position = false; var parties := get_tree().get_nodes_in_group("player_party")
    if not parties.is_empty() and parties[0] is Node3D: return_position = (parties[0] as Node3D).global_position; has_return_position = true

func _restore_exploration_position(target_position: Vector3) -> void:
    await get_tree().process_frame; await get_tree().process_frame; var parties := get_tree().get_nodes_in_group("player_party")
    if not parties.is_empty() and parties[0] is Node3D: (parties[0] as Node3D).global_position = target_position

func serialize() -> Dictionary:
    return {"active":active,"encounter_id":encounter_id,"encounter_type":encounter_type,"return_zone_id":return_zone_id,"return_position":[return_position.x,return_position.y,return_position.z],"has_return_position":has_return_position,"miniboss_data":miniboss_data,"pending_loot":pending_loot}

func deserialize(data: Dictionary) -> void:
    active = bool(data.get("active",false)); _resolving = false; encounter_id = str(data.get("encounter_id","")); encounter_type = str(data.get("encounter_type","")); return_zone_id = str(data.get("return_zone_id",""))
    var position_data: Array = data.get("return_position",[0,0,0]); if position_data.size() >= 3: return_position = Vector3(float(position_data[0]),float(position_data[1]),float(position_data[2]))
    has_return_position = bool(data.get("has_return_position",false)); miniboss_data = data.get("miniboss_data",{}).duplicate(true); pending_loot = data.get("pending_loot",{}).duplicate(true)
