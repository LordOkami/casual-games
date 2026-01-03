extends Node2D
## Ball Bounce: Timing-based platform bouncing

const GRAVITY = 1500.0
const BOUNCE_FORCE = -800.0
const PERFECT_BOUNCE_FORCE = -950.0
const PERFECT_THRESHOLD = 50.0

@onready var ball: ColorRect = $Ball
@onready var platforms_container: Node2D = $PlatformsContainer
@onready var camera: Camera2D = $Camera2D

var velocity: float = 0.0
var game_active: bool = false
var game_started: bool = false
var spawn_timer: float = 0.0
var screen_width: float
var highest_y: float = 0.0
var combo: int = 0

var platform_colors: Array[Color] = [Color("#ff6b6b"), Color("#4ecdc4"), Color("#45b7d1"), Color("#96ceb4"), Color("#ffeaa7")]

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	GameManager.start_game("ball_bounce")
	ball.position = Vector2(screen_width / 2 - 20, 800)
	_spawn_starting_platforms()

func _spawn_starting_platforms() -> void:
	_create_platform(Vector2(screen_width / 2, 1000), 400)
	for i in range(5):
		_create_platform(Vector2(randf_range(100, screen_width - 100), 900 - i * 150), randf_range(120, 200))

func _create_platform(pos: Vector2, width: float) -> void:
	var platform = ColorRect.new()
	platform.size = Vector2(width, 25)
	platform.position = pos - Vector2(width / 2, 0)
	platform.color = platform_colors[randi() % platform_colors.size()]
	platforms_container.add_child(platform)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if not game_started:
			game_started = true
			game_active = true
		if game_active:
			_try_bounce()

func _try_bounce() -> void:
	var ball_bottom = ball.position.y + 40
	for platform in platforms_container.get_children():
		var plat_top = platform.position.y
		if plat_top >= ball_bottom and plat_top < ball_bottom + 200:
			if ball.position.x + 20 > platform.position.x and ball.position.x + 20 < platform.position.x + platform.size.x:
				if velocity > 0:
					var is_perfect = plat_top - ball_bottom < PERFECT_THRESHOLD
					velocity = PERFECT_BOUNCE_FORCE if is_perfect else BOUNCE_FORCE
					if is_perfect:
						combo += 1
						GameManager.add_score(10 * combo)
					else:
						combo = 0
						GameManager.add_score(1)
					AudioManager.play_sfx("tap")
					return

func _process(delta: float) -> void:
	if not game_active:
		ball.position.y += sin(Time.get_ticks_msec() * 0.003) * 0.3
		return

	velocity += GRAVITY * delta
	ball.position.y += velocity * delta

	if ball.position.y < highest_y:
		highest_y = ball.position.y

	camera.position.y = lerp(camera.position.y, min(ball.position.y - 300, camera.position.y), 5 * delta)

	spawn_timer += delta
	if spawn_timer >= 1.5:
		spawn_timer = 0
		_create_platform(Vector2(randf_range(80, screen_width - 80), highest_y - 200), randf_range(100, 180))

	for platform in platforms_container.get_children():
		if platform.position.y > camera.position.y + 800:
			platform.queue_free()

	if ball.position.y > camera.position.y + 700:
		_game_over()

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	AudioManager.play_sfx("hit")
	GameManager.end_game()
