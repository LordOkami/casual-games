extends Node2D
## Frog Jump - Tap and hold to charge, release to jump!
## Lateral scrolling - always jump to the right!

signal jump_completed(jump_count: int)
signal game_over_triggered

# Screen constants
const SCREEN_WIDTH = 720.0
const SCREEN_HEIGHT = 1280.0

# Frog physics
const GRAVITY = 1800.0
const MAX_CHARGE_TIME = 1.5
const MIN_JUMP_POWER = 400.0
const MAX_JUMP_POWER = 1100.0
const JUMP_ANGLE_MIN = 30.0  # degrees from horizontal (more horizontal)
const JUMP_ANGLE_MAX = 70.0  # degrees from horizontal

# Platform settings
const PLATFORM_START_WIDTH = 180.0
const PLATFORM_MIN_WIDTH = 60.0
const PLATFORM_WIDTH_DECREASE = 6.0
const PLATFORM_START_DISTANCE_X = 180.0
const PLATFORM_MAX_DISTANCE_X = 400.0
const PLATFORM_DISTANCE_INCREASE = 12.0
const PLATFORM_HEIGHT = 20.0
const PLATFORM_RANDOM_FACTOR = 0.25
const PLATFORM_Y_VARIATION = 120.0  # Vertical variation between platforms

# Trajectory preview
const TRAJECTORY_POINTS = 30
const TRAJECTORY_FULL_JUMPS = 3
const TRAJECTORY_FADE_JUMPS = 5

# Camera
const FROG_SCREEN_X = 200.0  # Frog stays at left side of screen
const CAMERA_SMOOTH = 4.0

# Rope swing (tongue) settings
const ROPE_SWING_UNLOCK_PLATFORM = 10  # Unlocks after platform 10
const TONGUE_ANGLE = 45.0  # Degrees from horizontal (upward-right)
const TONGUE_MAX_LENGTH = 400.0
const TONGUE_SPEED = 1500.0  # How fast tongue extends
const SWING_GRAVITY = 800.0  # Pendulum gravity
const SWING_DAMPING = 0.995  # Slight damping on swing

# Game state
var game_active: bool = false
var is_charging: bool = false
var charge_time: float = 0.0
var jump_count: int = 0
var frog_velocity: Vector2 = Vector2.ZERO
var frog_jumping: bool = false
var current_platform_index: int = 0

# Rope swing state
var is_swinging: bool = false
var tongue_extending: bool = false
var tongue_length: float = 0.0
var tongue_anchor: Vector2 = Vector2.ZERO
var swing_angle: float = 0.0  # Current angle of rope
var swing_angular_velocity: float = 0.0  # Angular velocity for pendulum
var rope_swing_available: bool = false

# Nodes
var frog: Node2D
var frog_body: Polygon2D
var frog_eyes: Node2D
var world_container: Node2D  # Contains everything that moves with camera
var platforms_container: Node2D
var trajectory_container: Node2D
var particles_container: Node2D
var background_container: Node2D
var game_ui: CanvasLayer
var charge_indicator: Node2D

# Platform data
var platforms: Array[Dictionary] = []
var camera_x: float = 0.0
var camera_target_x: float = 0.0

# Visual effects
var landing_particles: Array[Dictionary] = []

# Background elements
var clouds: Array[Dictionary] = []
var trees: Array[Dictionary] = []

func _ready() -> void:
	_setup_scene()
	_start_game()

func _setup_scene() -> void:
	# Sky background (fixed)
	var bg = ColorRect.new()
	bg.color = Color(0.529, 0.808, 0.922)  # Sky blue
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	add_child(bg)

	# World container - moves with camera
	world_container = Node2D.new()
	add_child(world_container)

	# Background elements container
	background_container = Node2D.new()
	background_container.z_index = -1
	world_container.add_child(background_container)

	# Water/ground at bottom
	var water = ColorRect.new()
	water.color = Color(0.255, 0.412, 0.882, 0.6)
	water.position = Vector2(-1000, SCREEN_HEIGHT - 150)
	water.size = Vector2(50000, 200)  # Very wide for scrolling
	water.z_index = -2
	world_container.add_child(water)

	# Ground line
	var ground = ColorRect.new()
	ground.color = Color(0.4, 0.26, 0.13)
	ground.position = Vector2(-1000, SCREEN_HEIGHT - 150)
	ground.size = Vector2(50000, 10)
	ground.z_index = -1
	world_container.add_child(ground)

	# Platforms container
	platforms_container = Node2D.new()
	platforms_container.z_index = 1
	world_container.add_child(platforms_container)

	# Trajectory container
	trajectory_container = Node2D.new()
	trajectory_container.z_index = 2
	world_container.add_child(trajectory_container)

	# Particles container
	particles_container = Node2D.new()
	particles_container.z_index = 3
	world_container.add_child(particles_container)

	# Create frog
	_create_frog()

	# Create background elements
	_create_background_elements()

	# Charge indicator
	_create_charge_indicator()

	# UI
	var ui_scene = load("res://scenes/game_ui.tscn")
	game_ui = ui_scene.instantiate()
	add_child(game_ui)

func _create_frog() -> void:
	frog = Node2D.new()
	frog.z_index = 5
	world_container.add_child(frog)

	# Frog body - rounded polygon
	frog_body = Polygon2D.new()
	frog_body.color = Color(0.133, 0.545, 0.133)  # Forest green
	frog_body.polygon = PackedVector2Array([
		Vector2(-25, 10),
		Vector2(-30, 0),
		Vector2(-25, -15),
		Vector2(-10, -25),
		Vector2(10, -25),
		Vector2(25, -15),
		Vector2(30, 0),
		Vector2(25, 10),
		Vector2(15, 15),
		Vector2(-15, 15)
	])
	frog.add_child(frog_body)

	# Frog belly
	var belly = Polygon2D.new()
	belly.color = Color(0.565, 0.933, 0.565)  # Light green
	belly.polygon = PackedVector2Array([
		Vector2(-15, 8),
		Vector2(-18, 0),
		Vector2(-12, -10),
		Vector2(12, -10),
		Vector2(18, 0),
		Vector2(15, 8)
	])
	frog.add_child(belly)

	# Eyes container
	frog_eyes = Node2D.new()
	frog.add_child(frog_eyes)

	# Left eye
	var left_eye_white = Polygon2D.new()
	left_eye_white.color = Color.WHITE
	left_eye_white.polygon = _create_circle_polygon(8, 8)
	left_eye_white.position = Vector2(-12, -18)
	frog_eyes.add_child(left_eye_white)

	var left_pupil = Polygon2D.new()
	left_pupil.color = Color.BLACK
	left_pupil.polygon = _create_circle_polygon(4, 6)
	left_pupil.position = Vector2(-10, -18)  # Looking right
	frog_eyes.add_child(left_pupil)

	# Right eye
	var right_eye_white = Polygon2D.new()
	right_eye_white.color = Color.WHITE
	right_eye_white.polygon = _create_circle_polygon(8, 8)
	right_eye_white.position = Vector2(12, -18)
	frog_eyes.add_child(right_eye_white)

	var right_pupil = Polygon2D.new()
	right_pupil.color = Color.BLACK
	right_pupil.polygon = _create_circle_polygon(4, 6)
	right_pupil.position = Vector2(14, -18)  # Looking right
	frog_eyes.add_child(right_pupil)

	# Back legs (visible when charging)
	var left_leg = Polygon2D.new()
	left_leg.name = "LeftLeg"
	left_leg.color = Color(0.133, 0.545, 0.133)
	left_leg.polygon = PackedVector2Array([
		Vector2(-20, 10),
		Vector2(-35, 20),
		Vector2(-40, 15),
		Vector2(-25, 5)
	])
	frog.add_child(left_leg)

	var right_leg = Polygon2D.new()
	right_leg.name = "RightLeg"
	right_leg.color = Color(0.133, 0.545, 0.133)
	right_leg.polygon = PackedVector2Array([
		Vector2(20, 10),
		Vector2(35, 20),
		Vector2(40, 15),
		Vector2(25, 5)
	])
	frog.add_child(right_leg)

func _create_circle_polygon(radius: float, segments: int = 12) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _create_background_elements() -> void:
	# Create initial clouds
	for i in range(10):
		_add_cloud(randf() * 2000, randf_range(50, 300))

	# Create initial trees/bushes
	for i in range(15):
		_add_tree(randf() * 2000, SCREEN_HEIGHT - 180)

func _add_cloud(x: float, y: float) -> void:
	clouds.append({
		"x": x,
		"y": y,
		"width": randf_range(80, 150),
		"height": randf_range(30, 50),
		"speed": randf_range(10, 30)
	})

func _add_tree(x: float, y: float) -> void:
	trees.append({
		"x": x,
		"y": y,
		"height": randf_range(40, 80),
		"width": randf_range(30, 50)
	})

func _create_charge_indicator() -> void:
	charge_indicator = Node2D.new()
	charge_indicator.visible = false
	charge_indicator.z_index = 4
	add_child(charge_indicator)

func _start_game() -> void:
	GameManager.start_game()
	game_active = true
	jump_count = 0
	current_platform_index = 0
	is_charging = false
	frog_jumping = false
	charge_time = 0.0
	camera_x = 0.0
	camera_target_x = 0.0

	# Reset rope swing state
	is_swinging = false
	tongue_extending = false
	tongue_length = 0.0
	swing_angle = 0.0
	swing_angular_velocity = 0.0
	rope_swing_available = false

	# Clear containers
	for child in platforms_container.get_children():
		child.queue_free()
	for child in trajectory_container.get_children():
		child.queue_free()

	platforms.clear()
	landing_particles.clear()

	# Create initial platforms
	_create_initial_platforms()

	# Position frog on first platform
	var first_platform = platforms[0]
	frog.position = Vector2(first_platform.x, first_platform.y - 25)
	frog.rotation = 0
	frog.scale = Vector2.ONE

	# Set initial camera
	camera_x = first_platform.x - FROG_SCREEN_X
	camera_target_x = camera_x

func _create_initial_platforms() -> void:
	# Starting platform (large, at left)
	var start_x = 150.0
	var start_y = SCREEN_HEIGHT - 350
	_add_platform(start_x, start_y, PLATFORM_START_WIDTH * 1.5)

	# Generate next platforms (going right)
	for i in range(10):
		_generate_next_platform()

func _add_platform(x: float, y: float, width: float) -> void:
	var platform_data = {
		"x": x,
		"y": y,
		"width": width,
		"index": platforms.size()
	}
	platforms.append(platform_data)

	# Create visual
	var platform = Node2D.new()
	platform.position = Vector2(x, y)

	# Platform top (lily pad style)
	var pad = Polygon2D.new()
	pad.color = Color(0.0, 0.502, 0.0)  # Dark green
	var half_w = width / 2
	pad.polygon = PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(-half_w * 0.8, -PLATFORM_HEIGHT * 0.5),
		Vector2(0, -PLATFORM_HEIGHT * 0.3),
		Vector2(half_w * 0.8, -PLATFORM_HEIGHT * 0.5),
		Vector2(half_w, 0),
		Vector2(half_w * 0.8, PLATFORM_HEIGHT * 0.3),
		Vector2(0, PLATFORM_HEIGHT * 0.5),
		Vector2(-half_w * 0.8, PLATFORM_HEIGHT * 0.3)
	])
	platform.add_child(pad)

	# Highlight
	var highlight = Polygon2D.new()
	highlight.color = Color(0.196, 0.804, 0.196, 0.5)
	highlight.polygon = PackedVector2Array([
		Vector2(-half_w * 0.6, -PLATFORM_HEIGHT * 0.2),
		Vector2(0, -PLATFORM_HEIGHT * 0.1),
		Vector2(half_w * 0.4, -PLATFORM_HEIGHT * 0.2),
		Vector2(half_w * 0.3, PLATFORM_HEIGHT * 0.1),
		Vector2(-half_w * 0.4, PLATFORM_HEIGHT * 0.15)
	])
	platform.add_child(highlight)

	platforms_container.add_child(platform)

func _generate_next_platform() -> void:
	if platforms.is_empty():
		return

	var last = platforms[-1]
	var platform_num = platforms.size()

	# Calculate horizontal distance (always to the right, increases with platform number)
	var base_distance = PLATFORM_START_DISTANCE_X + platform_num * PLATFORM_DISTANCE_INCREASE
	base_distance = min(base_distance, PLATFORM_MAX_DISTANCE_X)

	# Add randomness
	var random_offset = base_distance * PLATFORM_RANDOM_FACTOR * randf()
	var distance_x = base_distance + random_offset

	# Calculate width (decreases with platform number)
	var width = PLATFORM_START_WIDTH - platform_num * PLATFORM_WIDTH_DECREASE
	width = max(width, PLATFORM_MIN_WIDTH)
	width += randf_range(-15, 15)  # Random variation
	width = max(width, PLATFORM_MIN_WIDTH)

	# Vertical variation (up or down from last platform)
	var y_offset = randf_range(-PLATFORM_Y_VARIATION, PLATFORM_Y_VARIATION * 0.5)
	var new_y = last.y + y_offset
	# Keep platforms in reasonable vertical range
	new_y = clamp(new_y, SCREEN_HEIGHT - 700, SCREEN_HEIGHT - 200)

	var new_x = last.x + distance_x

	_add_platform(new_x, new_y, width)

	# Add background elements as we progress
	if randf() > 0.5:
		_add_tree(new_x + randf_range(-100, 100), SCREEN_HEIGHT - 180)
	if randf() > 0.7:
		_add_cloud(new_x + randf_range(0, 300), randf_range(50, 250))

func _input(event: InputEvent) -> void:
	if not game_active:
		return

	var is_press = false
	var is_release = false

	if event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed

	if is_press:
		if frog_jumping and rope_swing_available and not is_swinging:
			# Start rope swing while in air
			_start_tongue()
		elif not frog_jumping and not is_swinging:
			# Start charging jump while on platform
			_start_charging()
	elif is_release:
		if is_swinging or tongue_extending:
			# Release rope swing
			_release_tongue()
		elif is_charging:
			# Release jump
			_release_jump()

func _start_charging() -> void:
	if frog_jumping:
		return

	is_charging = true
	charge_time = 0.0
	charge_indicator.visible = true
	AudioManager.play_sfx("charge")

	# Squash frog animation
	var tween = create_tween()
	tween.tween_property(frog, "scale", Vector2(1.2, 0.7), 0.1)

func _release_jump() -> void:
	if not is_charging:
		return

	is_charging = false
	charge_indicator.visible = false

	# Calculate jump power based on charge time
	var charge_ratio = min(charge_time / MAX_CHARGE_TIME, 1.0)
	var power = lerp(MIN_JUMP_POWER, MAX_JUMP_POWER, charge_ratio)

	# Calculate angle (higher charge = more vertical, but always going right)
	var angle_degrees = lerp(JUMP_ANGLE_MIN, JUMP_ANGLE_MAX, charge_ratio)
	var angle_rad = deg_to_rad(angle_degrees)

	# Always jump to the right!
	frog_velocity = Vector2(
		cos(angle_rad) * power,  # Always positive X (right)
		-sin(angle_rad) * power
	)

	frog_jumping = true
	AudioManager.play_sfx("jump")

	# Stretch frog animation
	var tween = create_tween()
	tween.tween_property(frog, "scale", Vector2(0.8, 1.3), 0.1)
	tween.tween_property(frog, "scale", Vector2(1.0, 1.0), 0.2)

	# Rotate frog in jump direction
	frog.rotation = atan2(frog_velocity.y, frog_velocity.x) + PI/2

func _start_tongue() -> void:
	# Start extending tongue at 45 degrees upward-right
	tongue_extending = true
	tongue_length = 0.0

	# Calculate anchor direction (45 degrees up-right from frog)
	var tongue_angle_rad = deg_to_rad(-TONGUE_ANGLE)  # Negative for upward
	tongue_anchor = frog.position  # Will be updated as tongue extends

	AudioManager.play_sfx("charge")

func _release_tongue() -> void:
	if is_swinging:
		# Convert swing to linear velocity
		# The tangential velocity of the swing
		var tangent_angle = swing_angle + PI / 2  # Perpendicular to rope
		var tangent_speed = swing_angular_velocity * tongue_length
		frog_velocity = Vector2(cos(tangent_angle), sin(tangent_angle)) * tangent_speed

		# Add some of the existing momentum
		frog_velocity.x = max(frog_velocity.x, 200)  # Ensure forward momentum

	is_swinging = false
	tongue_extending = false
	tongue_length = 0.0
	AudioManager.play_sfx("jump")

func _update_tongue(delta: float) -> void:
	if tongue_extending:
		# Extend tongue
		tongue_length += TONGUE_SPEED * delta

		if tongue_length >= TONGUE_MAX_LENGTH:
			# Tongue reached max length, start swinging
			tongue_length = TONGUE_MAX_LENGTH
			tongue_extending = false
			is_swinging = true

			# Calculate anchor point
			var tongue_angle_rad = deg_to_rad(-TONGUE_ANGLE)
			tongue_anchor = frog.position + Vector2(cos(tongue_angle_rad), sin(tongue_angle_rad)) * tongue_length

			# Initialize swing angle (angle from anchor to frog)
			var to_frog = frog.position - tongue_anchor
			swing_angle = atan2(to_frog.y, to_frog.x)

			# Convert current velocity to angular velocity
			var tangent_angle = swing_angle + PI / 2
			var tangent_dir = Vector2(cos(tangent_angle), sin(tangent_angle))
			swing_angular_velocity = frog_velocity.dot(tangent_dir) / tongue_length

	elif is_swinging:
		# Pendulum physics
		# Angular acceleration from gravity
		var gravity_torque = SWING_GRAVITY * cos(swing_angle) / tongue_length
		swing_angular_velocity += gravity_torque * delta

		# Apply damping
		swing_angular_velocity *= SWING_DAMPING

		# Update angle
		swing_angle += swing_angular_velocity * delta

		# Update frog position based on rope
		frog.position = tongue_anchor + Vector2(cos(swing_angle), sin(swing_angle)) * tongue_length

		# Rotate frog to face swing direction
		frog.rotation = swing_angle + PI / 2

func _process(delta: float) -> void:
	if not game_active:
		return

	# Update rope swing availability
	rope_swing_available = current_platform_index >= ROPE_SWING_UNLOCK_PLATFORM

	if is_charging:
		_update_charging(delta)

	if tongue_extending or is_swinging:
		_update_tongue(delta)
	elif frog_jumping:
		_update_frog_physics(delta)

	_update_camera(delta)
	_update_particles(delta)
	_update_background(delta)
	_check_generate_platforms()
	queue_redraw()

func _update_charging(delta: float) -> void:
	charge_time += delta
	charge_time = min(charge_time, MAX_CHARGE_TIME)

	# Update trajectory preview
	_update_trajectory_preview()

	# Animate legs (push back for charging)
	var charge_ratio = charge_time / MAX_CHARGE_TIME
	var leg_offset = charge_ratio * 15

	var left_leg = frog.get_node_or_null("LeftLeg")
	var right_leg = frog.get_node_or_null("RightLeg")
	if left_leg:
		left_leg.position.x = -leg_offset
		left_leg.position.y = leg_offset
	if right_leg:
		right_leg.position.x = -leg_offset * 0.5
		right_leg.position.y = leg_offset

func _update_trajectory_preview() -> void:
	# Clear old trajectory
	for child in trajectory_container.get_children():
		child.queue_free()

	# Check if we should show trajectory
	var trajectory_visibility = _get_trajectory_visibility()
	if trajectory_visibility <= 0:
		return

	# Calculate trajectory (always to the right)
	var charge_ratio = min(charge_time / MAX_CHARGE_TIME, 1.0)
	var power = lerp(MIN_JUMP_POWER, MAX_JUMP_POWER, charge_ratio)
	var angle_degrees = lerp(JUMP_ANGLE_MIN, JUMP_ANGLE_MAX, charge_ratio)
	var angle_rad = deg_to_rad(angle_degrees)

	var velocity = Vector2(
		cos(angle_rad) * power,
		-sin(angle_rad) * power
	)

	var pos = frog.position
	var dt = 0.05

	# Number of points based on visibility
	var num_points = int(TRAJECTORY_POINTS * trajectory_visibility)

	for i in range(num_points):
		var t = i * dt
		var x = pos.x + velocity.x * t
		var y = pos.y + velocity.y * t + 0.5 * GRAVITY * t * t

		var dot = Polygon2D.new()
		var alpha = (1.0 - float(i) / num_points) * 0.6 * trajectory_visibility
		dot.color = Color(1, 1, 1, alpha)
		dot.polygon = _create_circle_polygon(4 - i * 0.1, 6)
		dot.position = Vector2(x, y)
		trajectory_container.add_child(dot)

func _get_trajectory_visibility() -> float:
	# Full visibility for first TRAJECTORY_FULL_JUMPS
	if jump_count < TRAJECTORY_FULL_JUMPS:
		return 1.0

	# Fade out over next jumps
	var fade_progress = float(jump_count - TRAJECTORY_FULL_JUMPS) / float(TRAJECTORY_FADE_JUMPS - TRAJECTORY_FULL_JUMPS)
	return max(0.0, 1.0 - fade_progress)

func _update_frog_physics(delta: float) -> void:
	# Apply gravity
	frog_velocity.y += GRAVITY * delta

	# Move frog
	frog.position += frog_velocity * delta

	# Rotate frog based on velocity
	frog.rotation = atan2(frog_velocity.y, frog_velocity.x) + PI/2

	# Check landing
	_check_landing()

	# Check if fell off screen (below water)
	if frog.position.y > SCREEN_HEIGHT:
		_game_over()

func _check_landing() -> void:
	# Check collision with platforms
	for i in range(platforms.size()):
		var platform = platforms[i]
		var half_width = platform.width / 2

		# Check if frog is within platform horizontal bounds
		if frog.position.x >= platform.x - half_width and frog.position.x <= platform.x + half_width:
			# Check if frog is landing on platform (coming from above)
			if frog_velocity.y > 0 and frog.position.y >= platform.y - 30 and frog.position.y <= platform.y + 10:
				_land_on_platform(i)
				return

func _land_on_platform(platform_index: int) -> void:
	var platform = platforms[platform_index]

	# Stop frog - NO sliding, stays exactly where it lands
	frog_jumping = false
	frog_velocity = Vector2.ZERO
	frog.position.y = platform.y - 25
	frog.rotation = 0

	# Reset legs
	var left_leg = frog.get_node_or_null("LeftLeg")
	var right_leg = frog.get_node_or_null("RightLeg")
	if left_leg:
		left_leg.position = Vector2.ZERO
	if right_leg:
		right_leg.position = Vector2.ZERO

	# Squash animation on landing
	var tween = create_tween()
	tween.tween_property(frog, "scale", Vector2(1.3, 0.7), 0.08)
	tween.tween_property(frog, "scale", Vector2(1.0, 1.0), 0.15)

	# Spawn landing particles
	_spawn_landing_particles(frog.position)

	# Check if this is a new platform (forward progress)
	if platform_index > current_platform_index:
		current_platform_index = platform_index
		jump_count += 1
		GameManager.add_score(1)
		emit_signal("jump_completed", jump_count)
		AudioManager.play_sfx("land")
	elif platform_index < current_platform_index:
		# Landed on previous platform - game over (went backwards)
		_game_over()
		return

func _spawn_landing_particles(pos: Vector2) -> void:
	for i in range(8):
		var angle = randf() * PI  # Only upward
		var speed = randf_range(100, 200)
		landing_particles.append({
			"x": pos.x,
			"y": pos.y,
			"vx": cos(angle) * speed * (1 if randf() > 0.5 else -1),
			"vy": -sin(angle) * speed,
			"life": 0.5,
			"size": randf_range(3, 6)
		})

func _update_camera(delta: float) -> void:
	# Camera follows frog horizontally (frog stays at left side of screen)
	camera_target_x = frog.position.x - FROG_SCREEN_X

	# Smooth camera movement
	camera_x = lerp(camera_x, camera_target_x, delta * CAMERA_SMOOTH)

	# Move world container (simulates camera moving right)
	world_container.position.x = -camera_x

func _update_particles(delta: float) -> void:
	# Update landing particles
	for particle in landing_particles:
		particle.x += particle.vx * delta
		particle.y += particle.vy * delta
		particle.vy += GRAVITY * 0.5 * delta
		particle.life -= delta

	landing_particles = landing_particles.filter(func(p): return p.life > 0)

func _update_background(delta: float) -> void:
	# Move clouds slowly
	for cloud in clouds:
		cloud.x -= cloud.speed * delta * 0.1

func _check_generate_platforms() -> void:
	# Generate more platforms as frog progresses right
	var furthest_x = 0.0
	if not platforms.is_empty():
		furthest_x = platforms[-1].x

	while furthest_x < frog.position.x + SCREEN_WIDTH * 2:
		_generate_next_platform()
		furthest_x = platforms[-1].x

func _game_over() -> void:
	game_active = false
	frog_jumping = false

	AudioManager.play_sfx("death")
	GameManager.end_game()
	emit_signal("game_over_triggered")

	# Frog falls animation
	var tween = create_tween()
	tween.tween_property(frog, "rotation", frog.rotation + PI * 2, 0.5)
	tween.parallel().tween_property(frog, "modulate:a", 0.0, 0.5)

func restart() -> void:
	frog.modulate.a = 1.0
	_start_game()
	if game_ui.has_method("hide_game_over"):
		game_ui.hide_game_over()

func _draw() -> void:
	# Draw clouds (parallax - move slower than camera)
	for cloud in clouds:
		var screen_x = cloud.x - camera_x * 0.3
		if screen_x > -200 and screen_x < SCREEN_WIDTH + 200:
			var cloud_color = Color(1, 1, 1, 0.7)
			# Draw cloud as ellipses
			draw_circle(Vector2(screen_x, cloud.y), cloud.width * 0.3, cloud_color)
			draw_circle(Vector2(screen_x + cloud.width * 0.3, cloud.y - 10), cloud.width * 0.25, cloud_color)
			draw_circle(Vector2(screen_x - cloud.width * 0.3, cloud.y + 5), cloud.width * 0.2, cloud_color)

	# Draw trees (parallax - move slightly slower)
	for tree in trees:
		var screen_x = tree.x - camera_x * 0.8
		if screen_x > -100 and screen_x < SCREEN_WIDTH + 100:
			# Tree trunk
			draw_rect(Rect2(screen_x - 5, tree.y - tree.height * 0.3, 10, tree.height * 0.5), Color(0.4, 0.26, 0.13))
			# Tree foliage
			var foliage_color = Color(0.13, 0.55, 0.13, 0.8)
			draw_circle(Vector2(screen_x, tree.y - tree.height * 0.5), tree.width * 0.5, foliage_color)
			draw_circle(Vector2(screen_x - 15, tree.y - tree.height * 0.3), tree.width * 0.35, foliage_color)
			draw_circle(Vector2(screen_x + 15, tree.y - tree.height * 0.35), tree.width * 0.4, foliage_color)

	# Draw landing particles
	for particle in landing_particles:
		var alpha = particle.life * 2
		var color = Color(0.565, 0.933, 0.565, alpha)
		var screen_x = particle.x - camera_x
		draw_circle(Vector2(screen_x, particle.y), particle.size, color)

	# Draw charge indicator (fixed to screen, above frog)
	if is_charging:
		var charge_ratio = charge_time / MAX_CHARGE_TIME
		var bar_width = 100 * charge_ratio
		var frog_screen_x = frog.position.x - camera_x
		var bar_pos = Vector2(frog_screen_x - 50, frog.position.y - 60)

		# Background
		draw_rect(Rect2(bar_pos, Vector2(100, 10)), Color(0.3, 0.3, 0.3, 0.7))
		# Fill
		var fill_color = Color.GREEN.lerp(Color.RED, charge_ratio)
		draw_rect(Rect2(bar_pos, Vector2(bar_width, 10)), fill_color)
		# Border
		draw_rect(Rect2(bar_pos, Vector2(100, 10)), Color.WHITE, false, 2.0)

		# Arrow indicator showing jump direction
		var arrow_x = frog_screen_x + 50
		var arrow_y = frog.position.y - 30
		var arrow_length = 30 + charge_ratio * 40
		var angle_rad = deg_to_rad(lerp(JUMP_ANGLE_MIN, JUMP_ANGLE_MAX, charge_ratio))
		var arrow_end = Vector2(arrow_x + cos(-angle_rad) * arrow_length, arrow_y + sin(-angle_rad) * arrow_length)
		draw_line(Vector2(arrow_x, arrow_y), arrow_end, Color.YELLOW, 3.0)
		# Arrow head
		var head_size = 10
		draw_line(arrow_end, arrow_end + Vector2(-head_size, head_size).rotated(-angle_rad), Color.YELLOW, 3.0)
		draw_line(arrow_end, arrow_end + Vector2(-head_size, -head_size).rotated(-angle_rad), Color.YELLOW, 3.0)

	# Draw tongue/rope
	if tongue_extending or is_swinging:
		var frog_screen_pos = Vector2(frog.position.x - camera_x, frog.position.y)
		var tongue_angle_rad = deg_to_rad(-TONGUE_ANGLE)

		var tongue_end: Vector2
		if tongue_extending:
			# Tongue extending outward
			tongue_end = frog_screen_pos + Vector2(cos(tongue_angle_rad), sin(tongue_angle_rad)) * tongue_length
		else:
			# Swinging - tongue goes to anchor
			tongue_end = Vector2(tongue_anchor.x - camera_x, tongue_anchor.y)

		# Draw tongue (pink/red rope)
		draw_line(frog_screen_pos, tongue_end, Color(0.9, 0.3, 0.4), 4.0)

		# Draw anchor point (sticky blob)
		draw_circle(tongue_end, 8, Color(0.9, 0.3, 0.4))
		draw_circle(tongue_end, 5, Color(1.0, 0.5, 0.6))

	# Draw rope swing hint when available and jumping
	if frog_jumping and rope_swing_available and not is_swinging and not tongue_extending:
		var frog_screen_x = frog.position.x - camera_x
		var hint_pos = Vector2(frog_screen_x, frog.position.y - 80)

		# Pulsing hint
		var pulse = (sin(Time.get_ticks_msec() / 150.0) + 1) / 2
		var hint_alpha = 0.5 + pulse * 0.3

		# Draw "TAP" hint with tongue icon
		draw_string(ThemeDB.fallback_font, hint_pos + Vector2(-25, 0), "TAP!", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 1, hint_alpha))

		# Draw small tongue preview
		var preview_start = hint_pos + Vector2(0, 15)
		var tongue_angle_rad = deg_to_rad(-TONGUE_ANGLE)
		var preview_end = preview_start + Vector2(cos(tongue_angle_rad), sin(tongue_angle_rad)) * 30
		draw_line(preview_start, preview_end, Color(0.9, 0.3, 0.4, hint_alpha), 2.0)
