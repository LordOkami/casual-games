extends Node2D
## Pong: Classic paddle game vs AI

const PADDLE_SPEED = 600.0
const BALL_SPEED_INITIAL = 400.0
const MAX_BALL_SPEED = 800.0
const AI_SPEED = 450.0
const PADDLE_WIDTH = 20
const PADDLE_HEIGHT = 120

@onready var player_paddle: ColorRect = $PlayerPaddle
@onready var ai_paddle: ColorRect = $AIPaddle
@onready var ball: ColorRect = $Ball
@onready var player_score_label: Label = $PlayerScore
@onready var ai_score_label: Label = $AIScore

var ball_velocity: Vector2 = Vector2.ZERO
var ball_speed: float = BALL_SPEED_INITIAL
var player_score: int = 0
var ai_score: int = 0
var game_active: bool = false
var game_started: bool = false
var screen_width: float
var screen_height: float
var touch_y: float = 0.0

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	GameManager.start_game("pong")
	_reset_ball()

func _reset_ball() -> void:
	ball.position = Vector2(screen_width / 2 - 15, screen_height / 2 - 15)
	ball_speed = BALL_SPEED_INITIAL
	var angle = randf_range(-PI/4, PI/4)
	var direction = 1 if randf() > 0.5 else -1
	ball_velocity = Vector2(cos(angle) * direction, sin(angle)).normalized() * ball_speed

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseMotion or event is InputEventMouseButton:
		var pos_y = 0.0
		if event is InputEventScreenTouch:
			pos_y = event.position.y
			if event.pressed and not game_started:
				game_started = true
				game_active = true
		elif event is InputEventMouseMotion:
			pos_y = event.position.y
		elif event is InputEventMouseButton and event.pressed:
			if not game_started:
				game_started = true
				game_active = true
			pos_y = event.position.y
		touch_y = clamp(pos_y, PADDLE_HEIGHT / 2, screen_height - PADDLE_HEIGHT / 2)

func _process(delta: float) -> void:
	if not game_active:
		return

	player_paddle.position.y = lerp(player_paddle.position.y, touch_y - PADDLE_HEIGHT / 2, 15 * delta)
	player_paddle.position.y = clamp(player_paddle.position.y, 0, screen_height - PADDLE_HEIGHT)

	var ai_target = ball.position.y - PADDLE_HEIGHT / 2
	ai_paddle.position.y += sign(ai_target - ai_paddle.position.y) * min(abs(ai_target - ai_paddle.position.y), AI_SPEED * delta)
	ai_paddle.position.y = clamp(ai_paddle.position.y, 0, screen_height - PADDLE_HEIGHT)

	ball.position += ball_velocity * delta

	if ball.position.y <= 0 or ball.position.y + 30 >= screen_height:
		ball_velocity.y = -ball_velocity.y
		AudioManager.play_sfx("tap")

	var ball_rect = Rect2(ball.position, Vector2(30, 30))
	var player_rect = Rect2(player_paddle.position, Vector2(PADDLE_WIDTH, PADDLE_HEIGHT))
	var ai_rect = Rect2(ai_paddle.position, Vector2(PADDLE_WIDTH, PADDLE_HEIGHT))

	if ball_rect.intersects(player_rect) and ball_velocity.x < 0:
		_paddle_hit(player_paddle)
	elif ball_rect.intersects(ai_rect) and ball_velocity.x > 0:
		_paddle_hit(ai_paddle)

	if ball.position.x < -30:
		_ai_scores()
	elif ball.position.x > screen_width:
		_player_scores()

func _paddle_hit(paddle: ColorRect) -> void:
	var hit_pos = (ball.position.y + 15 - paddle.position.y) / PADDLE_HEIGHT
	var angle = lerp(-PI/3, PI/3, hit_pos)
	ball_speed = min(ball_speed + 20, MAX_BALL_SPEED)
	var direction = 1 if paddle == player_paddle else -1
	ball_velocity = Vector2(cos(angle) * direction, sin(angle)).normalized() * ball_speed
	AudioManager.play_sfx("tap")

func _player_scores() -> void:
	player_score += 1
	GameManager.add_score()
	player_score_label.text = str(player_score)
	_reset_ball()

func _ai_scores() -> void:
	ai_score += 1
	ai_score_label.text = str(ai_score)
	AudioManager.play_sfx("hit")
	if ai_score >= 5:
		game_active = false
		GameManager.end_game()
	else:
		_reset_ball()
