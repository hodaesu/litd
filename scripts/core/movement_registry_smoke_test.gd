extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    var summary: Dictionary = MovementRegistry.summary()
    _expect(int(summary.get("total", 0)) >= 600, "exhaustive movement count")
    for hero_id: String in ["aurelien","malvor","lysandra","darius"]:
        _expect(MovementRegistry.skill_movements(hero_id).size() == 45, "%s 45 skills" % hero_id)
        for branch: String in ["offense","defense","special"]:
            _expect(MovementRegistry.skill_movements(hero_id, branch).size() == 15, "%s %s 15" % [hero_id,branch])
    var heavy: Dictionary = MovementRegistry.for_trigger("heavy_attack")
    _expect(not heavy.is_empty(), "heavy attack trigger")
    _expect((heavy.get("markers", []) as Array).has("impact"), "impact marker")
    _expect(MovementRegistry.for_owner("enemy_01", "enemy").size() >= 5, "enemy movement family")
    _expect(MovementRegistry.blender_queue().size() > 500, "Blender production queue")
    if failures.is_empty():
        print("MOVEMENT_REGISTRY_SMOKE_OK")
        get_tree().quit(0)
    else:
        for failure: String in failures:
            push_error("MOVEMENT_REGISTRY_SMOKE: %s" % failure)
        get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
