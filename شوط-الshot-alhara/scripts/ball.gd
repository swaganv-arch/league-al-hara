extends RigidBody3D

@export var max_linear_speed: float = 28.0
@export var max_angular_speed: float = 24.0

var _spawn_position: Vector3
var _spawn_rotation: Vector3

func _ready() -> void:
	_spawn_position = global_position
	_spawn_rotation = rotation
	if not is_in_group("ball"):
		add_to_group("ball")

func set_spawn_position(pos: Vector3) -> void:
	_spawn_position = pos

func reset_ball(at_position: Vector3 = Vector3.INF) -> void:
	var target := _spawn_position if at_position == Vector3.INF else at_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	global_position = target
	rotation = _spawn_rotation

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() > max_linear_speed:
		linear_velocity = linear_velocity.normalized() * max_linear_speed

	if angular_velocity.length() > max_angular_speed:
		angular_velocity = angular_velocity.normalized() * max_angular_speed
