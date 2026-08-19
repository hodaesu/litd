extends Node

const RUNNER := preload("res://scripts/core/ui_player_journey_smoke_test.gd")

func _ready() -> void:
    var runner := RUNNER.new()
    runner.name = "UIPlayerJourneySmokeRunner"
    get_tree().root.add_child(runner)
    runner.call_deferred("run")
