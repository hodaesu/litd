extends Node

func _ready() -> void:
    var starter := {"id": "starter", "hp": 20, "player_owned": true}
    CharacterTraitDirector.prepare_character(starter, "starter", true)
    var invalid: Dictionary = CharacterTraitDirector.set_starter_traits(starter, ["courage", "temerity"], [])
    assert(not bool(invalid.get("ok", true)))
    var valid: Dictionary = CharacterTraitDirector.set_starter_traits(starter, ["courage", "temerity"], ["arachnophobia"])
    assert(bool(valid.get("ok", false)))
    assert((starter.get("positive_traits", []) as Array).size() == 2)
    CharacterTraitDirector.add_exposure(starter, "arachnid", 12)
    assert(CharacterTraitDirector.has_pending_evolution(starter))
    assert((starter.get("positive_traits", []) as Array).has("courage"))
    var resolved: Dictionary = CharacterTraitDirector.resolve_pending_evolution(starter, "temerity")
    assert(bool(resolved.get("ok", false)))
    assert(not (starter.get("negative_traits", []) as Array).has("arachnophobia"))
    assert((starter.get("positive_traits", []) as Array).has("arachnid_fighter"))
    assert((starter.get("positive_traits", []) as Array).has("courage"))
    assert(not (starter.get("positive_traits", []) as Array).has("temerity"))
    assert((starter.get("positive_traits", []) as Array).size() <= 2)
    var enemy := {"id": 10, "name": "Jorōgumo", "hp": 10}
    CharacterTraitDirector.prepare_character(enemy, "enemy:10:1")
    assert((enemy.get("positive_traits", []) as Array).size() <= 2)
    assert((enemy.get("negative_traits", []) as Array).size() <= 2)
    print("CHARACTER_TRAITS_SMOKE_OK")
    get_tree().quit()
