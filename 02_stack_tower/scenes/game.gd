extends Node2D
## Stack Tower: Stack blocks perfectly to build the tallest tower

const BLOCK_HEIGHT = 60.0
const INITIAL_WIDTH = 300.0
const MOVE_SPEED_INITIAL = 300.0
const SPEED_INCREMENT = 15.0
const PERFECT_THRESHOLD = 10.0

@onready var blocks_container: Node2D = $BlocksContainer
@onready var current_block: ColorRect = $CurrentBlock
@onready var camera: Camera2D = $Camera2D

var current_width: float = INITIAL_WIDTH
var current_x: float = 0.0
var moving_right: bool = true
var move_speed: float = MOVE_SPEED_INITIAL
var stack_height: int = 0
var game_active: bool = false
var game_started: bool = false
var base_y: float = 1100.0
var screen_width: float

var colors: Array[Color] = [
	Color("#e63946"), Color("#f4a261"), Color("#2a9d8f"),
	Color("#264653"), Color("#e9c46a"), Color("#9c27b0")
]

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	GameManager.start_game("stack_tower")
	_setup_base()
	_spawn_new_block()

func _setup_base() -> void:
	var base = ColorRect.new()
	base.size = Vector2(INITIAL_WIDTH, BLOCK_HEIGHT)
	base.position = Vector2((screen_width - INITIAL_WIDTH) / 2, base_y)
	base.color = colors[0]
	blocks_container.add_child(base)
	current_x = (screen_width - INITIAL_WIDTH) / 2

func _spawn_new_block() -> void:
	current_block.size = Vector2(current_width, BLOCK_HEIGHT)
	current_block.position.y = base_y - (stack_height + 1) * BLOCK_HEIGHT
	current_block.position.x = -current_width
	current_block.color = colors[(stack_height + 1) % colors.size()]
	moving_right = true
	game_active = true

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if game_active:
			game_started = true
			_place_block()

func _process(delta: float) -> void:
	if not game_active or not game_started:
		return

	if moving_right:
		current_block.position.x += move_speed * delta
		if current_block.position.x + current_width > screen_width + 50:
			moving_right = false
	else:
		current_block.position.x -= move_speed * delta
		if current_block.position.x < -50:
			moving_right = true

func _place_block() -> void:
	game_active = false
	AudioManager.play_sfx("tap")

	var overlap_left = max(current_block.position.x, current_x)
	var overlap_right = min(current_block.position.x + current_width, current_x + current_width)
	var overlap_width = overlap_right - overlap_left

	if overlap_width <= 0:
		_game_over()
		return

	if abs(current_block.position.x - current_x) < PERFECT_THRESHOLD:
		overlap_width = current_width
		overlap_left = current_x
		_show_perfect()

	var stacked = ColorRect.new()
	stacked.size = Vector2(overlap_width, BLOCK_HEIGHT)
	stacked.position = Vector2(overlap_left, current_block.position.y)
	stacked.color = current_block.color
	blocks_container.add_child(stacked)

	current_width = overlap_width
	current_x = overlap_left
	stack_height += 1
	move_speed += SPEED_INCREMENT
	GameManager.add_score()

	if stack_height > 8:
		var tween = create_tween()
		tween.tween_property(camera, "position:y", base_y - stack_height * BLOCK_HEIGHT + 400, 0.3)

	if current_width < 20:
		_game_over()
		return

	_spawn_new_block()

func _show_perfect() -> void:
	var label = Label.new()
	label.text = "PERFECT!"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.position = Vector2(screen_width / 2 - 100, current_block.position.y - 60)
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0, 0.8)
	tween.tween_callback(label.queue_free)

func _game_over() -> void:
	await get_tree().create_timer(0.5).timeout
	GameManager.end_game()
