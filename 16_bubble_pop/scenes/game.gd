extends Control
## Bubble Pop: Tap rising bubbles before they escape!
## Different bubble sizes give different points
## Combo system rewards quick consecutive pops

const SCREEN_WIDTH = 720
const SCREEN_HEIGHT = 1280
const SPAWN_AREA_TOP = 1200
const ESCAPE_LINE = 150
const MAX_ESCAPED = 5

# Bubble sizes and their properties
const BUBBLE_SIZES = {
	"small": {"radius": 35, "points": 3, "speed_mult": 1.3},
	"medium": {"radius": 55, "points": 2, "speed_mult": 1.0},
	"large": {"radius": 80, "points": 1, "speed_mult": 0.7}
}

# Bubble colors
const BUBBLE_COLORS = [
	Color("#e63946"),  # Red
	Color("#2a9d8f"),  # Teal
	Color("#e9c46a"),  # Yellow
	Color("#9c27b0"),  # Purple
	Color("#00bcd4"),  # Cyan
	Color("#ff9800"),  # Orange
]

const GOLDEN_COLOR = Color("#ffd700")

@onready var bubbles_container: Control = $BubblesContainer
@onready var escaped_label: Label = $EscapedLabel
@onready var combo_label: Label = $ComboLabel

var bubbles: Array = []
var base_speed: float = 120.0
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2
var game_active: bool = true
var escaped_count: int = 0
var game_time: float = 0.0

# Combo system
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT = 1.0

func _ready() -> void:
	GameManager.start_game("bubble_pop")
	_update_escaped_display()
	combo_label.modulate.a = 0.0

func _process(delta: float) -> void:
	if not game_active:
		return

	game_time += delta

	# Update difficulty over time
	_update_difficulty()

	# Spawn bubbles
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_bubble()

	# Update combo timer
	if combo_count > 0:
		combo_timer += delta
		if combo_timer >= COMBO_TIMEOUT:
			_reset_combo()

	# Move bubbles and check for escapes
	var to_remove: Array = []
	for bubble in bubbles:
		if not is_instance_valid(bubble):
			to_remove.append(bubble)
			continue

		bubble.position.y -= bubble.get_meta("speed") * delta

		# Check if bubble escaped
		if bubble.position.y < ESCAPE_LINE:
			to_remove.append(bubble)
			_bubble_escaped(bubble)

	for bubble in to_remove:
		_remove_bubble(bubble)

func _update_difficulty() -> void:
	# Increase speed and spawn rate over time
	var progress = min(game_time / 120.0, 1.0)  # Max difficulty at 2 minutes
	base_speed = lerp(120.0, 220.0, progress)
	spawn_interval = lerp(1.2, 0.4, progress)

func _spawn_bubble() -> void:
	var bubble = Control.new()

	# Determine bubble type
	var size_type: String
	var rand = randf()
	if rand < 0.3:
		size_type = "small"
	elif rand < 0.7:
		size_type = "medium"
	else:
		size_type = "large"

	var props = BUBBLE_SIZES[size_type]
	var radius = props.radius
	var points = props.points
	var speed = base_speed * props.speed_mult

	# Check for golden bubble (10% chance)
	var is_golden = randf() < 0.1
	if is_golden:
		points = 10

	# Set bubble size
	bubble.size = Vector2(radius * 2, radius * 2)
	bubble.custom_minimum_size = bubble.size

	# Random X position with margin
	var margin = radius + 20
	var x_pos = randf_range(margin, SCREEN_WIDTH - margin)
	bubble.position = Vector2(x_pos - radius, SPAWN_AREA_TOP)

	# Store metadata
	bubble.set_meta("speed", speed)
	bubble.set_meta("points", points)
	bubble.set_meta("radius", radius)
	bubble.set_meta("is_golden", is_golden)

	# Create the bubble visual (circle shape)
	var color_rect = ColorRect.new()
	color_rect.name = "BubbleVisual"
	color_rect.size = Vector2(radius * 2, radius * 2)

	if is_golden:
		color_rect.color = GOLDEN_COLOR
	else:
		color_rect.color = BUBBLE_COLORS[randi() % BUBBLE_COLORS.size()]

	bubble.add_child(color_rect)

	# Add shine effect (small white circle)
	var shine = ColorRect.new()
	shine.name = "Shine"
	shine.size = Vector2(radius * 0.4, radius * 0.4)
	shine.position = Vector2(radius * 0.3, radius * 0.3)
	shine.color = Color(1, 1, 1, 0.5)
	bubble.add_child(shine)

	# Add clickable button
	var btn = Button.new()
	btn.flat = true
	btn.size = Vector2(radius * 2, radius * 2)
	btn.modulate.a = 0
	btn.pressed.connect(_on_bubble_clicked.bind(bubble))
	bubble.add_child(btn)

	bubbles.append(bubble)
	bubbles_container.add_child(bubble)

	# Spawn animation
	bubble.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _on_bubble_clicked(bubble: Control) -> void:
	if not game_active:
		return
	if not is_instance_valid(bubble):
		return

	var points = bubble.get_meta("points")
	var is_golden = bubble.get_meta("is_golden")

	# Increment combo
	combo_count += 1
	combo_timer = 0.0

	# Calculate final points with combo bonus
	var combo_bonus = 0
	if combo_count >= 3:
		combo_bonus = combo_count - 2
		points += combo_bonus
		_show_combo()

	GameManager.add_score(points)

	# Play appropriate sound
	if is_golden:
		AudioManager.play_sfx("combo")
	else:
		AudioManager.play_sfx("pop")

	# Create pop effect
	_create_pop_effect(bubble)

	# Remove bubble
	_remove_bubble(bubble)

func _show_combo() -> void:
	combo_label.text = "COMBO x" + str(combo_count)
	combo_label.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.1)

func _reset_combo() -> void:
	combo_count = 0
	var tween = create_tween()
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.3)

func _bubble_escaped(bubble: Control) -> void:
	escaped_count += 1
	_update_escaped_display()
	AudioManager.play_sfx("hit")

	if escaped_count >= MAX_ESCAPED:
		game_active = false
		GameManager.end_game()

func _update_escaped_display() -> void:
	escaped_label.text = "Escaped: " + str(escaped_count) + "/" + str(MAX_ESCAPED)

	# Flash red when close to losing
	if escaped_count >= MAX_ESCAPED - 2:
		escaped_label.modulate = Color.RED
	elif escaped_count >= MAX_ESCAPED - 3:
		escaped_label.modulate = Color.ORANGE

func _create_pop_effect(bubble: Control) -> void:
	var pos = bubble.position + bubble.size / 2
	var radius = bubble.get_meta("radius")
	var color = bubble.get_node("BubbleVisual").color

	# Create particle-like pop effect
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.color = color
		particle.position = pos - Vector2(6, 6)
		bubbles_container.add_child(particle)

		# Random direction
		var angle = (TAU / 6) * i + randf_range(-0.3, 0.3)
		var distance = radius * 1.5
		var target_pos = pos + Vector2(cos(angle), sin(angle)) * distance

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_pos - Vector2(6, 6), 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_property(particle, "scale", Vector2(0.1, 0.1), 0.3)
		tween.chain().tween_callback(particle.queue_free)

func _remove_bubble(bubble: Control) -> void:
	if bubble in bubbles:
		bubbles.erase(bubble)
	if is_instance_valid(bubble):
		bubble.queue_free()
