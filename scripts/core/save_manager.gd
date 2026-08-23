extends Node

const SAVE_PATH := "user://light_in_the_dark_save.json"
const SAVE_VERSION := "0.31"

func save_game() -> bool:
    var payload := {
        "version": SAVE_VERSION,
        "gold": GameState.gold,
        "essence": GameState.essence,
        "light": GameState.light,
        "supplies": GameState.supplies,
        "party": GameState.party,
        "equipment": EquipmentManager.serialize(),
        "creatures": CreatureManager.serialize(),
        "politics": PoliticalState.serialize(),
        "campaign": CampaignState.serialize(),
        "bounty_contracts": BountyContractDirector.serialize(),
        "hero_renown": EnemyFearDirector.serialize(),
        "chapter_01": Chapter01Runtime.serialize(),
        "chapter_02": Chapter02Runtime.serialize(),
        "chapter_03": Chapter03Runtime.serialize(),
        "chapter_04": Chapter04Runtime.serialize(),
        "chapter_05": Chapter05Runtime.serialize(),
        "chapter_06": Chapter06Runtime.serialize(),
        "chapter_07": Chapter07Runtime.serialize(),
        "chapter_08": Chapter08Runtime.serialize(),
        "chapter_09": Chapter09Runtime.serialize(),
        "chapter_10": Chapter10Runtime.serialize(),
        "endgame": EndgameState.serialize(),
        "deep_vestiges": DeepVestigeRuntime.serialize(),
        "expedition_room": GameState.expedition_room,
        "ashlands": AshlandsRuntime.serialize(),
        "expedition": ExpeditionManager.serialize(),
        "field_encounters": FieldEncounterRuntime.serialize(),
        "community": CommunityRuntime.serialize(),
        "ashlands_minibosses": AshlandsMinibossDirector.serialize(),
        "ashlands_combat": AshlandsCombatBridge.serialize()
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null: return false
    file.store_string(JSON.stringify(payload)); GameState.add_log("Partie sauvegardée."); return true

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH): return false
    var file := FileAccess.open(SAVE_PATH,FileAccess.READ); var payload = JSON.parse_string(file.get_as_text())
    if typeof(payload) != TYPE_DICTIONARY: return false
    GameState.gold = int(payload.get("gold",120)); GameState.essence = int(payload.get("essence",18)); GameState.light = int(payload.get("light",75)); GameState.supplies = int(payload.get("supplies",8)); GameState.party = payload.get("party",DataLoader.heroes.duplicate(true))
    for hero_value in GameState.party: HeroSkillManager.prepare_hero(hero_value); EnemyFearDirector.prepare_hero(hero_value); PersistentInjuryRuntime.prepare_character(hero_value)
    EquipmentManager.deserialize(payload.get("equipment",{})); CreatureManager.deserialize(payload.get("creatures",{})); GameState.expedition_room = int(payload.get("expedition_room",0)); PoliticalState.deserialize(payload.get("politics",{})); CampaignState.deserialize(payload.get("campaign",{})); BountyContractDirector.deserialize(payload.get("bounty_contracts",{})); EnemyFearDirector.deserialize(payload.get("hero_renown",{})); AshlandsRuntime.deserialize(payload.get("ashlands",{}))
    Chapter01Runtime.deserialize(payload.get("chapter_01",{})); Chapter02Runtime.deserialize(payload.get("chapter_02",{})); Chapter03Runtime.deserialize(payload.get("chapter_03",{})); Chapter04Runtime.deserialize(payload.get("chapter_04",{})); Chapter05Runtime.deserialize(payload.get("chapter_05",{})); Chapter06Runtime.deserialize(payload.get("chapter_06",{})); Chapter07Runtime.deserialize(payload.get("chapter_07",{})); Chapter08Runtime.deserialize(payload.get("chapter_08",{})); Chapter09Runtime.deserialize(payload.get("chapter_09",{})); Chapter10Runtime.deserialize(payload.get("chapter_10",{})); EndgameState.deserialize(payload.get("endgame",{})); DeepVestigeRuntime.deserialize(payload.get("deep_vestiges",{}))
    ExpeditionManager.deserialize(payload.get("expedition",{})); FieldEncounterRuntime.deserialize(payload.get("field_encounters",{})); CommunityRuntime.deserialize(payload.get("community",{})); AshlandsMinibossDirector.deserialize(payload.get("ashlands_minibosses",{})); AshlandsCombatBridge.deserialize(payload.get("ashlands_combat",{}))
    Chapter01Runtime.refresh_progress(); Chapter02Runtime.refresh_progress(); Chapter03Runtime.refresh_progress(); Chapter04Runtime.refresh_progress(); Chapter05Runtime.refresh_progress(); Chapter06Runtime.refresh_progress(); Chapter07Runtime.refresh_progress(); Chapter08Runtime.refresh_progress(); Chapter09Runtime.refresh_progress(); Chapter10Runtime.refresh_progress(); DeepVestigeRuntime.refresh_unlocks()
    if EndgameState.is_postgame_unlocked(): EndgameState.record_current_ending()
    GameState.add_log("Sauvegarde chargée."); return true
