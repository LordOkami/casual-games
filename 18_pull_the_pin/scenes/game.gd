extends Node2D
## Pull The Pin: Satisfying puzzle game
## Pull pins in the correct order to guide balls to goals while avoiding hazards

# Grid and cell constants
const CELL_SIZE: float = 60.0
const GRID_COLS: int = 10
const GRID_ROWS: int = 16
const GRAVITY: float = 800.0
const BALL_RADIUS: float = 20.0
const PIN_LENGTH: float = 80.0
const PIN_WIDTH: float = 12.0

# Pin types
enum PinType { NORMAL, LOCKED, TIMED }

# Object types for level generation
enum ObjectType { EMPTY, WALL, BALL, GOAL, HAZARD, KEY, PIN_H, PIN_V, LOCKED_PIN_H, LOCKED_PIN_V, TIMED_PIN_H, TIMED_PIN_V }

# Ball colors and their matching goals
const BALL_COLORS: Array = [
	Color("#4ECDC4"),  # Teal
	Color("#FF6B9D"),  # Pink
	Color("#FFE66D"),  # Yellow
	Color("#95E1D3"),  # Mint
	Color("#F38181"),  # Coral
]

@onready var game_ui: GameUI = $GameUI
@onready var game_container: Node2D = $GameContainer
@onready var ball_container: Node2D = $BallContainer
@onready var pin_container: Node2D = $PinContainer
@onready var effect_container: Node2D = $EffectContainer

var screen_width: float
var screen_height: float
var grid_offset: Vector2

var balls: Array = []
var pins: Array = []
var goals: Array = []
var hazards: Array = []
var walls: Array = []
var keys_collected: int = 0
var total_keys: int = 0

var total_balls: int = 0
var balls_saved: int = 0
var balls_lost: int = 0
var level_active: bool = false

var hint_pin: Node2D = null

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	grid_offset = Vector2(
		(screen_width - GRID_COLS * CELL_SIZE) / 2,
		120  # Below top bar
	)

	GameManager.start_game("pull_the_pin")
	game_ui.hint_requested.connect(_on_hint_requested)
	game_ui.next_level_requested.connect(_on_next_level)
	game_ui.retry_requested.connect(_on_retry)

	_load_level(GameManager.current_level)

func _input(event: InputEvent) -> void:
	if not level_active:
		return

	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed:
		pos = event.position
	else:
		return

	# Check if clicked on a pin
	for pin_data in pins:
		var pin: Node2D = pin_data.node
		if not is_instance_valid(pin):
			continue

		var pin_rect = _get_pin_rect(pin_data)
		if pin_rect.has_point(pos):
			_try_pull_pin(pin_data)
			break

func _get_pin_rect(pin_data: Dictionary) -> Rect2:
	var pin: Node2D = pin_data.node
	var pos = pin.global_position
	if pin_data.horizontal:
		return Rect2(pos.x - PIN_LENGTH / 2 - 10, pos.y - PIN_WIDTH / 2 - 10, PIN_LENGTH + 20, PIN_WIDTH + 20)
	else:
		return Rect2(pos.x - PIN_WIDTH / 2 - 10, pos.y - PIN_LENGTH / 2 - 10, PIN_WIDTH + 20, PIN_LENGTH + 20)

func _try_pull_pin(pin_data: Dictionary) -> void:
	var pin_type: PinType = pin_data.type

	# Check if locked pin and keys not collected
	if pin_type == PinType.LOCKED and keys_collected < total_keys:
		game_ui.show_popup("Need Key!", Color(1, 0.5, 0.2))
		AudioManager.play_sfx("hit")
		return

	_pull_pin(pin_data)

func _pull_pin(pin_data: Dictionary) -> void:
	var pin: Node2D = pin_data.node
	if not is_instance_valid(pin):
		return

	AudioManager.play_sfx("pin_pull")
	pins.erase(pin_data)

	# Satisfying pull animation
	var tween = create_tween()
	var pull_dir = Vector2.RIGHT if pin_data.horizontal else Vector2.DOWN
	tween.tween_property(pin, "position", pin.position + pull_dir * 150, 0.2).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(pin, "modulate:a", 0.0, 0.2)
	tween.tween_callback(pin.queue_free)

	# Add score for pulling pin
	GameManager.add_score(10)

	# Clear hint if this was the hint pin
	if hint_pin == pin:
		hint_pin = null

func _process(delta: float) -> void:
	if not level_active:
		return

	_update_balls(delta)
	_update_timed_pins(delta)
	_check_level_complete()

func _update_balls(delta: float) -> void:
	for ball_data in balls.duplicate():
		if not is_instance_valid(ball_data.node):
			balls.erase(ball_data)
			continue

		var ball: Node2D = ball_data.node

		# Apply gravity
		ball_data.velocity.y += GRAVITY * delta

		# Predict next position
		var next_pos = ball.position + ball_data.velocity * delta

		# Check collisions with walls
		var collision = _check_wall_collision(ball.position, next_pos, BALL_RADIUS)
		if collision.hit:
			if collision.normal.y < -0.5:
				# Hit floor - stop vertical movement
				ball_data.velocity.y = 0
				next_pos.y = collision.point.y - BALL_RADIUS
			elif collision.normal.y > 0.5:
				# Hit ceiling
				ball_data.velocity.y = abs(ball_data.velocity.y) * 0.3
				next_pos.y = collision.point.y + BALL_RADIUS
			else:
				# Hit side wall
				ball_data.velocity.x = -ball_data.velocity.x * 0.5
				if collision.normal.x > 0:
					next_pos.x = collision.point.x + BALL_RADIUS
				else:
					next_pos.x = collision.point.x - BALL_RADIUS

		# Check collision with pins (pins act as platforms)
		for pin_data in pins:
			if not is_instance_valid(pin_data.node):
				continue
			var pin_collision = _check_pin_collision(ball.position, next_pos, BALL_RADIUS, pin_data)
			if pin_collision.hit:
				if pin_data.horizontal:
					# Horizontal pin acts as floor
					ball_data.velocity.y = 0
					next_pos.y = pin_collision.point.y - BALL_RADIUS
				else:
					# Vertical pin acts as wall
					ball_data.velocity.x = -ball_data.velocity.x * 0.3
					if ball.position.x < pin_data.node.position.x:
						next_pos.x = pin_collision.point.x - BALL_RADIUS
					else:
						next_pos.x = pin_collision.point.x + BALL_RADIUS

		# Apply position
		ball.position = next_pos

		# Squash and stretch effect
		var speed = ball_data.velocity.length()
		var squash = clamp(1.0 + speed * 0.0003, 1.0, 1.4)
		if abs(ball_data.velocity.y) > abs(ball_data.velocity.x):
			ball.scale = Vector2(1.0 / sqrt(squash), sqrt(squash))
		else:
			ball.scale = Vector2(sqrt(squash), 1.0 / sqrt(squash))

		# Check if ball reached goal
		for goal_data in goals:
			if not is_instance_valid(goal_data.node):
				continue
			if ball.position.distance_to(goal_data.node.position) < BALL_RADIUS + 25:
				if ball_data.color_idx == goal_data.color_idx:
					_ball_reached_goal(ball_data)
					break

		# Check if ball hit hazard
		for hazard in hazards:
			if not is_instance_valid(hazard):
				continue
			if ball.position.distance_to(hazard.position) < BALL_RADIUS + 20:
				_ball_hit_hazard(ball_data)
				break

		# Check if ball collected key
		for key_data in walls.duplicate():
			if key_data.get("is_key", false) and is_instance_valid(key_data.node):
				if ball.position.distance_to(key_data.node.position) < BALL_RADIUS + 15:
					_collect_key(key_data)
					break

		# Check if ball fell off screen
		if ball.position.y > screen_height + 100:
			_ball_lost(ball_data)

func _check_wall_collision(from: Vector2, to: Vector2, radius: float) -> Dictionary:
	var result = {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}

	for wall_data in walls:
		if wall_data.get("is_key", false):
			continue
		if not is_instance_valid(wall_data.node):
			continue

		var wall_rect: Rect2 = wall_data.rect
		var expanded = Rect2(
			wall_rect.position.x - radius,
			wall_rect.position.y - radius,
			wall_rect.size.x + radius * 2,
			wall_rect.size.y + radius * 2
		)

		if expanded.has_point(to):
			result.hit = true
			# Determine collision normal
			var center = wall_rect.get_center()
			var diff = to - center
			if abs(diff.x / wall_rect.size.x) > abs(diff.y / wall_rect.size.y):
				result.normal = Vector2(sign(diff.x), 0)
				result.point = Vector2(
					wall_rect.position.x if diff.x < 0 else wall_rect.position.x + wall_rect.size.x,
					to.y
				)
			else:
				result.normal = Vector2(0, sign(diff.y))
				result.point = Vector2(
					to.x,
					wall_rect.position.y if diff.y < 0 else wall_rect.position.y + wall_rect.size.y
				)
			break

	return result

func _check_pin_collision(from: Vector2, to: Vector2, radius: float, pin_data: Dictionary) -> Dictionary:
	var result = {"hit": false, "point": Vector2.ZERO}
	var pin: Node2D = pin_data.node
	var pin_pos = pin.position

	var pin_rect: Rect2
	if pin_data.horizontal:
		pin_rect = Rect2(
			pin_pos.x - PIN_LENGTH / 2,
			pin_pos.y - PIN_WIDTH / 2,
			PIN_LENGTH,
			PIN_WIDTH
		)
	else:
		pin_rect = Rect2(
			pin_pos.x - PIN_WIDTH / 2,
			pin_pos.y - PIN_LENGTH / 2,
			PIN_WIDTH,
			PIN_LENGTH
		)

	var expanded = Rect2(
		pin_rect.position.x - radius,
		pin_rect.position.y - radius,
		pin_rect.size.x + radius * 2,
		pin_rect.size.y + radius * 2
	)

	if expanded.has_point(to) and not expanded.has_point(from):
		result.hit = true
		result.point = pin_pos

	return result

func _update_timed_pins(delta: float) -> void:
	for pin_data in pins.duplicate():
		if pin_data.type != PinType.TIMED:
			continue
		if not is_instance_valid(pin_data.node):
			continue

		pin_data.timer -= delta
		if pin_data.timer <= 0:
			_pull_pin(pin_data)
		elif pin_data.timer < 2.0:
			# Blinking effect when about to disappear
			var blink = sin(pin_data.timer * 10) * 0.5 + 0.5
			pin_data.node.modulate.a = blink

func _ball_reached_goal(ball_data: Dictionary) -> void:
	balls_saved += 1
	AudioManager.play_sfx("ball_collect")

	var ball = ball_data.node
	_create_particles(ball.position, ball_data.color)

	# Success animation
	var tween = create_tween()
	tween.tween_property(ball, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(ball, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ball.queue_free)

	balls.erase(ball_data)
	game_ui.update_stars(_calculate_stars())

func _ball_hit_hazard(ball_data: Dictionary) -> void:
	balls_lost += 1
	AudioManager.play_sfx("explosion")

	var ball = ball_data.node
	_create_explosion(ball.position)
	_screen_shake()

	ball.queue_free()
	balls.erase(ball_data)

func _ball_lost(ball_data: Dictionary) -> void:
	balls_lost += 1
	var ball = ball_data.node
	ball.queue_free()
	balls.erase(ball_data)

func _collect_key(key_data: Dictionary) -> void:
	keys_collected += 1
	AudioManager.play_sfx("unlock")
	game_ui.show_popup("Key!", Color(1, 0.84, 0))

	var key = key_data.node
	var tween = create_tween()
	tween.tween_property(key, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(key, "modulate:a", 0.0, 0.2)
	tween.tween_callback(key.queue_free)

	walls.erase(key_data)

	# Unlock locked pins visual feedback
	if keys_collected >= total_keys:
		for pin_data in pins:
			if pin_data.type == PinType.LOCKED and is_instance_valid(pin_data.node):
				pin_data.node.modulate = Color(0.8, 0.8, 0.2)
				var unlock_tween = create_tween()
				unlock_tween.tween_property(pin_data.node, "scale", Vector2(1.2, 1.2), 0.1)
				unlock_tween.tween_property(pin_data.node, "scale", Vector2(1.0, 1.0), 0.1)

func _calculate_stars() -> int:
	if total_balls == 0:
		return 0
	var ratio = float(balls_saved) / float(total_balls)
	if ratio >= 1.0:
		return 3
	elif ratio >= 0.7:
		return 2
	elif ratio >= 0.4:
		return 1
	return 0

func _check_level_complete() -> void:
	if balls.size() == 0 and level_active:
		level_active = false
		var stars = _calculate_stars()

		if stars == 0:
			# Failed - not enough balls saved
			await get_tree().create_timer(0.5).timeout
			GameManager.end_game()
		else:
			# Success!
			game_ui.set_balls_saved(balls_saved, total_balls)

			if stars == 3:
				game_ui.show_popup("GENIUS!", Color(1, 0.84, 0))
			elif stars == 2:
				game_ui.show_popup("Great!", Color(0.3, 0.9, 0.3))
			else:
				game_ui.show_popup("Complete!", Color(0.6, 0.8, 1))

			await get_tree().create_timer(0.8).timeout
			GameManager.add_score(stars * 50)
			GameManager.complete_level(stars)

func _on_next_level() -> void:
	GameManager.next_level()
	_load_level(GameManager.current_level)

func _on_retry() -> void:
	_load_level(GameManager.current_level)

func _on_hint_requested() -> void:
	if pins.size() > 0 and hint_pin == null:
		# Find the best pin to pull (simple heuristic: topmost pin that's not locked)
		var best_pin: Dictionary = {}
		var best_score: float = -INF

		for pin_data in pins:
			if pin_data.type == PinType.LOCKED and keys_collected < total_keys:
				continue
			if not is_instance_valid(pin_data.node):
				continue

			# Score based on position (higher pins first) and type
			var score = -pin_data.node.position.y
			if pin_data.type == PinType.TIMED:
				score += 100  # Prioritize timed pins

			if score > best_score:
				best_score = score
				best_pin = pin_data

		if best_pin.size() > 0:
			hint_pin = best_pin.node
			_show_hint(best_pin)
			AudioManager.play_sfx("tap")

func _show_hint(pin_data: Dictionary) -> void:
	var pin = pin_data.node
	var hint_effect = ColorRect.new()
	hint_effect.size = Vector2(30, 30)
	hint_effect.position = pin.position - Vector2(15, 15)
	hint_effect.color = Color(1, 1, 0, 0.8)
	effect_container.add_child(hint_effect)

	var tween = create_tween().set_loops(3)
	tween.tween_property(hint_effect, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(hint_effect, "modulate:a", 0.0, 0.3)
	tween.tween_property(hint_effect, "scale", Vector2(1.0, 1.0), 0.0)
	tween.tween_property(hint_effect, "modulate:a", 0.8, 0.0)
	tween.chain().tween_callback(hint_effect.queue_free)

func _create_particles(pos: Vector2, color: Color) -> void:
	for i in range(12):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = color
		particle.position = pos - Vector2(4, 4)
		effect_container.add_child(particle)

		var angle = randf() * TAU
		var speed = randf_range(150, 300)
		var vel = Vector2(cos(angle), sin(angle)) * speed

		var tween = create_tween()
		tween.tween_property(particle, "position", particle.position + vel * 0.5, 0.5).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "scale", Vector2(0.1, 0.1), 0.5)
		tween.tween_callback(particle.queue_free)

func _create_explosion(pos: Vector2) -> void:
	# Flash
	var flash = ColorRect.new()
	flash.size = Vector2(100, 100)
	flash.position = pos - Vector2(50, 50)
	flash.color = Color(1, 0.5, 0, 0.8)
	effect_container.add_child(flash)

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(2, 2), 0.1)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(flash.queue_free)

	# Debris
	for i in range(15):
		var debris = ColorRect.new()
		debris.size = Vector2(randf_range(4, 12), randf_range(4, 12))
		debris.color = Color(0.3, 0.3, 0.3)
		debris.position = pos
		effect_container.add_child(debris)

		var angle = randf() * TAU
		var speed = randf_range(200, 400)
		var end_pos = pos + Vector2(cos(angle), sin(angle)) * speed * 0.4

		var tween = create_tween()
		tween.tween_property(debris, "position", end_pos, 0.4).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(debris, "rotation", randf_range(-3, 3), 0.4)
		tween.parallel().tween_property(debris, "modulate:a", 0.0, 0.4)
		tween.tween_callback(debris.queue_free)

func _screen_shake() -> void:
	var original_pos = game_container.position
	var tween = create_tween()
	for i in range(5):
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		tween.tween_property(game_container, "position", original_pos + offset, 0.03)
	tween.tween_property(game_container, "position", original_pos, 0.03)

# Level Generation
func _load_level(level: int) -> void:
	_clear_level()

	level_active = true
	balls_saved = 0
	balls_lost = 0
	keys_collected = 0
	total_keys = 0
	total_balls = 0
	hint_pin = null

	# Generate level based on level number
	var level_data = _generate_level(level)
	_build_level(level_data)

	game_ui.update_stars(0)

func _clear_level() -> void:
	for child in ball_container.get_children():
		child.queue_free()
	for child in pin_container.get_children():
		child.queue_free()
	for child in game_container.get_children():
		if child.name != "Background":
			child.queue_free()
	for child in effect_container.get_children():
		child.queue_free()

	balls.clear()
	pins.clear()
	goals.clear()
	hazards.clear()
	walls.clear()

func _generate_level(level: int) -> Dictionary:
	# Seed for consistent level generation
	seed(level * 12345)

	var data = {
		"walls": [],
		"pins": [],
		"balls": [],
		"goals": [],
		"hazards": [],
		"keys": []
	}

	# Difficulty scaling
	var num_balls = mini(2 + level / 10, 5)
	var num_pins = mini(3 + level / 5, 8)
	var num_hazards = mini(level / 8, 4)
	var has_locked_pins = level >= 10
	var has_timed_pins = level >= 20
	var num_keys = 1 if has_locked_pins and randi() % 3 == 0 else 0

	# Create container walls (left, right, bottom)
	var container_left = grid_offset.x + CELL_SIZE
	var container_right = grid_offset.x + (GRID_COLS - 1) * CELL_SIZE
	var container_bottom = grid_offset.y + (GRID_ROWS - 2) * CELL_SIZE

	# Left wall
	data.walls.append({
		"rect": Rect2(container_left - CELL_SIZE, grid_offset.y + CELL_SIZE * 2, CELL_SIZE * 0.3, (GRID_ROWS - 4) * CELL_SIZE)
	})
	# Right wall
	data.walls.append({
		"rect": Rect2(container_right + CELL_SIZE * 0.7, grid_offset.y + CELL_SIZE * 2, CELL_SIZE * 0.3, (GRID_ROWS - 4) * CELL_SIZE)
	})

	# Add some internal walls/platforms based on level
	var num_platforms = 2 + level % 4
	for i in range(num_platforms):
		var px = randf_range(container_left + CELL_SIZE, container_right - CELL_SIZE * 2)
		var py = grid_offset.y + CELL_SIZE * (4 + i * 2 + randf_range(0, 1))
		var pwidth = randf_range(CELL_SIZE, CELL_SIZE * 3)
		data.walls.append({
			"rect": Rect2(px, py, pwidth, CELL_SIZE * 0.4)
		})

	# Create goals at bottom
	var goal_spacing = (container_right - container_left) / float(num_balls + 1)
	for i in range(num_balls):
		var gx = container_left + goal_spacing * (i + 1)
		var gy = container_bottom + CELL_SIZE * 0.5
		data.goals.append({
			"pos": Vector2(gx, gy),
			"color_idx": i % BALL_COLORS.size()
		})

	# Create balls at top
	var ball_spacing = (container_right - container_left) / float(num_balls + 1)
	for i in range(num_balls):
		var bx = container_left + ball_spacing * (i + 1) + randf_range(-20, 20)
		var by = grid_offset.y + CELL_SIZE * 2 + randf_range(0, CELL_SIZE)
		data.balls.append({
			"pos": Vector2(bx, by),
			"color_idx": i % BALL_COLORS.size()
		})

	# Create pins
	var locked_count = 0
	var timed_count = 0
	for i in range(num_pins):
		var horizontal = randi() % 2 == 0
		var px: float
		var py: float

		if horizontal:
			px = randf_range(container_left + PIN_LENGTH / 2, container_right - PIN_LENGTH / 2)
			py = grid_offset.y + CELL_SIZE * (3 + i * 1.5) + randf_range(0, CELL_SIZE * 0.5)
		else:
			px = randf_range(container_left + CELL_SIZE, container_right - CELL_SIZE)
			py = grid_offset.y + CELL_SIZE * (4 + i * 1.2)

		var pin_type = PinType.NORMAL
		if has_locked_pins and locked_count < num_keys and randi() % 4 == 0:
			pin_type = PinType.LOCKED
			locked_count += 1
		elif has_timed_pins and timed_count < 2 and randi() % 5 == 0:
			pin_type = PinType.TIMED
			timed_count += 1

		data.pins.append({
			"pos": Vector2(px, py),
			"horizontal": horizontal,
			"type": pin_type
		})

	# Add hazards
	for i in range(num_hazards):
		var hx = randf_range(container_left + CELL_SIZE, container_right - CELL_SIZE)
		var hy = grid_offset.y + CELL_SIZE * (6 + i * 2) + randf_range(0, CELL_SIZE)
		data.hazards.append({
			"pos": Vector2(hx, hy)
		})

	# Add keys if needed
	for i in range(num_keys):
		var kx = randf_range(container_left + CELL_SIZE, container_right - CELL_SIZE)
		var ky = grid_offset.y + CELL_SIZE * randf_range(5, 10)
		data.keys.append({
			"pos": Vector2(kx, ky)
		})

	return data

func _build_level(data: Dictionary) -> void:
	# Build walls
	for wall_info in data.walls:
		var wall = ColorRect.new()
		wall.size = wall_info.rect.size
		wall.position = wall_info.rect.position
		wall.color = Color(0.25, 0.28, 0.35)
		game_container.add_child(wall)
		walls.append({"node": wall, "rect": wall_info.rect})

	# Build goals
	for goal_info in data.goals:
		var goal = _create_goal(goal_info.pos, goal_info.color_idx)
		game_container.add_child(goal)
		goals.append({"node": goal, "color_idx": goal_info.color_idx})

	# Build hazards
	for hazard_info in data.hazards:
		var hazard = _create_hazard(hazard_info.pos)
		game_container.add_child(hazard)
		hazards.append(hazard)

	# Build keys
	for key_info in data.keys:
		var key = _create_key(key_info.pos)
		game_container.add_child(key)
		walls.append({"node": key, "is_key": true})
		total_keys += 1

	# Build pins
	for pin_info in data.pins:
		var pin = _create_pin(pin_info.pos, pin_info.horizontal, pin_info.type)
		pin_container.add_child(pin)
		pins.append({
			"node": pin,
			"horizontal": pin_info.horizontal,
			"type": pin_info.type,
			"timer": 5.0 if pin_info.type == PinType.TIMED else 0.0
		})

	# Build balls
	for ball_info in data.balls:
		var ball = _create_ball(ball_info.pos, ball_info.color_idx)
		ball_container.add_child(ball)
		balls.append({
			"node": ball,
			"color_idx": ball_info.color_idx,
			"color": BALL_COLORS[ball_info.color_idx],
			"velocity": Vector2.ZERO
		})
		total_balls += 1

func _create_ball(pos: Vector2, color_idx: int) -> Node2D:
	var ball = Node2D.new()
	ball.position = pos

	var circle = ColorRect.new()
	circle.size = Vector2(BALL_RADIUS * 2, BALL_RADIUS * 2)
	circle.position = Vector2(-BALL_RADIUS, -BALL_RADIUS)
	circle.color = BALL_COLORS[color_idx]
	ball.add_child(circle)

	# Shine effect
	var shine = ColorRect.new()
	shine.size = Vector2(BALL_RADIUS * 0.6, BALL_RADIUS * 0.6)
	shine.position = Vector2(-BALL_RADIUS * 0.4, -BALL_RADIUS * 0.6)
	shine.color = Color(1, 1, 1, 0.4)
	ball.add_child(shine)

	return ball

func _create_goal(pos: Vector2, color_idx: int) -> Node2D:
	var goal = Node2D.new()
	goal.position = pos

	# Container/bucket shape
	var back = ColorRect.new()
	back.size = Vector2(60, 50)
	back.position = Vector2(-30, -10)
	back.color = BALL_COLORS[color_idx].darkened(0.3)
	goal.add_child(back)

	# Opening
	var front = ColorRect.new()
	front.size = Vector2(50, 40)
	front.position = Vector2(-25, -5)
	front.color = BALL_COLORS[color_idx].darkened(0.5)
	goal.add_child(front)

	# Arrow indicator
	var arrow = ColorRect.new()
	arrow.size = Vector2(20, 20)
	arrow.position = Vector2(-10, -40)
	arrow.color = BALL_COLORS[color_idx]
	arrow.rotation = PI / 4
	goal.add_child(arrow)

	return goal

func _create_hazard(pos: Vector2) -> Node2D:
	var hazard = Node2D.new()
	hazard.position = pos

	# Spike/bomb visual
	var body = ColorRect.new()
	body.size = Vector2(40, 40)
	body.position = Vector2(-20, -20)
	body.color = Color(0.8, 0.2, 0.2)
	hazard.add_child(body)

	# X mark
	var x1 = ColorRect.new()
	x1.size = Vector2(30, 6)
	x1.position = Vector2(-15, -3)
	x1.rotation = PI / 4
	x1.color = Color(0.2, 0.05, 0.05)
	hazard.add_child(x1)

	var x2 = ColorRect.new()
	x2.size = Vector2(30, 6)
	x2.position = Vector2(-15, -3)
	x2.rotation = -PI / 4
	x2.color = Color(0.2, 0.05, 0.05)
	hazard.add_child(x2)

	return hazard

func _create_key(pos: Vector2) -> Node2D:
	var key = Node2D.new()
	key.position = pos

	# Key shape
	var head = ColorRect.new()
	head.size = Vector2(25, 25)
	head.position = Vector2(-12.5, -20)
	head.color = Color(1, 0.84, 0)
	key.add_child(head)

	var shaft = ColorRect.new()
	shaft.size = Vector2(8, 25)
	shaft.position = Vector2(-4, 0)
	shaft.color = Color(1, 0.84, 0)
	key.add_child(shaft)

	return key

func _create_pin(pos: Vector2, horizontal: bool, type: PinType) -> Node2D:
	var pin = Node2D.new()
	pin.position = pos

	# Pin body
	var body = ColorRect.new()
	if horizontal:
		body.size = Vector2(PIN_LENGTH, PIN_WIDTH)
		body.position = Vector2(-PIN_LENGTH / 2, -PIN_WIDTH / 2)
	else:
		body.size = Vector2(PIN_WIDTH, PIN_LENGTH)
		body.position = Vector2(-PIN_WIDTH / 2, -PIN_LENGTH / 2)

	# Color based on type
	match type:
		PinType.NORMAL:
			body.color = Color(0.6, 0.65, 0.7)  # Metallic gray
		PinType.LOCKED:
			body.color = Color(0.85, 0.7, 0.2)  # Gold
		PinType.TIMED:
			body.color = Color(0.9, 0.3, 0.3)  # Red

	pin.add_child(body)

	# Metallic shine
	var shine = ColorRect.new()
	if horizontal:
		shine.size = Vector2(PIN_LENGTH * 0.8, PIN_WIDTH * 0.3)
		shine.position = Vector2(-PIN_LENGTH * 0.4, -PIN_WIDTH * 0.35)
	else:
		shine.size = Vector2(PIN_WIDTH * 0.3, PIN_LENGTH * 0.8)
		shine.position = Vector2(-PIN_WIDTH * 0.35, -PIN_LENGTH * 0.4)
	shine.color = Color(1, 1, 1, 0.3)
	pin.add_child(shine)

	# Handle/knob
	var handle = ColorRect.new()
	handle.size = Vector2(20, 20)
	if horizontal:
		handle.position = Vector2(PIN_LENGTH / 2 - 5, -10)
	else:
		handle.position = Vector2(-10, PIN_LENGTH / 2 - 5)
	handle.color = body.color.lightened(0.2)
	pin.add_child(handle)

	# Lock icon for locked pins
	if type == PinType.LOCKED:
		var lock = ColorRect.new()
		lock.size = Vector2(12, 12)
		lock.position = Vector2(-6, -6)
		lock.color = Color(0.3, 0.25, 0.1)
		pin.add_child(lock)

	# Timer indicator for timed pins
	if type == PinType.TIMED:
		var timer_bg = ColorRect.new()
		timer_bg.size = Vector2(16, 16)
		timer_bg.position = Vector2(-8, -8)
		timer_bg.color = Color(0.2, 0.1, 0.1)
		pin.add_child(timer_bg)

	return pin
