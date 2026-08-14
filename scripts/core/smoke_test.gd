extends SceneTree

func _initialize() -> void:
    var failures: Array[String] = []
    for path in [
        "res://data/classes.json", "res://data/races.json", "res://data/heroes.json",
        "res://data/enemies.json", "res://data/skills.json"
    ]:
        if not FileAccess.file_exists(path):
            failures.append("Missing: " + path)
    if failures.is_empty():
        print("SMOKE_TEST_OK")
        quit(0)
    for failure in failures:
        push_error(failure)
    quit(1)
