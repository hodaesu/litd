extends Node

func _ready() -> void:
    var hero := {"id": "aurelien", "level": 16, "hp": 42}
    EnemyFearDirector.reset_new_game()
    EnemyFearDirector.record_deed(hero, "dungeon_survived", 3)
    EnemyFearDirector.record_deed(hero, "boss_defeated", 1)
    var enemy := {"id": 1, "name": "Goule affamée", "hp": 38, "max_hp": 38, "boss": false}
    var starting := EnemyFearDirector.initialize_enemy(enemy, [hero])
    assert(starting > 0)
    var before := int(enemy.get("enemy_fear", 0))
    EnemyFearDirector.apply_event(enemy, "critical_hit")
    assert(int(enemy.get("enemy_fear", 0)) > before)
    var body := EnemyBodyDirector.compose_for_enemy(enemy)
    assert(not body.is_empty())
    var payload := EnemyFearDirector.serialize()
    EnemyFearDirector.reset_new_game()
    EnemyFearDirector.deserialize(payload)
    assert(EnemyFearDirector.renown_score(hero) > 0.0)
    print("ENEMY_FEAR_RENOWN_SMOKE_OK")
    get_tree().quit()
