extends Node

const RUNNER := preload("res://scripts/core/mobile_touch_smoke_test_v2.gd")

func _ready() -> void:
    call_deferred("_start_runner")

func _start_runner() -> void:
    var runner := RUNNER.new()
    runner.name = "MobileTouchSmokeRunner"
    get_tree().root.add_child(runner)
    runner.call_deferred("run")
