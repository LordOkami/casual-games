extends Node2D
## Flappy Clone: Tap to fly through pipes
## Simple one-touch gameplay with increasing difficulty

const GRAVITY = 1200.0
const FLAP_FORCE = -450.0
const PIPE_SPEED = 200.0
const PIPE_SPAWN_TIME = 1.8
const GAP_SIZE = 280.0
const PIPE_WIDTH = 80.0

@onready var bird: Area2D = $Bird
@onready var pipe_container: Node2D = $PipeContainer
@onready var game_ui = $GameUI

var velocity: float = 0.0
var game_started: bool = false
var game_active: bool = false
var pipe_timer: float = 0.0
var screen_width: float
var screen_height: float

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	GameManager.start_game("flappy_clone")
	bird.position = Vector2(screen_width * 0.3, screen_height * 0.4)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_tap()
	elif event is InputEventMouseButton and event.pressed:
		_handle_tap()

func _handle_tap() -> void:
	if not game_active and not game_started:
		game_started = true
		game_active = true
	if game_active:
		velocity = FLAP_FORCE
		AudioManager.play_sfx("tap")
		var tween = create_tween()
		tween.tween_property(bird, "rotation_degrees", -25, 0.1)

func _process(delta: float) -> void:
	if not game_active:
		bird.position.y += sin(Time.get_ticks_msec() * 0.005) * 0.5
		return

	velocity += GRAVITY * delta
	bird.position.y += velocity * delta
	bird.rotation_degrees = lerp(bird.rotation_degrees, clamp(velocity * 0.1, -30, 90), 0.1)

	pipe_timer += delta
	if pipe_timer >= PIPE_SPAWN_TIME:
		pipe_timer = 0.0
		_spawn_pipe()

	for pipe in pipe_container.get_children():
		pipe.position.x -= PIPE_SPEED * delta
		if pipe.position.x < -100:
			pipe.queue_free()

	if bird.position.y < -50 or bird.position.y > screen_height - 50:
		_game_over()

func _spawn_pipe() -> void:
	var pipe = Node2D.new()
	var gap_y = randf_range(screen_height * 0.25, screen_height * 0.65)
	pipe.position = Vector2(screen_width + 100, gap_y)

	# Top pipe
	var top = ColorRect.new()
	top.size = Vector2(PIPE_WIDTH, screen_height)
	top.position = Vector2(-PIPE_WIDTH/2, -GAP_SIZE/2 - screen_height)
	top.color = Color("#2d6a4f")
	pipe.add_child(top)

	# Bottom pipe
	var bottom = ColorRect.new()
	bottom.size = Vector2(PIPE_WIDTH, screen_height)
	bottom.position = Vector2(-PIPE_WIDTH/2, GAP_SIZE/2)
	bottom.color = Color("#2d6a4f")
	pipe.add_child(bottom)

	# Score trigger
	var score_area = Area2D.new()
	var score_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(10, GAP_SIZE)
	score_shape.shape = shape
	score_area.add_child(score_shape)
	score_area.area_entered.connect(_on_score_area_entered)
	pipe.add_child(score_area)

	# Collision areas
	var top_col = Area2D.new()
	var top_shape = CollisionShape2D.new()
	var ts = RectangleShape2D.new()
	ts.size = Vector2(PIPE_WIDTH, screen_height)
	top_shape.shape = ts
	top_shape.position = Vector2(0, -GAP_SIZE/2 - screen_height/2)
	top_col.add_child(top_shape)
	top_col.area_entered.connect(_on_pipe_hit)
	pipe.add_child(top_col)

	var bottom_col = Area2D.new()
	var bottom_shape = CollisionShape2D.new()
	var bs = RectangleShape2D.new()
	bs.size = Vector2(PIPE_WIDTH, screen_height)
	bottom_shape.shape = bs
	bottom_shape.position = Vector2(0, GAP_SIZE/2 + screen_height/2)
	bottom_col.add_child(bottom_shape)
	bottom_col.area_entered.connect(_on_pipe_hit)
	pipe.add_child(bottom_col)

	pipe_container.add_child(pipe)

func _on_score_area_entered(area: Area2D) -> void:
	if area.get_parent() == bird:
		GameManager.add_score()

func _on_pipe_hit(area: Area2D) -> void:
	if area.get_parent() == bird:
		_game_over()

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	AudioManager.play_sfx("hit")
	await get_tree().create_timer(0.3).timeout
	GameManager.end_game()
