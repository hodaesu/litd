extends Node

const DB_SCRIPT := preload("res://scripts/core/veilleurs_content_db_v07.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var db: VeilleursContentDBV07 = DB_SCRIPT.new() as VeilleursContentDBV07
    db.reload()
    var summary: Dictionary = db.production_summary()
    _check((summary.get("errors", []) as Array).is_empty(), "production ContentDB loads without errors")
    _check(int(summary.get("watchers", 0)) == 4, "four Watchers remain loaded")
    _check(int(summary.get("standard_enemies", 0)) == 24, "24 standard enemies remain loaded")
    _check(int(summary.get("bosses", 0)) == 5, "five bosses load")
    _check(int(summary.get("watcher_skills", 0)) == 180, "180 Watcher skills remain available")
    _check(int(summary.get("enemy_trees", 0)) == 72, "72 enemy trees load")
    _check(int(summary.get("enemy_skills", 0)) == 1080, "1080 enemy skills generate")
    _check(int(summary.get("boss_trees", 0)) == 15, "15 boss trees load")
    _check(int(summary.get("boss_skills", 0)) == 225, "225 boss skills generate")
    _check(int(summary.get("all_normal_skills", 0)) == 1485, "1485 normal skills total")
    _check(int(summary.get("khar_sen_nodes", 0)) == 18, "expanded Khar-Sen has 18 nodes")
    _check(int(summary.get("planned_dungeons", 0)) == 6, "six production dungeons planned")

    for enemy_id_value: Variant in db.enemies_by_id.keys():
        var enemy_id := str(enemy_id_value)
        _check(db.production_skills_for(enemy_id).size() == 45, "%s has 45 generated skills" % enemy_id)
    for boss_id_value: Variant in db.bosses_by_id.keys():
        var boss_id := str(boss_id_value)
        _check(db.production_skills_for(boss_id).size() == 45, "%s has 45 generated skills" % boss_id)
        _check(not bool(db.boss(boss_id).get("recruitable", true)), "%s cannot be recruited" % boss_id)

    _check(int(db.recruitment.get("max_recruits_per_expedition", 0)) == 2, "recruitment cap per expedition is two")
    _check(int(db.recruitment.get("refuge_recruit_cap", 0)) == 12, "Refuge recruit cap is twelve")
    _check(int(db.progression.get("level_cap", 0)) == 50, "level cap is 50")
    _check((db.archives.get("tabs", []) as Array).size() == 5, "Archives expose five tabs")
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V07_PRODUCTION_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V07_PRODUCTION: " + failure)
    print("VEILLEURS_V07_PRODUCTION_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
