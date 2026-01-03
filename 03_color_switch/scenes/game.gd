extends Node2D
## Color Switch: Pass through obstacles matching your color

const GRAVITY = 1800.0
const JUMP_FORCE = -650.0
const SPAWN_DISTANCE = 400.0

@onready var ball: Area2D = $Ball
@onready var ball_sprite: ColorRect = $Ball/Sprite
@onready var obstacles_container: Node2D = $ObstaclesContainer
@onready var camera: Camera2D = $Camera2D

var velocity: float = 0.0
var game_active: bool = false
var game_started: bool = false
var screen_width: float
var next_spawn_y: float

var colors: Array[Color] = [Color("#f94144"), Color("#f8961e"), Color("#90be6d"), Color("#577590")]
var current_color_index: int = 0

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	GameManager.start_game("color_switch")
	_set_ball_color(0)
	ball.position = Vector2(screen_width / 2, 900)
	next_spawn_y = 600.0
	_spawn_initial_obstacles()

func _spawn_initial_obstacles() -> void:
	for i in range(3):
		_spawn_obstacle(next_spawn_y)
		next_spawn_y -= SPAWN_DISTANCE

func _set_ball_color(index: int) -> void:
	current_color_index = index
	ball_sprite.color = colors[index]

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if not game_started:
			game_started = true
			game_active = true
		if game_active:
			velocity = JUMP_FORCE
			AudioManager.play_sfx("tap")

func _process(delta: float) -> void:
	if not game_active:
		return

	velocity += GRAVITY * delta
	ball.position.y += velocity * delta

	if ball.position.y < camera.position.y - 100:
		camera.position.y = ball.position.y + 100

	while next_spawn_y > ball.position.y - 800:
		_spawn_obstacle(next_spawn_y)
		next_spawn_y -= SPAWN_DISTANCE

	for obstacle in obstacles_container.get_children():
		if obstacle.position.y > camera.position.y + 800:
			obstacle.queue_free()

	if ball.position.y > camera.position.y + 600:
		_game_over()

func _spawn_obstacle(y_pos: float) -> void:
	var container = Node2D.new()
	container.position = Vector2(screen_width / 2, y_pos)
	obstacles_container.add_child(container)

	var radius = 120.0
	for i in range(4):
		var segment = Area2D.new()
		var arc = ColorRect.new()
		arc.size = Vector2(30, radius * 0.8)
		arc.color = colors[i]
		arc.position = Vector2(-15, -radius)
		segment.add_child(arc)
		segment.rotation = (TAU / 4) * i
		segment.area_entered.connect(_on_obstacle_hit.bind(colors[i]))
		container.add_child(segment)

	var tween = create_tween().set_loops()
	tween.tween_property(container, "rotation", TAU, 3.0)

	var switcher = _create_color_switcher(y_pos + 150)
	obstacles_container.add_child(switcher)

func _create_color_switcher(y_pos: float) -> Area2D:
	var switcher = Area2D.new()
	switcher.position = Vector2(screen_width / 2, y_pos)
	var star = ColorRect.new()
	star.size = Vector2(40, 40)
	star.position = Vector2(-20, -20)
	star.color = Color.WHITE
	switcher.add_child(star)
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	switcher.add_child(collision)
	switcher.area_entered.connect(_on_switcher_collected.bind(switcher))
	return switcher

func _on_obstacle_hit(area: Area2D, obstacle_color: Color) -> void:
	if area.get_parent() != ball:
		return
	if obstacle_color != colors[current_color_index]:
		_game_over()

func _on_switcher_collected(area: Area2D, switcher: Area2D) -> void:
	if area.get_parent() != ball:
		return
	GameManager.add_score()
	_set_ball_color(randi() % colors.size())
	switcher.queue_free()

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	AudioManager.play_sfx("hit")
	GameManager.end_game()
