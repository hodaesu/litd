extends CanvasLayer
class_name MobileExplorationControls

var controller: ExplorationPartyController
var held := {"left": false, "right": false, "up": false, "down": false, "run": false}

func _ready() -> void:
    visible = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
    call_deferred("_bind_controller")

func _bind_controller() -> void:
    var nodes := get_tree().get_nodes_in_group("player_party")
    if not nodes.is_empty():
        controller = nodes[0] as ExplorationPartyController

func _process(_delta: float) -> void:
    if controller == null:
        _bind_controller()
        return
    var x := float(held["right"]) - float(held["left"])
    var y := float(held["down"]) - float(held["up"])
    controller.set_virtual_input(Vector2(x, y).normalized() if Vector2(x, y).length_squared() > 1.0 else Vector2(x, y))
    controller.set_virtual_run(bool(held["run"]))

func _set_hold(key: String, value: bool) -> void:
    held[key] = value

func _on_left_down() -> void: _set_hold("left", true)
func _on_left_up() -> void: _set_hold("left", false)
func _on_right_down() -> void: _set_hold("right", true)
func _on_right_up() -> void: _set_hold("right", false)
func _on_up_down() -> void: _set_hold("up", true)
func _on_up_up() -> void: _set_hold("up", false)
func _on_down_down() -> void: _set_hold("down", true)
func _on_down_up() -> void: _set_hold("down", false)
func _on_run_down() -> void: _set_hold("run", true)
func _on_run_up() -> void: _set_hold("run", false)
func _on_interact_pressed() -> void:
    if controller != null:
        controller.interact()
