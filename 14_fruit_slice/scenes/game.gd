extends Node2D
## Fruit Slice: Swipe to slice fruits, avoid bombs

const FRUIT_GRAVITY = 800.0
const INITIAL_LIVES = 3
const BOMB_CHANCE = 0.15

@onready var fruits_container: Node2D = $FruitsContainer
@onready var slice_trail: Line2D = $SliceTrail
@onready var lives_label: Label = $LivesLabel

var lives: int = INITIAL_LIVES
var spawn_timer: float = 0.0
var game_active: bool = true
var is_swiping: bool = false
var swipe_points: Array[Vector2] = []
var screen_width: float
var screen_height: float

var fruit_types: Array[Dictionary] = [
	{"color": Color("#ff6b6b"), "size": 60, "points": 10},
	{"color": Color("#ffa502"), "size": 70, "points": 15},
	{"color": Color("#7bed9f"), "size": 50, "points": 10},
	{"color": Color("#eccc68"), "size": 80, "points": 20}
]

func _ready() -> void:
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	GameManager.start_game("fruit_slice")
	_update_lives_display()
	slice_trail.width = 8
	slice_trail.default_color = Color(1, 1, 1, 0.8)

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			is_swiping = true
			swipe_points.clear()
		else:
			is_swiping = false
			swipe_points.clear()
			slice_trail.clear_points()
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and is_swiping):
		if is_swiping:
			swipe_points.append(event.position)
			if swipe_points.size() > 20:
				swipe_points.remove_at(0)
			_update_slice_trail()
			_check_slices(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			is_swiping = true
			swipe_points.clear()
		else:
			is_swiping = false
			swipe_points.clear()
			slice_trail.clear_points()

func _update_slice_trail() -> void:
	slice_trail.clear_points()
	for point in swipe_points:
		slice_trail.add_point(point)

func _check_slices(pos: Vector2) -> void:
	for fruit in fruits_container.get_children():
		if fruit.get_meta("sliced", false):
			continue
		if pos.distance_to(fruit.position) < fruit.get_meta("size", 60):
			_slice_fruit(fruit)

func _slice_fruit(fruit: Node2D) -> void:
	fruit.set_meta("sliced", true)
	if fruit.get_meta("is_bomb", false):
		AudioManager.play_sfx("hit")
		lives -= 1
		_update_lives_display()
		if lives <= 0:
			_game_over()
	else:
		GameManager.add_score(fruit.get_meta("points", 10))
		AudioManager.play_sfx("score")
	fruit.queue_free()

func _update_lives_display() -> void:
	lives_label.text = "Lives: " + "❤".repeat(lives)

func _process(delta: float) -> void:
	if not game_active:
		return

	spawn_timer += delta
	var spawn_interval = lerp(1.2, 0.4, GameManager.current_score / 500.0)
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_fruit()

	for fruit in fruits_container.get_children():
		var vel = fruit.get_meta("velocity") as Vector2
		vel.y += FRUIT_GRAVITY * delta
		fruit.set_meta("velocity", vel)
		fruit.position += vel * delta
		fruit.rotation += 2 * delta

		if fruit.position.y > screen_height + 100:
			if not fruit.get_meta("sliced", false) and not fruit.get_meta("is_bomb", false):
				lives -= 1
				_update_lives_display()
				if lives <= 0:
					_game_over()
			fruit.queue_free()

func _spawn_fruit() -> void:
	var is_bomb = randf() < BOMB_CHANCE
	var fruit = Node2D.new()
	var sprite = ColorRect.new()

	if is_bomb:
		sprite.size = Vector2(70, 70)
		sprite.position = Vector2(-35, -35)
		sprite.color = Color("#2d3436")
		fruit.set_meta("is_bomb", true)
		fruit.set_meta("size", 70)
	else:
		var fruit_type = fruit_types[randi() % fruit_types.size()]
		sprite.size = Vector2(fruit_type.size, fruit_type.size)
		sprite.position = -sprite.size / 2
		sprite.color = fruit_type.color
		fruit.set_meta("points", fruit_type.points)
		fruit.set_meta("size", fruit_type.size)
		fruit.set_meta("is_bomb", false)

	fruit.add_child(sprite)
	fruit.position = Vector2(randf_range(100, screen_width - 100), screen_height + 50)
	fruit.set_meta("velocity", Vector2(randf_range(-100, 100), randf_range(-900, -700)))
	fruit.set_meta("sliced", false)
	fruits_container.add_child(fruit)

func _game_over() -> void:
	game_active = false
	GameManager.end_game()
