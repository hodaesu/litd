extends Node

signal state_changed
signal screen_requested(screen_name: String)

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
    DeepVestigeRuntime.reset_new_game()
    party = []
    for hero in DataLoader.heroes:
        var prepared_hero: Dictionary = hero.duplicate(true)
        HeroSkillManager.prepare_hero(prepared_hero)
        party.append(prepared_hero)
    gold = 120
    essence = 18
    light = 75
    supplies = 8
    expedition_room = 0
    battle_enemies = []
    log_lines = ["Le Sanctuaire attend."]
    state_changed.emit()

func request_screen(name: String) -> void:
    current_screen = name
    screen_requested.emit(name)

func add_log(text: String) -> void:
    log_lines.push_front(text)
    if log_lines.size() > 8:
        log_lines.resize(8)
    state_changed.emit()

func alive_heroes() -> Array:
    return party.filter(func(h): return int(h.get("hp", 0)) > 0)

func alive_enemies() -> Array:
    return battle_enemies.filter(func(e): return int(e.get("hp", 0)) > 0)
