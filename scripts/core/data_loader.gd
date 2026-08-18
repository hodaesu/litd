extends Node

var classes: Array = []
var races: Array = []
var heroes: Array = []
var enemies: Array = []
var skills: Array = []
var equipment: Array = []
var equipment_rarities: Array = []
var equipment_affixes: Array = []
var capturable_creatures: Array = []
var quests: Array = []
var events: Array = []
var dialogues: Array = []
var ashlands_lore: Dictionary = {}

func _ready() -> void:
    reload_all()

func load_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_error("Fichier manquant: " + path)
        return []
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed == null:
        push_error("JSON invalide: " + path)
        return []
    return parsed

func reload_all() -> void:
    classes = load_json("res://data/classes.json")
    races = load_json("res://data/races.json")
    heroes = load_json("res://data/heroes.json")
    enemies = load_json("res://data/enemies.json")
    skills = load_json("res://data/skills.json")
    equipment = load_json("res://data/equipment.json")
    equipment_rarities = load_json("res://data/equipment_rarities.json")
    equipment_affixes = load_json("res://data/equipment_affixes.json")
    capturable_creatures = load_json("res://data/capturable_creatures.json")
    quests = load_json("res://data/quests.json")
    events = load_json("res://data/events.json")
    dialogues = load_json("res://data/dialogues.json")
    var lore_value = load_json("res://data/levels/ashlands_lore.json")
    ashlands_lore = lore_value if typeof(lore_value) == TYPE_DICTIONARY else {}

func find_by_id(items: Array, id_value: Variant) -> Dictionary:
    for item in items:
        if item.get("id") == id_value:
            return item
    return {}
