extends Node

const RUNNER := preload("res://scripts/core/ui_roguelike_journey_smoke_test_v3.gd")
const PROBE := preload("res://scripts/core/ui_player_journey_probe.gd")

func _ready() -> void:
    call_deferred("_start_runner")

func _start_runner() -> void:
    var probe: Node = PROBE.new()
    probe.name = "UIPlayerJourneyProbe"
    get_tree().root.add_child(probe)
    var runner: Node = RUNNER.new()
    runner.name = "UIPlayerJourneySmokeRunner"
    get_tree().root.add_child(runner)
    runner.call_deferred("run")
