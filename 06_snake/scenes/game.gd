extends Node2D
## Snake: Classic snake game - eat and grow

const CELL_SIZE = 40
const GRID_WIDTH = 18
const GRID_HEIGHT = 25
const INITIAL_SPEED = 0.15
const MIN_SPEED = 0.06
const COMBO_WINDOW = 2.0  # Time in seconds to maintain/increase combo
const COMBO_RESET_TIME = 3.0  # Time in seconds before combo resets
const MAX_COMBO = 5  # Maximum combo multiplier

@onready var snake_container: Node2D = $SnakeContainer
@onready var food: ColorRect = $Food
@onready var game_ui: GameUI = $GameUI

var snake: Array[Vector2i] = []
var direction: Vector2i = Vector2i.UP
var next_direction: Vector2i = Vector2i.UP
var game_active: bool = false
var game_started: bool = false
var move_timer: float = 0.0
var current_speed: float = INITIAL_SPEED
var food_position: Vector2i
var swipe_start: Vector2 = Vector2.ZERO

# Combo system variables
var combo_count: int = 0
var combo_multiplier: int = 1
var time_since_last_food: float = 0.0
var combo_active: bool = false

func _ready() -> void:
	GameManager.start_game("snake")
	_init_snake()
	_spawn_food()

func _init_snake() -> void:
	snake.clear()
	var start_x = GRID_WIDTH / 2
	var start_y = GRID_HEIGHT / 2
	snake.append(Vector2i(start_x, start_y))
	snake.append(Vector2i(start_x, start_y + 1))
	snake.append(Vector2i(start_x, start_y + 2))
	_update_snake_visuals()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
		else:
			_handle_swipe(event.position - swipe_start)
	elif event is InputEventMouseButton:
		if event.pressed:
			swipe_start = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_swipe(event.position - swipe_start)

func _handle_swipe(swipe_dir: Vector2) -> void:
	if swipe_dir.length() < 30:
		return
	if not game_started:
		game_started = true
		game_active = true
	if abs(swipe_dir.x) > abs(swipe_dir.y):
		if swipe_dir.x > 0 and direction != Vector2i.LEFT:
			next_direction = Vector2i.RIGHT
		elif swipe_dir.x < 0 and direction != Vector2i.RIGHT:
			next_direction = Vector2i.LEFT
	else:
		if swipe_dir.y > 0 and direction != Vector2i.UP:
			next_direction = Vector2i.DOWN
		elif swipe_dir.y < 0 and direction != Vector2i.DOWN:
			next_direction = Vector2i.UP

func _process(delta: float) -> void:
	if not game_active:
		return
	move_timer += delta
	if move_timer >= current_speed:
		move_timer = 0.0
		_move_snake()

	# Track time since last food for combo reset
	if combo_active:
		time_since_last_food += delta
		if time_since_last_food >= COMBO_RESET_TIME:
			_reset_combo()

func _move_snake() -> void:
	direction = next_direction
	var new_head = snake[0] + direction

	if new_head.x < 0 or new_head.x >= GRID_WIDTH or new_head.y < 0 or new_head.y >= GRID_HEIGHT:
		_game_over()
		return

	for i in range(snake.size()):
		if new_head == snake[i]:
			_game_over()
			return

	var ate_food = new_head == food_position
	snake.insert(0, new_head)
	if not ate_food:
		snake.pop_back()
	else:
		_on_food_eaten()
		current_speed = max(current_speed - 0.005, MIN_SPEED)
		_spawn_food()
	_update_snake_visuals()

func _spawn_food() -> void:
	var valid: Array[Vector2i] = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if pos not in snake:
				valid.append(pos)
	if valid.is_empty():
		_game_over()
		return
	food_position = valid[randi() % valid.size()]
	food.position = Vector2(food_position.x * CELL_SIZE + 2, food_position.y * CELL_SIZE + 2)
	food.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)

func _update_snake_visuals() -> void:
	for child in snake_container.get_children():
		child.queue_free()
	for i in range(snake.size()):
		var segment = ColorRect.new()
		segment.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
		segment.position = Vector2(snake[i].x * CELL_SIZE + 2, snake[i].y * CELL_SIZE + 2)
		segment.color = Color("#2d6a4f") if i == 0 else Color("#40916c").lerp(Color("#95d5b2"), float(i) / snake.size())
		snake_container.add_child(segment)

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	AudioManager.play_sfx("hit")
	GameManager.end_game()

func _on_food_eaten() -> void:
	# Check if food was eaten within combo window
	if combo_active and time_since_last_food <= COMBO_WINDOW:
		# Increase combo
		combo_count += 1
		combo_multiplier = mini(combo_count + 1, MAX_COMBO)
	else:
		# Start new combo
		combo_count = 0
		combo_multiplier = 1

	# Add score with multiplier
	GameManager.add_score(combo_multiplier)

	# Activate combo and reset timer
	combo_active = true
	time_since_last_food = 0.0

	# Update UI with combo status
	game_ui.update_combo(combo_multiplier)

func _reset_combo() -> void:
	combo_count = 0
	combo_multiplier = 1
	combo_active = false
	time_since_last_food = 0.0
	game_ui.update_combo(0)  # 0 indicates no active combo
