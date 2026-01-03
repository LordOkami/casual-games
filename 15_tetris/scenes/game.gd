extends Control
## Tetris: Classic falling blocks puzzle

const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const CELL_SIZE = 35
const INITIAL_DROP_TIME = 0.8
const MIN_DROP_TIME = 0.1

@onready var grid_container: Control = $GridContainer
@onready var next_container: Control = $NextContainer

var grid: Array = []
var current_piece: Dictionary = {}
var next_piece: Dictionary = {}
var current_pos: Vector2i = Vector2i.ZERO
var drop_timer: float = 0.0
var current_drop_time: float = INITIAL_DROP_TIME
var game_active: bool = true
var lines_cleared: int = 0
var swipe_start: Vector2 = Vector2.ZERO
var last_tap_time: float = 0.0

var PIECES: Array[Dictionary] = [
	{"shape": [[0,0], [1,0], [0,1], [1,1]], "color": Color("#f1c40f")},
	{"shape": [[0,0], [1,0], [2,0], [3,0]], "color": Color("#3498db")},
	{"shape": [[0,0], [1,0], [2,0], [1,1]], "color": Color("#9b59b6")},
	{"shape": [[0,0], [0,1], [1,1], [2,1]], "color": Color("#e74c3c")},
	{"shape": [[2,0], [0,1], [1,1], [2,1]], "color": Color("#e67e22")},
	{"shape": [[1,0], [2,0], [0,1], [1,1]], "color": Color("#2ecc71")},
	{"shape": [[0,0], [1,0], [1,1], [2,1]], "color": Color("#e91e63")}
]

func _ready() -> void:
	GameManager.start_game("tetris")
	_init_grid()
	_spawn_next_piece()
	_spawn_piece()

func _init_grid() -> void:
	grid = []
	for x in range(GRID_WIDTH):
		grid.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(null)

func _spawn_next_piece() -> void:
	next_piece = PIECES[randi() % PIECES.size()].duplicate(true)
	_update_next_display()

func _spawn_piece() -> void:
	current_piece = next_piece.duplicate(true)
	current_pos = Vector2i(GRID_WIDTH / 2 - 1, 0)
	_spawn_next_piece()
	if not _is_valid_position(current_pos, current_piece.shape):
		game_active = false
		GameManager.end_game()

func _update_next_display() -> void:
	for child in next_container.get_children():
		if child.name != "Label":
			child.queue_free()
	for cell in next_piece.shape:
		var block = ColorRect.new()
		block.size = Vector2(25, 25)
		block.position = Vector2(cell[0] * 27 + 20, cell[1] * 27 + 40)
		block.color = next_piece.color
		next_container.add_child(block)

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
			last_tap_time = Time.get_ticks_msec()
		else:
			var delta = event.position - swipe_start
			var duration = Time.get_ticks_msec() - last_tap_time
			if delta.length() < 30 and duration < 200:
				_rotate_piece()
			elif abs(delta.x) > abs(delta.y):
				_move_piece(1 if delta.x > 30 else -1 if delta.x < -30 else 0)
			elif delta.y > 50:
				_hard_drop()

func _move_piece(dir: int) -> void:
	if dir == 0:
		return
	var new_pos = current_pos + Vector2i(dir, 0)
	if _is_valid_position(new_pos, current_piece.shape):
		current_pos = new_pos
		AudioManager.play_sfx("tap")
		_update_display()

func _rotate_piece() -> void:
	var new_shape: Array = []
	for cell in current_piece.shape:
		new_shape.append([cell[1], -cell[0] + 2])
	if _is_valid_position(current_pos, new_shape):
		current_piece.shape = new_shape
		AudioManager.play_sfx("tap")
		_update_display()

func _hard_drop() -> void:
	while _is_valid_position(current_pos + Vector2i(0, 1), current_piece.shape):
		current_pos.y += 1
		GameManager.add_score(2)
	_lock_piece()

func _is_valid_position(pos: Vector2i, shape: Array) -> bool:
	for cell in shape:
		var x = pos.x + cell[0]
		var y = pos.y + cell[1]
		if x < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT:
			return false
		if y >= 0 and grid[x][y] != null:
			return false
	return true

func _lock_piece() -> void:
	for cell in current_piece.shape:
		var x = current_pos.x + cell[0]
		var y = current_pos.y + cell[1]
		if y >= 0:
			grid[x][y] = current_piece.color
	_clear_lines()
	_spawn_piece()
	_update_display()

func _clear_lines() -> void:
	var lines: Array[int] = []
	for y in range(GRID_HEIGHT):
		var full = true
		for x in range(GRID_WIDTH):
			if grid[x][y] == null:
				full = false
				break
		if full:
			lines.append(y)

	if lines.is_empty():
		return

	AudioManager.play_sfx("score")
	for clear_y in lines:
		for y in range(clear_y, 0, -1):
			for x in range(GRID_WIDTH):
				grid[x][y] = grid[x][y - 1]
		for x in range(GRID_WIDTH):
			grid[x][0] = null

	lines_cleared += lines.size()
	GameManager.add_score([0, 100, 300, 500, 800][min(lines.size(), 4)])
	current_drop_time = max(MIN_DROP_TIME, INITIAL_DROP_TIME - lines_cleared * 0.02)

func _process(delta: float) -> void:
	if not game_active:
		return
	drop_timer += delta
	if drop_timer >= current_drop_time:
		drop_timer = 0.0
		var new_pos = current_pos + Vector2i(0, 1)
		if _is_valid_position(new_pos, current_piece.shape):
			current_pos = new_pos
			_update_display()
		else:
			_lock_piece()

func _update_display() -> void:
	for child in grid_container.get_children():
		if child.name != "Background":
			child.queue_free()

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] != null:
				var block = ColorRect.new()
				block.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
				block.position = Vector2(x * CELL_SIZE + 1, y * CELL_SIZE + 1)
				block.color = grid[x][y]
				grid_container.add_child(block)

	for cell in current_piece.shape:
		var x = current_pos.x + cell[0]
		var y = current_pos.y + cell[1]
		if y >= 0:
			var block = ColorRect.new()
			block.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			block.position = Vector2(x * CELL_SIZE + 1, y * CELL_SIZE + 1)
			block.color = current_piece.color
			grid_container.add_child(block)
