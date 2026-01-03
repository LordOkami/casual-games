extends Control
## 2048: Slide tiles to combine matching numbers

const GRID_SIZE = 4
const CELL_SIZE = 150
const CELL_MARGIN = 10

@onready var grid_container: Control = $GridContainer
@onready var tiles_container: Control = $GridContainer/TilesContainer

var grid: Array = []
var game_active: bool = true
var swipe_start: Vector2 = Vector2.ZERO

var tile_colors: Dictionary = {
	2: Color("#eee4da"), 4: Color("#ede0c8"), 8: Color("#f2b179"),
	16: Color("#f59563"), 32: Color("#f67c5f"), 64: Color("#f65e3b"),
	128: Color("#edcf72"), 256: Color("#edcc61"), 512: Color("#edc850"),
	1024: Color("#edc53f"), 2048: Color("#edc22e")
}

func _ready() -> void:
	GameManager.start_game("2048")
	_init_grid()
	_spawn_tile()
	_spawn_tile()

func _init_grid() -> void:
	grid = []
	for x in range(GRID_SIZE):
		grid.append([])
		for y in range(GRID_SIZE):
			grid[x].append(0)
			var cell = ColorRect.new()
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.position = Vector2(x * (CELL_SIZE + CELL_MARGIN) + CELL_MARGIN, y * (CELL_SIZE + CELL_MARGIN) + CELL_MARGIN)
			cell.color = Color("#cdc1b4")
			grid_container.add_child(cell)

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
		else:
			_handle_swipe(event.position - swipe_start)
	elif event is InputEventMouseButton:
		if event.pressed:
			swipe_start = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_swipe(event.position - swipe_start)

func _handle_swipe(direction: Vector2) -> void:
	if direction.length() < 50:
		return
	if abs(direction.x) > abs(direction.y):
		_move_tiles(Vector2.RIGHT if direction.x > 0 else Vector2.LEFT)
	else:
		_move_tiles(Vector2.DOWN if direction.y > 0 else Vector2.UP)

func _move_tiles(direction: Vector2) -> void:
	var moved = false
	var merged: Array = []
	for i in range(GRID_SIZE):
		merged.append([false, false, false, false])

	var x_range = range(GRID_SIZE) if direction != Vector2.RIGHT else range(GRID_SIZE - 1, -1, -1)
	var y_range = range(GRID_SIZE) if direction != Vector2.DOWN else range(GRID_SIZE - 1, -1, -1)

	for y in y_range:
		for x in x_range:
			if grid[x][y] == 0:
				continue
			var new_x = x
			var new_y = y
			while true:
				var next_x = new_x + int(direction.x)
				var next_y = new_y + int(direction.y)
				if next_x < 0 or next_x >= GRID_SIZE or next_y < 0 or next_y >= GRID_SIZE:
					break
				if grid[next_x][next_y] == 0:
					new_x = next_x
					new_y = next_y
				elif grid[next_x][next_y] == grid[x][y] and not merged[next_x][next_y]:
					new_x = next_x
					new_y = next_y
					merged[new_x][new_y] = true
					break
				else:
					break
			if new_x != x or new_y != y:
				moved = true
				if grid[new_x][new_y] == grid[x][y]:
					grid[new_x][new_y] *= 2
					GameManager.add_score(grid[new_x][new_y])
				else:
					grid[new_x][new_y] = grid[x][y]
				grid[x][y] = 0

	if moved:
		AudioManager.play_sfx("tap")
		_update_visuals()
		await get_tree().create_timer(0.15).timeout
		_spawn_tile()
		if _check_game_over():
			game_active = false
			GameManager.end_game()

func _spawn_tile() -> void:
	var empty: Array = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid[x][y] == 0:
				empty.append(Vector2(x, y))
	if empty.is_empty():
		return
	var cell = empty[randi() % empty.size()]
	grid[int(cell.x)][int(cell.y)] = 2 if randf() < 0.9 else 4
	_update_visuals()

func _update_visuals() -> void:
	for child in tiles_container.get_children():
		child.queue_free()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid[x][y] > 0:
				var tile = ColorRect.new()
				tile.size = Vector2(CELL_SIZE, CELL_SIZE)
				tile.position = Vector2(x * (CELL_SIZE + CELL_MARGIN) + CELL_MARGIN, y * (CELL_SIZE + CELL_MARGIN) + CELL_MARGIN)
				tile.color = tile_colors.get(grid[x][y], Color("#3c3a32"))
				var label = Label.new()
				label.text = str(grid[x][y])
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.size = tile.size
				label.add_theme_font_size_override("font_size", 48 if grid[x][y] < 1000 else 36)
				label.add_theme_color_override("font_color", Color("#776e65") if grid[x][y] < 8 else Color.WHITE)
				tile.add_child(label)
				tiles_container.add_child(tile)

func _check_game_over() -> bool:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid[x][y] == 0:
				return false
			if x < GRID_SIZE - 1 and grid[x + 1][y] == grid[x][y]:
				return false
			if y < GRID_SIZE - 1 and grid[x][y + 1] == grid[x][y]:
				return false
	return true
