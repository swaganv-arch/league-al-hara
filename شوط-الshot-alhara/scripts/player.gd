extends CharacterBody3D

@export var walk_speed: float = 6.5
@export var sprint_speed: float = 11.5
@export var dash_speed: float = 14.5
@export var turn_speed: float = 24.0
@export var pass_force: float = 8.0
@export var max_shoot_force: float = 14.0
@export var kick_reach_distance: float = 2.85
@export var dribble_pickup_radius: float = 2.65
@export var dribble_hold_distance: float = 1.95
@export var dribble_follow_speed: float = 13.5
@export var stop_brake_speed: float = 7.5
@export var invert_forward: bool = true

@export var walk_anim_name: String = "Walking"
@export var run_anim_name: String = "Running"
@export var anim_blend_time: float = 0.18

@export var anim_player_path: NodePath = NodePath("AnimationPlayer")
@export var visual_root_path: NodePath = NodePath("SmartRigArmature")
@export var kick_zone_path: NodePath = NodePath("KickZone")

var _anim_player: AnimationPlayer
var _visual_root: Node3D
var _kick_zone: Area3D

var _shoot_charge: float = 0.0
var _is_charging: bool = false
var _dash_timer: float = 0.0
var _kick_cooldown: float = 0.0
var _is_sprinting: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if anim_player_path != NodePath("") and has_node(anim_player_path):
		_anim_player = get_node(anim_player_path) as AnimationPlayer
	if visual_root_path != NodePath("") and has_node(visual_root_path):
		_visual_root = get_node(visual_root_path) as Node3D
	if kick_zone_path != NodePath("") and has_node(kick_zone_path):
		_kick_zone = get_node(kick_zone_path) as Area3D

	var default_anim: String = walk_anim_name if (_anim_player != null and _anim_player.has_animation(walk_anim_name)) else run_anim_name
	if _anim_player != null and _anim_player.has_animation(default_anim):
		_anim_player.play(default_anim)
		_anim_player.seek(0.0, true)
		_anim_player.pause()

func _physics_process(delta: float) -> void:
	if _kick_cooldown > 0.0:
		_kick_cooldown -= delta

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	_handle_input(delta)
	move_and_slide()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	_update_kick_zone_position()
	_update_dribble(delta)
	_update_locomotion_animation()

func _horiz_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _get_forward_dir() -> Vector3:
	var fwd: Vector3 = Vector3.FORWARD
	if _visual_root != null:
		fwd = _visual_root.global_transform.basis * Vector3.FORWARD
	else:
		fwd = transform.basis * Vector3.FORWARD

	if invert_forward:
		fwd = -fwd

	fwd.y = 0.0
	return fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD

func _handle_input(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	_is_sprinting = Input.is_key_pressed(KEY_SHIFT) and direction != Vector3.ZERO

	if Input.is_action_just_pressed("ui_select") and _dash_timer <= 0.0 and direction != Vector3.ZERO:
		_dash_timer = 0.15

	var current_speed: float = sprint_speed if _is_sprinting else walk_speed
	if _dash_timer > 0.0:
		_dash_timer -= delta
		current_speed = dash_speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if _visual_root != null:
			var target_angle: float = atan2(direction.x, direction.z)
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_angle, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 14.0 * delta)

	if Input.is_key_pressed(KEY_E) and _kick_cooldown <= 0.0:
		_kick_ball(pass_force, 0.7, "PASS")

	if Input.is_key_pressed(KEY_F):
		_is_charging = true
		_shoot_charge = clampf(_shoot_charge + delta * 1.4, 0.35, 1.0)
	elif _is_charging:
		_kick_ball(max_shoot_force * _shoot_charge, 1.6 * _shoot_charge, "SHOOT")
		_shoot_charge = 0.0
		_is_charging = false

func _update_dribble(delta: float) -> void:
	if _kick_cooldown > 0.0 or _is_charging or not is_on_floor():
		return

	var horiz_player_speed: float = Vector2(velocity.x, velocity.z).length()
	var forward: Vector3 = _get_forward_dir()

	for node in get_tree().get_nodes_in_group("ball"):
		if node is RigidBody3D:
			var ball_body: RigidBody3D = node as RigidBody3D
			var to_ball := Vector3(ball_body.global_position.x - global_position.x, 0.0, ball_body.global_position.z - global_position.z)
			var dist: float = to_ball.length()
			if dist > dribble_pickup_radius or dist < 0.15:
				continue

			var dir_to_ball: Vector3 = to_ball / dist
			if forward.dot(dir_to_ball) < 0.15:
				continue

			ball_body.sleeping = false

			if horiz_player_speed <= 0.25:
				var brake: float = clampf(stop_brake_speed * delta, 0.0, 1.0)
				ball_body.linear_velocity.x = lerp(ball_body.linear_velocity.x, 0.0, brake)
				ball_body.linear_velocity.z = lerp(ball_body.linear_velocity.z, 0.0, brake)
				ball_body.angular_velocity = ball_body.angular_velocity.lerp(Vector3.ZERO, brake)
				continue

			var desired_ball_pos: Vector3 = global_position + forward * dribble_hold_distance
			var to_target: Vector3 = desired_ball_pos - ball_body.global_position
			to_target.y = 0.0

			var pull_vel: Vector3 = to_target * dribble_follow_speed
			var max_pull: float = maxf(horiz_player_speed * 1.15, 4.0)
			if pull_vel.length() > max_pull:
				pull_vel = pull_vel.normalized() * max_pull

			var desired_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z) + pull_vel
			ball_body.linear_velocity.x = lerp(ball_body.linear_velocity.x, desired_vel.x, clampf(15.0 * delta, 0.0, 1.0))
			ball_body.linear_velocity.z = lerp(ball_body.linear_velocity.z, desired_vel.z, clampf(15.0 * delta, 0.0, 1.0))

			var move_horiz: Vector3 = Vector3(ball_body.linear_velocity.x, 0.0, ball_body.linear_velocity.z)
			if move_horiz.length() > 0.25:
				var roll_axis: Vector3 = Vector3.UP.cross(move_horiz.normalized()).normalized()
				ball_body.angular_velocity = roll_axis * (move_horiz.length() / 0.35)

func _update_kick_zone_position() -> void:
	if _kick_zone == null:
		return
	var forward: Vector3 = _get_forward_dir()
	_kick_zone.position = Vector3(forward.x * 1.85, 0.65, forward.z * 1.85)

func _update_locomotion_animation() -> void:
	if _anim_player == null:
		return

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.35 and is_on_floor():
		var target_anim: String = run_anim_name if (_is_sprinting and _anim_player.has_animation(run_anim_name)) else walk_anim_name
		if not _anim_player.has_animation(target_anim):
			target_anim = run_anim_name if _anim_player.has_animation(run_anim_name) else walk_anim_name
		if not _anim_player.has_animation(target_anim):
			return

		if _anim_player.current_animation != target_anim or not _anim_player.is_playing():
			_anim_player.play(target_anim, anim_blend_time)

		var base_ref_speed: float = sprint_speed if target_anim == run_anim_name else walk_speed
		_anim_player.speed_scale = clampf(horiz_speed / maxf(base_ref_speed, 0.1), 0.85, 1.55)
	else:
		_anim_player.speed_scale = 0.0
		_anim_player.pause()

func _kick_ball(force: float, lift: float, kick_type: String) -> void:
	var forward: Vector3 = _get_forward_dir()
	var kicked_any: bool = false

	for node in get_tree().get_nodes_in_group("ball"):
		if node is RigidBody3D:
			var ball_body: RigidBody3D = node as RigidBody3D
			var dist: float = _horiz_dist(global_position, ball_body.global_position)
			if dist <= kick_reach_distance:
				ball_body.sleeping = false
				var kick_dir: Vector3 = ball_body.global_position - global_position
				kick_dir.y = 0.0
				if kick_dir.length() < 0.05:
					kick_dir = forward
				kick_dir = kick_dir.normalized()
				ball_body.linear_velocity = Vector3.ZERO
				ball_body.apply_central_impulse(kick_dir * force + Vector3.UP * lift)
				kicked_any = true

	if kicked_any:
		_kick_cooldown = 0.28
		print("Kick executed: ", kick_type, " | force: ", force)
