extends Node

signal state_changed
signal screen_requested(screen_name: String)
signal new_game_reset

const MAX_CHARACTER_LEVEL: int = 50
const CANONICAL_PARTY_IDENTITIES := {
    "aurelien": {"canonical_id": "sahen_varo", "name": "Sahen Varo"},
    "malvor": {"canonical_id": "mira_sen", "name": "Mira Sen"},
    "lysandra": {"canonical_id": "narem_osh", "name": "Narem Osh"},
    "darius": {"canonical_id": "ysra_nahal", "name": "Ysra Nahal"}
}

var current_screen := "title"
var gold := 120
var essence := 18
var light := 75
var supplies := 8
var expedition_room := 0
var expedition_rooms := 4
var _party: Array = []
var party: Array:
    get:
        return _party
    set(value):
        _party = value
        canonicalize_party_identity(_party)
var battle_enemies: Array = []
var battle_rounds := 0
var selected_hero := 0
var log_lines: Array[String] = []

func _ready() -> void:
    reset_new_game()

func canonicalize_party_identity(party_value: Array) -> void:
    for hero_value: Variant in party_value:
        if not hero_value is Dictionary:
            continue
        var hero: Dictionary = hero_value
        var runtime_id := str(hero.get("id", ""))
        var identity: Dictionary = CANONICAL_PARTY_IDENTITIES.get(runtime_id, {})
        if identity.is_empty():
            continue
        hero["canonical_id"] = str(identity.get("canonical_id", ""))
        hero["name"] = str(identity.get("name", "Héros"))

func reset_new_game() -> void:
    ContentScopeDirector.reset_new_game()
    EnemyFearDirector.reset_new_game()
    FieldEncounterRuntime.reset_new_game()
    EquipmentManager.reset_new_game()
    CombatLoadoutManager.reset_new_game()
    CreatureManager.reset_new_game()
    PoliticalState.reset_new_game()
    CampaignState.reset_new_game()
    SideQuestRuntime.reset_new_game()
    BountyContractDirector.reset_new_game()
    ExpeditionReportDirector.reset_new_game()
    ExpeditionPreparationDirector.reset_new_game()
    ExplorationDirector.reset_new_game()
    CampaignMemoryDirector.reset_new_game()
    AshlandsRuntime.reset_world_progression()
    Chapter01Runtime.reset_new_game()
    Chapter02Runtime.reset_new_game()
    Chapter03Runtime.reset_new_game()
    Chapter04Runtime.reset_new_game()
    Chapter05Runtime.reset_new_game()
    Chapter06Runtime.reset_new_game()
    Chapter07Runtime.reset_new_game()
    Chapter08Runtime.reset_new_game()
    DeepVestigeRuntime.reset_new_game()
    Chapter09Runtime.reset_new_game()
    Chapter10Runtime.reset_new_game()
    party = []
    for hero in DataLoader.heroes:
        var prepared_hero: Dictionary = hero.duplicate(true)
        HeroSkillManager.prepare_hero(prepared_hero)
        prepared_hero["player_owned"] = true
        var trait_seed_key := str(prepared_hero.get("canonical_id", prepared_hero.get("id", "")))
        CharacterTraitDirector.prepare_character(prepared_hero, trait_seed_key, false)
        EnemyFearDirector.prepare_hero(prepared_hero)
        PersistentInjuryRuntime.prepare_character(prepared_hero)
        party.append(prepared_hero)
    canonicalize_party_identity(party)
    gold = 120
    essence = 18
    light = 75
    supplies = 8
    expedition_room = 0
    battle_enemies = []
    battle_rounds = 0
    log_lines = ["Le Sanctuaire attend."]
    new_game_reset.emit()
    state_changed.emit()

func request_screen(name: String) -> void:
    current_screen = name
    screen_requested.emit(name)

func add_log(text: String) -> void:
    log_lines.push_front(text)
    if log_lines.size() > 8:
        log_lines.resize(8)
    state_changed.emit()

func alive_heroes() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for hero_value in party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) > 0:
            result.append(hero)
    return result

func alive_enemies() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for enemy_value in battle_enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) > 0:
            result.append(enemy)
    return result
