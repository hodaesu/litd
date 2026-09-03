extends Node

signal session_started(snapshot: Dictionary)
signal session_changed(snapshot: Dictionary)
signal room_entered(room_id: String, snapshot: Dictionary)
signal interaction_previewed(anchor_id: String, preview: Dictionary)
signal interaction_resolved(anchor_id: String, action_id: String, result: Dictionary)
signal combat_requested(encounter_id: String, room_id: String)
signal combat_resolved(encounter_id: String, victory: bool, snapshot: Dictionary)

const SESSION_RUNTIME := preload("res://scripts/core/veilleurs_vs001_session_runtime.gd")
const VS001 := preload("res://scripts/core/veilleurs_vs001_runtime.gd")
const ZONE_ID := "veilleurs_vs001_voices_under_sanctuary"
const SCENE_PATH := "res://scenes/world/veilleurs/voices_under_sanctuary_playable.tscn"

var session: RefCounted = SESSION_RUNTIME.new()
var pending_combat: Dictionary = {}
var cleared_encounters: Dictionary = {}
var claimed_loot: Dictionary = {}
var last_interaction: Dictionary = {}

func _ready() -> void:
    if not AshlandsCombatBridge.ashlands_combat_finished.is_connected(_on_combat_finished):
        AshlandsCombatBridge.ashlands_combat_finished.connect(_on_combat_finished)
    if not GameState.new_game_reset.is_connected(reset_new_game):
        GameState.new_game_reset.connect(reset_new_game)

func reset_new_game() -> void:
    session = SESSION_RUNTIME.new()
    pending_combat.clear()
    cleared_encounters.clear()
    claimed_loot.clear()
    last_interaction.clear()

func start_new_session() -> Dictionary:
    session = SESSION_RUNTIME.new()
    pending_combat.clear()
    cleared_encounters.clear()
    claimed_loot.clear()
    last_interaction.clear()
    var snapshot: Dictionary = session.call("start", "WATCHERS_VERTICAL_001")
    session_started.emit(snapshot.duplicate(true))
    session_changed.emit(snapshot.duplicate(true))
    return snapshot

func ensure_session() -> Dictionary:
    var snapshot: Dictionary = session.call("snapshot")
    if not bool(snapshot.get("active", false)):
        return start_new_session()
    return snapshot

func snapshot() -> Dictionary:
    return session.call("snapshot")

func is_active() -> bool:
    return bool(snapshot().get("active", false))

func current_room() -> String:
    return str(session.call("current_room"))

func enter_room(room_id: String) -> Dictionary:
    ensure_session()
    if room_id == current_room():
        return {"success": true, "moved": false, "state": snapshot()}
    var result: Dictionary = session.call("enter_room", room_id, "normal_move")
    if bool(result.get("success", false)):
        var state_value: Dictionary = result.get("state", snapshot())
        room_entered.emit(room_id, state_value.duplicate(true))
        session_changed.emit(state_value.duplicate(true))
    return result

func preview_anchor(anchor_id: String) -> Dictionary:
    ensure_session()
    var preview: Dictionary = _build_preview(anchor_id)
    last_interaction = {"anchor_id": anchor_id, "preview": preview.duplicate(true)}
    interaction_previewed.emit(anchor_id, preview.duplicate(true))
    return preview

func execute_anchor_action(anchor_id: String, action_id: String) -> Dictionary:
    ensure_session()
    var preview: Dictionary = _build_preview(anchor_id)
    var options: Array = preview.get("options", [])
    var allowed := false
    for option_value: Variant in options:
        var option: Dictionary = option_value
        if str(option.get("id", "")) == action_id:
            allowed = true
            break
    if not allowed:
        var blocked := {"success": false, "reason": "action_not_available", "anchor_id": anchor_id, "action_id": action_id}
        interaction_resolved.emit(anchor_id, action_id, blocked.duplicate(true))
        return blocked

    var result: Dictionary = _resolve_action(anchor_id, action_id)
    if result.has("state"):
        var state_value: Dictionary = result.get("state", snapshot())
        session_changed.emit(state_value.duplicate(true))
    interaction_resolved.emit(anchor_id, action_id, result.duplicate(true))
    return result

func interaction_prompt(anchor_id: String) -> String:
    var preview: Dictionary = _build_preview(anchor_id)
    return str(preview.get("prompt", "Examiner"))

func is_encounter_cleared(encounter_id: String) -> bool:
    return bool(cleared_encounters.get(encounter_id, false))

func is_loot_claimed(room_key: String) -> bool:
    return bool(claimed_loot.get(room_key, false))

func secret_unlocked() -> bool:
    return bool(snapshot().get("s8_unlocked", false))

func _build_preview(anchor_id: String) -> Dictionary:
    var state_value: Dictionary = snapshot()
    var room_id := str(state_value.get("current_room", ""))
    var preview := {
        "anchor_id": anchor_id,
        "title": "Interaction",
        "description": "",
        "prompt": "EXAMINER",
        "room_id": room_id,
        "options": []
    }
    match anchor_id:
        "extraction_gate":
            preview["title"] = "Sortie du Sanctuaire inférieur"
            preview["description"] = "Revenir physiquement à l’entrée permet d’extraire la compagnie. L’extraction est irréversible pour cette expédition."
            preview["prompt"] = "EXTRAIRE"
            preview["options"] = [_option("extract", "EXTRAIRE", true)]
        "s1_fresco":
            preview["title"] = "Fresque des Trois Traces"
            preview["description"] = "Une structure antérieure aux formes stabilisées des Trois Éveils. L’examen informe seulement : rien n’est consommé."
            preview["options"] = [_option("inspect", "OBSERVER", false)]
        "s2_tripwire":
            preview["title"] = "Fil tendu dans la galerie"
            var tripwire_state := str(state_value.get("s2_tripwire", "armed"))
            preview["description"] = "État : %s. Inspecter n’actionne jamais le piège." % tripwire_state
            if tripwire_state in ["armed", "detected"]:
                preview["options"] = [
                    _option("inspect", "EXAMINER", false),
                    _option("disarm_tripwire", "DÉSARMER", false),
                    _option("trigger_tripwire", "FORCER LE PASSAGE", true)
                ]
            else:
                preview["options"] = [_option("inspect", "EXAMINER", false)]
        "s2_salvage":
            preview["title"] = "Câble récupérable"
            preview["description"] = "Le mécanisme peut être démonté uniquement après neutralisation du piège."
            preview["options"] = [_option("salvage_tripwire", "RÉCUPÉRER", false)] if str(state_value.get("s2_tripwire", "armed")) == "disarmed" else [_option("inspect", "EXAMINER", false)]
        "s3_combat":
            preview["title"] = "Salle des Dormeurs"
            preview["description"] = "Deux Goules affamées et une éclaireuse occupent la salle."
            preview["prompt"] = "AFFRONTER"
            preview["options"] = [_option("inspect", "OBSERVER", false)] if is_encounter_cleared("vs001_s3_ghouls") else [
                _option("inspect", "OBSERVER", false),
                _option("fight_s3", "ENGAGER LE COMBAT", true)
            ]
        "s3_corpses":
            preview["title"] = "Cadavres de la Salle des Dormeurs"
            preview["description"] = "Les corps restent des éléments du monde. Leur fouille est séparée du combat."
            preview["options"] = [_option("search_s3", "FOUILLER", false)] if is_encounter_cleared("vs001_s3_ghouls") and not is_loot_claimed("s3") else [_option("inspect", "EXAMINER", false)]
        "s4_supplies":
            preview["title"] = "Réserve oubliée"
            preview["description"] = "Une branche facultative contenant de l’huile, des soins et des outils."
            preview["options"] = [_option("search_s4", "RÉCUPÉRER", false)] if not is_loot_claimed("s4") else [_option("inspect", "EXAMINER", false)]
        "s4_black_basin":
            preview["title"] = "Bassin noir"
            preview["description"] = "Le bassin est un objet d’observation et de Rémanence. Aucun usage automatique n’est déclenché."
            preview["options"] = [_option("inspect", "EXAMINER", false)]
        "s5_scout_corpse":
            preview["title"] = "Éclaireur tombé"
            preview["description"] = "Le corps porte encore les traces d’une tentative d’approche du dispositif."
            preview["options"] = [_option("search_s5", "EXAMINER ET FOUILLER", false)] if not is_loot_claimed("s5") else [_option("inspect", "EXAMINER", false)]
        "s5_wall_voice":
            preview["title"] = "Voix dans la paroi"
            preview["description"] = "Une vibration répétitive traverse la pierre. L’écoute ne consomme rien."
            preview["options"] = [_option("inspect", "ÉCOUTER", false)]
        "s6_survivor":
            preview = _recruitment_preview(state_value)
        "s7_combat":
            preview["title"] = "Chambre des Voix"
            preview["description"] = "Une Goule vorace accompagnée de deux Goules affamées protège le dispositif."
            preview["prompt"] = "AFFRONTER"
            preview["options"] = [_option("inspect", "OBSERVER", false)] if is_encounter_cleared("vs001_s7_ghouls") else [
                _option("inspect", "OBSERVER", false),
                _option("fight_s7", "ENGAGER LE COMBAT", true)
            ]
        "s7_acoustic_device":
            preview["title"] = "Dispositif acoustique"
            preview["description"] = "Le choix sur le dispositif clôt l’objectif. Étudier peut révéler un passage inférieur."
            if not is_encounter_cleared("vs001_s7_ghouls"):
                preview["options"] = [_option("inspect", "OBSERVER À DISTANCE", false)]
            elif str(state_value.get("s7_device", "intact")) == "intact":
                preview["options"] = [
                    _option("study_device", "ÉTUDIER", false),
                    _option("disable_device", "DÉSACTIVER", true),
                    _option("destroy_device", "DÉTRUIRE", true)
                ]
            else:
                preview["options"] = [_option("inspect", "EXAMINER", false)]
        "s7_secret_stair":
            preview["title"] = "Jointure sous la pierre"
            preview["description"] = "Le passage inférieur n’existe comme route praticable qu’après compréhension du dispositif."
            preview["options"] = [_option("reveal_secret", "OUVRIR LE PASSAGE", false)] if bool(state_value.get("s8_unlocked", false)) else [_option("inspect", "EXAMINER", false)]
        "s8_archive":
            preview["title"] = "Archive Basse"
            preview["description"] = "Des traces de pensée précèdent la nomination officielle des Trois Éveils."
            preview["options"] = [_option("inspect", "LIRE", false)]
        "s8_fragment":
            preview["title"] = "Fragment des Trois Voies"
            preview["description"] = "Le fragment peut être emporté une fois découvert."
            preview["options"] = [_option("search_s8", "RECUEILLIR", false)] if not is_loot_claimed("s8") else [_option("inspect", "EXAMINER", false)]
        _:
            preview["title"] = "Trace"
            preview["description"] = "Aucune action irréversible n’est associée à cette trace."
            preview["options"] = [_option("inspect", "EXAMINER", false)]
    return preview

func _recruitment_preview(state_value: Dictionary) -> Dictionary:
    var outcome := str(state_value.get("s6_outcome", "unresolved"))
    var s6_state: Dictionary = state_value.get("s6_state", {})
    var preview := {
        "anchor_id": "s6_survivor",
        "title": "Goule blessée",
        "description": "Peur %d · Confiance %d · Douleur %d · Stabilité %d. Observer ne force jamais le lien." % [
            int(s6_state.get("fear", 0)),
            int(s6_state.get("trust", 0)),
            int(s6_state.get("pain", 0)),
            int(s6_state.get("stability", 0))
        ],
        "prompt": "APPROCHER",
        "room_id": "s6_survivor",
        "options": []
    }
    if outcome != "unresolved":
        preview["description"] = "Cette rencontre est résolue : %s." % outcome
        preview["options"] = [_option("inspect", "EXAMINER", false)]
        return preview
    preview["options"] = [
        _option("s6_observe", "OBSERVER", false),
        _option("s6_lower_guard", "NAYRA · ABAISSER LA GARDE", false),
        _option("s6_diagnose", "AÏSHA · DIAGNOSTIQUER", false),
        _option("s6_treat", "AÏSHA · SOIGNER", false),
        _option("s6_deescalate", "IDRIS · DÉSAMORCER", false),
        _option("s6_offer_food", "OFFRIR DE LA NOURRITURE", false),
        _option("s6_recruit", "TENTER LE LIEN", true),
        _option("s6_leave", "LAISSER EN VIE", true),
        _option("s6_attack", "ATTAQUER", true)
    ]
    return preview

func _resolve_action(anchor_id: String, action_id: String) -> Dictionary:
    match action_id:
        "inspect":
            return {"success": true, "informational_only": true, "anchor_id": anchor_id, "state": snapshot()}
        "extract":
            var extraction: Dictionary = session.call("extract", "vs001_physical_exit")
            call_deferred("_return_to_hub_after_extraction")
            return extraction
        "disarm_tripwire":
            return session.call("set_tripwire_state", "disarmed")
        "trigger_tripwire":
            return session.call("set_tripwire_state", "triggered")
        "salvage_tripwire":
            var salvage: Dictionary = session.call("set_tripwire_state", "salvaged")
            if bool(salvage.get("success", false)):
                claimed_loot["s2_salvage"] = true
            return salvage
        "fight_s3":
            return _begin_combat("vs001_s3_ghouls", "s3_sleepers", "s3")
        "fight_s7":
            return _begin_combat("vs001_s7_ghouls", "s7_voice_chamber", "s7")
        "search_s3":
            return _claim_room_loot("s3")
        "search_s4":
            return _claim_room_loot("s4")
        "search_s5":
            return _claim_room_loot("s5")
        "search_s8":
            return _claim_room_loot("s8")
        "s6_observe":
            return session.call("recruitment_action", "observe")
        "s6_lower_guard":
            return session.call("recruitment_action", "nayra_lower_guard")
        "s6_diagnose":
            return session.call("recruitment_action", "aisha_diagnose")
        "s6_treat":
            return session.call("recruitment_action", "aisha_treat")
        "s6_deescalate":
            return session.call("recruitment_action", "idris_deescalate")
        "s6_offer_food":
            return session.call("recruitment_action", "offer_food")
        "s6_recruit":
            var subdue: Dictionary = session.call("recruitment_action", "subdue")
            if not bool(subdue.get("success", false)):
                return subdue
            var roll: int = _deterministic_recruitment_roll()
            return session.call("resolve_recruitment", "nayra", roll)
        "s6_leave":
            return session.call("recruitment_action", "leave")
        "s6_attack":
            return _begin_combat("vs001_s6_wounded_ghoul", "s6_survivor", "s6_kill")
        "study_device":
            return session.call("resolve_device", "study", true)
        "disable_device":
            return session.call("resolve_device", "disable", true)
        "destroy_device":
            return session.call("resolve_device", "destroy", true)
        "reveal_secret":
            return {"success": secret_unlocked(), "secret_visible": secret_unlocked(), "state": snapshot()}
        _:
            return {"success": false, "reason": "unhandled_action", "action_id": action_id}

func _claim_room_loot(room_key: String) -> Dictionary:
    if is_loot_claimed(room_key):
        return {"success": false, "reason": "loot_already_claimed", "state": snapshot()}
    var result: Dictionary = session.call("acquire_room_loot", room_key)
    if bool(result.get("success", false)):
        claimed_loot[room_key] = true
    return result

func _begin_combat(encounter_id: String, room_id: String, source_key: String) -> Dictionary:
    if not pending_combat.is_empty() or AshlandsCombatBridge.active:
        return {"success": false, "reason": "combat_already_active", "state": snapshot()}
    pending_combat = {
        "encounter_id": encounter_id,
        "room_id": room_id,
        "source_key": source_key,
        "rounds": 0
    }
    GameState.battle_rounds = 0
    AshlandsCombatBridge.begin(encounter_id, "normal")
    _prepare_vs001_enemies(encounter_id)
    combat_requested.emit(encounter_id, room_id)
    return {"success": true, "combat_started": true, "encounter_id": encounter_id, "state": snapshot()}

func _prepare_vs001_enemies(encounter_id: String) -> void:
    var profile_keys: Array[String] = []
    if encounter_id == "vs001_s3_ghouls":
        profile_keys = ["hungry_standard", "hungry_standard", "hungry_scout"]
    elif encounter_id == "vs001_s7_ghouls":
        profile_keys = ["voracious_evolved", "hungry_standard", "hungry_standard"]
    elif encounter_id == "vs001_s6_wounded_ghoul":
        profile_keys = ["hungry_standard"]
    if profile_keys.is_empty():
        return

    var enemies: Array = []
    for index: int in range(profile_keys.size()):
        var enemy: Dictionary = _enemy_from_profile(profile_keys[index], index)
        if encounter_id == "vs001_s6_wounded_ghoul":
            enemy["name"] = "Goule blessée"
            enemy["hp"] = maxi(1, int(round(float(enemy.get("max_hp", 30)) * 0.28)))
        enemies.append(enemy)
    GameState.battle_enemies = enemies

func _enemy_from_profile(profile_key: String, index: int) -> Dictionary:
    var base_value: Variant = DataLoader.find_by_id(DataLoader.enemies, 1)
    var enemy: Dictionary = base_value.duplicate(true) if base_value is Dictionary else {}
    var profile: Dictionary = VS001.ghoul_profile(profile_key)
    var stats: Dictionary = profile.get("stats", {})
    enemy["id"] = 9100 + index
    enemy["name"] = str(profile.get("display_name", "Goule"))
    enemy["creature_id"] = "hungry_ghoul"
    enemy["family"] = "ghoul"
    enemy["vs001_profile"] = profile_key
    enemy["evolution_level"] = int(profile.get("evolution_level", 1))
    enemy["hp"] = int(stats.get("hp", 30))
    enemy["max_hp"] = int(stats.get("hp", 30))
    enemy["damage"] = stats.get("damage", [3, 6])
    enemy["accuracy"] = int(stats.get("accuracy", 74))
    enemy["dodge"] = int(stats.get("dodge", 9))
    enemy["initiative"] = int(stats.get("initiative", 11))
    enemy["armor"] = int(stats.get("armor", 0))
    enemy["resolve"] = int(stats.get("resolve", 55))
    enemy["fear_resistance"] = int(stats.get("fear_resistance", 30))
    enemy["bleed_resistance"] = int(stats.get("bleed_resistance", 25))
    enemy["fear"] = 0
    enemy["guarding"] = false
    enemy["recruitable"] = false
    enemy["vs001_authored_recruitment_only"] = true
    return enemy

func _deterministic_recruitment_roll() -> int:
    var state_value: Dictionary = snapshot()
    var balance: Dictionary = VS001.load_balance()
    var check: Dictionary = balance.get("recruitment_s6", {}).get("capture_check", {})
    var roll_range: Array = check.get("deterministic_roll_range", [-8, 8])
    var low: int = int(roll_range[0])
    var high: int = int(roll_range[1])
    var span: int = maxi(1, high - low + 1)
    var signature := "%s|%s|%s" % [
        str(state_value.get("seed", "WATCHERS_VERTICAL_001")),
        str(state_value.get("pulse_index", 0)),
        str(state_value.get("s6_state", {}))
    ]
    return low + abs(signature.hash()) % span

func _option(id_value: String, label_value: String, irreversible: bool) -> Dictionary:
    return {"id": id_value, "label": label_value, "irreversible": irreversible}

func _on_combat_finished(encounter_id: String, victory: bool, _loot: Dictionary) -> void:
    if pending_combat.is_empty() or str(pending_combat.get("encounter_id", "")) != encounter_id:
        return
    var source_key := str(pending_combat.get("source_key", ""))
    var rounds: int = maxi(1, int(GameState.battle_rounds))
    if victory:
        session.call("resolve_combat", rounds, true)
        cleared_encounters[encounter_id] = true
        if source_key == "s6_kill":
            session.call("recruitment_action", "kill")
    else:
        session.call("extract", "defeat")
    var state_value: Dictionary = snapshot()
    pending_combat.clear()
    combat_resolved.emit(encounter_id, victory, state_value.duplicate(true))
    session_changed.emit(state_value.duplicate(true))

func _return_to_hub_after_extraction() -> void:
    AshlandsSceneRouter.return_to_hub("vs001_extracted")
