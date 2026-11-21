extends Camera3D

@export var player_path: NodePath
@export var ball_path: NodePath
@export var follow_speed: float = 3.0
@export var offset: Vector3 = Vector3(0.0, 15.0, 13.0)
@export var clamp_x: float = 10.0
@export var clamp_z: float = 7.0

var _player: Node3D
var _ball: Node3D

func _ready() -> void:
	if player_path != NodePath("") and has_node(player_path):
		_player = get_node(player_path)
	if ball_path != NodePath("") and has_node(ball_path):
		_ball = get_node(ball_path)
	current = true

func _process(delta: float) -> void:
	var focus_pos := Vector3.ZERO
	if _player != null and _ball != null:
		focus_pos = _player.global_position.lerp(_ball.global_position, 0.35)
	elif _player != null:
		focus_pos = _player.global_position
	elif _ball != null:
		focus_pos = _ball.global_position

	focus_pos.x = clampf(focus_pos.x, -clamp_x, clamp_x)
	focus_pos.z = clampf(focus_pos.z, -clamp_z, clamp_z)
	focus_pos.y = 0.0

	var desired_pos := focus_pos + offset
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	look_at(focus_pos + Vector3(0.0, 1.0, 0.0), Vector3.UP)
