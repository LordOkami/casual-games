extends Node2D
## Breakout: Destroy all blocks with the ball

const PADDLE_WIDTH = 120
const PADDLE_HEIGHT = 20
const BALL_RADIUS = 12
const BALL_SPEED = 500.0
const BRICK_ROWS = 8
const BRICK_COLS = 9

@onready var paddle: ColorRect = $Paddle
@onready var ball: ColorRect = $Ball
@onready var bricks_container: Node2D = $BricksContainer

var ball_velocity: Vector2 = Vector2.ZERO
var game_active: bool = false
var game_started: bool = false
var screen_width: float
var screen_height: float
var bricks_remaining: int = 0
var paddle_target_x: float = 0.0

var brick_colors: Array[Color] = [Color("#e63946"), Color("#f4a261"), Color("#e9c46a"), Color("#2a9d8f"), Color("#264653"), Color("#9c27b0"), Color("#00bcd4"), Color("#4caf50")]

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	GameManager.start_game("breakout")
	_init_game()

func _init_game() -> void:
	paddle.size = Vector2(PADDLE_WIDTH, PADDLE_HEIGHT)
	paddle.position = Vector2((screen_width - PADDLE_WIDTH) / 2, screen_height - 150)
	ball.size = Vector2(BALL_RADIUS * 2, BALL_RADIUS * 2)
	ball.position = Vector2(screen_width / 2 - BALL_RADIUS, paddle.position.y - BALL_RADIUS * 2 - 10)
	_create_bricks()
	paddle_target_x = paddle.position.x

func _create_bricks() -> void:
	bricks_remaining = 0
	var start_x = (screen_width - (BRICK_COLS * 80)) / 2
	for row in range(BRICK_ROWS):
		for col in range(BRICK_COLS):
			var brick = ColorRect.new()
			brick.size = Vector2(75, 30)
			brick.position = Vector2(start_x + col * 80, 200 + row * 35)
			brick.color = brick_colors[row % brick_colors.size()]
			brick.set_meta("points", (BRICK_ROWS - row) * 10)
			bricks_container.add_child(brick)
			bricks_remaining += 1

func _input(event: InputEvent) -> void:
	var pos_x = 0.0
	if event is InputEventScreenTouch:
		pos_x = event.position.x
		if event.pressed and not game_started:
			_start_game()
	elif event is InputEventMouseMotion:
		pos_x = event.position.x
	elif event is InputEventMouseButton and event.pressed:
		pos_x = event.position.x
		if not game_started:
			_start_game()
	if pos_x > 0:
		paddle_target_x = clamp(pos_x - PADDLE_WIDTH / 2, 0, screen_width - PADDLE_WIDTH)

func _start_game() -> void:
	game_started = true
	game_active = true
	ball_velocity = Vector2(randf_range(-1, 1), -1).normalized() * BALL_SPEED

func _process(delta: float) -> void:
	paddle.position.x = lerp(paddle.position.x, paddle_target_x, 15 * delta)

	if not game_active:
		ball.position.x = paddle.position.x + PADDLE_WIDTH / 2 - BALL_RADIUS
		return

	ball.position += ball_velocity * delta

	if ball.position.x <= 0 or ball.position.x + BALL_RADIUS * 2 >= screen_width:
		ball_velocity.x = -ball_velocity.x
		AudioManager.play_sfx("tap")
	if ball.position.y <= 0:
		ball_velocity.y = abs(ball_velocity.y)
		AudioManager.play_sfx("tap")
	if ball.position.y > screen_height:
		_game_over()
		return

	var ball_rect = Rect2(ball.position, ball.size)
	var paddle_rect = Rect2(paddle.position, paddle.size)
	if ball_rect.intersects(paddle_rect) and ball_velocity.y > 0:
		var hit_pos = (ball.position.x + BALL_RADIUS - paddle.position.x) / PADDLE_WIDTH
		var angle = lerp(-PI/3, PI/3, hit_pos)
		ball_velocity = Vector2(sin(angle), -cos(angle)) * BALL_SPEED
		AudioManager.play_sfx("tap")

	for brick in bricks_container.get_children():
		var brick_rect = Rect2(brick.position, brick.size)
		if ball_rect.intersects(brick_rect):
			ball_velocity.y = -ball_velocity.y
			GameManager.add_score(brick.get_meta("points", 10))
			brick.queue_free()
			bricks_remaining -= 1
			if bricks_remaining <= 0:
				_init_game()
				game_started = false
			break

func _game_over() -> void:
	game_active = false
	AudioManager.play_sfx("hit")
	GameManager.end_game()
