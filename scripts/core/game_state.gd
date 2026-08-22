extends Node

signal state_changed
signal screen_requested(screen_name: String)
signal new_game_reset

const MAX_CHARACTER_LEVEL: int = 50

var current_screen := "title"
var gold := 120
var essence := 18
var light := 75
var supplies := 8
var expedition_room := 0
var expedition_rooms := 4
var party: Array = []
var battle_enemies: Array = []
var selected_hero := 0
var log_lines: Array[String] = []

func _ready() -> void:
    reset_new_game()

func reset_new_game() -> void:
    EnemyFearDirector.reset_new_game()
    FieldEncounterRuntime.reset_new_game()
    EquipmentManager.reset_new_game()
    CreatureManager.reset_new_game()
    PoliticalState.reset_new_game()
    CampaignState.reset_new_game()
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
        CharacterTraitDirector.prepare_character(prepared_hero, str(prepared_hero.get("id", "")), str(prepared_hero.get("id", "")) == "aurelien")
        EnemyFearDirector.prepare_hero(prepared_hero)
        party.append(prepared_hero)
    gold = 120
    essence = 18
    light = 75
    supplies = 8
    expedition_room = 0
    battle_enemies = []
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
