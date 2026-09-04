extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _test_corpse_blocks_front_compression()
    _test_projection_into_ally_resolves_collision()
    _test_impossible_two_rank_boss_formation_is_rejected()
    _finish()

func _test_corpse_blocks_front_compression() -> void:
    var corpse := {"id": "corpse_p1", "combat_position": 0, "rank_span": 1, "blocking": true}
    var actors := [
        {"id": "a", "combat_position": 1, "rank_span": 1},
        {"id": "b", "combat_position": 2, "rank_span": 1},
        {"id": "c", "combat_position": 3, "rank_span": 1}
    ]
    var result := CombatPositionRules.compress_toward_front(actors, [corpse], false)
    _check(bool(result.get("success", false)), "Tests_48/T04 : la formation avec cadavre bloquant doit rester résoluble")
    var formation: Array = result.get("formation", [])
    _check(formation.size() == 3, "Tests_48/T04 : aucun acteur ne doit être perdu pendant la compression")
    if formation.size() == 3:
        _check(int((formation[0] as Dictionary).get("combat_position", -1)) == 1, "Tests_48/T04 : l'acteur derrière le cadavre P1 ne doit pas le traverser")
        _check(int((formation[1] as Dictionary).get("combat_position", -1)) == 2, "Tests_48/T04 : la compression ne doit pas pousser artificiellement un acteur à travers le corps")
        _check(int((formation[2] as Dictionary).get("combat_position", -1)) == 3, "Tests_48/T04 : la formation arrière doit rester cohérente")
    _check(bool(CombatPositionRules.validate_formation(formation, [corpse]).get("valid", false)), "Tests_48/T04 : le résultat final doit être une formation physiquement valide")

func _test_projection_into_ally_resolves_collision() -> void:
    var actors := [
        {"id": "projected", "combat_position": 0, "rank_span": 1},
        {"id": "ally", "combat_position": 1, "rank_span": 1},
        {"id": "rear", "combat_position": 3, "rank_span": 1}
    ]
    var result := CombatPositionRules.project_actor(actors, "projected", 1)
    _check(bool(result.get("success", false)), "Tests_48/T05 : une projection dans un allié doit résoudre la collision si un rang libre existe")
    var formation: Array = result.get("formation", [])
    _check(bool(CombatPositionRules.validate_formation(formation).get("valid", false)), "Tests_48/T05 : la projection résolue ne doit laisser aucune superposition")
    var positions: Dictionary = {}
    for value: Variant in formation:
        if value is Dictionary:
            var actor: Dictionary = value
            positions[str(actor.get("id", ""))] = int(actor.get("combat_position", -1))
    _check(int(positions.get("projected", -1)) == 1, "Tests_48/T05 : la cible projetée doit avancer dans le rang de collision")
    _check(int(positions.get("ally", -1)) == 2, "Tests_48/T05 : l'allié heurté doit être déplacé vers le rang libre")
    _check(int(positions.get("rear", -1)) == 3, "Tests_48/T05 : un acteur non impliqué ne doit pas être déplacé sans raison")

func _test_impossible_two_rank_boss_formation_is_rejected() -> void:
    var actors := [
        {"id": "enemy_1", "rank_span": 1},
        {"id": "enemy_2", "rank_span": 1},
        {"id": "enemy_3", "rank_span": 1},
        {"id": "enemy_4", "rank_span": 1},
        {"id": "boss", "rank_span": 2, "boss": true}
    ]
    _check(CombatPositionRules.formation_capacity_required(actors) == 6, "Tests_48/T06 : quatre ennemis standards + boss 2 rangs doivent exiger 6 rangs")
    _check(not CombatPositionRules.can_fit_formation(actors), "Tests_48/T06 : une formation exigeant 6 rangs doit être refusée dans P1-P4")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_FORMATION_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_FORMATION_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_FORMATION_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
