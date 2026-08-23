extends Node

signal save_started(slot: int)
signal save_finished(slot: int, success: bool, recovered: bool)

const SAVE_PATH := "user://light_in_the_dark_save.json"
const SAVE_VERSION := "0.31"
const SLOT_COUNT := 3
const AUTOSAVE_SLOT := -1

var active_slot := 0
var last_status := ""
var session_started_ms := 0

func _ready() -> void:
    session_started_ms = Time.get_ticks_msec()

func save_game(slot: int = active_slot) -> bool:
    slot = _valid_slot(slot)
    save_started.emit(slot)
    last_status = "Sauvegarde en cours…"
    var payload := _build_payload()
    var body := JSON.stringify(payload)
    var envelope := {"checksum":body.sha256_text(),"payload":payload}
    var success := _atomic_write(_path(slot), JSON.stringify(envelope))
    if success:
        active_slot = slot if slot >= 0 else active_slot
        last_status = "Sauvegarde terminée."
        GameState.add_log("Partie sauvegardée%s." % (" automatiquement" if slot == AUTOSAVE_SLOT else ""))
    else:
        last_status = "Échec de la sauvegarde."
    save_finished.emit(slot, success, false)
    return success

func autosave(reason: String = "") -> bool:
    var success := save_game(AUTOSAVE_SLOT)
    if success and reason != "":
        last_status = "Autosauvegarde : %s" % reason
    return success

func load_game(slot: int = active_slot) -> bool:
    slot = _valid_slot(slot)
    var recovered := false
    var payload := _read_payload(_path(slot))
    if payload.is_empty():
        payload = _read_payload(_backup_path(slot))
        recovered = not payload.is_empty()
    if payload.is_empty() and slot == 0:
        payload = _read_payload(SAVE_PATH)
    if payload.is_empty():
        last_status = "Sauvegarde absente ou irrécupérable."
        save_finished.emit(slot, false, false)
        return false
    payload = _migrate(payload)
    if payload.is_empty():
        last_status = "Version de sauvegarde incompatible."
        save_finished.emit(slot, false, recovered)
        return false
    _apply_payload(payload)
    active_slot = slot if slot >= 0 else active_slot
    last_status = "Sauvegarde de secours restaurée." if recovered else "Sauvegarde chargée."
    GameState.add_log(last_status)
    save_finished.emit(slot, true, recovered)
    return true

func slot_metadata(slot: int) -> Dictionary:
    var payload := _read_payload(_path(_valid_slot(slot)))
    if payload.is_empty():
        payload = _read_payload(_backup_path(_valid_slot(slot)))
    return payload.get("metadata", {}).duplicate(true)

func all_slots_metadata() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for slot in range(SLOT_COUNT):
        var metadata := slot_metadata(slot)
        var empty := metadata.is_empty()
        metadata["slot"] = slot
        metadata["empty"] = empty
        result.append(metadata)
    var autosave_metadata := slot_metadata(AUTOSAVE_SLOT)
    var autosave_empty := autosave_metadata.is_empty()
    autosave_metadata["slot"] = AUTOSAVE_SLOT
    autosave_metadata["autosave"] = true
    autosave_metadata["empty"] = autosave_empty
    result.append(autosave_metadata)
    return result

func delete_slot(slot: int) -> bool:
    slot = _valid_slot(slot)
    var removed := false
    for path in [_path(slot), _backup_path(slot), _temp_path(slot)]:
        if FileAccess.file_exists(path):
            removed = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK or removed
    return removed

func _build_payload() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "metadata": {
            "timestamp": Time.get_datetime_string_from_system(),
            "chapter": CampaignState.current_chapter_number(),
            "zone": AshlandsRuntime.current_zone_id,
            "party": GameState.party.map(func(hero: Dictionary): return {"id":hero.get("id", ""),"name":hero.get("name", ""),"hp":hero.get("hp", 0),"max_hp":hero.get("max_hp", 0)}),
            "play_seconds": int((Time.get_ticks_msec() - session_started_ms) / 1000),
            "screen": GameState.current_screen
        },
        "gold": GameState.gold, "essence": GameState.essence, "light": GameState.light, "supplies": GameState.supplies,
        "party": GameState.party, "equipment": EquipmentManager.serialize(), "combat_loadouts": CombatLoadoutManager.serialize(),
        "creatures": CreatureManager.serialize(), "politics": PoliticalState.serialize(), "campaign": CampaignState.serialize(),
        "side_quests": SideQuestRuntime.serialize(), "bounty_contracts": BountyContractDirector.serialize(),
        "hero_renown": EnemyFearDirector.serialize(), "chapter_01": Chapter01Runtime.serialize(),
        "chapter_02": Chapter02Runtime.serialize(), "chapter_03": Chapter03Runtime.serialize(), "chapter_04": Chapter04Runtime.serialize(),
        "chapter_05": Chapter05Runtime.serialize(), "chapter_06": Chapter06Runtime.serialize(), "chapter_07": Chapter07Runtime.serialize(),
        "chapter_08": Chapter08Runtime.serialize(), "chapter_09": Chapter09Runtime.serialize(), "chapter_10": Chapter10Runtime.serialize(),
        "endgame": EndgameState.serialize(), "deep_vestiges": DeepVestigeRuntime.serialize(), "expedition_room": GameState.expedition_room,
        "ashlands": AshlandsRuntime.serialize(), "expedition": ExpeditionManager.serialize(), "field_encounters": FieldEncounterRuntime.serialize(),
        "community": CommunityRuntime.serialize(), "ashlands_minibosses": AshlandsMinibossDirector.serialize(),
        "ashlands_combat": AshlandsCombatBridge.serialize(), "campaign_memory": CampaignMemoryDirector.serialize(),
        "expedition_reports": ExpeditionReportDirector.serialize(), "preparation_presets": ExpeditionPreparationDirector.serialize()
    }

func _apply_payload(payload: Dictionary) -> void:
    GameState.gold = int(payload.get("gold", 120)); GameState.essence = int(payload.get("essence", 18))
    GameState.light = int(payload.get("light", 75)); GameState.supplies = int(payload.get("supplies", 8))
    GameState.party = payload.get("party", DataLoader.heroes.duplicate(true))
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        HeroSkillManager.prepare_hero(hero); EnemyFearDirector.prepare_hero(hero); PersistentInjuryRuntime.prepare_character(hero)
    EquipmentManager.deserialize(payload.get("equipment", {})); CombatLoadoutManager.deserialize(payload.get("combat_loadouts", {}))
    CreatureManager.deserialize(payload.get("creatures",{})); GameState.expedition_room = int(payload.get("expedition_room",0))
    PoliticalState.deserialize(payload.get("politics", {})); CampaignState.deserialize(payload.get("campaign", {}))
    SideQuestRuntime.deserialize(payload.get("side_quests", {})); BountyContractDirector.deserialize(payload.get("bounty_contracts", {}))
    EnemyFearDirector.deserialize(payload.get("hero_renown", {})); AshlandsRuntime.deserialize(payload.get("ashlands", {}))
    Chapter01Runtime.deserialize(payload.get("chapter_01", {})); Chapter02Runtime.deserialize(payload.get("chapter_02", {}))
    Chapter03Runtime.deserialize(payload.get("chapter_03", {})); Chapter04Runtime.deserialize(payload.get("chapter_04", {}))
    Chapter05Runtime.deserialize(payload.get("chapter_05", {})); Chapter06Runtime.deserialize(payload.get("chapter_06", {}))
    Chapter07Runtime.deserialize(payload.get("chapter_07", {})); Chapter08Runtime.deserialize(payload.get("chapter_08", {}))
    Chapter09Runtime.deserialize(payload.get("chapter_09", {})); Chapter10Runtime.deserialize(payload.get("chapter_10", {}))
    EndgameState.deserialize(payload.get("endgame",{})); DeepVestigeRuntime.deserialize(payload.get("deep_vestiges", {}))
    ExpeditionManager.deserialize(payload.get("expedition", {})); FieldEncounterRuntime.deserialize(payload.get("field_encounters",{}))
    CommunityRuntime.deserialize(payload.get("community",{})); AshlandsMinibossDirector.deserialize(payload.get("ashlands_minibosses", {}))
    AshlandsCombatBridge.deserialize(payload.get("ashlands_combat", {})); CampaignMemoryDirector.deserialize(payload.get("campaign_memory", {}))
    ExpeditionReportDirector.deserialize(payload.get("expedition_reports", {})); ExpeditionPreparationDirector.deserialize(payload.get("preparation_presets", {}))
    Chapter01Runtime.refresh_progress(); Chapter02Runtime.refresh_progress(); Chapter03Runtime.refresh_progress(); Chapter04Runtime.refresh_progress()
    Chapter05Runtime.refresh_progress(); Chapter06Runtime.refresh_progress(); Chapter07Runtime.refresh_progress(); Chapter08Runtime.refresh_progress()
    Chapter09Runtime.refresh_progress(); Chapter10Runtime.refresh_progress(); DeepVestigeRuntime.refresh_unlocks()
    if EndgameState.is_postgame_unlocked(): EndgameState.record_current_ending()

func _migrate(payload: Dictionary) -> Dictionary:
    var version := String(payload.get("version", "0.31"))
    if version != SAVE_VERSION:
        return {}
    payload["campaign_memory"] = payload.get("campaign_memory", {})
    payload["expedition_reports"] = payload.get("expedition_reports", {})
    payload["preparation_presets"] = payload.get("preparation_presets", {})
    return payload

func _atomic_write(path: String, text: String) -> bool:
    var temp := _temp_for(path)
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(text)
    file.flush()
    file.close()
    if FileAccess.file_exists(path):
        DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(_backup_for(path)))
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) == OK

func _read_payload(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if parsed is not Dictionary:
        return {}
    if parsed.has("payload"):
        var payload: Dictionary = parsed.get("payload", {})
        var body := JSON.stringify(payload)
        if String(parsed.get("checksum", "")) != body.sha256_text():
            return {}
        return payload
    return parsed

func _valid_slot(slot: int) -> int:
    return AUTOSAVE_SLOT if slot == AUTOSAVE_SLOT else clampi(slot, 0, SLOT_COUNT - 1)

func _path(slot: int) -> String:
    return "user://litd_autosave.json" if slot == AUTOSAVE_SLOT else "user://litd_slot_%d.json" % slot

func _backup_path(slot: int) -> String:
    return _backup_for(_path(slot))

func _temp_path(slot: int) -> String:
    return _temp_for(_path(slot))

func _backup_for(path: String) -> String:
    return path + ".bak"

func _temp_for(path: String) -> String:
    return path + ".tmp"
