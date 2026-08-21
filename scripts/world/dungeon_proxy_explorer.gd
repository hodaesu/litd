extends CharacterBody3D

# Contrôleur volontairement simple pour le blockout. Il accepte AZERTY, QWERTY
# et les flèches afin de tester les dimensions, les passages et les collisions
# avant de brancher les animations définitives du groupe.

@export var move_speed: float = 5.0
@export var acceleration: float = 18.0
@export var gravity: float = 18.0

func _physics_process(delta: float) -> void:
    var input_vector: Vector2 = _movement_input()
    var desired: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y).normalized() * move_speed
    velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0
    move_and_slide()

func _movement_input() -> Vector2:
    var x_axis: float = 0.0
    var y_axis: float = 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
        x_axis -= 1.0
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        x_axis += 1.0
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
        y_axis -= 1.0
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        y_axis += 1.0
    return Vector2(x_axis, y_axis)
