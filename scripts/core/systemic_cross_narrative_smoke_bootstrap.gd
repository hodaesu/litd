extends Node

const RUNNER := preload("res://scripts/core/systemic_cross_narrative_smoke_test.gd")

func _ready() -> void:
    call_deferred("_start_runner")

func _start_runner() -> void:
    var runner := RUNNER.new()
    runner.name = "SystemicCrossNarrativeSmokeRunner"
    get_tree().root.add_child(runner)
    runner.call_deferred("run")
