extends Area3D
class_name LoreCollectible

signal read(entry: Dictionary)

var entry: Dictionary = {}
var collected := false

func configure(value: Dictionary) -> void:
    entry = value.duplicate(true)
    collected = AshlandsRuntime.is_lore_collected(str(entry.get("id", "")))
    _refresh_availability()
    set_process(int(entry.get("minimum_madness", 0)) > 0)

func _process(_delta: float) -> void:
    _refresh_availability()

func _refresh_availability() -> void:
    var available := not collected and _meets_madness_requirement()
    visible = available
    monitoring = available

func _meets_madness_requirement() -> bool:
    var minimum := int(entry.get("minimum_madness", 0))
    if minimum <= 0:
        return true
    for hero in GameState.party:
        if int(hero.get("madness", 0)) >= minimum:
            return true
    return false

func can_interact() -> bool:
    return not collected and not entry.is_empty() and _meets_madness_requirement()

func interact() -> void:
    if not can_interact():
        return
    collected = true
    _refresh_availability()
    AshlandsRuntime.collect_lore(entry)
    read.emit(entry)
