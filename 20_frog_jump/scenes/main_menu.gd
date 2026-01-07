extends Control
## Main Menu for Frog Jump

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var title_label: Label = $TitleLabel
@onready var frog_icon: Label = $FrogIcon
@onready var best_score_label: Label = $BestScoreLabel

# Animated frogs in background
var bg_frogs: Array[Dictionary] = []
const NUM_BG_FROGS = 5

# Lily pads
var lily_pads: Array[Dictionary] = []
const NUM_LILY_PADS = 8

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)

	# Update best score
	best_score_label.text = "BEST: " + str(GameManager.high_score)

	# Create background elements
	_create_lily_pads()
	_create_bg_frogs()

	# Animate title
	_animate_entrance()

func _create_lily_pads() -> void:
	for i in range(NUM_LILY_PADS):
		lily_pads.append({
			"x": randf() * 720,
			"y": randf_range(400, 1200),
			"size": randf_range(40, 80),
			"rotation": randf() * TAU
		})

func _create_bg_frogs() -> void:
	for i in range(NUM_BG_FROGS):
		bg_frogs.append({
			"x": randf() * 720,
			"y": randf_range(500, 1100),
			"scale": randf_range(0.3, 0.6),
			"jump_timer": randf() * 3.0,
			"jump_offset": 0.0,
			"direction": 1 if randf() > 0.5 else -1
		})

func _animate_entrance() -> void:
	# Title animation
	title_label.modulate.a = 0
	title_label.position.y -= 50
	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(title_label, "position:y", title_label.position.y + 50, 0.5).set_trans(Tween.TRANS_BACK)

	# Frog icon bounce
	frog_icon.scale = Vector2.ZERO
	var tween2 = create_tween()
	tween2.tween_interval(0.3)
	tween2.tween_property(frog_icon, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC)

	# Button fade in
	play_button.modulate.a = 0
	var tween3 = create_tween()
	tween3.tween_interval(0.5)
	tween3.tween_property(play_button, "modulate:a", 1.0, 0.3)

func _process(delta: float) -> void:
	# Animate background frogs
	for frog_data in bg_frogs:
		frog_data.jump_timer -= delta
		if frog_data.jump_timer <= 0:
			frog_data.jump_timer = randf_range(2.0, 4.0)
			frog_data.jump_offset = 30.0
			frog_data.x += frog_data.direction * randf_range(30, 80)
			frog_data.direction *= -1 if randf() > 0.7 else 1
			frog_data.x = clamp(frog_data.x, 50, 670)

		# Decay jump offset
		frog_data.jump_offset = lerp(frog_data.jump_offset, 0.0, delta * 5.0)

	# Frog icon subtle bounce
	var bounce = sin(Time.get_ticks_msec() / 500.0) * 5
	frog_icon.position.y = 250 + bounce

	queue_redraw()

func _draw() -> void:
	# Draw water background
	draw_rect(Rect2(0, 300, 720, 980), Color(0.255, 0.412, 0.882, 0.3))

	# Draw lily pads
	for pad in lily_pads:
		_draw_lily_pad(Vector2(pad.x, pad.y), pad.size, pad.rotation)

	# Draw background frogs
	for frog_data in bg_frogs:
		_draw_mini_frog(
			Vector2(frog_data.x, frog_data.y - frog_data.jump_offset),
			frog_data.scale,
			frog_data.direction
		)

func _draw_lily_pad(pos: Vector2, size: float, rot: float) -> void:
	var points = PackedVector2Array()
	for i in range(8):
		var angle = rot + (float(i) / 8) * TAU
		var r = size * (0.8 + sin(angle * 3) * 0.2)
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)

	draw_colored_polygon(points, Color(0.0, 0.4, 0.0, 0.5))

func _draw_mini_frog(pos: Vector2, scale: float, direction: int) -> void:
	var s = 30 * scale

	# Body
	var body = PackedVector2Array([
		pos + Vector2(-s, s * 0.3),
		pos + Vector2(-s * 0.8, -s * 0.5),
		pos + Vector2(0, -s * 0.8),
		pos + Vector2(s * 0.8, -s * 0.5),
		pos + Vector2(s, s * 0.3),
		pos + Vector2(0, s * 0.5)
	])
	draw_colored_polygon(body, Color(0.133, 0.545, 0.133, 0.7))

	# Eyes
	draw_circle(pos + Vector2(-s * 0.4, -s * 0.6), s * 0.25, Color(1, 1, 1, 0.8))
	draw_circle(pos + Vector2(s * 0.4, -s * 0.6), s * 0.25, Color(1, 1, 1, 0.8))
	draw_circle(pos + Vector2(-s * 0.4, -s * 0.6), s * 0.12, Color(0, 0, 0, 0.8))
	draw_circle(pos + Vector2(s * 0.4, -s * 0.6), s * 0.12, Color(0, 0, 0, 0.8))

func _on_play_pressed() -> void:
	AudioManager.play_sfx("tap")
	get_tree().change_scene_to_file("res://scenes/game.tscn")
