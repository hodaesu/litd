extends Node
const RUNNER := preload("res://scripts/core/knowledge_store_smoke_test.gd")
func _ready() -> void:
    call_deferred("_run")
func _run() -> void:
    var runner = RUNNER.new()
    get_tree().root.add_child(runner)
    runner.call_deferred("run")
