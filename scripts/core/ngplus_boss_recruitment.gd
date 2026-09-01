extends Node

# Legacy NG+ boss-recruitment shim.
# Canon rule: NG+ never turns bosses, minibosses or human justice subjects into
# capturable creatures. This node is kept as a compatibility surface because
# older runtime code still calls it, but it deliberately exposes no recruits.

func _ready() -> void:
    pass

func enabled() -> bool:
    return false

func party_reference_level() -> int:
    if GameState.party.is_empty():
        return 1
    var total := 0
    var count := 0
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        total += clampi(int(hero.get("level", 1)), 1, GameState.MAX_CHARACTER_LEVEL)
        count += 1
    return clampi(int(round(float(total) / float(maxi(1, count)))), 1, GameState.MAX_CHARACTER_LEVEL)

func encounter_id_from_enemy(enemy: Dictionary) -> String:
    for key in ["chapter_boss_id", "chapter_miniboss_id"]:
        var value := String(enemy.get(key, ""))
        if value != "":
            return value
    return String(enemy.get("encounter_id", ""))

func raw_entry_for_encounter(_encounter_id: String) -> Dictionary:
    return {}

func raw_entry_for_species(_species_id: String) -> Dictionary:
    return {}

func definition_for_enemy(_enemy: Dictionary) -> Dictionary:
    return {}

func definition_for_species(_species_id: String) -> Dictionary:
    return {}
