extends Node2D
## Game: Main gameplay for Gravity Flip
## Infinite runner with gravity flipping mechanic

signal player_died
signal gem_collected

# Constants
const SCREEN_WIDTH = 720.0
const SCREEN_HEIGHT = 1280.0
const FLOOR_Y = 1180.0
const CEILING_Y = 100.0
const PLAYER_SIZE = 40.0
const BASE_SPEED = 200.0
const GRAVITY_STRENGTH = 1500.0
const FLIP_ROTATION_TIME = 0.2
const OBSTACLE_SPAWN_DISTANCE = 400.0
const GEM_SPAWN_CHANCE = 0.3
const SPEED_INCREASE_DISTANCE = 500.0
const SPEED_INCREASE_PERCENT = 0.1

# Game state
var game_active: bool = false
var gravity_direction: float = 1.0  # 1.0 = down, -1.0 = up
var current_speed: float = BASE_SPEED
var distance_traveled: float = 0.0
var last_obstacle_x: float = 0.0
var player_velocity_y: float = 0.0
var is_flipping: bool = false
var last_speed_milestone: float = 0.0

# Nodes
var player: Node2D
var player_visual: ColorRect
var trail_container: Node2D
var obstacles_container: Node2D
var gems_container: Node2D
var stars_container: Node2D
var floor_line: ColorRect
var ceiling_line: ColorRect
var game_ui: CanvasLayer

# Particles
var gem_particles: Array[Dictionary] = []
var trail_points: Array[Dictionary] = []
const MAX_TRAIL_POINTS = 15
const TRAIL_FADE_SPEED = 3.0

# Stars background
var stars: Array[Dictionary] = []
const NUM_STARS = 40

# Screen shake
var shake_amount: float = 0.0
var shake_decay: float = 5.0
var original_camera_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_setup_scene()
	_create_stars()
	_start_game()

func _setup_scene() -> void:
	# Create background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	add_child(bg)

	# Stars container
	stars_container = Node2D.new()
	stars_container.z_index = 0
	add_child(stars_container)

	# Floor line
	floor_line = ColorRect.new()
	floor_line.color = Color("#9b59b6")
	floor_line.position = Vector2(0, FLOOR_Y)
	floor_line.size = Vector2(SCREEN_WIDTH, 4)
	floor_line.z_index = 1
	add_child(floor_line)

	# Ceiling line
	ceiling_line = ColorRect.new()
	ceiling_line.color = Color("#9b59b6")
	ceiling_line.position = Vector2(0, CEILING_Y)
	ceiling_line.size = Vector2(SCREEN_WIDTH, 4)
	ceiling_line.z_index = 1
	add_child(ceiling_line)

	# Obstacles container
	obstacles_container = Node2D.new()
	obstacles_container.z_index = 2
	add_child(obstacles_container)

	# Gems container
	gems_container = Node2D.new()
	gems_container.z_index = 2
	add_child(gems_container)

	# Trail container
	trail_container = Node2D.new()
	trail_container.z_index = 3
	add_child(trail_container)

	# Player
	player = Node2D.new()
	player.position = Vector2(150, FLOOR_Y - PLAYER_SIZE / 2)
	player.z_index = 5
	add_child(player)

	player_visual = ColorRect.new()
	player_visual.color = Color("#9b59b6")
	player_visual.size = Vector2(PLAYER_SIZE, PLAYER_SIZE)
	player_visual.position = Vector2(-PLAYER_SIZE / 2, -PLAYER_SIZE / 2)
	player.add_child(player_visual)

	# Game UI
	var ui_scene = load("res://scenes/game_ui.tscn")
	game_ui = ui_scene.instantiate()
	add_child(game_ui)

func _create_stars() -> void:
	for i in range(NUM_STARS):
		var star = {
			"x": randf() * SCREEN_WIDTH,
			"y": randf() * (FLOOR_Y - CEILING_Y) + CEILING_Y,
			"size": randf_range(1.0, 2.5),
			"alpha": randf_range(0.2, 0.6)
		}
		stars.append(star)

func _start_game() -> void:
	GameManager.start_game()
	game_active = true
	distance_traveled = 0.0
	current_speed = BASE_SPEED
	gravity_direction = 1.0
	player_velocity_y = 0.0
	last_obstacle_x = SCREEN_WIDTH
	last_speed_milestone = 0.0
	player.position = Vector2(150, FLOOR_Y - PLAYER_SIZE / 2)
	player.rotation = 0.0

	# Clear containers
	for child in obstacles_container.get_children():
		child.queue_free()
	for child in gems_container.get_children():
		child.queue_free()

	trail_points.clear()
	gem_particles.clear()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tap") and game_active and not is_flipping:
		_flip_gravity()

func _flip_gravity() -> void:
	gravity_direction *= -1.0
	is_flipping = true
	player_velocity_y = 0.0
	AudioManager.play_sfx("flip")

	# Animate rotation
	var flip_tween = create_tween()
	var target_rotation = player.rotation + PI
	flip_tween.tween_property(player, "rotation", target_rotation, FLIP_ROTATION_TIME)
	flip_tween.tween_callback(func(): is_flipping = false)

func _process(delta: float) -> void:
	if not game_active:
		return

	_update_player(delta)
	_update_obstacles(delta)
	_update_gems(delta)
	_update_trail(delta)
	_update_particles(delta)
	_update_stars(delta)
	_update_shake(delta)
	_spawn_obstacles()
	_check_collisions()
	_update_distance(delta)
	queue_redraw()

func _update_player(delta: float) -> void:
	# Apply gravity
	player_velocity_y += GRAVITY_STRENGTH * gravity_direction * delta

	# Move player
	player.position.y += player_velocity_y * delta

	# Clamp to floor/ceiling and reset velocity when touching
	if gravity_direction > 0:
		# Falling down
		if player.position.y >= FLOOR_Y - PLAYER_SIZE / 2:
			player.position.y = FLOOR_Y - PLAYER_SIZE / 2
			player_velocity_y = 0.0
	else:
		# Falling up
		if player.position.y <= CEILING_Y + PLAYER_SIZE / 2:
			player.position.y = CEILING_Y + PLAYER_SIZE / 2
			player_velocity_y = 0.0

	# Add trail point
	if trail_points.size() == 0 or trail_points[0].pos.distance_to(player.position) > 10:
		trail_points.insert(0, {"pos": player.position, "alpha": 1.0})
		if trail_points.size() > MAX_TRAIL_POINTS:
			trail_points.pop_back()

func _update_trail(delta: float) -> void:
	for point in trail_points:
		point.alpha -= TRAIL_FADE_SPEED * delta
	trail_points = trail_points.filter(func(p): return p.alpha > 0)

func _update_obstacles(delta: float) -> void:
	var move_amount = current_speed * delta
	for obstacle in obstacles_container.get_children():
		obstacle.position.x -= move_amount
		if obstacle.position.x < -100:
			obstacle.queue_free()

func _update_gems(delta: float) -> void:
	var move_amount = current_speed * delta
	for gem in gems_container.get_children():
		gem.position.x -= move_amount
		gem.rotation += delta * 2.0
		if gem.position.x < -50:
			gem.queue_free()

func _update_particles(delta: float) -> void:
	for particle in gem_particles:
		particle.x += particle.vx * delta
		particle.y += particle.vy * delta
		particle.vy += 300.0 * delta
		particle.life -= delta
	gem_particles = gem_particles.filter(func(p): return p.life > 0)

func _update_stars(delta: float) -> void:
	var star_speed = current_speed * 0.1
	for star in stars:
		star.x -= star_speed * delta
		if star.x < 0:
			star.x = SCREEN_WIDTH
			star.y = randf() * (FLOOR_Y - CEILING_Y) + CEILING_Y

func _update_shake(delta: float) -> void:
	if shake_amount > 0:
		shake_amount -= shake_decay * delta
		shake_amount = max(0, shake_amount)
		var offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		position = original_camera_offset + offset
	else:
		position = original_camera_offset

func _update_distance(delta: float) -> void:
	distance_traveled += current_speed * delta
	GameManager.add_distance(current_speed * delta)

	# Speed increase every 500 distance
	if distance_traveled - last_speed_milestone >= SPEED_INCREASE_DISTANCE:
		last_speed_milestone = distance_traveled
		current_speed *= (1.0 + SPEED_INCREASE_PERCENT)

func _spawn_obstacles() -> void:
	while last_obstacle_x < distance_traveled + SCREEN_WIDTH + 200:
		last_obstacle_x += OBSTACLE_SPAWN_DISTANCE + randf() * 200.0
		var spawn_x = last_obstacle_x - distance_traveled + SCREEN_WIDTH

		# Random obstacle type
		var obstacle_type = randi() % 4

		match obstacle_type:
			0:
				# Floor spike
				_create_spike(spawn_x, FLOOR_Y, false)
			1:
				# Ceiling spike
				_create_spike(spawn_x, CEILING_Y, true)
			2:
				# Both spikes (narrow passage)
				_create_spike(spawn_x, FLOOR_Y, false)
				_create_spike(spawn_x, CEILING_Y, true)
			3:
				# Gap (no floor for a bit - handled by collision)
				_create_gap(spawn_x)

		# Spawn gem
		if randf() < GEM_SPAWN_CHANCE:
			var gem_y = randf_range(CEILING_Y + 150, FLOOR_Y - 150)
			_create_gem(spawn_x + 100, gem_y)

func _create_spike(x: float, y: float, is_ceiling: bool) -> void:
	var spike = Node2D.new()
	spike.position = Vector2(x, y)
	spike.set_meta("type", "spike")

	var spike_visual = ColorRect.new()
	spike_visual.color = Color("#e74c3c")
	spike_visual.size = Vector2(30, 60)

	if is_ceiling:
		spike_visual.position = Vector2(-15, 0)
		spike.set_meta("is_ceiling", true)
	else:
		spike_visual.position = Vector2(-15, -60)
		spike.set_meta("is_ceiling", false)

	spike.add_child(spike_visual)
	obstacles_container.add_child(spike)

func _create_gap(x: float) -> void:
	var gap = Node2D.new()
	gap.position = Vector2(x, FLOOR_Y)
	gap.set_meta("type", "gap")
	gap.set_meta("width", 120.0)

	# Visual indicator of gap (dark area)
	var gap_visual = ColorRect.new()
	gap_visual.color = Color(0, 0, 0, 0.8)
	gap_visual.size = Vector2(120, 100)
	gap_visual.position = Vector2(-60, 0)
	gap.add_child(gap_visual)

	obstacles_container.add_child(gap)

func _create_gem(x: float, y: float) -> void:
	var gem = Node2D.new()
	gem.position = Vector2(x, y)
	gem.set_meta("type", "gem")

	var gem_visual = ColorRect.new()
	gem_visual.color = Color("#3498db")
	gem_visual.size = Vector2(25, 25)
	gem_visual.position = Vector2(-12.5, -12.5)
	gem.add_child(gem_visual)

	gems_container.add_child(gem)

func _check_collisions() -> void:
	var player_rect = Rect2(
		player.position.x - PLAYER_SIZE / 2,
		player.position.y - PLAYER_SIZE / 2,
		PLAYER_SIZE,
		PLAYER_SIZE
	)

	# Check obstacles
	for obstacle in obstacles_container.get_children():
		var obs_type = obstacle.get_meta("type")

		if obs_type == "spike":
			var spike_rect: Rect2
			if obstacle.get_meta("is_ceiling"):
				spike_rect = Rect2(obstacle.position.x - 15, obstacle.position.y, 30, 60)
			else:
				spike_rect = Rect2(obstacle.position.x - 15, obstacle.position.y - 60, 30, 60)

			if player_rect.intersects(spike_rect):
				_game_over()
				return

		elif obs_type == "gap":
			var gap_width = obstacle.get_meta("width")
			var gap_x = obstacle.position.x - gap_width / 2

			# Check if player is over gap and at floor level
			if player.position.x > gap_x and player.position.x < gap_x + gap_width:
				if gravity_direction > 0 and player.position.y >= FLOOR_Y - PLAYER_SIZE / 2 - 5:
					_game_over()
					return

	# Check gems
	for gem in gems_container.get_children():
		var gem_rect = Rect2(
			gem.position.x - 15,
			gem.position.y - 15,
			30,
			30
		)
		if player_rect.intersects(gem_rect):
			_collect_gem(gem)

func _collect_gem(gem: Node2D) -> void:
	# Spawn particles
	for i in range(8):
		var angle = randf() * TAU
		var speed = randf_range(100, 200)
		gem_particles.append({
			"x": gem.position.x,
			"y": gem.position.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"life": 0.5
		})

	gem.queue_free()
	GameManager.add_gem()
	emit_signal("gem_collected")

func _game_over() -> void:
	game_active = false
	shake_amount = 15.0
	AudioManager.play_sfx("death")
	GameManager.end_game()
	emit_signal("player_died")

func restart() -> void:
	_start_game()
	if game_ui.has_method("hide_game_over"):
		game_ui.hide_game_over()

func _draw() -> void:
	# Draw stars
	for star in stars:
		var color = Color(1, 1, 1, star.alpha)
		draw_circle(Vector2(star.x, star.y), star.size, color)

	# Draw trail
	for i in range(trail_points.size()):
		var point = trail_points[i]
		var size = (1.0 - float(i) / MAX_TRAIL_POINTS) * PLAYER_SIZE * 0.5
		var alpha = point.alpha * 0.6
		var color = Color(0.608, 0.349, 0.714, alpha)
		draw_circle(point.pos, size, color)

	# Draw gem particles
	for particle in gem_particles:
		var alpha = particle.life * 2.0
		var color = Color(0.204, 0.596, 0.859, alpha)
		draw_circle(Vector2(particle.x, particle.y), 4, color)
