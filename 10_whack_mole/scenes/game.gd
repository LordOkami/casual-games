extends Control
## Whack-a-Mole: Tap moles quickly before time runs out

const GRID_COLS = 3
const GRID_ROWS = 4
const HOLE_SIZE = 180
const GAME_DURATION = 60.0

@onready var holes_container: Control = $HolesContainer
@onready var timer_label: Label = $TimerLabel

var holes: Array[Control] = []
var active_moles: Dictionary = {}
var spawn_timer: float = 0.0
var current_spawn_time: float = 1.2
var time_remaining: float = GAME_DURATION
var game_active: bool = true
var screen_width: float

enum MoleType { NORMAL, GOLDEN, BOMB }

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	GameManager.start_game("whack_mole")
	_create_holes()

func _create_holes() -> void:
	var start_x = (screen_width - GRID_COLS * HOLE_SIZE) / 2
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var hole = Control.new()
			hole.size = Vector2(HOLE_SIZE, HOLE_SIZE)
			hole.position = Vector2(start_x + col * HOLE_SIZE, 300 + row * HOLE_SIZE)

			var bg = ColorRect.new()
			bg.size = Vector2(HOLE_SIZE - 20, HOLE_SIZE - 20)
			bg.position = Vector2(10, 10)
			bg.color = Color("#3d2817")
			hole.add_child(bg)

			var mole = ColorRect.new()
			mole.name = "Mole"
			mole.size = Vector2(100, 100)
			mole.position = Vector2(40, 40)
			mole.color = Color("#8b5a2b")
			mole.visible = false
			hole.add_child(mole)

			var btn = Button.new()
			btn.flat = true
			btn.size = Vector2(HOLE_SIZE, HOLE_SIZE)
			btn.modulate.a = 0
			btn.pressed.connect(_on_hole_clicked.bind(holes.size()))
			hole.add_child(btn)

			holes.append(hole)
			holes_container.add_child(hole)

func _on_hole_clicked(index: int) -> void:
	if not game_active:
		return
	if active_moles.has(index):
		var mole_data = active_moles[index]
		var points = 10 if mole_data.type == MoleType.NORMAL else 50 if mole_data.type == MoleType.GOLDEN else -30
		GameManager.add_score(points)
		holes[index].get_node("Mole").visible = false
		active_moles.erase(index)
		AudioManager.play_sfx("tap")
	else:
		GameManager.add_score(-5)

func _process(delta: float) -> void:
	if not game_active:
		return

	time_remaining -= delta
	timer_label.text = "TIME: " + str(int(time_remaining))

	if time_remaining <= 0:
		game_active = false
		GameManager.end_game()
		return

	var progress = 1.0 - (time_remaining / GAME_DURATION)
	current_spawn_time = lerp(1.2, 0.4, progress)

	spawn_timer += delta
	if spawn_timer >= current_spawn_time:
		spawn_timer = 0.0
		_spawn_mole()

	var to_remove: Array[int] = []
	for index in active_moles:
		active_moles[index].time -= delta
		if active_moles[index].time <= 0:
			to_remove.append(index)

	for index in to_remove:
		holes[index].get_node("Mole").visible = false
		active_moles.erase(index)

func _spawn_mole() -> void:
	var empty: Array[int] = []
	for i in range(holes.size()):
		if not active_moles.has(i):
			empty.append(i)
	if empty.is_empty():
		return

	var index = empty[randi() % empty.size()]
	var mole = holes[index].get_node("Mole")

	var mole_type = MoleType.NORMAL
	var rand = randf()
	if rand < 0.1:
		mole_type = MoleType.GOLDEN
		mole.color = Color.GOLD
	elif rand < 0.2:
		mole_type = MoleType.BOMB
		mole.color = Color("#333333")
	else:
		mole.color = Color("#8b5a2b")

	active_moles[index] = {"type": mole_type, "time": lerp(1.5, 0.5, 1.0 - time_remaining / GAME_DURATION)}
	mole.visible = true
