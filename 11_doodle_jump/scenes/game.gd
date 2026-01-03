extends Node2D
## Doodle Jump: Jump on platforms to climb higher

const GRAVITY = 1200.0
const JUMP_FORCE = -700.0
const SUPER_JUMP_FORCE = -1100.0
const SPAWN_INTERVAL = 150.0

@onready var player: Node2D = $Player
@onready var platforms_container: Node2D = $PlatformsContainer
@onready var camera: Camera2D = $Camera2D

var velocity: Vector2 = Vector2.ZERO
var game_active: bool = false
var game_started: bool = false
var highest_y: float = 0.0
var next_platform_y: float = 0.0
var screen_width: float
var touch_x: float = 0.0

enum PlatformType { NORMAL, MOVING, BREAKING, SPRING }
var platform_colors = {PlatformType.NORMAL: Color("#4caf50"), PlatformType.MOVING: Color("#2196f3"), PlatformType.BREAKING: Color("#ff9800"), PlatformType.SPRING: Color("#e91e63")}

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	GameManager.start_game("doodle_jump")
	player.position = Vector2(screen_width / 2, 900)
	_spawn_starting_platforms()

func _spawn_starting_platforms() -> void:
	_create_platform(Vector2(screen_width / 2 - 50, 1000), PlatformType.NORMAL)
	for i in range(10):
		_create_platform(Vector2(randf_range(50, screen_width - 50) - 50, 900 - i * SPAWN_INTERVAL), _get_random_type(900 - i * SPAWN_INTERVAL))
	next_platform_y = 900 - 10 * SPAWN_INTERVAL

func _get_random_type(y: float) -> int:
	var rand = randf()
	if rand < 0.6:
		return PlatformType.NORMAL
	elif rand < 0.75:
		return PlatformType.MOVING
	elif rand < 0.9:
		return PlatformType.BREAKING
	return PlatformType.SPRING

func _create_platform(pos: Vector2, type: int) -> void:
	var platform = ColorRect.new()
	platform.size = Vector2(100, 20)
	platform.position = pos
	platform.color = platform_colors[type]
	platform.set_meta("type", type)
	platform.set_meta("original_x", pos.x)
	platforms_container.add_child(platform)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_x = event.position.x
		if event.pressed and not game_started:
			game_started = true
			game_active = true
			velocity.y = JUMP_FORCE
	elif event is InputEventMouseMotion:
		touch_x = event.position.x

func _process(delta: float) -> void:
	if not game_active:
		return

	player.position.x = lerp(player.position.x, touch_x, 10 * delta)
	if player.position.x < -20:
		player.position.x = screen_width + 20
	elif player.position.x > screen_width + 20:
		player.position.x = -20

	velocity.y += GRAVITY * delta
	player.position.y += velocity.y * delta

	if velocity.y > 0:
		_check_platform_collisions()

	if player.position.y < highest_y:
		highest_y = player.position.y
		GameManager.current_score = int(-highest_y / 50)
		GameManager.emit_signal("score_changed", GameManager.current_score)

	camera.position.y = lerp(camera.position.y, min(player.position.y - 300, camera.position.y), 5 * delta)

	while next_platform_y > highest_y - 800:
		_create_platform(Vector2(randf_range(50, screen_width - 50) - 50, next_platform_y), _get_random_type(next_platform_y))
		next_platform_y -= SPAWN_INTERVAL

	for platform in platforms_container.get_children():
		if platform.get_meta("type") == PlatformType.MOVING:
			platform.position.x = platform.get_meta("original_x") + sin(Time.get_ticks_msec() * 0.002) * 100
		if platform.position.y > camera.position.y + 800:
			platform.queue_free()

	if player.position.y > camera.position.y + 700:
		_game_over()

func _check_platform_collisions() -> void:
	for platform in platforms_container.get_children():
		if player.position.y + 25 >= platform.position.y and player.position.y + 25 <= platform.position.y + 30:
			if player.position.x > platform.position.x - 20 and player.position.x < platform.position.x + 120:
				_land_on_platform(platform)
				break

func _land_on_platform(platform: ColorRect) -> void:
	var type = platform.get_meta("type")
	velocity.y = SUPER_JUMP_FORCE if type == PlatformType.SPRING else JUMP_FORCE
	AudioManager.play_sfx("tap")
	if type == PlatformType.BREAKING:
		platform.queue_free()

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	AudioManager.play_sfx("hit")
	GameManager.end_game()
