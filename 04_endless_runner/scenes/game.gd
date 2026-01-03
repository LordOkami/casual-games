extends Node2D
## Endless Runner: Run and jump over obstacles

const GRAVITY = 2500.0
const JUMP_FORCE = -900.0
const INITIAL_SPEED = 400.0
const MAX_SPEED = 1000.0
const GROUND_Y = 1000.0

@onready var player: Node2D = $Player
@onready var obstacles_container: Node2D = $ObstaclesContainer

var velocity_y: float = 0.0
var game_speed: float = INITIAL_SPEED
var game_active: bool = false
var game_started: bool = false
var is_grounded: bool = true
var can_double_jump: bool = true
var next_obstacle_x: float = 800.0
var distance: float = 0.0
var screen_width: float

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	GameManager.start_game("endless_runner")
	player.position = Vector2(150, GROUND_Y - 50)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if not game_started:
			game_started = true
			game_active = true
		if game_active:
			_try_jump()

func _try_jump() -> void:
	if is_grounded:
		velocity_y = JUMP_FORCE
		is_grounded = false
		can_double_jump = true
		AudioManager.play_sfx("tap")
	elif can_double_jump:
		velocity_y = JUMP_FORCE * 0.85
		can_double_jump = false
		AudioManager.play_sfx("tap")

func _process(delta: float) -> void:
	if not game_active:
		return

	if not is_grounded:
		velocity_y += GRAVITY * delta
		player.position.y += velocity_y * delta
		if player.position.y >= GROUND_Y - 50:
			player.position.y = GROUND_Y - 50
			is_grounded = true
			velocity_y = 0

	game_speed = min(game_speed + 10 * delta, MAX_SPEED)

	for obstacle in obstacles_container.get_children():
		obstacle.position.x -= game_speed * delta
		if obstacle.position.x < -100:
			obstacle.queue_free()

	if next_obstacle_x < screen_width:
		_spawn_obstacle()
		next_obstacle_x += randf_range(400, 800)
	next_obstacle_x -= game_speed * delta

	distance += game_speed * delta * 0.01
	if int(distance) > GameManager.current_score:
		GameManager.current_score = int(distance)
		GameManager.emit_signal("score_changed", GameManager.current_score)

	_check_collisions()

func _spawn_obstacle() -> void:
	var obstacle = ColorRect.new()
	var height = randf_range(40, 100)
	obstacle.size = Vector2(40, height)
	obstacle.position = Vector2(screen_width + 100, GROUND_Y - height)
	obstacle.color = Color("#e63946")
	obstacles_container.add_child(obstacle)

func _check_collisions() -> void:
	var player_rect = Rect2(player.position.x - 20, player.position.y - 50, 40, 50)
	for obstacle in obstacles_container.get_children():
		var obs_rect = Rect2(obstacle.position, obstacle.size)
		if player_rect.intersects(obs_rect):
			_game_over()
			return

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	AudioManager.play_sfx("hit")
	await get_tree().create_timer(0.5).timeout
	GameManager.end_game()
