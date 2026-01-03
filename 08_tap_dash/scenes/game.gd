extends Node2D
## Tap Dash: Tap at turns to change direction

const CELL_SIZE = 60
const PLAYER_SPEED = 350.0
const MAX_SPEED = 700.0

@onready var player: ColorRect = $Player
@onready var path_container: Node2D = $PathContainer
@onready var camera: Camera2D = $Camera2D

var current_direction: Vector2 = Vector2.UP
var game_active: bool = false
var game_started: bool = false
var current_speed: float = PLAYER_SPEED
var path_tiles: Array[Vector2i] = []
var current_tile_index: int = 0
var screen_width: float

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	GameManager.start_game("tap_dash")
	_generate_path()
	player.position = _tile_to_world(path_tiles[0])
	camera.position = player.position

func _generate_path() -> void:
	var current_pos = Vector2i(6, 20)
	var direction = Vector2i.UP
	path_tiles.append(current_pos)

	for i in range(500):
		if randf() < 0.3:
			direction = Vector2i.LEFT if randf() < 0.5 else Vector2i.RIGHT if direction.y != 0 else Vector2i.UP
		var next_pos = current_pos + direction
		next_pos.x = clamp(next_pos.x, 1, 10)
		path_tiles.append(next_pos)
		current_pos = next_pos
	_draw_path()

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * CELL_SIZE + CELL_SIZE/2, -tile.y * CELL_SIZE + 1200)

func _draw_path() -> void:
	for i in range(path_tiles.size()):
		var tile = ColorRect.new()
		tile.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
		tile.position = _tile_to_world(path_tiles[i]) - Vector2(CELL_SIZE/2 - 2, CELL_SIZE/2 - 2)
		tile.color = Color("#3d5a80")
		if i > 0 and i < path_tiles.size() - 1:
			var prev_dir = path_tiles[i] - path_tiles[i-1]
			var next_dir = path_tiles[i+1] - path_tiles[i]
			if prev_dir != next_dir:
				tile.color = Color("#ee6c4d")
		path_container.add_child(tile)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if not game_started:
			game_started = true
			game_active = true
		if game_active:
			_try_turn()

func _try_turn() -> void:
	for i in range(current_tile_index + 1, min(current_tile_index + 5, path_tiles.size() - 1)):
		var prev_dir = path_tiles[i] - path_tiles[i-1]
		var next_dir = path_tiles[i+1] - path_tiles[i] if i + 1 < path_tiles.size() else prev_dir
		if prev_dir != next_dir:
			if player.position.distance_to(_tile_to_world(path_tiles[i])) < CELL_SIZE * 1.5:
				current_direction = Vector2(next_dir.x, -next_dir.y).normalized()
				AudioManager.play_sfx("tap")
				return

func _process(delta: float) -> void:
	if not game_active:
		return

	player.position += current_direction * current_speed * delta
	current_speed = min(current_speed + 5 * delta, MAX_SPEED)
	camera.position = camera.position.lerp(player.position + Vector2(0, -200), 5 * delta)

	var on_path = false
	for i in range(max(0, current_tile_index - 2), min(path_tiles.size(), current_tile_index + 5)):
		if player.position.distance_to(_tile_to_world(path_tiles[i])) < CELL_SIZE * 0.7:
			on_path = true
			current_tile_index = max(current_tile_index, i)
			break

	if not on_path:
		_game_over()
		return

	if current_tile_index > GameManager.current_score / 10:
		GameManager.add_score()

func _game_over() -> void:
	if not game_active:
		return
	game_active = false
	AudioManager.play_sfx("hit")
	GameManager.end_game()
