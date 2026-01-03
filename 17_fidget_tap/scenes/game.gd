extends Control
## FidgetTap: Main game scene
## A satisfying fidget clicker with haptic feedback and visual effects

@onready var game_ui: CanvasLayer = $GameUI
@onready var background: ColorRect = $Background
@onready var tap_button: Control = $TapButton
@onready var outer_ring: ColorRect = $TapButton/OuterRing
@onready var inner_circle: ColorRect = $TapButton/InnerCircle
@onready var pulse_ring: ColorRect = $TapButton/PulseRing
@onready var ripple_container: Control = $RippleContainer

## Zen mode state
var zen_mode: bool = false

## Tap tracking for pattern detection
var _last_tap_time: float = 0.0
var _tap_count_in_window: int = 0
var _long_press_timer: float = 0.0
var _is_pressing: bool = false

## Color gradient based on tap speed (cool → warm)
const COLOR_GRADIENT: Array = [
	Color("#62c5d3"),  # Teal (cool/slow) - primary color
	Color("#4dd0e1"),  # Light cyan
	Color("#80deea"),  # Lighter cyan
	Color("#26c6da"),  # Teal
	Color("#00acc1"),  # Dark cyan
	Color("#00897b"),  # Teal
	Color("#43a047"),  # Green
	Color("#7cb342"),  # Light green
	Color("#c0ca33"),  # Lime
	Color("#fdd835"),  # Yellow
	Color("#ffb300"),  # Amber
	Color("#fb8c00"),  # Orange
	Color("#f4511e"),  # Deep orange
	Color("#e53935"),  # Red (warm/fast)
]

## Zen mode ambient colors
const ZEN_COLORS: Array = [
	Color("#1a237e"),  # Deep indigo
	Color("#283593"),  # Indigo
	Color("#303f9f"),  # Mid indigo
	Color("#3949ab"),  # Light indigo
	Color("#1e88e5"),  # Blue
	Color("#039be5"),  # Light blue
	Color("#00acc1"),  # Cyan
	Color("#00897b"),  # Teal
	Color("#43a047"),  # Green
	Color("#7cb342"),  # Light green
]

var _current_color_index: int = 0
var _zen_color_timer: float = 0.0
const ZEN_COLOR_TRANSITION_TIME: float = 3.0

## Tap speed thresholds
const DOUBLE_TAP_THRESHOLD: float = 0.3
const LONG_PRESS_THRESHOLD: float = 0.5
const RAPID_TAP_THRESHOLD: int = 5  ## Taps within 1 second
const RAPID_TAP_WINDOW: float = 1.0

func _ready() -> void:
	# Check for zen mode flag
	if FileAccess.file_exists("user://zen_mode.tmp"):
		zen_mode = true
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("zen_mode.tmp")

	_setup_visuals()
	GameManager.start_game("fidget_tap")

func _setup_visuals() -> void:
	if zen_mode:
		background.color = ZEN_COLORS[0]
		outer_ring.color = Color(1, 1, 1, 0.1)
		inner_circle.color = Color(1, 1, 1, 0.2)
	else:
		background.color = Color(0.1, 0.1, 0.14)
		outer_ring.color = COLOR_GRADIENT[0]
		inner_circle.color = COLOR_GRADIENT[0].lightened(0.2)

	pulse_ring.color = Color(1, 1, 1, 0)
	pulse_ring.visible = true

func _process(delta: float) -> void:
	# Handle long press detection
	if _is_pressing:
		_long_press_timer += delta
		if _long_press_timer >= LONG_PRESS_THRESHOLD:
			_trigger_long_press()
			_long_press_timer = 0.0

	# Zen mode color shifting
	if zen_mode:
		_zen_color_timer += delta
		if _zen_color_timer >= ZEN_COLOR_TRANSITION_TIME:
			_zen_color_timer = 0.0
			_shift_zen_colors()

	# Decay rapid tap counter
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_tap_time > RAPID_TAP_WINDOW:
		_tap_count_in_window = 0

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	# Handle touch/mouse press
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press_start(event.position)
		else:
			_on_press_end()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press_start(event.position)
			else:
				_on_press_end()

func _on_press_start(position: Vector2) -> void:
	_is_pressing = true
	_long_press_timer = 0.0

	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last = current_time - _last_tap_time

	# Detect tap patterns
	if time_since_last < DOUBLE_TAP_THRESHOLD and _tap_count_in_window >= 1:
		# Double tap
		_trigger_double_tap()
	else:
		# Single tap
		_trigger_single_tap()

	_last_tap_time = current_time
	_tap_count_in_window += 1

	# Check for rapid taps
	if _tap_count_in_window >= RAPID_TAP_THRESHOLD:
		_trigger_rapid_taps()
		_tap_count_in_window = 0

	# Visual feedback
	_animate_tap_button()
	_spawn_ripple(position)
	_update_color_by_speed()

	# Record stats
	FidgetStats.record_tap()
	game_ui.animate_tap()

func _on_press_end() -> void:
	_is_pressing = false
	_long_press_timer = 0.0

func _trigger_single_tap() -> void:
	HapticFeedback.light_impact()
	AudioManager.play_sfx("soft_tap")

func _trigger_double_tap() -> void:
	HapticFeedback.medium_impact()
	AudioManager.play_sfx("medium_tap")

func _trigger_long_press() -> void:
	HapticFeedback.heavy_impact()
	HapticFeedback.rumble_pattern(2, 100)
	AudioManager.play_sfx("heavy_tap")
	_animate_heavy_pulse()

func _trigger_rapid_taps() -> void:
	HapticFeedback.success_notification()
	AudioManager.play_sfx("score")
	_animate_success_burst()

func _animate_tap_button() -> void:
	var tween = create_tween()
	tween.set_parallel(true)

	# Scale down then up
	tween.tween_property(tap_button, "scale", Vector2(0.9, 0.9), 0.05)
	tween.chain().tween_property(tap_button, "scale", Vector2(1.05, 1.05), 0.08)
	tween.chain().tween_property(tap_button, "scale", Vector2(1.0, 1.0), 0.1)

	# Pulse the outer ring
	_animate_pulse_ring()

func _animate_pulse_ring() -> void:
	pulse_ring.scale = Vector2(1.0, 1.0)
	pulse_ring.color = Color(1, 1, 1, 0.5)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse_ring, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(pulse_ring, "color:a", 0.0, 0.3)

func _animate_heavy_pulse() -> void:
	var tween = create_tween()
	tween.tween_property(tap_button, "scale", Vector2(0.85, 0.85), 0.1)
	tween.tween_property(tap_button, "scale", Vector2(1.15, 1.15), 0.15)
	tween.tween_property(tap_button, "scale", Vector2(1.0, 1.0), 0.2)

func _animate_success_burst() -> void:
	# Create multiple expanding rings
	for i in range(3):
		var delay = i * 0.1
		await get_tree().create_timer(delay).timeout
		_animate_pulse_ring()

func _spawn_ripple(position: Vector2) -> void:
	var ripple = ColorRect.new()
	ripple.size = Vector2(20, 20)
	ripple.position = position - Vector2(10, 10)
	ripple.color = inner_circle.color
	ripple.pivot_offset = Vector2(10, 10)

	# Make it circular using a shader or just use transparency
	ripple.modulate.a = 0.6

	ripple_container.add_child(ripple)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2(8, 8), 0.5)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(ripple.queue_free)

func _update_color_by_speed() -> void:
	if zen_mode:
		return

	var stats = FidgetStats.get_all_stats()
	var streak = stats.current_streak

	# Map streak to color index
	var color_index = clampi(streak - 1, 0, COLOR_GRADIENT.size() - 1)

	if color_index != _current_color_index:
		_current_color_index = color_index
		var target_color = COLOR_GRADIENT[color_index]

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(outer_ring, "color", target_color, 0.2)
		tween.tween_property(inner_circle, "color", target_color.lightened(0.2), 0.2)

func _shift_zen_colors() -> void:
	var next_index = (_current_color_index + 1) % ZEN_COLORS.size()
	var next_color = ZEN_COLORS[next_index]
	_current_color_index = next_index

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(background, "color", next_color, ZEN_COLOR_TRANSITION_TIME)
